import Foundation

// Read-only, exact-bundle-ID compatibility metadata. Remote JSON is never
// allowed to contain executable scripts, arbitrary URLs, entitlements,
// signing commands, permission grants or file operations.
struct BloomBoxGameProfileIndex: Codable {
    let schemaVersion: Int
    let catalogID: String
    let updatedAt: String
    let profiles: [BloomBoxGameProfile]

    static func validated(from data: Data) -> BloomBoxGameProfileIndex? {
        // JSONDecoder ignores unknown fields by default. Reject them instead:
        // a catalog change cannot silently add executable actions or hidden
        // permission controls to a supposedly declarative profile.
        guard data.count > 0, data.count <= 100_000,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              Set(root.keys).isSubset(of: Set(["schemaVersion", "catalogID", "updatedAt", "profiles"])),
              let raw = root["profiles"] as? [[String: Any]], raw.count <= 100 else {
            return nil
        }
        let profileFields = Set(["bundleID", "name", "revision", "gameMode",
                                 "requiresRAMPlus", "requiresJIT", "compatibility", "evidence", "notes"])
        let settingFields = Set(["orientation", "jitNeeded", "classicMode", "spoofSDKVersion",
                                 "hideLiveContainer", "dontInjectTweakLoader", "fixFilePicker",
                                 "fixLocalNotification"])
        for entry in raw {
            guard Set(entry.keys).isSubset(of: profileFields) else { return nil }
            if let flags = entry["compatibility"] {
                guard let flags = flags as? [String: Any],
                      Set(flags.keys).isSubset(of: settingFields) else { return nil }
            }
        }
        guard let index = try? JSONDecoder().decode(BloomBoxGameProfileIndex.self, from: data),
              index.isValid else { return nil }
        return index
    }

    var isValid: Bool {
        guard schemaVersion == 1,
              catalogID == "bloombox.game-compatibility",
              profiles.count <= 100 else { return false }
        let ids = profiles.map(\.bundleID)
        return Set(ids).count == ids.count && profiles.allSatisfy(\.isValid)
    }
}

struct BloomBoxGameProfile: Codable, Identifiable {
    let bundleID: String
    let name: String
    let revision: Int
    let gameMode: Bool
    let requiresRAMPlus: Bool
    let requiresJIT: Bool
    let compatibility: BloomBoxGameCompatibility?
    let evidence: String?
    let notes: String?

    var id: String { bundleID }

    var isValid: Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        let bundleValid = bundleID.count >= 3 && bundleID.count <= 130 &&
            bundleID.contains(".") &&
            bundleID.unicodeScalars.allSatisfy { allowed.contains($0) } &&
            !bundleID.contains("..") && !bundleID.hasPrefix(".") && !bundleID.hasSuffix(".")
        return bundleValid && !name.isEmpty && name.count <= 90 &&
            (1...100000).contains(revision) &&
            (evidence?.count ?? 0) <= 600 &&
            (notes?.count ?? 0) <= 600 &&
            (compatibility?.isValid ?? true) &&
            !(gameMode && compatibility?.classicMode == true && requiresJIT)
    }
}

struct BloomBoxGameCompatibility: Codable {
    let orientation: String?
    let jitNeeded: Bool?
    let classicMode: Bool?
    let spoofSDKVersion: Bool?
    let hideLiveContainer: Bool?
    let dontInjectTweakLoader: Bool?
    let fixFilePicker: Bool?
    let fixLocalNotification: Bool?

    var isValid: Bool {
        (orientation == nil || ["landscape", "portrait", "auto"].contains(orientation!))
    }
    var hasChanges: Bool {
        orientation != nil || jitNeeded != nil || classicMode != nil ||
        spoofSDKVersion != nil || hideLiveContainer != nil ||
        dontInjectTweakLoader != nil || fixFilePicker != nil ||
        fixLocalNotification != nil
    }
}
