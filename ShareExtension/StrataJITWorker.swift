import Foundation

/// Discovers the current iOS RemotePairing port rather than assuming it is always 49152.
/// This runs synchronously on StrataJITWorker's dedicated serial helper queue.
private final class BloomBoxRemotePairingDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var ports = Set<UInt16>()

    func discover(timeout: TimeInterval) -> [UInt16] {
        browser.delegate = self
        browser.schedule(in: .current, forMode: .default)
        browser.searchForServices(ofType: "_remotepairing._tcp.", inDomain: "local.")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            _ = RunLoop.current.run(mode: .default, before: min(deadline, Date().addingTimeInterval(0.1)))
        }
        browser.stop()
        services.forEach { $0.stop() }
        return ports.sorted()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 2)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        if (1...65535).contains(sender.port) { ports.insert(UInt16(sender.port)) }
    }
}

private enum BloomBoxJITEndpoint {
    static func configuration(manualPort: Int?, report: (String) -> Void) -> StikJIT.Configuration {
        var config = StikJIT.Configuration()
        if let manualPort, (1...65535).contains(manualPort) {
            config.rsdPort = UInt16(manualPort)
            report("Remote pairing endpoint: \\(config.deviceAddress):\\(config.rsdPort) (manual).")
            return config
        }
        // Do not delay the working configuration; the port may still be 49152.
        if EndpointProbe.failureReason(address: config.deviceAddress, port: config.rsdPort, timeout: 1.2) == nil {
            report("Remote pairing endpoint: \\(config.deviceAddress):\\(config.rsdPort) (default, reachable).")
            return config
        }
        report("Default RemotePairing port 49152 is unreachable. Discovering the current port via Bonjour…")
        let candidates = BloomBoxRemotePairingDiscovery().discover(timeout: 4)
        for port in candidates where port != config.rsdPort {
            // Other nearby iPhones may advertise this service: verify on our own VPN address.
            if EndpointProbe.failureReason(address: config.deviceAddress, port: port, timeout: 0.8) == nil {
                config.rsdPort = port
                report("Remote pairing endpoint: \\(config.deviceAddress):\\(port) (Bonjour, reachable).")
                return config
            }
        }
        report("No reachable RemotePairing port was discovered. Trying 49152; if it fails, reconnect LocalDevVPN or set the port manually in Modules > JIT. Do not re-pair yet.")
        return config
    }
}

/// Runs debugger work outside the target process, serially. Pairing data never enters logs.
enum StrataJITWorker {
    private static let lock = NSLock()
    private static var tokens = Set<String>()
    static let queue = DispatchQueue(label: "Strata.JIT.helper")
    static func handle(_ context: NSExtensionContext) -> Bool {
        guard let item = context.inputItems.first as? NSExtensionItem,
              let input = item.userInfo, input["strataJIT"] as? Bool == true else { return false }
        guard let token = input["token"] as? String, UUID(uuidString: token) != nil,
              let pid = input["pid"] as? Int32, pid > 0,
              let data = input["pairing"] as? Data, data.count < 2_000_000,
              let group = input["group"] as? String,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            context.cancelRequest(withError: NSError(domain: "StrataJIT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JIT request."]))
            return true
        }
        lock.lock()
        let inserted = tokens.insert(token).inserted
        lock.unlock()
        guard inserted else { return true }
        queue.async {
            defer { lock.lock(); tokens.remove(token); lock.unlock() }
            let fm = FileManager.default
            let status = container.appendingPathComponent("Library/StrataJIT/\(token).json")
            func report(_ message: String, done: Bool = false, success: Bool = false) {
                let object: [String: Any] = ["message": message, "done": done, "success": success]
                try? fm.createDirectory(at: status.deletingLastPathComponent(), withIntermediateDirectories: true)
                if let encoded = try? JSONSerialization.data(withJSONObject: object) { try? encoded.write(to: status, options: .atomic) }
            }
            report("JIT helper connected.")
            let pairing = fm.temporaryDirectory.appendingPathComponent("\(token).plist")
            defer { try? fm.removeItem(at: pairing) }
            do {
                try data.write(to: pairing, options: [.atomic, .completeFileProtection])
                let library = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
                let paths = DDIPaths.default(in: library.appendingPathComponent("StrataJIT"))
                let operation = input["operation"] as? String ?? "enable"
                if operation == "reset" {
                    try StikJIT.resetCachedDDI(at: paths)
                    report("Developer disk image cache reset.", done: true, success: true)
                    context.completeRequest(returningItems: nil)
                    return
                }
                let config = BloomBoxJITEndpoint.configuration(manualPort: input["remotePort"] as? Int, report: report)
                let readiness = StikJIT.prepareDevice(pairingFile: pairing, paths: paths, configuration: config) { stage in
                    report(String(describing: stage))
                }
                switch readiness {
                case .unreachable(let reason), .preparationFailed(let reason): throw NSError(domain: "StrataJIT", code: 2, userInfo: [NSLocalizedDescriptionKey: reason])
                case .ready(let state):
                    if operation == "prepare" {
                        let txm = state.isTXMPresent.map { $0 ? "present" : "not present" } ?? "unknown"
                        report("Device ready. TXM/SPTM: " + txm, done: true, success: true)
                        context.completeRequest(returningItems: nil)
                        return
                    }
                    guard let txm = state.isTXMPresent else { throw NSError(domain: "StrataJIT", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot determine device JIT requirements."]) }
                    let script = input["script"] as? String ?? ""
                    if txm && script.isEmpty { throw NSError(domain: "StrataJIT", code: 4, userInfo: [NSLocalizedDescriptionKey: "This guest needs a compatible iOS JIT script. Configure its JIT script in app settings before launching."]) }
                    report("Connecting debugger…")
                    // Preserve the guest's existing protocol; never substitute a universal script for an arbitrary engine.
                    try StikJIT.enableJIT(targetPID: pid, pairingFile: pairing, ddiPaths: paths, configuration: config,
                        script: script.isEmpty ? .universal : .customBase64(script), progress: { report($0) })
                    report("JIT request completed.", done: true, success: true)
                }
            } catch { report(error.localizedDescription, done: true) }
            context.completeRequest(returningItems: nil)
        }
        return true
    }
}

/// Request entry point used before a share view is created.
@objc(StrataJITRequestHandler)
final class StrataJITRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) { _ = StrataJITWorker.handle(context) }
    @objc(begin:)
    static func begin(_ context: NSExtensionContext) { _ = StrataJITWorker.handle(context) }
}
