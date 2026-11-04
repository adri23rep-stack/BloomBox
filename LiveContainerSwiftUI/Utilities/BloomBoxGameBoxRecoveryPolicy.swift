import Foundation

/// Local-only crash recovery for the GameBox UI; no changes to installed guests.
enum BloomBoxGameBoxRecoveryPolicy {
    static let stageKey = "BloomBoxGameBoxV2OpenStage"
    static let safeModeKey = "BloomBoxGameBoxV2SafeMode"
    static let skippedIconKey = "BloomBoxGameBoxV2QuarantinedIcon"

    /// Called once before normal Home mode restoration has a chance to
    /// overwrite the previous unfinished checkpoint.
    @discardableResult
    static func recoverPreviousSession(defaults: UserDefaults) -> Bool {
        let previous = defaults.string(forKey: stageKey) ?? "closed"
        if previous != "closed" {
            defaults.set(true, forKey: safeModeKey)
            if previous.hasPrefix("icon:") {
                defaults.set(String(previous.dropFirst(5)), forKey: skippedIconKey)
            }
        }
        close(defaults: defaults)
        return defaults.bool(forKey: safeModeKey)
    }

    /// Mark this BEFORE changing LiveBoardMode, not during the complex UI's body.
    /// Unfinished checkpoints on next entry mean the previous UI did not
    /// complete a normal exit (a crash, force-quit, or process termination).
    @discardableResult
    static func begin(defaults: UserDefaults) -> Bool {
        let prior = defaults.string(forKey: stageKey) ?? "closed"
        if prior != "closed" {
            defaults.set(true, forKey: safeModeKey)
            if prior.hasPrefix("icon:") {
                defaults.set(String(prior.dropFirst(5)), forKey: skippedIconKey)
            }
        }
        defaults.set("opening", forKey: stageKey)
        return defaults.bool(forKey: safeModeKey)
    }

    static func checkpoint(_ stage: String, defaults: UserDefaults) {
        defaults.set(stage, forKey: stageKey)
    }

    static func noteIcon(_ id: String, defaults: UserDefaults) {
        guard !id.isEmpty else { return }
        defaults.set("icon:" + id, forKey: stageKey)
    }

    static func shouldSkipIcon(_ id: String, defaults: UserDefaults) -> Bool {
        defaults.string(forKey: skippedIconKey) == id
    }

    static func useFullUI(defaults: UserDefaults) {
        defaults.set(false, forKey: safeModeKey)
        // Keep any quarantined icon when retrying full mode, otherwise the
        // same corrupt resource could repeatedly terminate the process.
        defaults.set("opening", forKey: stageKey)
    }

    static func useSafeUI(defaults: UserDefaults) {
        defaults.set(true, forKey: safeModeKey)
        defaults.set("safe", forKey: stageKey)
    }

    static func close(defaults: UserDefaults) {
        defaults.set("closed", forKey: stageKey)
    }
}
