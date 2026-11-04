import Foundation

func check(_ condition: @autoclosure () -> Bool, _ failure: String) {
    if !condition() { fatalError(failure) }
}

struct App {
    let key: String
    let title: String
    let bundleID: String
}
let apps = [
    App(key: "k1", title: "MeloNX", bundleID: "org.example.emulator"),
    App(key: "k2", title: "Cámara", bundleID: "mx.example.photo"),
    App(key: "k3", title: "SideStore", bundleID: "com.example.signer"),
]
func search(_ query: String) -> [String] {
    BloomBoxHomeAppPolicy.matching(apps, query: query,
                                  title: { $0.title },
                                  bundleID: { $0.bundleID }).map(\.key)
}
check(search("") == ["k1", "k2", "k3"], "Blank search must preserve installed order")
check(search("  ") == ["k1", "k2", "k3"], "Whitespace search must show all")
check(search("melon") == ["k1"], "Case-insensitive name search failed")
check(search("MX.EXAMPLE") == ["k2"], "Bundle ID search failed")
check(search("CÁM") == ["k2"], "Localized name search failed")
check(search("missing").isEmpty, "Unknown query should return empty")

let favorite0 = "[\"k2\"]"
let favorite1 = BloomBoxHomeAppPolicy.toggledFavorite("k1", in: favorite0)
check(BloomBoxHomeAppPolicy.favorites(from: favorite1) == ["k2", "k1"],
      "Favorites must keep user order")
check(BloomBoxHomeAppPolicy.favorites(
        from: BloomBoxHomeAppPolicy.toggledFavorite("k2", in: favorite1)) == ["k1"],
      "Unfavorite must remove only requested key")
check(BloomBoxHomeAppPolicy.toggledFavorite("", in: favorite0) == favorite0,
      "Empty key must not change saved favorites")
check(BloomBoxHomeAppPolicy.favorites(from: "bad json").isEmpty,
      "Malformed legacy favorites must decode safely")

let categories = "[\"Games\",\"Ports\"]"
let created = BloomBoxHomeAppPolicy.addingCategory("  Creativity ", to: categories)
check(BloomBoxHomeAppPolicy.categoryNames(from: created) == ["Games", "Ports", "Creativity"],
      "Category should be trimmed and appended")
check(BloomBoxHomeAppPolicy.addingCategory("creativity", to: created) == created,
      "Category names must be case-insensitively unique")
check(BloomBoxHomeAppPolicy.addingCategory(String(repeating: "x", count: 31), to: created) == created,
      "Category length limit regression")
check(BloomBoxHomeAppPolicy.addingCategory("   ", to: created) == created,
      "Empty category regression")
check(BloomBoxHomeAppPolicy.categoryNames(from: "corrupt") == ["Games", "Ports", "Tools"],
      "Saved category fallback changed")

let assigned = BloomBoxHomeAppPolicy.assigningCategory("Games", to: "k1", in: "{}")
check(BloomBoxHomeAppPolicy.assignedCategories(from: assigned)["k1"] == "Games",
      "Assigned category missing")
let removed = BloomBoxHomeAppPolicy.assigningCategory(nil, to: "k1", in: assigned)
check(BloomBoxHomeAppPolicy.assignedCategories(from: removed)["k1"] == nil,
      "Uncategorizing app must remove persisted mapping")
check(BloomBoxHomeAppPolicy.assigningCategory("Games", to: "", in: "{}") == "{}",
      "Empty keys must not be stored")
print("BloomBox Home app search, favorites and categories tests passed.")
