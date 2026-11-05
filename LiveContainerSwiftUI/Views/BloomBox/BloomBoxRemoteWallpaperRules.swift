import Foundation
import Combine

/// Small, read-only remote configuration. Curated Commons image URLs
/// require a matching public-domain license/source record; arbitrary hosts,
/// executable payloads, JIT settings and permission instructions are rejected.
@MainActor
final class BloomBoxRemoteWallpaperRules: ObservableObject {
    static let shared = BloomBoxRemoteWallpaperRules()

    @Published private(set) var revision = 0
    @Published private(set) var lastSync: Date?
    @Published private(set) var lastError: String?

    private let defaults = LiveContainerPreferencesAdapter.defaults
    private let cachedKey = "BloomBoxGameBoxWallpaperRulesVerified-v1"
    private let lastSyncKey = "BloomBoxGameBoxWallpaperRulesSynced-v1"
    private var index: BloomBoxWallpaperRuleIndex?
    private var refreshing = false
    private var lastAttempt: Date?

    // Preview feed on a dedicated catalog branch. Change only this URL to
    // /main/catalog/gamebox-wallpaper-rules.json after the catalog PR merges.
    private static let catalogURL = URL(string:
        "https://raw.githubusercontent.com/adri23rep-stack/BloomBox-Catalog/feature/gamebox-wallpaper-keywords-20261105/catalog/gamebox-wallpaper-rules.json")!

    private init() {
        if let bytes = defaults.data(forKey: cachedKey),
           let valid = BloomBoxWallpaperRuleIndex.validated(from: bytes) {
            index = valid
        }
        lastSync = defaults.object(forKey: lastSyncKey) as? Date
    }

    func rule(bundleID: String?, name: String) -> BloomBoxWallpaperRule? {
        index?.rule(bundleID: bundleID, name: name)
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard !refreshing else { return }
        // Do not hit raw.githubusercontent.com on every icon selection.
        if !force {
            if let lastAttempt, Date().timeIntervalSince(lastAttempt) < 1800 { return }
            if let lastSync, Date().timeIntervalSince(lastSync) < 3600 { return }
        }
        refreshing = true
        lastAttempt = Date()
        defer { refreshing = false }

        do {
            var request = URLRequest(url: Self.catalogURL)
            request.timeoutInterval = 12
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("BloomBox-GameBox/2.0 (https://github.com/adri23rep-stack/BloomBox)",
                             forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  http.url?.scheme == "https",
                  http.url?.host == "raw.githubusercontent.com",
                  http.url?.path == Self.catalogURL.path,
                  data.count > 0 && data.count <= 60_000,
                  let decoded = BloomBoxWallpaperRuleIndex.validated(from: data) else {
                throw NSError(domain: "BloomBoxGameBoxWallpaperCatalog", code: 1,
                              userInfo: [NSLocalizedDescriptionKey:
                                  "Las reglas remotas no son válidas; se conserva la última lista segura."])
            }
            guard !Task.isCancelled else { return }
            // No UI rebuild if the HTTPS response was identical to our cache.
            if data != defaults.data(forKey: cachedKey) {
                index = decoded
                defaults.set(data, forKey: cachedKey)
                revision &+= 1
            } else if index == nil {
                index = decoded
                revision &+= 1
            }
            lastSync = Date()
            defaults.set(lastSync, forKey: lastSyncKey)
            lastError = nil
        } catch {
            // Connection failures and bad updates must never remove offline rules.
            lastError = error.localizedDescription
        }
    }
}
