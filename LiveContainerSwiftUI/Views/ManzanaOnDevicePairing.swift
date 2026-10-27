// SPDX-License-Identifier: GPL-2.0-or-later
import BackgroundTasks
import dnssd
import Foundation
import SwiftUI
import UIKit
import UserNotifications

/// Adapted from Leviidev/Husk (GPL-2.0-or-later) for BloomBox on-device remote pairing.
///
/// iOS 27 can pair with a computer it finds on the local network, started from
/// the iPhone: Settings › Privacy & Security › Developer Mode lists every
/// `_remotepairing-pairable-host._tcp` service, and pairing with one asks for the
/// PIN that host shows. BloomBox plays that computer for its own iPhone:
/// libhusk_rppairing (src/rppairing-ios, idevice's PairableHost) listens on a
/// port and runs the pairing; this publishes the port through mDNSResponder
/// (dns_sd, so only the Local Network permission is needed, not the multicast
/// entitlement) and stores the resulting RPPairing file where Built-in StikJIT
/// reads it.
///
/// The user pairs from Settings, so BloomBox has to keep running in the background:
/// a BGContinuedProcessingTask ("<bundle id>.pairing.session", permitted by
/// `$(PRODUCT_BUNDLE_IDENTIFIER).pairing.*` in Info.plist) whose system progress
/// UI also shows the PIN. When iOS refuses it (a re-signed bundle whose
/// identifier no longer matches), only the short background grace period
/// remains, and the walkthrough says so. The PIN is also sent as a notification.
///
/// Log category "jit-pairing": states only, never the PIN, device name or identifiers.
@MainActor final class ManzanaOnDevicePairing: ObservableObject {
    static let shared = ManzanaOnDevicePairing()

    /// Shown on the iPhone as "Pair with BloomBox"; the host identifier is derived from it.
    static let hostName = "BloomBox"
    static let timeout: TimeInterval = 300

    enum Phase: Equatable {
        case idle
        /// Advertised; the user pairs from Settings.
        case waiting
        /// The iPhone asked for the code.
        case pin(String)
        case paired(device: String)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    /// iOS refused the continued-processing task: BloomBox can only wait briefly in the background.
    @Published private(set) var backgroundLimited = false
    /// Explain whether iOS actually accepted the background protection.
    @Published private(set) var backgroundStatus = "Not started"
    // iOS may expire a background job even while the pairing listener is alive.
    // A user-initiated retry can request a fresh job without rebuilding the host.
    @Published private(set) var protectionRetryAvailable = false

    static var isSupported: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))
    }

    var isShowingPin: Bool {
        if case .pin = phase { return true }
        return false
    }

    var active: Bool {
        switch phase {
        case .waiting, .pin: return true
        default: return false
        }
    }

    private var session: OpaquePointer?
    private var registration: DNSServiceRef?
    private var continued: AnyObject?            // BGContinuedProcessingTask (iOS 26+)
    private var registered: String?
    private var continuedRequestPending = false
    private var grace: UIBackgroundTaskIdentifier = .invalid
    private var deadline: Timer?

    private init() {}

    private func log(_ line: String) { NSLog("[BloomBox JIT pairing] %@", line) }

    func start() {
        guard Self.isSupported, !active, session == nil else { return }
        var error: UnsafeMutablePointer<CChar>?
        guard let session = husk_rppairing_new(Self.hostName, &error) else {
            fail(Self.take(error) ?? "BloomBox could not open its pairing port.")
            return
        }
        self.session = session
        phase = .waiting
        backgroundLimited = true
        protectionRetryAvailable = false
        backgroundStatus = "Preparing background pairing protection…"
        log("started")
        requestNotifications()
        guard publish(session) else {
            husk_rppairing_free(session)
            self.session = nil
            return
        }
        beginBackground()
        deadline = Timer.scheduledTimer(withTimeInterval: Self.timeout, repeats: false) { _ in
            MainActor.assumeIsolated {
                ManzanaOnDevicePairing.shared.cancel(reason: "Pairing timed out. Try again when you are ready to pair from Settings.")
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            var bytes: UnsafeMutablePointer<UInt8>?
            var length = 0
            var device: UnsafeMutablePointer<CChar>?
            var failure: UnsafeMutablePointer<CChar>?
            let status = husk_rppairing_accept(session, { pin, _ in
                guard let pin else { return }
                let code = String(cString: pin)
                DispatchQueue.main.async { ManzanaOnDevicePairing.shared.showPin(code) }
            }, nil, &bytes, &length, &device, &failure)
            let data = bytes.map { Data(bytes: $0, count: length) }
            husk_rppairing_bytes_free(bytes, length)
            let name = Self.take(device)
            let message = Self.take(failure)
            DispatchQueue.main.async {
                ManzanaOnDevicePairing.shared.finished(status: status, data: data, device: name, message: message)
            }
        }
    }

    /// Stops a pairing in progress. `reason` is shown as the failure; nil returns to idle.
    func cancel(reason: String? = nil) {
        guard let session else { return }
        husk_rppairing_cancel(session)
        stopAdvertising()
        deadline?.invalidate()
        deadline = nil
        phase = reason.map(Phase.failed) ?? .idle
        protectionRetryAvailable = false
        endBackground(success: false)
        log(reason == nil ? "cancelled" : "stopped")
    }

    /// Forget a finished or failed attempt so the walkthrough starts clean.
    func reset() {
        guard !active else { return }
        phase = .idle
    }

    private func showPin(_ pin: String) {
        guard active else { return }
        phase = .pin(pin)
        log("code shown")
        if #available(iOS 26.0, *), let task = continued as? BGContinuedProcessingTask {
            // The system already shows continued task progress in a Live Activity.
            // Update that existing activity instead of creating a competing one.
            task.updateTitle("BloomBox JIT PIN: \(pin)", subtitle: "Enter this code in iPhone Settings")
            task.progress.completedUnitCount = 3
        }
        // Request the notification even if the app just changed state. This is
        // the fallback when the system task UI is hidden or minimized.
        notify("BloomBox JIT PIN: \(pin)", body: "Enter this code in Settings to finish pairing.")

    }

    private func finished(status: Int32, data: Data?, device: String?, message: String?) {
        if let session { husk_rppairing_free(session) }
        session = nil
        stopAdvertising()
        deadline?.invalidate()
        deadline = nil
        switch status {
        case 0:
            do {
                guard let data else { throw NSError(domain: "ManzanaJIT", code: 20) }
                try LiveBoardBuiltInJIT.storeOnDevicePairing(data)
                phase = .paired(device: device ?? "this \(Self.deviceKind)")
                log("paired")
                if UIApplication.shared.applicationState != .active {
                    notify("Paired with BloomBox", body: "Return to BloomBox to finish setting up JIT.")
                }
                endBackground(success: true)
            } catch {
                fail("Pairing finished, but BloomBox could not save the pairing file.")
            }
        case 2:
            endBackground(success: false)
        default:
            fail(message.map { "Pairing failed: \($0)" } ?? "Pairing failed. Try again.")
        }
    }

    private func fail(_ message: String) {
        if let session { husk_rppairing_cancel(session) }
        stopAdvertising()
        phase = .failed(message)
        log("failed")
        endBackground(success: false)
    }

    static var deviceKind: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }

    nonisolated private static func take(_ string: UnsafeMutablePointer<CChar>?) -> String? {
        guard let string else { return nil }
        defer { husk_rppairing_string_free(string) }
        return String(cString: string)
    }

    // MARK: Advertising

    private func publish(_ session: OpaquePointer) -> Bool {
        var txt = TXTRecordRef()
        TXTRecordCreate(&txt, 0, nil)
        defer { TXTRecordDeallocate(&txt) }
        for index in 0..<husk_rppairing_txt_count(session) {
            guard let key = husk_rppairing_txt_key(session, index),
                  let value = husk_rppairing_txt_value(session, index) else { continue }
            TXTRecordSetValue(&txt, key, UInt8(clamping: strlen(value)), value)
        }
        var ref: DNSServiceRef?
        let error = DNSServiceRegister(
            &ref, 0, 0, husk_rppairing_service_name(session), "_remotepairing-pairable-host._tcp", nil, nil,
            husk_rppairing_port(session).bigEndian, TXTRecordGetLength(&txt), TXTRecordGetBytesPtr(&txt),
            { _, _, error, _, _, _, _ in
                guard error != DNSServiceErrorType(kDNSServiceErr_NoError) else { return }
                DispatchQueue.main.async { ManzanaOnDevicePairing.shared.advertisingFailed(error) }
            }, nil)
        guard error == DNSServiceErrorType(kDNSServiceErr_NoError), let ref else {
            advertisingFailed(error)
            return false
        }
        DNSServiceSetDispatchQueue(ref, .main)
        registration = ref
        return true
    }

    private func advertisingFailed(_ error: DNSServiceErrorType) {
        guard active else { return }
        log("advertising failed error=\(error)")
        fail(error == DNSServiceErrorType(kDNSServiceErr_PolicyDenied)
             ? "BloomBox needs Local Network access to pair. Allow it in Settings › Apps › BloomBox, then try again."
             : "BloomBox could not announce itself on the local network. Check that Wi-Fi is on, then try again.")
    }

    private func stopAdvertising() {
        if let registration { DNSServiceRefDeallocate(registration) }
        registration = nil
    }

    // MARK: Background

    /// The permitted "<bundle id>.pairing.*" identifier from Info.plist, made concrete.
    private var taskIdentifier: String? {
        let permitted = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []
        guard let wildcard = permitted.first(where: { $0.hasSuffix(".pairing.*") }) else { return nil }
        return String(wildcard.dropLast()) + "session"
    }

    /// Allows retrying only when the previous request was refused or expired.
    /// A fresh request is made in the foreground in direct response to a tap.
    func retryBackgroundProtection() {
        guard active, protectionRetryAvailable, UIApplication.shared.applicationState == .active else { return }
        guard continued == nil && !continuedRequestPending else { return }
        if #available(iOS 26.0, *) {
            protectionRetryAvailable = false
            backgroundLimited = true
            backgroundStatus = "Requesting background protection again…"
            submitContinued()
        }
    }

    private func beginBackground() {
        grace = UIApplication.shared.beginBackgroundTask(withName: "BloomBox pairing") {
            MainActor.assumeIsolated {
                let pairing = ManzanaOnDevicePairing.shared
                if pairing.continued == nil && pairing.active {
                    pairing.backgroundLimited = true
                    pairing.backgroundStatus = "iOS ended background execution before the PIN arrived."
                    pairing.cancel(reason: "iOS suspended BloomBox before the PIN could be received. "
                                         + "Start again once background protection is active, then open Settings.")
                }
                pairing.endGrace()
            }
        }
        if #available(iOS 26.0, *) { submitContinued() } else { backgroundLimited = true }
    }

    @available(iOS 26.0, *)
    private func submitContinued() {
        guard let identifier = taskIdentifier else {
            backgroundLimited = true
            protectionRetryAvailable = true
            backgroundStatus = "Background task identifier is unavailable after signing."
            log("missing background task identifier")
            return
        }
        if registered != identifier {
            let ok = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
                guard let task = task as? BGContinuedProcessingTask else { task.setTaskCompleted(success: false); return }
                MainActor.assumeIsolated { ManzanaOnDevicePairing.shared.attach(task) }
            }
            guard ok else {
                log("register refused")
                backgroundLimited = true
                protectionRetryAvailable = true
                backgroundStatus = "iOS refused to register background pairing."
                return
            }
            registered = identifier
        }
        let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: "Pairing with BloomBox",
                                                       subtitle: "Settings › Privacy & Security › Developer Mode")
        // .fail can reject immediately when the device is temporarily busy.
        // The default .queue strategy lets iOS grant this user-initiated job
        // when resources are available. The UI must wait for attach(), not submit().
        request.strategy = .queue
        continuedRequestPending = true
        do {
            try BGTaskScheduler.shared.submit(request)
            log("continued-processing submitted")
            // The launch handler may already have run by the time submit returns.
            if continued == nil {
                backgroundLimited = true
                backgroundStatus = "Waiting for iOS to activate background protection…"
            }
        } catch {
            continuedRequestPending = false
            log("continued-processing refused: \(error.localizedDescription)")
            backgroundLimited = true
            protectionRetryAvailable = true
            backgroundStatus = "iOS refused background protection: \(error.localizedDescription)"
        }
    }

    @available(iOS 26.0, *)
    private func attach(_ task: BGContinuedProcessingTask) {
        guard active else { task.setTaskCompleted(success: false); return }
        continued = task
        continuedRequestPending = false
        protectionRetryAvailable = false
        backgroundLimited = false
        backgroundStatus = "Background protection active. Open iPhone Settings and select Pair with BloomBox."
        // Host listening + Bonjour advertising are already complete.
        // Report real progress: 2/4 ready, 3/4 PIN, 4/4 paired.
        task.progress.totalUnitCount = 4
        task.progress.completedUnitCount = 2
        if case .pin(let pin) = phase {
            task.updateTitle("BloomBox JIT PIN: \(pin)", subtitle: "Enter this code in iPhone Settings")
            task.progress.completedUnitCount = 3
        }
        task.expirationHandler = {
            DispatchQueue.main.async {
                let pairing = ManzanaOnDevicePairing.shared
                // The short UIKit background allowance may still be valid:
                // do not cancel a handshake while that grace period remains.
                pairing.continued = nil
                pairing.continuedRequestPending = false
                pairing.backgroundLimited = true
                pairing.protectionRetryAvailable = UIApplication.shared.applicationState == .active
                pairing.backgroundStatus = "iOS ended the continuous task. If you are in BloomBox, tap Retry background protection before opening Settings."
                task.setTaskCompleted(success: false)
                if pairing.grace == .invalid && pairing.active {
                    pairing.cancel(reason: "iOS stopped background pairing before a PIN arrived. "
                                          + "Check the background protection status and retry.")
                }
            }
        }
        log("continued-processing running")
    }

    private func endBackground(success: Bool) {
        if #available(iOS 26.0, *) {
            if continuedRequestPending, let identifier = taskIdentifier {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            }
        }
        continuedRequestPending = false
        protectionRetryAvailable = false
        if #available(iOS 26.0, *), let task = continued as? BGContinuedProcessingTask {
            if success {
                task.progress.completedUnitCount = task.progress.totalUnitCount
            }
            task.setTaskCompleted(success: success)
        }
        continued = nil
        if success {
            backgroundStatus = "Pairing completed successfully."
        }
        endGrace()
    }

    private func endGrace() {
        guard grace != .invalid else { return }
        UIApplication.shared.endBackgroundTask(grace)
        grace = .invalid
    }

    // MARK: Notifications

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(_ title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "husk.pairing.\(UUID().uuidString)",
                                                                     content: content, trigger: nil))
    }
}
