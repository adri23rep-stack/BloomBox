import Foundation
func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
}
let base = BloomBoxHomeNavigation(pageCount: 4, currentPage: 3, hiddenJSON: "[1]")
check(base.visible == [0, 2, 3], "Decode existing hidden pages")
check(base.safePage == 3, "Preserve selected Home page")
let hidden = base.toggledVisibility(at: 2)!
check(hidden.hidden == Set([1, 2]), "Hide page")
check(hidden.safePage == 4, "Choose closest Home page when selected page hides")
let last = BloomBoxHomeNavigation(pageCount: 3, currentPage: 3, hiddenJSON: "[1,2]")
check(last.toggledVisibility(at: 0) == nil, "Never hide all Home pages")
check(last.selectedFromOverview(2)!.safePage == 3, "Unhide page selected in overview")
check(last.selectedFromOverview(2)!.hidden == Set([1]), "Keep other hidden pages")
let corrupted = BloomBoxHomeNavigation(pageCount: 2, currentPage: 99, hiddenJSON: "[-3,0,1,100]")
check(corrupted.hidden == Set([1]), "Repair stale/all-hidden preferences")
check(corrupted.safePage == 1, "Recover from invalid tab selection")
check(BloomBoxHomeNavigation(pageCount: 2, currentPage: 0, hiddenJSON: "oops").safePage == 0,
      "News remains accessible")
check(BloomBoxHomeNavigation(pageCount: 2, currentPage: 3, hiddenJSON: "[1]").safePage == 3,
      "App Library remains accessible")
let before = BloomBoxHomeNavigation(pageCount: 4, currentPage: 3, hiddenJSON: "[1,3]")
let removed = before.removedPage(at: 2, destinationContainsIcons: true, newPageCount: 3)!
check(removed.hidden == Set([1]), "Shift hidden indexes and expose displaced icons")
check(removed.safePage == 3, "Select valid page after deletion")
let library = BloomBoxHomeNavigation(pageCount: 3, currentPage: 4, hiddenJSON: "[]")
check(library.removedPage(at: 1, destinationContainsIcons: false,
                          newPageCount: 2)!.safePage == 3,
      "Follow App Library when Home page count changes")
let widgets = BloomBoxHomeNavigation.reindexWidgets([0: ["clock"], 1: ["photo"], 2: ["notes"]],
                                                     removing: 1)
check(widgets.remaining[0] == ["clock"] && widgets.remaining[1] == ["notes"],
      "Reindex widget pages without changing their IDs")
check(widgets.displaced == ["photo"], "Relocate widgets rather than drop them")
check(BloomBoxHomeNavigation(pageCount: 1, currentPage: 1, hiddenJSON: "[]")
        .removedPage(at: 0, destinationContainsIcons: false, newPageCount: 1) == nil,
      "Never remove final Home page")
print("BloomBox Home page navigation and widget reindex: passed")
