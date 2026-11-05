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
    // v1 accepted a narrower topic alphabet and could reject the entire
    // updated catalog when one valid Wikipedia article contained parentheses.
    // Restart the verified cache and synchronization clock with the fix.
    private let cachedKey = "BloomBoxGameBoxWallpaperRulesVerified-v2"
    private let lastSyncKey = "BloomBoxGameBoxWallpaperRulesSynced-v2"
    // Offline identity fallback for the seven curated emulator photos.
    // The remote catalog still overrides these entries when available.
    // Raw literal is source metadata only: no image bytes are bundled.
    private static let bundledRules: Data = Data(#"{"schemaVersion":1,"catalogID":"bloombox.gamebox.wallpaper-rules","updatedAt":"2026-11-05","rules":[{"id":"melonnx-switch","bundleIDs":[],"keywords":["MeloNX","MelonNX","Melon NX","MelonNX Emulator"],"provider":"wikipedia","query":"Nintendo Switch","note":"MeloNX/MelonNX emulates Nintendo Switch; exact bundle ID to be added after inspection of the installed IPA. Curated Evan-Amos console photograph (public domain), linked to the Commons file details.","imageURL":"https://upload.wikimedia.org/wikipedia/commons/5/5b/Nintendo-Switch-Console-Flat-Top.jpg","sourceURL":"https://commons.wikimedia.org/wiki/File:Nintendo-Switch-Console-Flat-Top.jpg","imageLicense":"Public domain"},{"id":"lemonx-switch","bundleIDs":[],"keywords":["LemoNX","Lemon NX","LemoNX Binaries"],"provider":"wikipedia","query":"Nintendo Switch","note":"Nintendo Switch emulator; no unverified bundle ID. Curated Evan-Amos console photograph (public domain), linked to the Commons file details.","imageURL":"https://upload.wikimedia.org/wikipedia/commons/5/5b/Nintendo-Switch-Console-Flat-Top.jpg","sourceURL":"https://commons.wikimedia.org/wiki/File:Nintendo-Switch-Console-Flat-Top.jpg","imageLicense":"Public domain"},{"id":"dolphinios-gamecube","bundleIDs":["me.oatmealdome.DolphiniOS-njb-patreon-beta"],"keywords":["DolphiniOS","Dolphin iOS","Dolphin Emulator"],"provider":"wikipedia","query":"Nintendo GameCube","note":"Generic GameCube background for the Wii/GameCube emulator, not game cover art. Curated Evan-Amos console photograph (public domain), linked to the Commons file details.","imageURL":"https://upload.wikimedia.org/wikipedia/commons/8/8a/Nintendo-GameCube-Console-FL.jpg","sourceURL":"https://commons.wikimedia.org/wiki/File:Nintendo-GameCube-Console-FL.jpg","imageLicense":"Public domain"},{"id":"melocafe-wiiu","bundleIDs":[],"keywords":["MeloCafe","Melo Cafe","Cemu"],"provider":"wikipedia","query":"Wii U","note":"Wii U emulator. Do not use an unverified or placeholder bundle ID. Curated Evan-Amos console photograph (public domain), linked to the Commons file details.","imageURL":"https://upload.wikimedia.org/wikipedia/commons/d/dd/Nintendo-Wii-U-Console-FL.jpg","sourceURL":"https://commons.wikimedia.org/wiki/File:Nintendo-Wii-U-Console-FL.jpg","imageLicense":"Public domain"},{"id":"vita3k-vita","bundleIDs":["org.vita3k.ios"],"keywords":["Vita3K","Vita3KiOS","Vita3K iOS"],"provider":"wikipedia","query":"PlayStation Vita","note":"PlayStation Vita emulator. Curated Evan-Amos console photograph (public domain), linked to the Commons file details.","imageURL":"https://upload.wikimedia.org/wikipedia/commons/c/c1/PlayStation-Vita-2001-FL.jpg","sourceURL":"https://commons.wikimedia.org/wiki/File:PlayStation-Vita-2001-FL.jpg","imageLicense":"Public domain"},{"id":"ppsspp-psp","bundleIDs":[],"keywords":["PPSSPP","PPSSPP Gold"],"provider":"wikipedia","query":"PlayStation Portable","note":"PSP emulator. Curated Evan-Amos console photograph (public domain), linked to the Commons file details.","imageURL":"https://upload.wikimedia.org/wikipedia/commons/a/a9/Sony-PSP-1000-Body.jpg","sourceURL":"https://commons.wikimedia.org/wiki/File:Sony-PSP-1000-Body.jpg","imageLicense":"Public domain"},{"id":"husk-android","bundleIDs":[],"keywords":["Husk","Husk Android"],"provider":"wikipedia","query":"Android (operating system)","note":"Husk is an Android emulator/runtime, NOT Minecraft Dungeons. Pinned photo is an Android gaming handset (Xperia Play) as a generic platform illustration, not Husk's logo or an emulated game's artwork. Photo by Evan-Amos, public domain.","imageURL":"https://upload.wikimedia.org/wikipedia/commons/e/e5/Sony-Xperia-Play-Open-FL.jpg","sourceURL":"https://commons.wikimedia.org/wiki/File:Sony-Xperia-Play-Open-FL.jpg","imageLicense":"Public domain"}]}"#.utf8)

    private var index: BloomBoxWallpaperRuleIndex?
    private var refreshing = false
    private var lastAttempt: Date?

    // Stable curated wallpaper feed, merged into BloomBox-Catalog/main.
    private static let catalogURL = URL(string:
        "https://raw.githubusercontent.com/adri23rep-stack/BloomBox-Catalog/main/catalog/gamebox-wallpaper-rules.json")!

    private init() {
        if let bytes = defaults.data(forKey: cachedKey),
           let valid = BloomBoxWallpaperRuleIndex.validated(from: bytes) {
            index = valid
        } else {
            index = BloomBoxWallpaperRuleIndex.validated(from: Self.bundledRules)
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
            if index != nil, let lastSync, Date().timeIntervalSince(lastSync) < 3600 { return }
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
