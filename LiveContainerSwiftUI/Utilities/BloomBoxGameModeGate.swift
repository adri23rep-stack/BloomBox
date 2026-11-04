import Foundation

/// Game Mode is a presentation mode, not a request to enable JIT.
/// RAM+ is required by this mode. JIT setup is required only when the
/// particular guest has JIT enabled (or the user explicitly requests it).
enum BloomBoxGameModeGate {
    enum Missing: String { case ramPlus, jit }
    static func firstMissing(ramConfirmed: Bool, liveProcessSigned: Bool,
                             builtInJITSelected: Bool, debuggingAvailable: Bool,
                             pairingPresent: Bool, jitRequired: Bool = true) -> Missing? {
        if !ramConfirmed || !liveProcessSigned { return .ramPlus }
        if jitRequired && (!builtInJITSelected || !debuggingAvailable || !pairingPresent) { return .jit }
        return nil
    }

    /// A normal Game Mode launch leaves the per-app policy in charge.
    /// Passing false directly to LiveContainer would also incorrectly override
    /// apps that have JIT enabled, so only explicit user requests force true.
    static func jitOverride(explicitlyRequested: Bool) -> Bool? {
        explicitlyRequested ? true : nil
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
