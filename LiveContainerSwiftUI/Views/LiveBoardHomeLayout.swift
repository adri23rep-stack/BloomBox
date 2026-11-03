import Foundation

/// BloomBox's home screen organization engine.
/// The Codable field names and permanent built-in IDs intentionally match old saves.
/// This is presentation state only: no guest containers or executable paths are touched.
struct LiveBoardHomeLayout: Codable, Equatable {
    struct Folder: Codable, Identifiable, Equatable {
        var id: String
        var name: String
        var apps: [String]
    }

    static let capacity = 24
    static let dockCapacity = 4
    // Persisted legacy IDs are user data, not executable Strata dependencies.
    static let pinnedKeys: Set<String> = [
        "manzana:sidestore", "manzana:install", "manzana:tweakstore"
    ]

    var initialized = false
    var pages: [[String?]] = [Array(repeating: nil, count: capacity)]
    var dock: [String] = []
    var folders: [Folder] = []
    var hidden: [String] = []
    var aliases: [String: String] = [:]

    static func decode(_ json: String) -> Self {
        guard let bytes = json.data(using: .utf8),
              let restored = try? JSONDecoder().decode(Self.self, from: bytes) else {
            return Self()
        }
        return restored
    }

    var encoded: String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private mutating func ensurePage(_ index: Int) {
        while pages.count <= index {
            pages.append(Array(repeating: nil, count: Self.capacity))
        }
    }

    private func position(of key: String) -> (page: Int, slot: Int)? {
        for pageIndex in pages.indices {
            if let slot = pages[pageIndex].firstIndex(where: { $0 == key }) {
                return (pageIndex, slot)
            }
        }
        return nil
    }

    private var occupiedApps: Set<String> {
        Set(dock + hidden + folders.flatMap(\.apps) +
            pages.flatMap { $0.compactMap { $0 }.filter { !$0.hasPrefix("folder:") } })
    }

    /// Restores a consistent placement without resetting the user's custom ordering.
    /// Duplicate installations, stale folder icons and unknown app IDs are pruned.
    mutating func reconcile(_ keys: [String], favorites: [String]) {
        let known = Set(keys)
        var occupied = Set<String>()
        hidden = hidden.filter {
            known.contains($0) && !Self.pinnedKeys.contains($0) &&
                occupied.insert($0).inserted
        }
        dock = Array(dock.filter {
            !$0.hasPrefix("folder:") && known.contains($0) &&
                occupied.insert($0).inserted
        }.prefix(Self.dockCapacity))

        var usedFolderIDs = Set<String>()
        folders = folders.filter { $0.id.hasPrefix("folder:") && usedFolderIDs.insert($0.id).inserted }
        for index in folders.indices {
            folders[index].apps = folders[index].apps.filter {
                known.contains($0) && occupied.insert($0).inserted
            }
        }
        folders.removeAll { $0.apps.isEmpty }
        let validFolderIDs = Set(folders.map(\.id))

        if pages.isEmpty { pages.append(Array(repeating: nil, count: Self.capacity)) }
        var visibleFolders = Set<String>()
        for pageIndex in pages.indices {
            pages[pageIndex] = Array(
                (pages[pageIndex] + Array(repeating: nil, count: Self.capacity))
                    .prefix(Self.capacity)
            )
            for slotIndex in pages[pageIndex].indices {
                guard let key = pages[pageIndex][slotIndex] else { continue }
                let valid: Bool
                if key.hasPrefix("folder:") {
                    valid = validFolderIDs.contains(key) &&
                        visibleFolders.insert(key).inserted
                } else {
                    valid = known.contains(key) && occupied.insert(key).inserted
                }
                if !valid { pages[pageIndex][slotIndex] = nil }
            }
        }

        if !initialized && !keys.isEmpty {
            var unique = Set<String>()
            let requested = favorites.filter {
                known.contains($0) && unique.insert($0).inserted
            }
            unique.removeAll()
            let defaults = keys.filter {
                known.contains($0) && unique.insert($0).inserted
            }
            let choices = Array((requested.isEmpty ? defaults : requested)
                .prefix(Self.dockCapacity))
            for app in choices { removePlacement(app) }
            dock = choices
            initialized = true
        }

        var assigned = occupiedApps
        for app in keys where !assigned.contains(app) {
            place(app, on: pages.count - 1)
            assigned.insert(app)
        }
        for folder in folders where position(of: folder.id) == nil {
            place(folder.id, on: 0)
        }
    }

    mutating func removePlacement(_ key: String) {
        for pageIndex in pages.indices {
            for slotIndex in pages[pageIndex].indices where pages[pageIndex][slotIndex] == key {
                pages[pageIndex][slotIndex] = nil
            }
        }
        dock.removeAll { $0 == key }
        hidden.removeAll { $0 == key }
        for index in folders.indices {
            folders[index].apps.removeAll { $0 == key }
        }
    }

    /// Places the app in a particular cell or the next available cell.
    /// When a cell is occupied, the previous icon is moved without deletion.
    mutating func place(_ key: String, on page: Int, slot: Int? = nil) {
        let target = max(0, page)
        removePlacement(key)
        ensurePage(target)
        if let slot, pages[target].indices.contains(slot) {
            let displaced = pages[target][slot]
            pages[target][slot] = key
            if let displaced { place(displaced, on: target) }
            return
        }
        var candidate = target
        while true {
            ensurePage(candidate)
            if let free = pages[candidate].firstIndex(where: { $0 == nil }) {
                pages[candidate][free] = key
                return
            }
            candidate += 1
        }
    }

    mutating func hide(_ key: String) {
        guard !Self.pinnedKeys.contains(key), !key.hasPrefix("folder:") else { return }
        removePlacement(key)
        hidden.append(key)
    }

    @discardableResult mutating func removePage(at index: Int) -> Bool {
        guard pages.count > 1, pages.indices.contains(index) else { return false }
        let displaced = pages.remove(at: index).compactMap { $0 }
        let destination = min(index, pages.count - 1)
        for key in displaced { place(key, on: destination) }
        return true
    }

    /// Newly installed apps go to a visible page instead of a hidden one.
    /// Never moves an older icon just to make room.
    @discardableResult mutating func revealNewApps(
        _ newKeys: [String], visiblePages: [Int], preferredPage: Int
    ) -> Int? {
        let visible = visiblePages.filter { pages.indices.contains($0) }
        var candidates = [preferredPage] + visible
        candidates = Array(candidates.enumerated().filter { offset, value in
            visible.contains(value) && !candidates.prefix(offset).contains(value)
        }.map(\.element))
        var moved = Set<String>()
        var lastPage: Int?
        for key in newKeys where moved.insert(key).inserted {
            guard !hidden.contains(key), !dock.contains(key),
                  !folders.contains(where: { $0.apps.contains(key) }) else { continue }
            let destination = candidates.first { pages[$0].contains(nil) } ?? pages.count
            place(key, on: destination)
            lastPage = destination
        }
        return lastPage
    }

    mutating func putInDock(_ key: String) {
        guard !key.hasPrefix("folder:"), dock.count < Self.dockCapacity else { return }
        removePlacement(key)
        dock.append(key)
    }

    /// Reordering and full-Dock replacement preserve displaced Home apps.
    @discardableResult mutating func moveToDock(
        _ key: String, at slot: Int, fallbackPage: Int = 0
    ) -> Bool {
        guard (0..<Self.dockCapacity).contains(slot), !key.hasPrefix("folder:") else {
            return false
        }
        if let originalDockSlot = dock.firstIndex(of: key) {
            dock.remove(at: originalDockSlot)
            dock.insert(key, at: min(slot, dock.count))
            return true
        }
        let previous = position(of: key)
        removePlacement(key)
        if dock.count < Self.dockCapacity {
            dock.insert(key, at: min(slot, dock.count))
        } else {
            let displaced = dock[slot]
            dock[slot] = key
            place(displaced, on: previous?.page ?? max(0, fallbackPage),
                  slot: previous?.slot)
        }
        return true
    }

    mutating func put(_ key: String, in folderID: String) {
        guard !key.hasPrefix("folder:"),
              let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        removePlacement(key)
        folders[index].apps.append(key)
    }

    /// Adopt existing built-in icons into a single folder without losing custom folders.
    mutating func groupBuiltInShortcuts(_ keys: [String]) {
        guard !keys.isEmpty else { return }
        let folderID = folders.first(where: { $0.name == "BloomBox" })?.id
            ?? "folder:bloombox"
        let wasVisible = position(of: folderID) != nil
        for key in keys { removePlacement(key) }
        if let index = folders.firstIndex(where: { $0.id == folderID }) {
            folders[index].apps = keys + folders[index].apps.filter { !keys.contains($0) }
        } else {
            folders.append(Folder(id: folderID, name: "BloomBox", apps: keys))
        }
        let emptied = Set(folders.filter { $0.apps.isEmpty }.map(\.id))
        folders.removeAll { emptied.contains($0.id) }
        for pageIndex in pages.indices {
            for slotIndex in pages[pageIndex].indices {
                if let entry = pages[pageIndex][slotIndex], emptied.contains(entry) {
                    pages[pageIndex][slotIndex] = nil
                }
            }
        }
        if !wasVisible { place(folderID, on: 0) }
    }

    mutating func createFolder(name: String, app: String) {
        let original = position(of: app)
        removePlacement(app)
        let folderID = "folder:" + UUID().uuidString
        folders.append(Folder(id: folderID, name: name, apps: [app]))
        place(folderID, on: original?.page ?? 0, slot: original?.slot)
    }

    mutating func dissolveFolder(_ id: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        let contents = folders[index].apps
        let original = position(of: id)
        removePlacement(id)
        folders.remove(at: index)
        for (offset, key) in contents.enumerated() {
            place(key, on: original?.page ?? 0,
                  slot: offset == 0 ? original?.slot : nil)
        }
    }
}

/// Widgets follow the page they belong to and never duplicate widget kinds.
enum BloomBoxWidgetPageLayout {
    static func removingPage(
        _ deleted: Int, target: Int, from original: [Int: [String]]
    ) -> [Int: [String]] {
        var result: [Int: [String]] = [:]
        for (page, widgets) in original where page != deleted {
            result[page > deleted ? page - 1 : page] = widgets
        }
        for kind in original[deleted] ?? [] where !result[target, default: []].contains(kind) {
            result[target, default: []].append(kind)
        }
        return result
    }
}

// Compatibility for historical Swift references. Serialized widget data is unchanged.
typealias ManzanaPageWidgetLayout = BloomBoxWidgetPageLayout
