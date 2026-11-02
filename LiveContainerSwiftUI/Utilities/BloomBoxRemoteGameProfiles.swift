import SwiftUI

/// Verified, cached game/LiveContainer settings. Only the exact official
/// BloomBox-Catalog URL may feed this registry; never download runnable content.
@MainActor
final class BloomBoxRemoteGameProfiles: ObservableObject {
    static let shared = BloomBoxRemoteGameProfiles()

    @Published private(set) var profiles: [BloomBoxGameProfile] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastSync: Date?
    @Published private(set) var updating = false

    private static let cacheKey = "BloomBoxGameProfilesVerified-v1"
    private static let syncKey = "BloomBoxGameProfilesLastSync-v1"
    private static let catalogURL = URL(string:
        "https://raw.githubusercontent.com/adri23rep-stack/BloomBox-Catalog/main/catalog/game-profiles.json")!
    private let defaults = LCUtils.appGroupUserDefault
    private var lastAttempt: Date?

    private init() {
        lastSync = defaults.object(forKey: Self.syncKey) as? Date
        if let data = defaults.data(forKey: Self.cacheKey),
           data.count <= 100_000,
           let index = BloomBoxGameProfileIndex.validated(from: data) {
            profiles = index.profiles
        }
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard !updating else { return }
        if !force, let lastAttempt,
           Date().timeIntervalSince(lastAttempt) < 3600 { return }
        updating = true
        lastAttempt = Date()
        defer { updating = false }
        do {
            var request = URLRequest(url: Self.catalogURL)
            request.timeoutInterval = 10
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  response.statusCode == 200,
                  data.count > 0, data.count <= 100_000,
                  response.url?.scheme == "https",
                  response.url?.host == "raw.githubusercontent.com",
                  response.url?.path == Self.catalogURL.path else {
                throw NSError(domain: "BloomBoxGameProfiles", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No se pudo verificar la lista de juegos. Se conserva la versión local."])
            }
            guard let index = BloomBoxGameProfileIndex.validated(from: data) else {
                throw NSError(domain: "BloomBoxGameProfiles", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Perfil remoto incompatible; no se aplicó."])
            }
            profiles = index.profiles
            defaults.set(data, forKey: Self.cacheKey)
            lastSync = Date()
            defaults.set(lastSync, forKey: Self.syncKey)
            lastError = nil
        } catch {
            // Keep the last validated cache, never replace it with a failed fetch.
            lastError = error.localizedDescription
        }
    }

    func profile(for bundleID: String?) -> BloomBoxGameProfile? {
        guard let bundleID else { return nil }
        if let remote = profiles.first(where: { $0.bundleID == bundleID }) {
            return remote
        }
        // Important offline fallback: verified from Husk's official project.yml.
        // The remote list may extend or override it after successful validation.
        if bundleID == "com.husk.app" {
            return BloomBoxGameProfile(
                bundleID: "com.husk.app", name: "Husk", revision: 1,
                gameMode: true, requiresRAMPlus: true, requiresJIT: true,
                compatibility: BloomBoxGameCompatibility(
                    orientation: "landscape", jitNeeded: true,
                    classicMode: nil, spoofSDKVersion: nil,
                    hideLiveContainer: nil, dontInjectTweakLoader: nil,
                    fixFilePicker: nil, fixLocalNotification: nil),
                evidence: "Probado en BloomBox con iOS 27.", notes: nil)
        }
        return nil
    }

    private func consentKey(for bundleID: String) -> String {
        "BloomBoxCompatibilityApproved-v1.\(bundleID)"
    }

    private func declinedKey(for bundleID: String) -> String {
        "BloomBoxCompatibilityDeclined-v1.\(bundleID)"
    }

    func needsApproval(_ profile: BloomBoxGameProfile) -> Bool {
        guard profile.compatibility?.hasChanges == true else { return false }
        return defaults.integer(forKey: consentKey(for: profile.bundleID)) < profile.revision &&
            defaults.integer(forKey: declinedKey(for: profile.bundleID)) < profile.revision
    }

    func decline(_ profile: BloomBoxGameProfile) {
        // Do not repeatedly interrupt a launch if this revision was declined.
        // A newer revision can ask again, and manual settings remain editable.
        defaults.set(profile.revision, forKey: declinedKey(for: profile.bundleID))
    }

    func applyApprovedProfile(_ profile: BloomBoxGameProfile, to app: LCAppModel) {
        guard app.bundleIdentifier == profile.bundleID,
              profile.isValid,
              let settings = profile.compatibility else { return }

        // Per-app LiveContainer settings only. No global permission, certificate,
        // script, network policy, signing, file or account settings are modified.
        switch settings.orientation {
        case "landscape": app.uiOrientationLock = .Landscape
        case "portrait": app.uiOrientationLock = .Portrait
        case "auto": app.uiOrientationLock = .Disabled
        default: break
        }
        if let value = settings.jitNeeded { app.uiIsJITNeeded = value }
        if let value = settings.classicMode { app.uiClassicMode = value }
        if let value = settings.spoofSDKVersion { app.uiSpoofSDKVersion = value }
        if let value = settings.hideLiveContainer { app.uiHideLiveContainer = value }
        if let value = settings.dontInjectTweakLoader { app.uiDontInjectTweakLoader = value }
        if let value = settings.fixFilePicker { app.uiFixFilePickerNew = value }
        if let value = settings.fixLocalNotification { app.uiFixLocalNotification = value }
        // Keep manually adjusted settings intact on later launches.
        defaults.set(profile.revision, forKey: consentKey(for: profile.bundleID))
    }
}
