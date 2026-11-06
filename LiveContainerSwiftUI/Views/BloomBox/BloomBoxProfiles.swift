import Foundation
import SwiftUI
import UIKit

/// BloomBox profile metadata is separate from LiveContainer's guest storage.
/// The primary profile deliberately reuses each app's current default container.
struct BloomBoxUserProfile: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var accentHex: String
    var photoFile: String?

    static let primaryID = "primary"
    static let initial = BloomBoxUserProfile(
        id: primaryID, name: "Mi perfil", accentHex: "8A6CF4", photoFile: nil
    )
}

enum BloomBoxProfileStore {
    static let profilesKey = "BloomBoxUserProfilesV1"
    static let activeKey = "BloomBoxActiveUserProfileV1"
    static let didActivate = Notification.Name("BloomBoxActiveProfileDidActivate")
    static let containerMapKey = "BloomBoxProfileContainersV1"
    static let revisionKey = "BloomBoxUserProfilesRevisionV1"
    static let palette = ["8A6CF4", "F064A7", "F28B55", "E5B83F",
                          "48BBA3", "58A3ED", "6A6CD9", "DF6574"]

    private static var defaults: UserDefaults { LiveContainerPreferencesAdapter.defaults }

    static var profiles: [BloomBoxUserProfile] {
        guard let data = defaults.data(forKey: profilesKey),
              let saved = try? JSONDecoder().decode([BloomBoxUserProfile].self, from: data),
              !saved.isEmpty else { return [.initial] }
        // Never let corrupt metadata silently orphan the original profile.
        if saved.contains(where: { $0.id == BloomBoxUserProfile.primaryID }) {
            return saved
        }
        return [.initial] + saved
    }

    static var active: BloomBoxUserProfile {
        let id = defaults.string(forKey: activeKey) ?? BloomBoxUserProfile.primaryID
        return profiles.first(where: { $0.id == id }) ?? profiles[0]
    }

    static func finishInitialSetup(name: String, accentHex: String, image: UIImage?) {
        var all = profiles
        guard let index = all.firstIndex(where: { $0.id == BloomBoxUserProfile.primaryID }) else { return }
        all[index].name = cleanedName(name)
        all[index].accentHex = safeAccent(accentHex)
        if let image, let file = savePhoto(image, for: BloomBoxUserProfile.primaryID) {
            all[index].photoFile = file
        }
        persist(all)
        defaults.set(BloomBoxUserProfile.primaryID, forKey: activeKey)
    }

    @discardableResult
    static func add(name: String, accentHex: String, image: UIImage?) -> BloomBoxUserProfile {
        let id = UUID().uuidString
        let photo = image.flatMap { savePhoto($0, for: id) }
        let new = BloomBoxUserProfile(
            id: id, name: cleanedName(name), accentHex: safeAccent(accentHex), photoFile: photo
        )
        var all = profiles
        all.append(new)
        persist(all)
        // New secondary profiles use the wizard's recommended Hybrid
        // experience. Existing profile choices remain unchanged.
        BloomBoxLaunchPreferences.setPreferredMode(
            "hybrid", profileID: id, defaults: defaults)
        return new
    }

    static func activate(_ id: String) {
        guard profiles.contains(where: { $0.id == id }), active.id != id else { return }
        defaults.set(id, forKey: activeKey)
        // New guest launches resolve the selected profile. Never move or
        // replace data belonging to a previous profile.
        NotificationCenter.default.post(name: didActivate, object: id)
    }

    /// Only changes BloomBox profile details. Existing LiveContainer
    /// guest folders, mappings and default containers remain untouched.
    @discardableResult
    static func edit(id: String, name: String, accentHex: String,
                     image: UIImage?) -> BloomBoxUserProfile? {
        var all = profiles
        guard let index = all.firstIndex(where: { $0.id == id }) else { return nil }
        all[index].name = cleanedName(name)
        all[index].accentHex = safeAccent(accentHex)
        if let image {
            if let filename = savePhoto(image, for: id) {
                all[index].photoFile = filename
            }
        } else {
            removePhoto(for: all[index])
            all[index].photoFile = nil
        }
        persist(all)
        return all[index]
    }

    /// Remove a secondary *profile record*, never the guest app data.
    /// The installed app containers stay available for manual recovery.
    @discardableResult
    static func delete(id: String) -> Bool {
        guard id != BloomBoxUserProfile.primaryID,
              let victim = profiles.first(where: { $0.id == id }) else { return false }
        let remaining = profiles.filter { $0.id != id }
        guard remaining.contains(where: { $0.id == BloomBoxUserProfile.primaryID }) else {
            return false
        }
        persist(remaining)
        // No filesystem operation touches an installed app or its containers.
        // Keep historical container mappings for possible data recovery.
        removePhoto(for: victim)
        if defaults.string(forKey: activeKey) == id {
            defaults.set(BloomBoxUserProfile.primaryID, forKey: activeKey)
            NotificationCenter.default.post(name: didActivate,
                                            object: BloomBoxUserProfile.primaryID)
        }
        return true
    }

    private static func removePhoto(for profile: BloomBoxUserProfile) {
        // Only our own per-profile image may be removed, never a guest folder.
        let expected = "profile-" + profile.id + ".jpg"
        guard profile.photoFile == expected,
              expected == URL(fileURLWithPath: expected).lastPathComponent else { return }
        try? FileManager.default.removeItem(
            at: photoDirectory.appendingPathComponent(expected))
    }

    static func updateColor(_ hex: String, for id: String) {
        var all = profiles
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].accentHex = safeAccent(hex)
        persist(all)
    }

    static func mapping(for profileID: String, appKey: String) -> String? {
        containerMappings[profileID]?[appKey]
    }

    static func rememberContainer(_ folderName: String, profileID: String, appKey: String) {
        var all = containerMappings
        var appMap = all[profileID] ?? [:]
        appMap[appKey] = folderName
        all[profileID] = appMap
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: containerMapKey)
        }
    }

    private static var containerMappings: [String: [String: String]] {
        guard let data = defaults.data(forKey: containerMapKey),
              let value = try? JSONDecoder().decode([String: [String: String]].self, from: data)
        else { return [:] }
        return value
    }

    static func photo(for profile: BloomBoxUserProfile) -> UIImage? {
        guard let filename = profile.photoFile,
              filename == URL(fileURLWithPath: filename).lastPathComponent,
              let data = try? Data(contentsOf: photoDirectory.appendingPathComponent(filename))
        else { return nil }
        return UIImage(data: data)
    }

    private static func savePhoto(_ image: UIImage, for id: String) -> String? {
        let maxDimension: CGFloat = 560
        let scale = min(1.0, maxDimension / max(image.size.width, image.size.height, 1))
        let size = CGSize(width: max(1, image.size.width * scale),
                          height: max(1, image.size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: size)
        let imageData = renderer.jpegData(withCompressionQuality: 0.79) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        let filename = "profile-" + id + ".jpg"
        do {
            try FileManager.default.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
            try imageData.write(to: photoDirectory.appendingPathComponent(filename), options: .atomic)
            return filename
        } catch {
            NSLog("[BloomBox] Could not save profile picture: %@", String(describing: error))
            return nil
        }
    }

    private static var photoDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBox/ProfilePhotos", isDirectory: true)
    }

    private static func persist(_ profiles: [BloomBoxUserProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: profilesKey)
        // Updating a photo in place does not change its filename. This token
        // tells every profile avatar to reload even when JSON is unchanged.
        defaults.set(UUID().uuidString, forKey: revisionKey)
    }

    private static func cleanedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Mi perfil" : String(trimmed.prefix(40))
    }

    private static func safeAccent(_ hex: String) -> String {
        palette.contains(hex.uppercased()) ? hex.uppercased() : palette[0]
    }
}

enum BloomBoxWizardPalette {
    static func color(_ hex: String) -> Color {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard normalized.count == 6, let number = UInt64(normalized, radix: 16) else {
            return Color(red: 0.54, green: 0.42, blue: 0.96)
        }
        return Color(
            red: Double((number >> 16) & 255) / 255,
            green: Double((number >> 8) & 255) / 255,
            blue: Double(number & 255) / 255
        )
    }
}
