import Foundation

struct BloomBoxGameBoxLibrary: Codable, Equatable {
    var categories = ["Games", "Ports", "Emuladores"]
    var assignments: [String: String] = [:]
    var hidden: Set<String> = []
    /// Migrate only the GameBox library; other launcher categories are untouched.
    /// Preserve assignments that users saved under the previous "Tools" tab.
    mutating func migrateGameBoxCategories() {
        categories = categories.map { $0 == "Tools" ? "Emuladores" : $0 }
        var unique = Set<String>()
        categories = categories.filter { unique.insert($0).inserted }
        if !categories.contains("Emuladores") { categories.append("Emuladores") }
        for (app, category) in assignments where category == "Tools" {
            assignments[app] = "Emuladores"
        }
    }
    mutating func addCategory(_ value: String) -> Bool {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 30,
              !(["Library", "Favorites", "All"] + categories).contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return false }
        categories.append(name); return true
    }
    mutating func removeCategory(_ name: String) {
        categories.removeAll { $0 == name }; assignments = assignments.filter { $0.value != name }
    }
}


/// "cinematic" remains the stable stored ID; GameBox is only its display name.
/// LiveBoardMode is the active session, not the persisted startup preference.
enum BloomBoxLaunchPreferences {
    static let primaryKey = "BloomBoxPrimaryLauncher"
    static let sessionKey = "LiveBoardMode"
    static let pendingKey = "BloomBoxGamePendingEntry"
    static let pendingAppKey = "BloomBoxGamePendingApp"

    static func preferredMode(defaults: UserDefaults) -> String {
        defaults.string(forKey: primaryKey) == "cinematic" ? "cinematic" : "ios"
    }

    /// Call exactly once per *process*, before mounting the launcher.
    /// Reopening after force-close never inherits the last temporary GameBox visit.
    @discardableResult
    static func resetForNewProcess(defaults: UserDefaults) -> String {
        let initial = preferredMode(defaults: defaults)
        defaults.set(initial, forKey: sessionKey)
        defaults.set(false, forKey: pendingKey)
        defaults.removeObject(forKey: pendingAppKey)
        return initial
    }
}

// Existing Swift callers retain their types; saved GameBox JSON stays unchanged.
typealias LiveBoardModeLibrary = BloomBoxGameBoxLibrary
