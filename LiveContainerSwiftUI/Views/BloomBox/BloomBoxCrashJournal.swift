// SPDX-License-Identifier: AGPL-3.0-only
// BloomBox diagnostics: local breadcrumbs and post-restart recovery.
// Never writes guest paths, certificates, tokens, or user files to diagnostics.
import Foundation
import SwiftUI
import MetricKit
import Darwin

/// Lightweight persistent journal. A process killed by iOS cannot execute a
/// Swift crash callback, so an unfinished foreground GameBox session is a
/// *suspected interruption*, never proof of a native exception.
final class BloomBoxCrashJournal: ObservableObject {
    static let shared = BloomBoxCrashJournal()

    @Published private(set) var previousInterrupted = false
    @Published private(set) var revision = 0

    private let runningKey = "BloomBoxGameBoxForegroundSession"
    private let interruptedKey = "BloomBoxGameBoxPreviousInterruption"
    private let defaults = LiveContainerPreferencesAdapter.defaults
    private let lock = NSLock()
    private var started = false
    private let maxLogBytes = 256 * 1024

    private init() {}

    private var folder: URL? {
        LiveContainerDiagnosticsAdapter.sharedDirectory
    }

    private func ensureFolder() -> URL? {
        guard let folder else { return nil }
        do {
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            return folder
        } catch {
            return nil
        }
    }

    /// Called at host start, before the launcher's preference reset.
    func beginHostSession() {
        guard !started else { return }
        started = true
        let interrupted = defaults.bool(forKey: runningKey)
        defaults.set(false, forKey: runningKey)
        defaults.set(interrupted, forKey: interruptedKey)
        previousInterrupted = interrupted
        if interrupted {
            // Safe graphics on next launch; user can re-enable full artwork.
            defaults.set(true, forKey: "BloomBoxGameBoxSafeGraphics")
        }
        trimOldLogs()
        record(interrupted ? "host.restarted.after.foreground.interruption" : "host.started")
    }

    func enterGameBox() {
        defaults.set(true, forKey: runningKey)
        record("gamebox.visible")
    }

    func leaveGameBox() {
        defaults.set(false, forKey: runningKey)
        record("gamebox.left")
    }

    func wentToBackground() {
        defaults.set(false, forKey: runningKey)
        record("host.background")
    }

    func returnedToForeground(gameBoxVisible: Bool) {
        if gameBoxVisible {
            defaults.set(true, forKey: runningKey)
            record("gamebox.foreground")
        }
    }

    func record(_ event: String) {
        // Whitelist only fixed operation names; never interpolate guest metadata.
        let safeEvent = String(event.prefix(100)).filter {
            $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0))
        }
        guard !safeEvent.isEmpty, let folder = ensureFolder() else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) pid=\(getpid()) \(safeEvent)\n"
        guard let data = line.data(using: .utf8) else { return }
        lock.lock()
        defer { lock.unlock() }
        let file = folder.appendingPathComponent("events.log")
        append(data, to: file)
        DispatchQueue.main.async { [weak self] in self?.revision &+= 1 }
    }

    private func append(_ data: Data, to file: URL) {
        let fd = Darwin.open(file.path, O_WRONLY | O_APPEND | O_CREAT, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { return }
        data.withUnsafeBytes { bytes in
            if let pointer = bytes.baseAddress {
                _ = Darwin.write(fd, pointer, bytes.count)
            }
        }
        _ = Darwin.close(fd)
    }

    /// Native diagnostics are delivered after the failure, if iOS can provide
    /// them. Keep the original JSON and export only by explicit user action.
    func saveMetricKit(_ payload: Data) {
        guard let folder = ensureFolder(), payload.count <= 2 * 1024 * 1024 else {
            record("metrickit.payload.unavailable")
            return
        }
        let name = "metric-" + UUID().uuidString + ".json"
        do {
            try payload.write(to: folder.appendingPathComponent(name), options: .atomic)
            record("metrickit.diagnostic.saved")
            trimOldLogs()
        } catch {
            record("metrickit.diagnostic.write_failed")
        }
    }

    func summary() -> String {
        guard let folder else { return "No hay registros todavía." }
        var pieces = [String]()
        if previousInterrupted || defaults.bool(forKey: interruptedKey) {
            pieces.append("RECUPERACIÓN: GameBox estaba visible cuando terminó la sesión anterior. Esto podría indicar un crash o cierre forzado; no es una causa confirmada.")
        }
        for file in ["events.log", "liveprocess.log"] {
            let url = folder.appendingPathComponent(file)
            if let data = try? Data(contentsOf: url),
               let text = String(data: data.suffix(64 * 1024), encoding: .utf8) {
                pieces.append("== \(file) ==\n" + text)
            }
        }
        let metrics = metricFiles(in: folder)
        if !metrics.isEmpty {
            pieces.append("MetricKit: \(metrics.count) diagnóstico(s) locales. Exporta el archivo para consultarlos.")
        }
        return pieces.isEmpty ? "No hay registros todavía." : pieces.joined(separator: "\n\n")
    }

    /// Plain text export combines breadcrumbs and original MetricKit JSON.
    /// This intentionally never uploads anything.
    func makeExport() -> URL? {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("BloomBox-Diagnostics-\(UUID().uuidString).txt")
        var report = "BloomBox — diagnóstico local\nEl registro de interrupción no confirma por sí solo un crash.\n\n"
        report += summary()
        if let folder {
            for url in metricFiles(in: folder) {
                if let data = try? Data(contentsOf: url),
                   let contents = String(data: data, encoding: .utf8) {
                    report += "\n\n== \(url.lastPathComponent) ==\n" + contents
                }
            }
        }
        do {
            try report.write(to: output, atomically: true, encoding: .utf8)
            return output
        } catch {
            record("diagnostics.export.failed")
            return nil
        }
    }

    func clear() {
        guard let folder else { return }
        for name in ["events.log", "liveprocess.log"] {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
        for url in metricFiles(in: folder) {
            try? FileManager.default.removeItem(at: url)
        }
        defaults.set(false, forKey: interruptedKey)
        previousInterrupted = false
        record("diagnostics.cleared")
    }

    private func metricFiles(in folder: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? [])
        .filter { $0.lastPathComponent.hasPrefix("metric-") && $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func trimOldLogs() {
        guard let folder = ensureFolder() else { return }
        lock.lock()
        defer { lock.unlock() }
        for name in ["events.log", "liveprocess.log"] {
            let file = folder.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: file), data.count > maxLogBytes else { continue }
            // Truncate only between sessions, preserving the newest records.
            try? Data(data.suffix(maxLogBytes / 2)).write(to: file, options: .atomic)
        }
        let reports = metricFiles(in: folder)
        if reports.count > 8 {
            for old in reports.prefix(reports.count - 8) {
                try? FileManager.default.removeItem(at: old)
            }
        }
    }
}

/// Xcode 26 compatibility: the legacy subscriber is still available on iOS 27.
/// The newer iOS 27 MetricManager API can replace this adapter later.
@available(iOS 13.0, *)
final class BloomBoxMetricKitSink: NSObject, MXMetricManagerSubscriber {
    static let shared = BloomBoxMetricKitSink()
    private var installed = false

    func start() {
        guard !installed else { return }
        installed = true
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let data = payload.jsonRepresentation()
            DispatchQueue.main.async {
                BloomBoxCrashJournal.shared.saveMetricKit(data)
            }
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        // Metrics are not crash reports. Avoid writing a daily large payload.
    }
}

struct BloomBoxDiagnosticsView: View {
    @ObservedObject private var journal = BloomBoxCrashJournal.shared
    @State private var exportURL: URL?
    @State private var confirmClear = false
    @AppStorage("BloomBoxGameBoxSafeGraphics", store: LiveContainerPreferencesAdapter.defaults)
    private var safeGraphics = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Recuperación y registros", systemImage: "stethoscope")
                    .font(.title2.bold())
                Text("Guarda pasos de GameBox y LiveProcess en este iPhone. Si iOS entrega un diagnóstico técnico, también se conserva. No se envía nada automáticamente.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if journal.previousInterrupted {
                    Label("Se detectó una sesión interrumpida. BloomBox arrancó en el escritorio para evitar repetir el problema.", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                Toggle(isOn: $safeGraphics) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Modo seguro de GameBox")
                        Text("Desactiva fondos pesados y carátulas personalizadas hasta que puedas probarlos otra vez.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    if #available(iOS 16.0, *), let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Compartir registro", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button("Copiar registro") {
                            UIPasteboard.general.string = journal.summary()
                        }
                    }
                    Spacer()
                    Button("Actualizar") { exportURL = journal.makeExport() }
                    Button("Limpiar", role: .destructive) { confirmClear = true }
                }
                Text(journal.summary())
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .navigationTitle("Diagnósticos")
        .onAppear { exportURL = journal.makeExport() }
        .confirmationDialog("¿Borrar los registros locales?", isPresented: $confirmClear) {
            Button("Borrar registros", role: .destructive) {
                journal.clear()
                exportURL = journal.makeExport()
            }
        }
    }
}
