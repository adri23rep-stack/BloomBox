import Foundation

/// Game Mode never guesses that a debugger session is active.
/// RAM+ must be present in the currently signed host AND LiveProcess;
/// JIT must be configured so a fresh attach can be attempted per launch.
enum BloomBoxGameModeGate {
    enum Missing: String { case ramPlus, jit }
    static func firstMissing(ramConfirmed: Bool, liveProcessSigned: Bool,
                             builtInJITSelected: Bool, debuggingAvailable: Bool,
                             pairingPresent: Bool) -> Missing? {
        if !ramConfirmed || !liveProcessSigned { return .ramPlus }
        if !builtInJITSelected || !debuggingAvailable || !pairingPresent { return .jit }
        return nil
    }

    /// The rendered Game launcher is authoritative during launch. SwiftUI's
    /// persisted mode may temporarily lag during iOS 27 scene rotation, and
    /// the legacy LiveContainer delegate may be called a second time.
    /// Route exactly once, only from Home; never route Game back to Game.
    static func shouldOfferGameSwitch(requiresGame: Bool, fromGameLauncher: Bool,
                                      persistedMode: String) -> Bool {
        requiresGame && !fromGameLauncher && persistedMode != "cinematic"
    }

    /// Explicit landscape apps (and Husk, whose guest renderer needs landscape)
    /// use Game Mode instead of inheriting the iOS Home portrait scene.
    static func requiresGameMode(bundleID: String?, name: String, landscapeLocked: Bool) -> Bool {
        let id = (bundleID ?? "").lowercased()
        let title = name.lowercased()
        return landscapeLocked || id.contains("husk") || title == "husk"
    }
}
