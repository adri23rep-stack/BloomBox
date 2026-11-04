import Foundation

/// Local preferences and custom icons owned by BloomBox.
/// Legacy Strata keys are read solely to migrate an existing installation.
struct BloomBoxAppAppearanceStorage {
    let defaults: UserDefaults
    let support: URL
    private let files: FileManager

    init(defaults: UserDefaults, support: URL = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask)[0],
         files: FileManager = .default) {
        self.defaults = defaults
        self.support = support
        self.files = files
    }

    private let namesKey = "BloomBoxAppNames"
    private let iconsKey = "BloomBoxAppIcons"
    private let migrationKey = "BloomBoxAppAppearanceMigrated"
    private let oldNamesKey = "StrataAppNames"
    private let oldIconsKey = "StrataAppIcons"

    private var iconDirectory: URL {
        support.appendingPathComponent("BloomBox/Icons", isDirectory: true)
    }
    private var oldIconDirectory: URL {
        support.appendingPathComponent("Strata/Icons", isDirectory: true)
    }
    private func dictionary(_ key: String) -> [String: String] {
        defaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    /// Never overwrites settings created by the new BloomBox store.
    func migrateIfNeeded() {
        guard !defaults.bool(forKey: migrationKey) else { return }
        var names = dictionary(namesKey)
        var icons = dictionary(iconsKey)
        for (id, title) in dictionary(oldNamesKey) where names[id] == nil {
            names[id] = title
        }
        for (id, filename) in dictionary(oldIconsKey)
            where icons[id] == nil && Self.safeFilename(filename) {
            icons[id] = filename
        }
        defaults.set(names, forKey: namesKey)
        defaults.set(icons, forKey: iconsKey)
        // Keep old settings and icon files to permit rollback to a prior build.
        defaults.set(true, forKey: migrationKey)
    }

    var names: [String: String] {
        migrateIfNeeded()
        return dictionary(namesKey)
    }

    var icons: [String: String] {
        migrateIfNeeded()
        return dictionary(iconsKey)
    }

    func updateName(_ value: String, for key: String) {
        var saved = names
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        saved[key] = trimmed.isEmpty ? nil : String(trimmed.prefix(100))
        defaults.set(saved, forKey: namesKey)
    }

    static func safeFilename(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 128 && name.hasSuffix(".png") &&
        !name.hasPrefix(".") && (name as NSString).lastPathComponent == name
    }

    func iconFilename(for key: String) -> String? {
        icons[key]
    }

    /// Copy artwork on demand, rather than blocking startup to migrate every icon.
    func iconURL(for key: String) -> URL? {
        guard let filename = iconFilename(for: key),
              Self.safeFilename(filename) else { return nil }
        let current = iconDirectory.appendingPathComponent(filename)
        if files.fileExists(atPath: current.path) { return current }
        let legacy = oldIconDirectory.appendingPathComponent(filename)
        guard files.fileExists(atPath: legacy.path) else { return nil }
        do {
            try files.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
            try files.copyItem(at: legacy, to: current)
        } catch {
            // Keep user's previous icon even when a migration copy is not writable.
            return files.fileExists(atPath: current.path) ? current : legacy
        }
        return current
    }

    @discardableResult
    func writeIcon(_ png: Data, for key: String) throws -> String {
        guard !png.isEmpty else { throw CocoaError(.fileWriteUnknown) }
        try files.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
        let filename = UUID().uuidString + ".png"
        let url = iconDirectory.appendingPathComponent(filename)
        try png.write(to: url, options: .atomic)
        var saved = icons
        let prior = saved.updateValue(filename, forKey: key)
        defaults.set(saved, forKey: iconsKey)
        if let prior { deleteUnreferenced(prior, usedBy: saved) }
        return filename
    }

    func removeIcon(for key: String) {
        var saved = icons
        guard let prior = saved.removeValue(forKey: key) else { return }
        defaults.set(saved, forKey: iconsKey)
        deleteUnreferenced(prior, usedBy: saved)
    }

    private func deleteUnreferenced(_ name: String, usedBy saved: [String: String]) {
        guard Self.safeFilename(name), !saved.values.contains(name) else { return }
        for directory in [iconDirectory, oldIconDirectory] {
            let url = directory.appendingPathComponent(name)
            if files.fileExists(atPath: url.path) { try? files.removeItem(at: url) }
        }
    }
}
