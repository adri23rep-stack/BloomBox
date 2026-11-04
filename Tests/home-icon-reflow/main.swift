import Foundation

func check(_ ok: @autoclosure () -> Bool, _ note: String) {
    precondition(ok(), note)
}
func widget(_ id: String, slot: Int, columns: Int, rows: Int) -> BloomBoxPlacedWidget {
    BloomBoxPlacedWidget(id: id, kind: "clock", slot: slot, columns: columns, rows: rows)
}

var home = BloomBoxHomeLayout()
home.initialized = true
home.pages = [
    (0..<24).map { Optional("P0-" + String($0)) },
    (0..<24).map { Optional("Hidden-" + String($0)) },
    ["P2"] + Array(repeating: nil, count: 23)
]
home.dock = ["sidestore"]
home.folders = [.init(id: "folder:tools", name: "Tools", apps: ["X", "Y"])]
let widgets = [0: [widget("cover", slot: 0, columns: 4, rows: 2)]]
let updated = BloomBoxHomeIconReflow.apply(to: home, widgets: widgets, hiddenPages: [1])
check(updated.pages[0].prefix(8).allSatisfy { $0 == nil || !($0?.hasPrefix("P0-") ?? false) },
      "Reserved widget cells must be empty")
check(updated.pages[1] == home.pages[1], "Hidden pages must not receive moved icons")
check(updated.pages[2].contains("P0-0"), "Displaced icons use existing visible Home pages")
check(updated.pages.count == 3, "No new page when visible page has space")
check(updated.dock == home.dock && updated.folders == home.folders,
      "Dock and folder membership are untouched")
let beforeIcons = home.pages.flatMap { $0.compactMap { $0 } }.sorted()
let afterIcons = updated.pages.flatMap { $0.compactMap { $0 } }.sorted()
check(beforeIcons == afterIcons, "No missing or duplicate app shortcuts")
check(BloomBoxHomeIconReflow.apply(to: updated, widgets: widgets, hiddenPages: [1]) == updated,
      "A stable widget layout must not keep moving apps")

// When no visible page can fit additional icons, create one new visible page
// and reuse it for the whole batch instead of allocating a page per app.
var full = BloomBoxHomeLayout()
full.initialized = true
full.pages = [(0..<24).map { Optional("F" + String($0)) }]
let oversized = [0: [widget("entire", slot: 0, columns: 4, rows: 4),
                     widget("bottom", slot: 16, columns: 4, rows: 2)]]
let reflowed = BloomBoxHomeIconReflow.apply(to: full, widgets: oversized, hiddenPages: [])
check(reflowed.pages.count == 2, "Batch spill should share one new page")
check(reflowed.pages[1].compactMap { $0 }.count == 24, "All displaced icons retained")
check(reflowed.pages[0].allSatisfy { $0 == nil }, "No icons overlap full-screen widget")
check(reflowed.pages.flatMap { $0.compactMap { $0 } }.sorted() ==
      full.pages.flatMap { $0.compactMap { $0 } }.sorted(), "Every shortcut survives reflow")
print("PASS: native BloomBox widget/icon reflow, hidden pages, batch overflow and idempotence.")
