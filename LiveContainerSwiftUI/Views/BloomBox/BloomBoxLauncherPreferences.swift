// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack (original BloomBox material only).
// Additional author-attribution term under AGPLv3 section 7(b):
// see LICENSE-ADDITIONAL-TERMS.md.

import Foundation

/// Persist the preferred experience per BloomBox profile while keeping
/// LiveBoardMode as a transient on-screen destination (ios/gamebox).
/// Existing installations retain their historical iOS Home preference.
enum BloomBoxLaunchPreferences {
    static let primaryKey = "BloomBoxPrimaryLauncher"
    static let sessionKey = "LiveBoardMode"
    static let profileModesKey = "BloomBoxProfileLauncherModesV1"
    static let shortcutKey = "BloomBoxGameBoxShortcutEnabled"
    static let shortcutXKey = "BloomBoxGameBoxShortcutX"
    static let shortcutYKey = "BloomBoxGameBoxShortcutY"
    static let recentGamesKey = "BloomBoxGameBoxRecentTitlesByProfileV1"
    // Historical transitions only: clear stale pending launches, never guest data.
    static let pendingKey = "BloomBoxGamePendingEntry"
    static let pendingAppKey = "BloomBoxGamePendingApp"

    static let validModes: Set<String> = ["ios", "gamebox", "hybrid"]

    static func savedModes(defaults: UserDefaults) -> [String: String] {
        guard let result = defaults.dictionary(forKey: profileModesKey) as? [String: String]
        else { return [:] }
        return result.filter { !$0.key.isEmpty && validModes.contains($0.value) }
    }

    static func preferredMode(defaults: UserDefaults, profileID: String = "primary") -> String {
        // No migration of the old ephemeral LiveBoardMode: that was never
        // a deliberate per-profile choice.
        savedModes(defaults: defaults)[profileID] ?? "ios"
    }

    static func runtimeMode(for preference: String) -> String {
        preference == "gamebox" ? "gamebox" : "ios"
    }

    static func setPreferredMode(_ preference: String, profileID: String,
                                 defaults: UserDefaults) {
        guard !profileID.isEmpty, validModes.contains(preference) else { return }
        var modes = savedModes(defaults: defaults)
        modes[profileID] = preference
        defaults.set(modes, forKey: profileModesKey)
        defaults.set(preference, forKey: primaryKey)
        // A mode switch never wipes guest settings or profile mappings.
    }

    static func rememberGame(_ name: String, profileID: String, defaults: UserDefaults) {
        let title = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        guard !title.isEmpty, !profileID.isEmpty else { return }
        var all = defaults.dictionary(forKey: recentGamesKey) as? [String: [String]] ?? [:]
        var recent = all[profileID] ?? []
        recent.removeAll { $0 == title }
        recent.insert(title, at: 0)
        all[profileID] = Array(recent.prefix(4))
        defaults.set(all, forKey: recentGamesKey)
        defaults.set(UUID().uuidString, forKey: "BloomBoxGameBoxRecentRevisionV1")
    }

    static func recentGames(profileID: String, defaults: UserDefaults) -> [String] {
        let all = defaults.dictionary(forKey: recentGamesKey) as? [String: [String]] ?? [:]
        return Array((all[profileID] ?? []).prefix(4))
    }

    @discardableResult
    static func resetForNewProcess(defaults: UserDefaults,
                                   profileID: String = "primary") -> String {
        let preference = preferredMode(defaults: defaults, profileID: profileID)
        defaults.set(preference, forKey: primaryKey)
        let runtime = runtimeMode(for: preference)
        defaults.set(runtime, forKey: sessionKey)
        defaults.set(false, forKey: pendingKey)
        defaults.removeObject(forKey: pendingAppKey)
        return runtime
    }
}
