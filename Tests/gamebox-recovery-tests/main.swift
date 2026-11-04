import Foundation

@main
struct GameBoxRecoveryTests {
    static func main() {
        let suite = "BloomBox.GameBox.Recovery.Tests." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("Could not create isolated test preferences")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        assert(!BloomBoxGameBoxRecoveryPolicy.recoverPreviousSession(defaults: defaults))
        assert(!BloomBoxGameBoxRecoveryPolicy.begin(defaults: defaults))
        assert(defaults.string(forKey: BloomBoxGameBoxRecoveryPolicy.stageKey) == "opening")

        BloomBoxGameBoxRecoveryPolicy.noteIcon("game-bundle-a", defaults: defaults)
        // Simulate a crash while the image was being decoded and a new process
        // starting with the regular desktop instead of GameBox.
        assert(BloomBoxGameBoxRecoveryPolicy.recoverPreviousSession(defaults: defaults))
        assert(BloomBoxGameBoxRecoveryPolicy.shouldSkipIcon("game-bundle-a", defaults: defaults))
        assert(defaults.string(forKey: BloomBoxGameBoxRecoveryPolicy.stageKey) == "closed")
        assert(BloomBoxGameBoxRecoveryPolicy.begin(defaults: defaults))

        BloomBoxGameBoxRecoveryPolicy.useFullUI(defaults: defaults)
        assert(!defaults.bool(forKey: BloomBoxGameBoxRecoveryPolicy.safeModeKey))
        assert(BloomBoxGameBoxRecoveryPolicy.shouldSkipIcon("game-bundle-a", defaults: defaults),
               "Retain the crashing icon quarantine on full-mode retry")

        BloomBoxGameBoxRecoveryPolicy.close(defaults: defaults)
        assert(!BloomBoxGameBoxRecoveryPolicy.recoverPreviousSession(defaults: defaults))
        assert(!BloomBoxGameBoxRecoveryPolicy.begin(defaults: defaults),
               "Clean exit must not force safe mode")

        BloomBoxGameBoxRecoveryPolicy.useSafeUI(defaults: defaults)
        assert(defaults.bool(forKey: BloomBoxGameBoxRecoveryPolicy.safeModeKey))
        assert(defaults.string(forKey: BloomBoxGameBoxRecoveryPolicy.stageKey) == "safe")
        BloomBoxGameBoxRecoveryPolicy.close(defaults: defaults)
        assert(BloomBoxGameBoxRecoveryPolicy.begin(defaults: defaults),
               "Manual safe-mode preference should survive clean exits")
        print("PASS: GameBox automatic crash recovery, quarantine, safe mode, retry and clean exit")
    }
}
