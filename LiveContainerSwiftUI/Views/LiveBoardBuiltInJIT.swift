import Foundation
import Combine

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
        let report: (String) -> Void = { message in
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
            let started = Date()
            let deadline = started.addingTimeInterval(300)
            var receivedStatus = false
            while Date() < deadline {
                try Task.checkCancellation()
                if let bytes = try? Data(contentsOf: status), let result = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] {
                    receivedStatus = true
                    let message = result["message"] as? String ?? ""
                    if message != lastMessage { report(message); lastMessage = message }
                    if result["done"] as? Bool == true { return result["success"] as? Bool == true }
                }
                if !receivedStatus && Date().timeIntervalSince(started) > 12 {
                    report("The JIT helper did not start. Confirm this update was installed with all extensions kept, then retry. No device connection was attempted.")
                    return false
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            report("JIT timed out. Check LocalDevVPN, pairing and Wi-Fi, then retry.")
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
        task = Task {
            success = await LiveBoardBuiltInJIT.enable(script: nil, operation: operation) { [weak self] in self?.message = $0 }
            busy = false
            task = nil
        }
    }
    func cancel() { task?.cancel() }
}
