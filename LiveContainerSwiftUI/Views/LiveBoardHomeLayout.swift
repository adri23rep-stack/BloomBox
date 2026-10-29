import Foundation

/// Presentation preferences only. No executable paths or guest runtime state are changed.
struct LiveBoardHomeLayout: Codable, Equatable {
    struct Folder: Codable, Identifiable, Equatable {
        var id: String
        var name: String
        var apps: [String]
    }
    static let capacity = 24
    var initialized = false
    var pages: [[String?]] = [Array(repeating: nil, count: capacity)]
    var dock: [String] = []
    var folders: [Folder] = []
    var hidden: [String] = []
    var aliases: [String: String] = [:]

    static func decode(_ value: String) -> Self {
        (try? JSONDecoder().decode(Self.self, from: Data(value.utf8))) ?? Self()
    }
    var encoded: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    mutating func reconcile(_ keys: [String], favorites: [String]) {
        let known = Set(keys)
        // Older saved layouts may have removed the built-in app. Unhide it on update.
        hidden.removeAll { Self.pinnedKeys.contains($0) }
        var seen = Set<String>()
        hidden = hidden.filter { known.contains($0) && seen.insert($0).inserted }
        dock = Array(dock.filter { known.contains($0) && seen.insert($0).inserted }.prefix(4))
        for index in folders.indices { folders[index].apps = folders[index].apps.filter { known.contains($0) && seen.insert($0).inserted } }
        folders.removeAll { $0.apps.isEmpty }
        let folderIDs = Set(folders.map { $0.id })
        if pages.isEmpty { pages = [Array(repeating: nil, count: Self.capacity)] }
        var placed = Set(dock + hidden + folders.flatMap { $0.apps })
        var seenFolders = Set<String>()
        for p in pages.indices {
            pages[p] = Array((pages[p] + Array(repeating: nil, count: Self.capacity)).prefix(Self.capacity))
            for slot in pages[p].indices {
                guard let key = pages[p][slot] else { continue }
                if key.hasPrefix("folder:") {
                    if !folderIDs.contains(key) || !seenFolders.insert(key).inserted { pages[p][slot] = nil }
                } else if !known.contains(key) || !placed.insert(key).inserted { pages[p][slot] = nil }
            }
        }
        if !initialized && !keys.isEmpty {
            var selected = Set<String>()
            dock = Array(favorites.filter { known.contains($0) && selected.insert($0).inserted }.prefix(4))
            if dock.isEmpty { dock = Array(keys.prefix(4)) }
            placed.formUnion(dock)
            initialized = true
        }
        for key in keys where !placed.contains(key) { place(key, on: max(0, pages.count - 1)) }
        for folder in folders where !seenFolders.contains(folder.id) { place(folder.id, on: 0) }
    }
    mutating func removePlacement(_ key: String) {
        for p in pages.indices { for s in pages[p].indices where pages[p][s] == key { pages[p][s] = nil } }
        dock.removeAll { $0 == key }
        hidden.removeAll { $0 == key }
        for i in folders.indices { folders[i].apps.removeAll { $0 == key } }
    }
    mutating func place(_ key: String, on page: Int, slot: Int? = nil) {
        removePlacement(key)
        let p = max(0, page)
        while pages.count <= p { pages.append(Array(repeating: nil, count: Self.capacity)) }
        if let slot, pages[p].indices.contains(slot) {
            let displaced = pages[p][slot]
            pages[p][slot] = key
            if let displaced { place(displaced, on: p) }
        } else if let free = pages[p].firstIndex(where: { $0 == nil }) {
            pages[p][free] = key
        } else { place(key, on: p + 1) }
    }
    /// Built-in SideStore can move, but must never disappear from Manzana.
    static let pinnedKeys: Set<String> = ["manzana:sidestore", "manzana:install", "manzana:tweakstore"]
    mutating func hide(_ key: String) {
        guard !Self.pinnedKeys.contains(key) else { return }
        removePlacement(key)
        hidden.append(key)
    }

    /// A page cannot be removed if it is the only page. Items are relocated first.
    @discardableResult mutating func removePage(at index: Int) -> Bool {
        guard pages.count > 1, pages.indices.contains(index) else { return false }
        let moved = pages.remove(at: index).compactMap { $0 }
        let destinationPage = min(index, pages.count - 1)
        for key in moved { place(key, on: destinationPage) }
        return true
    }
    /// When apps are installed, the usual reconciliation may put them on the
    /// final page even when it is hidden. Relocate only *new* keys to visible
    /// pages; existing layouts, folders and Dock remain untouched.
    @discardableResult mutating func revealNewApps(
        _ newKeys: [String], visiblePages: [Int], preferredPage: Int
    ) -> Int? {
        guard !newKeys.isEmpty else { return nil }
        let visible = visiblePages.filter { pages.indices.contains($0) }
        var lastTarget: Int?
        for key in newKeys {
            guard !hidden.contains(key) else { continue }
            guard !dock.contains(key) else { continue }
            let candidates = ([preferredPage] + visible)
                .filter { visible.contains($0) }
            var seenTargets = Set<Int>()
            let unique = candidates.filter { seenTargets.insert($0).inserted }
            if let target = unique.first(where: { pages[$0].contains(nil) }) {
                place(key, on: target)
                lastTarget = target
            } else {
                let target = pages.count
                place(key, on: target)
                lastTarget = target
            }
        }
        return lastTarget
    }

    mutating func putInDock(_ key: String) {
        guard dock.count < 4, !key.hasPrefix("folder:") else { return }
        removePlacement(key); dock.append(key)
    }
    /// Drop an icon onto a visible Dock slot. A full Dock exchanges the target
    /// icon with the dragged icon's original Home position, without data loss.
    /// Dragging a Dock icon onto another Dock slot simply reorders it.
    @discardableResult mutating func moveToDock(_ key: String, at slot: Int, fallbackPage: Int = 0) -> Bool {
        guard (0..<4).contains(slot), !key.hasPrefix("folder:") else { return false }
        if let oldDockIndex = dock.firstIndex(of: key) {
            dock.remove(at: oldDockIndex)
            dock.insert(key, at: min(slot, dock.count))
            return true
        }
        var originalPage: Int?
        var originalSlot: Int?
        for p in pages.indices {
            if let index = pages[p].firstIndex(where: { $0 == key }) {
                originalPage = p
                originalSlot = index
                break
            }
        }
        removePlacement(key)
        if dock.count < 4 {
            dock.insert(key, at: min(slot, dock.count))
        } else {
            let displaced = dock[slot]
            dock[slot] = key
            let targetPage = min(max(0, originalPage ?? fallbackPage), pages.count - 1)
            place(displaced, on: targetPage, slot: originalSlot)
        }
        return true
    }
    mutating func put(_ key: String, in folderID: String) {
        guard !key.hasPrefix("folder:"), folders.contains(where: { $0.id == folderID }) else { return }
        removePlacement(key)
        if let index = folders.firstIndex(where: { $0.id == folderID }) { folders[index].apps.append(key) }
    }
    mutating func createFolder(name: String, app: String) {
        removePlacement(app)
        let id = "folder:" + UUID().uuidString
        folders.append(Folder(id: id, name: name, apps: [app]))
        place(id, on: 0)
    }
    mutating func dissolveFolder(_ id: String) {
        let contents = folders.first(where: { $0.id == id })?.apps ?? []
        removePlacement(id); folders.removeAll { $0.id == id }
        for key in contents { place(key, on: 0) }
    }
}

/// Keeps widget assignments attached to their pages when page indices shift.
enum ManzanaPageWidgetLayout {
    static func removingPage(_ index: Int, target: Int, from previous: [Int: [String]]) -> [Int: [String]] {
        var shifted: [Int: [String]] = [:]
        for (old, items) in previous where old != index { shifted[old > index ? old - 1 : old] = items }
        for id in previous[index] ?? [] where !shifted[target, default: []].contains(id) {
            shifted[target, default: []].append(id)
        }
        return shifted
    }
}
