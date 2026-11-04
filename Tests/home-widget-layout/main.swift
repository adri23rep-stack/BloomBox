import Foundation

func check(_ value: @autoclosure () -> Bool, _ message: String) {
    guard value() else { fatalError(message) }
}
func widget(_ id: String, slot: Int = 0, columns: Int = 2, rows: Int = 2) -> BloomBoxPlacedWidget {
    BloomBoxPlacedWidget(id: id, kind: "media", slot: slot, columns: columns, rows: rows)
}

check(BloomBoxWidgetGrid.cells(slot: 0, columns: 2, rows: 2) == Set([0, 1, 4, 5]), "grid geometry")
check(BloomBoxWidgetGrid.cells(slot: 3, columns: 2, rows: 2) == nil, "wrap protection")
check(BloomBoxWidgetGrid.cells(slot: -1, columns: 1, rows: 1) == nil, "negative cell")
check(BloomBoxWidgetGrid.cells(slot: 23, columns: 2, rows: 2) == nil, "edge overflow")

let first = widget("A", slot: 0)
let second = widget("B", slot: 6)
let before = [0: [first, second], 1: [widget("C", slot: 0)]]
let moved = BloomBoxWidgetPlacement.move("A", to: 1, requestedSlot: 0, in: before)!
check(moved.page == 1 && moved.slot != 0, "fall back from occupied drop slot")
check(!moved.pages[0]!.contains { $0.id == "A" }, "remove source")
check(moved.pages[1]!.contains { $0.id == "A" }, "keep moved widget")
check(moved.pages[1]!.contains { $0.id == "C" }, "preserve other widget")
check(BloomBoxWidgetPlacement.move("unknown", to: 0, requestedSlot: nil, in: before) == nil, "unknown ID")
check(BloomBoxWidgetPlacement.move("A", to: -1, requestedSlot: nil, in: before) == nil, "invalid page")

let samePage = BloomBoxWidgetPlacement.move("A", to: 0, requestedSlot: nil, in: before)!
check(samePage.slot == 0, "same-page movement preserves slot")
let resized = BloomBoxWidgetPlacement.resize("A", columns: 4, rows: 2, in: before)!
check(resized.pages[0]!.first { $0.id == "A" }!.columns == 4, "resize dimensions")
check(resized.slot == 12, "reposition resized widget when blocked")
check(BloomBoxWidgetPlacement.resize("A", columns: 5, rows: 2, in: before) == nil, "invalid dimensions")

let duplicates = [0: [first, first], 1: [widget("A", slot: 4), widget("B", slot: 12)]]
let fixed = BloomBoxWidgetPlacement.move("A", to: 1, requestedSlot: 0, in: duplicates)!
check(fixed.pages.values.flatMap { $0 }.filter { $0.id == "A" }.count == 1,
      "deduplicate repeated saved widgets")

let stored = try JSONEncoder().encode(fixed.pages)
let decoded = try JSONDecoder().decode([Int: [BloomBoxPlacedWidget]].self, from: stored)
check(decoded == fixed.pages, "persist existing widget JSON shape")
print("PASS: native BloomBox widget moves, resizing, collision fallback, duplicates and saved JSON.")


// Existing visible page wins over allocating a new page. Hidden pages remain intact.
let blocked = widget("full", slot: 0, columns: 4, rows: 4)
let bottom = widget("bottom", slot: 16, columns: 4, rows: 2)
let availablePages: [Int: [BloomBoxPlacedWidget]] = [
    0: [blocked, bottom],
    1: [],
    2: [widget("hidden", slot: 0)],
    3: [widget("occupied", slot: 0)]
]
let spot = BloomBoxWidgetPlacement.freePosition(
    columns: 2, rows: 2, preferredPage: 0, visiblePages: [0, 1, 3],
    in: availablePages
)
check(spot?.page == 1 && spot?.slot == 0,
      "Use existing visible page when current page has no space")
check(BloomBoxWidgetPlacement.freePosition(
    columns: 2, rows: 2, preferredPage: 2, visiblePages: [0, 1, 3],
    in: availablePages
)?.page == 1, "Never relocate into hidden page")
check(BloomBoxWidgetPlacement.freePosition(
    columns: 5, rows: 2, preferredPage: 0, visiblePages: [0, 1],
    in: availablePages
) == nil, "Reject invalid widget geometry")
check(BloomBoxWidgetPlacement.freePosition(
    columns: 4, rows: 4, preferredPage: 0, visiblePages: [0],
    in: availablePages
) == nil, "Signal when a fresh page is genuinely necessary")
print("BloomBox widget relocation uses visible free pages and avoids page bloat")
