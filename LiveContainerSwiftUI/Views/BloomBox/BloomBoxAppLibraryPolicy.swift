import Foundation

/// Pure app-library policy: only BloomBox-known installed guests are supplied
/// by the caller, so external iOS apps are never inferred or indexed.
enum BloomBoxAppLibraryPolicy {
    struct Entry: Equatable {
        let key: String
        let name: String
        let bundleID: String
        let isBuiltIn: Bool
    }
    struct Section: Equatable {
        let title: String
        let keys: [String]
    }
    static let defaultCategoryOrder = [
        "Social", "Productividad", "Utilidades", "Juegos", "Creatividad", "Otras apps"
    ]

    static func category(_ entry: Entry, assigned: String?) -> String {
        if let assigned, !assigned.isEmpty { return assigned }
        if entry.isBuiltIn { return "Utilidades" }
        let hint = (entry.name + " " + entry.bundleID).lowercased()
        func matches(_ words: [String]) -> Bool { words.contains { hint.contains($0) } }
        if matches([
            "youtube", "tiktok", "instagram", "whatsapp", "discord", "facebook",
            "twitter", "threads", "telegram", "reddit", "messenger", "social"
        ]) { return "Social" }
        if matches([
            "game", "mario", "samba", "kart", "taiko", "melon", "emu",
            "minecraft", "ryujinx", "retro", "puzzle", "play"
        ]) { return "Juegos" }
        if matches([
            "ibis", "pixiv", "camera", "photo", "editor", "draw", "pinterest",
            "art", "paint", "creative", "music", "video"
        ]) { return "Creatividad" }
        if matches([
            "notes", "office", "docs", "drive", "calendar", "notion",
            "word", "excel", "productivity", "file", "takopi"
        ]) { return "Productividad" }
        if matches([
            "settings", "clock", "utility", "utilities", "browser",
            "safari", "remote", "tool", "jit", "terminal", "store"
        ]) { return "Utilidades" }
        return "Otras apps"
    }

    private static func unique(_ keys: [String], known: Set<String>) -> [String] {
        var seen = Set<String>()
        return keys.filter { known.contains($0) && seen.insert($0).inserted }
    }

    static func sections(
        entries: [Entry], favorites: [String], recent: [String],
        assigned: [String: String]
    ) -> [Section] {
        let keys = unique(entries.map(\.key), known: Set(entries.map(\.key)))
        let known = Set(keys)
        let favorites = unique(favorites, known: known)
        let suggestions = Array((favorites + keys.filter { !favorites.contains($0) }).prefix(8))
        let recentItems = unique(recent + Array(keys.reversed()), known: known)
        let recents = Array(recentItems.prefix(8))

        var sections: [String: [String]] = [:]
        var seen = Set<String>()
        for entry in entries where seen.insert(entry.key).inserted {
            sections[category(entry, assigned: assigned[entry.key]), default: []].append(entry.key)
        }
        let extra = sections.keys.filter { !defaultCategoryOrder.contains($0) }.sorted()
        let names = defaultCategoryOrder + extra
        let categorized = names.compactMap { name -> Section? in
            guard let grouped = sections[name], !grouped.isEmpty else { return nil }
            return Section(title: name, keys: grouped)
        }
        return [
            Section(title: "Sugerencias", keys: suggestions),
            Section(title: "Añadidas recientemente", keys: recents)
        ] + categorized
    }

    static func search(_ entries: [Entry], query: String) -> [String] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        return entries.filter { seen.insert($0.key).inserted }
            .filter {
                term.isEmpty || $0.name.localizedCaseInsensitiveContains(term) ||
                    $0.bundleID.localizedCaseInsensitiveContains(term)
            }
            .sorted {
                let compared = $0.name.localizedStandardCompare($1.name)
                return compared == .orderedSame ? $0.key < $1.key :
                    compared == .orderedAscending
            }
            .map(\.key)
    }
}
