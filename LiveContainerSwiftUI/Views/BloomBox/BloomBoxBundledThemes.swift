import Foundation

/// Owner-provided, offline themes. The first-run wizard will reuse these choices.
struct BloomBoxStarterTheme: Identifiable {
    let id: String
    let title: String
    let isDefault: Bool
}

enum BloomBoxBundledThemes {
    static let presets: [BloomBoxStarterTheme] = [
        BloomBoxStarterTheme(id: "KirbyPink", title: "Kirby Pink", isDefault: true),
        BloomBoxStarterTheme(id: "YellowBowser", title: "Yellow Bowser", isDefault: false)
    ]

    static let initializedKey = "BloomBoxStarterThemeInitialized"
    static let chosenKey = "BloomBoxStarterThemeChoice"

    static func url(for id: String) -> URL? {
        guard presets.contains(where: { $0.id == id }) else { return nil }
        return Bundle.main.url(forResource: id, withExtension: "bbtheme",
                               subdirectory: "StarterThemes")
    }

    static func previewURL(for id: String) -> URL? {
        guard presets.contains(where: { $0.id == id }) else { return nil }
        return Bundle.main.url(forResource: id, withExtension: "jpg",
                               subdirectory: "StarterThemes")
    }

    static func preset(matching url: URL) -> BloomBoxStarterTheme? {
        presets.first { preset in
            guard let source = self.url(for: preset.id) else { return false }
            return source.standardizedFileURL == url.standardizedFileURL
        }
    }

    /// Preserve all supplied artwork and settings, but never pre-hide the
    /// original exporter's own installed guest apps on someone else's phone.
    static func data(for id: String) throws -> Data {
        guard let url = url(for: id) else {
            throw BloomBoxThemePackage.ThemeError.invalid("Bundled BloomBox theme is unavailable.")
        }
        let original = try Data(contentsOf: url, options: .mappedIfSafe)
        _ = try BloomBoxThemePackage.read(original)
        guard var root = try JSONSerialization.jsonObject(with: original) as? [String: Any],
              var settings = root["settings"] as? [String: Any],
              let saved = settings["LiveBoardHomeLayout"] as? String,
              let bytes = saved.data(using: .utf8),
              var home = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
            throw BloomBoxThemePackage.ThemeError.invalid("The bundled layout is invalid.")
        }
        home["hidden"] = [String]()
        home["aliases"] = [String: String]()
        let normalized = try JSONSerialization.data(withJSONObject: home, options: [.sortedKeys])
        guard let layout = String(data: normalized, encoding: .utf8) else {
            throw BloomBoxThemePackage.ThemeError.invalid("The bundled layout cannot be read.")
        }
        settings["LiveBoardHomeLayout"] = layout
        root["settings"] = settings
        return try JSONSerialization.data(withJSONObject: root)
    }

    /// Apply Kirby only when there is no earlier personalized Home. This
    /// deliberately does not run for updates, even if they contain no theme.
    static func applyOnFreshInstall(defaults: UserDefaults, appKeys: [String],
                                    favorites: [String], wallpaperURL: URL) throws -> BloomBoxHomeLayout? {
        guard !defaults.bool(forKey: initializedKey) else { return nil }

        let protectedKeys = [
            "LiveBoardHomeLayout", "BloomBoxPlacedWidgetsV2",
            "ManzanaPageWidgets", "ManzanaMotionWallpaper",
            "LiveBoardHiddenPages", "BloomBoxLivingWidgetSettings",
            "BloomBoxWidgetMissingAppFallbacks",
            "LiveBoardWallpaperStyle", "ManzanaIconStyle"
        ]
        let previouslyCustomized = protectedKeys.contains { key in
            guard let value = defaults.object(forKey: key) else { return false }
            if let string = value as? String {
                return !string.isEmpty && string != "[]" && string != "{}"
                    && string != "black" && string != "default"
            }
            return true
        } || FileManager.default.fileExists(atPath: wallpaperURL.path)

        if previouslyCustomized {
            defaults.set(true, forKey: initializedKey)
            return nil
        }

        let package = try data(for: "KirbyPink")
        let layout = try BloomBoxThemePackage.apply(
            package, defaults: defaults, currentLayout: BloomBoxHomeLayout(),
            appKeys: appKeys, favorites: favorites, wallpaperURL: wallpaperURL)

        // The supplied theme already has its own Dock/folder positions. Do not
        // let the old first-run folder migration rearrange them immediately.
        defaults.set(true, forKey: "BloomBoxBuiltInFolderMigrated")
        defaults.set("KirbyPink", forKey: chosenKey)
        defaults.set(true, forKey: initializedKey)
        return layout
    }
}
