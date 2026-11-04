import Foundation
import Combine
import SwiftUI

@MainActor
enum BloomBoxBuiltInJIT {
    private static var busy = false
    static var pairingURL: URL {
        BloomBoxJITPairingStorage().pairingURL
    }
    static func importPairing(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        try storeOnDevicePairing(Data(contentsOf: url))
    }
    /// The in-app iOS 27 pairing host hands us exactly the same remote pairing format.
    static func storeOnDevicePairing(_ data: Data) throws {
        try BloomBoxJITPairingStorage().save(data)
        UserDefaults.standard.set("On-device pairing ready. Connect LocalDevVPN, then prepare JIT.", forKey: "BloomBoxJITLastStatus")
    }
    private static func saveLaunchStatus(message: String, operation: String, recent: [String]) {
        UserDefaults.standard.set(message, forKey: "BloomBoxJITLastStatus")
        let report: [String: Any] = [
            "operation": operation,
            "message": message,
            "recentMessages": recent
        ]
        guard let bytes = try? JSONSerialization.data(withJSONObject: report) else { return }
        let destination = pairingURL.deletingLastPathComponent()
            .appendingPathComponent("last-status.json")
        try? bytes.write(to: destination, options: .atomic)
    }

    static func enable(pid: Int32 = getpid(), script: String?, operation: String = "enable", progress: @escaping (String) -> Void) async -> Bool {
        var recentMessages: [String] = []
        var debuggerAttached = false
        let report: (String) -> Void = { message in
            debuggerAttached = debuggerAttached || BloomBoxJITProgressMarker.attached(message)
            progress(message)
            recentMessages.append(String(message.prefix(1024)))
            if recentMessages.count > 40 { recentMessages.removeFirst(recentMessages.count - 40) }
            saveLaunchStatus(message: message, operation: operation, recent: recentMessages)
        }
        if busy {
            report("Another JIT operation is already running.")
            return false
        }
        switch operation {
        case "enable":
            guard pid > 0 && pid != getpid() else {
                report("JIT requires a separate guest process.")
                return false
            }
        case "prepare", "reset": break
        default:
            report("Unsupported JIT action.")
            return false
        }
        guard #available(iOS 17.4, *) else {
            report("Built-in JIT requires iOS 17.4 or later.")
            return false
        }
        busy = true
        defer { busy = false }
        guard operation == "enable" || LCUtils.bloomBoxCanDebug() else { report("This installation lacks debugging permission (get-task-allow). Re-sign using a compatible signing method."); return false }
        let data: Data
        do { data = try BloomBoxJITPairingStorage().load() }
        catch { report(error.localizedDescription); return false }
        guard let group = LCSharedUtils.appGroupID(), let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { report("The shared app container is unavailable."); return false }
        if operation == "enable" {
            let file = root.appendingPathComponent("Library/BloomBoxJIT/Targets/\(pid).json")
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
        let status = root.appendingPathComponent("Library/BloomBoxJIT/\(token).json")
        let manualPortText = (LCUtils.appGroupUserDefault.string(forKey: "BloomBoxJITRemotePort") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let manualPort = manualPortText.isEmpty ? nil : UInt16(manualPortText)
        if !manualPortText.isEmpty && (manualPort == nil || manualPort == 0) {
            report("Invalid remote pairing port. Enter 1–65535 or leave the field empty for auto discovery.")
            return false
        }
        var helperInput: [String: Any] = ["bloomBoxJIT": true, "group": group, "operation": operation,
                                          "token": token, "pid": pid, "pairing": data, "script": script ?? ""]
        if let manualPort { helperInput["remotePort"] = Int(manualPort) }
        var helper: NSObject?
        defer {
            if let helper { LCUtils.bloomBoxStopJITHelper(helper) }
            try? FileManager.default.removeItem(at: status)
        }
        do {
            helper = try LCUtils.bloomBoxStartJITHelper(helperInput)
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
                    if let finished = result["done"] as? Bool, finished {
                        let completed = (result["success"] as? Bool) ?? false
                        if completed {
                            // Debugger success alone is not proof of executable JIT memory.
                            report("Debugger script finished. Verify executable JIT memory inside the guest before launching a game.")
                        }
                        return completed
                    }
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
    @Published var message = UserDefaults.standard.string(forKey: "BloomBoxJITLastStatus") ?? UserDefaults.standard.string(forKey: "StrataJITLastStatus") ?? ""
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
            success = await BloomBoxBuiltInJIT.enable(script: nil, operation: operation) { [weak self] line in
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

    /// Explicit animation is needed when the observable state is changed by a
    /// background JIT callback: relying solely on a child view's .animation
    /// can insert/remove the glass surface before SwiftUI animates it.
    private func setNotificationVisible(_ value: Bool) {
        if UIAccessibility.isReduceMotionEnabled {
            withAnimation(.easeInOut(duration: 0.12)) { visible = value }
        } else if value {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) { visible = true }
        } else {
            withAnimation(.easeInOut(duration: 0.34)) { visible = false }
        }
    }

    private static let maximumRecords = 60
    private static let maximumBytes = 2_000_000
    private static var logURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBoxJIT/jit-history.json")
    }

    private static var legacyLogURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StrataJIT/jit-history.json")
    }

    private init() {
        let savedURL = FileManager.default.fileExists(atPath: Self.logURL.path) ? Self.logURL : Self.legacyLogURL
        if let data = try? Data(contentsOf: savedURL),
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
            compact = false
            phase = .working
            setNotificationVisible(true)
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
                self.setNotificationVisible(false)
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
            self.setNotificationVisible(false)
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

/// BloomBox-only floating status: it never draws over apps outside the host.
/// On iOS 26+ the native glass surface morphs from a card to a compact orb.
/// Older iOS versions retain an animated material fallback.
struct BloomBoxJITFloatingView: View {
    @ObservedObject private var history = BloomBoxJITLogStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var glassNamespace
    @Namespace private var fallbackNamespace
    @State private var showingLog = false
    @State private var orbBreathing = false

    private var tint: Color {
        switch history.phase {
        case .working: return Color(red: 0.65, green: 0.43, blue: 1)
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
        case .waiting: return "JIT sin confirmar"
        case .success: return "JIT activado"
        case .failure: return "Error al activar JIT"
        }
    }

    private var subtitle: String {
        switch history.phase {
        case .working: return history.activeAppName
        case .waiting: return "Debugger conectado · " + history.activeAppName
        case .success: return history.activeAppName + " está listo"
        case .failure: return "Toca para ver el registro"
        }
    }

    private var morphAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.16)
            : .spring(response: 0.55, dampingFraction: 0.79, blendDuration: 0.1)
    }

    private var orb: some View {
        ZStack {
            Circle()
                .strokeBorder(tint.opacity(0.38), lineWidth: 1.4)
                .frame(width: 54, height: 54)
                .scaleEffect(orbBreathing && history.phase == .working ? 1.13 : 0.99)
                .opacity(orbBreathing && history.phase == .working ? 0.35 : 0.70)
                .allowsHitTesting(false)

            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(tint)
                    .id(symbol)
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
                if history.phase == .working {
                    ProgressView()
                        .tint(tint)
                        .scaleEffect(0.56)
                        .frame(width: 16, height: 12)
                } else {
                    Text("JIT")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(width: 62, height: 62)
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var notificationCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.16))
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(tint)
                    .id(symbol)
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }
            .frame(width: 43, height: 43)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if history.phase == .working {
                ProgressView()
                    .tint(tint)
                    .controlSize(.small)
            } else if history.phase == .success {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(tint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 280)
        .contentShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    /// Both sizes use the same glass identity, so iOS morphs the *material*,
    /// not just a shrinking screenshot of the previous notification.
    @ViewBuilder
    private var floatingSurface: some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: 28) {
                if history.compact {
                    Button { showingLog = true } label: { orb }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(tint.opacity(0.20)).interactive(),
                                     in: .circle)
                        .glassEffectID("bloombox-jit-status", in: glassNamespace)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottomTrailing)))
                } else {
                    Button { showingLog = true } label: { notificationCard }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(tint.opacity(0.16)).interactive(),
                                     in: .rect(cornerRadius: 23))
                        .glassEffectID("bloombox-jit-status", in: glassNamespace)
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottomTrailing)))
                }
            }
        } else {
            // Accessible opaque fallback when transparency is reduced, and
            // a material-based fallback on earlier systems.
            if history.compact {
                Button { showingLog = true } label: { orb }
                    .buttonStyle(.plain)
                    .background {
                        Circle()
                            .fill(fallbackFill)
                            .matchedGeometryEffect(id: "bloombox-jit-status", in: fallbackNamespace)
                    }
                    .overlay(Circle().strokeBorder(tint.opacity(0.38), lineWidth: 1))
            } else {
                Button { showingLog = true } label: { notificationCard }
                    .buttonStyle(.plain)
                    .background {
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .fill(fallbackFill)
                            .matchedGeometryEffect(id: "bloombox-jit-status", in: fallbackNamespace)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .strokeBorder(tint.opacity(0.38), lineWidth: 1)
                    }
            }
        }
    }

    private var fallbackFill: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.94))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    var body: some View {
        Group {
            if history.visible {
                floatingSurface
                    .shadow(color: tint.opacity(colorScheme == .dark ? 0.25 : 0.14), radius: 18, y: 7)
                    .accessibilityIdentifier("bloombox.jit.floating")
                    .accessibilityLabel(label + ". Toca para ver el registro.")
                    // Arrive from slightly below with a gentle glass "pop"; leave
                    // by dissolving and contracting towards the orb's anchor.
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity
                            .combined(with: .scale(scale: 0.90, anchor: .bottomTrailing))
                            .combined(with: .offset(y: 12)),
                        removal: .opacity
                            .combined(with: .scale(scale: 0.78, anchor: .bottomTrailing))
                            .combined(with: .offset(y: 8))))
            }
        }
        .animation(morphAnimation, value: history.compact)
        .animation(reduceMotion ? .easeInOut(duration: 0.12)
                   : (history.visible
                        ? .spring(response: 0.46, dampingFraction: 0.84)
                        : .easeInOut(duration: 0.34)),
                   value: history.visible)
        .animation(.easeInOut(duration: 0.22), value: history.phase)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                orbBreathing = true
            }
        }
        .onDisappear { orbBreathing = false }
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

// Source alias for host modules; pairing/JIT credentials keep their old saved IDs.
typealias LiveBoardBuiltInJIT = BloomBoxBuiltInJIT
