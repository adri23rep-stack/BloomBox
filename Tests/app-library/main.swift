import Foundation

func check(_ ok: @autoclosure () -> Bool, _ explanation: String) {
    if !ok() { fatalError(explanation) }
}
let builtIn = BloomBoxAppLibraryPolicy.Entry(
    key: "manzana:sidestore", name: "SideStore", bundleID: "", isBuiltIn: true)
let game = BloomBoxAppLibraryPolicy.Entry(
    key: "melon", name: "MeloNX", bundleID: "com.game.melon", isBuiltIn: false)
let chat = BloomBoxAppLibraryPolicy.Entry(
    key: "chat", name: "Discord", bundleID: "com.app.discord", isBuiltIn: false)
let editor = BloomBoxAppLibraryPolicy.Entry(
    key: "edit", name: "ibisPaint", bundleID: "com.app.ibis", isBuiltIn: false)
let apps = [builtIn, game, chat, editor]
check(BloomBoxAppLibraryPolicy.category(builtIn, assigned: nil) == "Utilidades",
      "built-in apps are utilities")
check(BloomBoxAppLibraryPolicy.category(game, assigned: nil) == "Juegos", "games")
check(BloomBoxAppLibraryPolicy.category(chat, assigned: nil) == "Social", "social")
check(BloomBoxAppLibraryPolicy.category(editor, assigned: nil) == "Creatividad", "creative")
check(BloomBoxAppLibraryPolicy.category(game, assigned: "Favoritos") == "Favoritos",
      "custom categories override heuristics")
let groups = BloomBoxAppLibraryPolicy.sections(
    entries: apps, favorites: ["melon", "melon", "uninstalled"],
    recent: ["chat", "chat", "invalid"], assigned: ["chat": "Mis Apps"])
check(groups.first?.keys.first == "melon", "user favorites first")
check(groups[0].keys.count == apps.count, "suggestions unique")
check(groups[1].keys.first == "chat", "recent launch order")
check(groups.contains { $0.title == "Mis Apps" && $0.keys == ["chat"] },
      "custom category retained")
check(groups.contains { $0.title == "Juegos" && $0.keys == ["melon"] },
      "auto classification remains")
check(BloomBoxAppLibraryPolicy.search(apps, query: "MELON") == ["melon"],
      "case-insensitive search")
check(BloomBoxAppLibraryPolicy.search(apps, query: "com.app.discord") == ["chat"],
      "bundle ID search")
check(BloomBoxAppLibraryPolicy.search(apps, query: "nonexistent").isEmpty,
      "no unrelated iOS apps included")
check(BloomBoxAppLibraryPolicy.search(apps + [game], query: "").count == apps.count,
      "duplicate installed identifiers not listed twice")
print("PASS: BloomBox library categories, favorites, recents, installed-app scope, and search.")
