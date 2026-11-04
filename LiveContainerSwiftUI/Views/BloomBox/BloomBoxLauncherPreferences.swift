// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack (original BloomBox material only).
// Additional author-attribution term under AGPLv3 section 7(b):
// see LICENSE-ADDITIONAL-TERMS.md.

import Foundation

/// Clean startup routing after a retired launcher, while keeping guest data.
enum BloomBoxLaunchPreferences {
    static let primaryKey = "BloomBoxPrimaryLauncher"
    static let sessionKey = "LiveBoardMode"
    // Historical keys only: discard stale transitions, not user app settings.
    static let pendingKey = "BloomBoxGamePendingEntry"
    static let pendingAppKey = "BloomBoxGamePendingApp"

    static func preferredMode(defaults: UserDefaults) -> String { "ios" }

    @discardableResult
    static func resetForNewProcess(defaults: UserDefaults) -> String {
        if defaults.string(forKey: primaryKey) != "ios" {
            defaults.set("ios", forKey: primaryKey)
        }
        defaults.set("ios", forKey: sessionKey)
        defaults.set(false, forKey: pendingKey)
        defaults.removeObject(forKey: pendingAppKey)
        return "ios"
    }
}
