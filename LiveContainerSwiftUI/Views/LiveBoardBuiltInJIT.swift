import Foundation
import Combine
import SwiftUI

@MainActor
enum LiveBoardBuiltInJIT {
    private static var busy = false
    static var pairingURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StrataJIT/pairingFile.plist")
    }
    static func importPairing(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        try storeOnDevicePairing(Data(contentsOf: url))
    }
    /// The in-app iOS 27 pairing host hands us exactly the same remote pairing format.
    static func storeOnDevicePairing(_ data: Data) throws {
        try StrataPairingRecord.validate(data)
        try FileManager.default.createDirectory(at: pairingURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: pairingURL, options: [.atomic, .completeFileProtection])
        UserDefaults.standard.set("On-device pairing ready. Connect LocalDevVPN, then prepare JIT.", forKey: "StrataJITLastStatus")
    }
    static func enable(pid: Int32 = getpid(), script: String?, operation: String = "enable", progress: @escaping (String) -> Void) async -> Bool {
        var recentMessages: [String] = []
        var debuggerAttached = false
        let report: (String) -> Void = { message in
            if BloomBoxJITProgressMarker.attached(message) { debuggerAttached = true }
            progress(message)
            UserDefaults.standard.set(message, forKey: "StrataJITLastStatus")
            recentMessages.append(String(message.prefix(1024)))
            recentMessages = Array(recentMessages.suffix(40))
            let status: [String: Any] = ["message": message, "operation": operation, "recentMessages": recentMessages]
            let file = pairingURL.deletingLastPathComponent().appendingPathComponent("last-status.json")
            if let data = try? JSONSerialization.data(withJSONObject: status) { try? data.write(to: file, options: .atomic) }
        }
        guard !busy else { report("Another JIT operation is already running."); return false }
        guard ["enable", "prepare", "reset"].contains(operation), operation != "enable" || (pid > 0 && pid != getpid()) else {
            report("JIT requires a separate guest process."); return false
        }
        busy = true
        defer { busy = false }
        guard #available(iOS 17.4, *) else { report("Built-in JIT requires iOS 17.4 or later."); return false }
        guard operation == "enable" || LCUtils.strataCanDebug() else { report("This installation lacks debugging permission (get-task-allow). Re-sign using a compatible signing method."); return false }
        guard let data = try? Data(contentsOf: pairingURL) else { report("Import your pairing file in JIT setup first."); return false }
        do { try StrataPairingRecord.validate(data) } catch { report(error.localizedDescription); return false }
        guard let group = LCSharedUtils.appGroupID(), let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { report("The shared app container is unavailable."); return false }
        if operation == "enable" {
            let file = root.appendingPathComponent("Library/StrataJIT/Targets/\(pid).json")
            report("Checking the running LiveProcess signature (PID \(pid))…")
            var target: [String: Any]?
            for _ in 0..<50 {
                if Task.isCancelled { report("JIT cancelled."); return false }
                if let bytes = try? Data(contentsOf: file),
                   let value = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                   value["pid"] as? Int32 == pid,
                   let timestamp = value["timestamp"] as? Double,
                   (0...60).contains(Date().timeIntervalSince1970 - timestamp) {
                    target = value
                    try? FileManager.default.removeItem(at: file)
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            guard let target else {
                report("LiveProcess did not report its signature. Keep all extensions when reinstalling; close the guest and try again.")
                return false
            }
            guard target["debug"] as? Bool == true else {
                report("LiveProcess lacks confirmed get-task-allow. SideStore must preserve the extension's debugging permission. No debugger connection was attempted.")
                return false
            }
            let ram = (target["ram"] as? Bool).map { $0 ? "active" : "missing" } ?? "unknown"
            report("LiveProcess: debugging permitted; RAM+ \(ram).")
        }
        let token = UUID().uuidString
        let status = root.appendingPathComponent("Library/StrataJIT/\(token).json")
        let manualPortText = (LCUtils.appGroupUserDefault.string(forKey: "BloomBoxJITRemotePort") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let manualPort = manualPortText.isEmpty ? nil : UInt16(manualPortText)
        if !manualPortText.isEmpty && (manualPort == nil || manualPort == 0) {
            report("Invalid remote pairing port. Enter 1–65535 or leave the field empty for auto discovery.")
            return false
        }
        var helperInput: [String: Any] = ["strataJIT": true, "group": group, "operation": operation,
                                          "token": token, "pid": pid, "pairing": data, "script": script ?? ""]
        if let manualPort { helperInput["remotePort"] = Int(manualPort) }
        var helper: NSObject?
        defer {
            if let helper { LCUtils.strataStopJITHelper(helper) }
            try? FileManager.default.removeItem(at: status)
        }
        do {
            helper = try LCUtils.strataStartJITHelper(helperInput)
            guard helper != nil else { report("JIT helper unavailable. Reinstall keeping app extensions."); return false }
            report("Preparing device. Keep LocalDevVPN connected and Developer Mode enabled.")
            var lastMessage = ""
            var nextMessageIndex = 0
            let started = Date()
            let deadline = started.addingTimeInterval(300)
            var receivedStatus = false
            while Date() < deadline {
                try Task.checkCancellation()
                if let bytes = try? Data(contentsOf: status), let result = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] {
                    receivedStatus = true
                    if let messages = result["messages"] as? [String] {
                        let firstIndex = result["firstMessageIndex"] as? Int ?? 0
                        for (index, message) in messages.enumerated()
                            where firstIndex + index >= nextMessageIndex {
                            report(message)
                        }
                        nextMessageIndex = max(nextMessageIndex, firstIndex + messages.count)
                    } else {
                        // Compatibility with helpers installed before this UI update.
                        let message = result["message"] as? String ?? ""
                        if message != lastMessage { report(message); lastMessage = message }
                    }
                    if result["done"] as? Bool == true { return result["success"] as? Bool == true }
                }
                if !receivedStatus && Date().timeIntervalSince(started) > 12 {
                    report("The JIT helper did not start. Confirm this update was installed with all extensions kept, then retry. No device connection was attempted.")
                    return false
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            if debuggerAttached {
                report("Debugger attached, but the guest did not finish the JIT protocol before the timeout. JIT is not confirmed; review the log before retrying.")
            } else {
                report("JIT timed out. Check LocalDevVPN, pairing and Wi-Fi, then retry.")
            }
        } catch is CancellationError { report("JIT cancelled.") }
        catch { report(error.localizedDescription) }
        return false
    }
}

/// Owns preparation independently of the setup sheet's lifetime.
@MainActor final class LiveBoardJITSession: ObservableObject {
    static let shared = LiveBoardJITSession()
    @Published var message = UserDefaults.standard.string(forKey: "StrataJITLastStatus") ?? ""
    @Published private(set) var busy = false
    @Published private(set) var success: Bool?
    private var task: Task<Void, Never>?
    func start(_ operation: String) {
        guard !busy else { return }
        busy = true; success = nil; message = "Starting…"
        let record = BloomBoxJITLogStore.shared.begin(
            appName: operation == "prepare" ? "Preparar dispositivo" : "Reiniciar caché DDI",
            provider: "Built-in JIT", showNotification: false)
        task = Task {
            success = await LiveBoardBuiltInJIT.enable(script: nil, operation: operation) { [weak self] line in
                self?.message = line
                BloomBoxJITLogStore.shared.append(line, to: record)
            }
            BloomBoxJITLogStore.shared.finish(record, success: success == true)
            busy = false
            task = nil
        }
    }
    func cancel() { task?.cancel() }
}


/// Local diagnostic history. Does not store the pairing file or script contents.
/// Keeping the history in BloomBox's own Documents directory avoids uploading it anywhere.
@MainActor
final class BloomBoxJITLogStore: ObservableObject {
    static let shared = BloomBoxJITLogStore()

    struct Attempt: Codable, Identifiable {
        let id: UUID
        let createdAt: Date
        let appName: String
        let provider: String
        var status: String
        var messages: [String]

        var displayStatus: String {
            switch status {
            case "running": return "Activando"
            case "debugger_attached": return "Debugger conectado · sin confirmar"
            case "awaiting_guest": return "Esperando respuesta del juego"
            case "timed_out_attached": return "Sin confirmación del juego"
            case "completed": return "JIT completado"
            case "failed": return "Falló la activación"
            case "interrupted": return "Proceso interrumpido"
            default: return status
            }
        }

        var exportText: String {
            let header = "BloomBox JIT — \(appName)\n\(createdAt.formatted())\nProvider: \(provider)\nResult: \(status)\n"
            return header + "\n" + messages.joined(separator: "\n")
        }
    }

    enum Phase: Equatable { case working, waiting, success, failure }

    @Published private(set) var attempts: [Attempt] = []
    @Published private(set) var activeAttemptID: UUID?
    @Published private(set) var visible = false
    @Published private(set) var compact = false
    @Published private(set) var phase: Phase = .working
    @Published private(set) var activeAppName = ""

    private var collapseTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private static let maximumRecords = 60
    private static let maximumBytes = 2_000_000
    private static var logURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StrataJIT/jit-history.json")
    }

    private init() {
        if let data = try? Data(contentsOf: Self.logURL),
           let loaded = try? JSONDecoder().decode([Attempt].self, from: data) {
            attempts = Array(loaded.prefix(Self.maximumRecords))
            // A terminated host must not leave an old "working" attempt forever.
            for index in attempts.indices
                where ["running", "debugger_attached", "awaiting_guest"].contains(attempts[index].status) {
                attempts[index].status = "interrupted"
            }
        }
    }

    @discardableResult
    func begin(appName: String, provider: String, showNotification: Bool = true) -> UUID {
        let attempt = Attempt(id: UUID(), createdAt: Date(), appName: appName,
                              provider: provider, status: "running", messages: [])
        attempts.insert(attempt, at: 0)
        if attempts.count > Self.maximumRecords {
            attempts.removeLast(attempts.count - Self.maximumRecords)
        }
        if showNotification {
            collapseTask?.cancel()
            idleTask?.cancel()
            dismissTask?.cancel()
            activeAttemptID = attempt.id
            activeAppName = appName
            visible = true
            compact = false
            phase = .working
            collapseTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled, self.activeAttemptID == attempt.id else { return }
                self.compact = true
            }
        }
        save()
        return attempt.id
    }

    func append(_ message: String, to id: UUID) {
        guard let index = attempts.firstIndex(where: { $0.id == id }) else { return }
        attempts[index].messages.append(String(message.prefix(4096)))
        if BloomBoxJITProgressMarker.attached(message) {
            attempts[index].status = "debugger_attached"
        } else if BloomBoxJITProgressMarker.awaitingGuest(message) {
            // The script is waiting for another guest breakpoint or detach. This is
            // not proof the JIT memory has been prepared successfully.
            attempts[index].status = "awaiting_guest"
            if activeAttemptID == id { scheduleWaitingHint(for: id) }
        }
        save()
    }

    private func scheduleWaitingHint(for id: UUID) {
        idleTask?.cancel()
        idleTask = Task {
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled, self.activeAttemptID == id,
                  self.attempts.first(where: { $0.id == id })?.status == "awaiting_guest" else { return }
            // Stop the endless spinner without sending debugger detach or killing the guest.
            // Keep collecting logs: only a real helper completion may report success.
            self.phase = .waiting
            self.compact = true
            self.dismissTask?.cancel()
            self.dismissTask = Task {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard !Task.isCancelled, self.activeAttemptID == id, self.phase == .waiting else { return }
                self.visible = false
                // Keep activeAttemptID until the real helper result arrives.
            }
        }
    }

    func finish(_ id: UUID, success: Bool) {
        guard let index = attempts.firstIndex(where: { $0.id == id }) else { return }
        let timedOutAfterAttach = !success
            && ["debugger_attached", "awaiting_guest"].contains(attempts[index].status)
            && attempts[index].messages.suffix(3).contains(where: BloomBoxJITProgressMarker.didTimeOut)
        attempts[index].status = success ? "completed" : timedOutAfterAttach ? "timed_out_attached" : "failed"
        save()
        guard activeAttemptID == id else { return }
        collapseTask?.cancel()
        idleTask?.cancel()
        compact = true
        phase = success ? .success : timedOutAfterAttach ? .waiting : .failure
        dismissTask?.cancel()
        if !visible { activeAttemptID = nil; return }
        dismissTask = Task {
            // Only a completed protocol produces a green confirmation.
            try? await Task.sleep(nanoseconds: success ? 2_500_000_000 : 9_000_000_000)
            guard !Task.isCancelled, self.activeAttemptID == id else { return }
            self.visible = false
            self.activeAttemptID = nil
        }
    }

    private func save() {
        let fm = FileManager.default
        let file = Self.logURL
        try? fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Keep complete individual attempts while trimming the oldest records to avoid large storage use.
        while attempts.count > 1 {
            guard let data = try? JSONEncoder().encode(attempts) else { return }
            if data.count <= Self.maximumBytes { break }
            attempts.removeLast()
        }
        if let data = try? JSONEncoder().encode(attempts) {
            try? data.write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
        }
    }
}

/// A non-blocking overlay in BloomBox. iOS does not allow a normal app to draw above
/// other apps: this indicator is shown only while BloomBox itself is visible.
struct BloomBoxJITFloatingView: View {
    @ObservedObject private var history = BloomBoxJITLogStore.shared
    @State private var showingLog = false

    private var color: Color {
        switch history.phase {
        case .working: return .purple
        case .waiting: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }

    private var symbol: String {
        switch history.phase {
        case .working: return "bolt.fill"
        case .waiting: return "clock.fill"
        case .success: return "checkmark"
        case .failure: return "exclamationmark.triangle.fill"
        }
    }

    private var label: String {
        switch history.phase {
        case .working: return "Activando JIT"
        case .waiting: return "Debugger conectado · JIT sin confirmar"
        case .success: return "JIT activado"
        case .failure: return "Error al activar JIT"
        }
    }

    var body: some View {
        Group {
            if history.visible {
                Button { showingLog = true } label: {
                    if history.compact {
                        VStack(spacing: 2) {
                            Image(systemName: symbol)
                                .font(.system(size: 20, weight: .semibold))
                            Text("JIT").font(.system(size: 10, weight: .bold))
                            if history.phase == .working {
                                ProgressView().tint(.white).scaleEffect(0.55).frame(height: 9)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(color.opacity(0.75), lineWidth: 1.5))
                        .shadow(color: color.opacity(0.4), radius: 12)
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(color)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(label).font(.subheadline.bold())
                                Text(history.activeAppName).font(.caption).lineLimit(1)
                                    .foregroundStyle(.secondary)
                            }
                            if history.phase == .working { ProgressView().tint(color) }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        .frame(maxWidth: 270)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(color.opacity(0.65), lineWidth: 1))
                        .shadow(color: color.opacity(0.25), radius: 14)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bloombox.jit.floating")
                .accessibilityLabel(label + ". Toca para ver el registro.")
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.77), value: history.compact)
        .animation(.easeInOut(duration: 0.2), value: history.visible)
        .sheet(isPresented: $showingLog) {
            NavigationView {
                BloomBoxJITLogHistoryView(appName: history.activeAppName)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") { showingLog = false }
                        }
                    }
            }.navigationViewStyle(.stack)
        }
    }
}

struct BloomBoxJITLogHistoryView: View {
    var appName: String? = nil
    @ObservedObject private var store = BloomBoxJITLogStore.shared

    private var records: [BloomBoxJITLogStore.Attempt] {
        guard let appName, !appName.isEmpty else { return store.attempts }
        return store.attempts.filter { $0.appName.caseInsensitiveCompare(appName) == .orderedSame }
    }

    var body: some View {
        List {
            if records.isEmpty {
                Label("Los próximos intentos aparecerán aquí.", systemImage: "doc.text.magnifyingglass")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records) { record in
                    NavigationLink {
                        BloomBoxJITLogDetailView(recordID: record.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: record.status == "completed" ? "checkmark.circle.fill" :
                                    ["running", "debugger_attached", "awaiting_guest", "timed_out_attached"].contains(record.status)
                                    ? "clock.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(record.status == "completed" ? .green :
                                    ["running", "debugger_attached", "awaiting_guest", "timed_out_attached"].contains(record.status)
                                    ? .orange : .red)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.appName).font(.headline)
                                Text(record.createdAt, style: .date).font(.caption)
                                Text(record.createdAt, style: .time).font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(record.displayStatus).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(appName == nil ? "Historial de JIT" : "JIT · \(appName!)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BloomBoxJITLogDetailView: View {
    let recordID: UUID
    @ObservedObject private var store = BloomBoxJITLogStore.shared

    private var record: BloomBoxJITLogStore.Attempt? {
        store.attempts.first { $0.id == recordID }
    }

    var body: some View {
        ScrollView {
            if let record {
                VStack(alignment: .leading, spacing: 12) {
                    Text(record.appName).font(.headline)
                    Text("\(record.provider) · \(record.displayStatus)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(record.exportText)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        UIPasteboard.general.string = record.exportText
                    } label: {
                        Label("Copiar registro", systemImage: "doc.on.doc")
                    }
                }.padding(16)
            }
        }
        .navigationTitle("Registro completo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if let record { UIPasteboard.general.string = record.exportText }
                } label: {
                    Label("Copiar", systemImage: "doc.on.doc")
                }
                .disabled(record == nil)
            }
        }
    }
}
