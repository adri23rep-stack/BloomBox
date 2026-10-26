import Foundation

func assertTrue(_ value: @autoclosure () -> Bool, _ message: String) {
    if !value() { fatalError("Manzana Home test failed: \(message)") }
}
var home = LiveBoardHomeLayout()
home.reconcile(["A", "B", "manzana:sidestore", "manzana:install"], favorites: [])
assertTrue(home.pages.count >= 1, "Home initial page")
assertTrue(!home.dock.isEmpty, "Home dock exists")
home.hide("manzana:sidestore")
home.hide("manzana:install")
assertTrue(!home.hidden.contains("manzana:sidestore"), "SideStore cannot hide")
assertTrue(!home.hidden.contains("manzana:install"), "Installer cannot hide")

home.pages = [
    ["A"] + Array(repeating: nil, count: 23),
    ["B"] + Array(repeating: nil, count: 23),
    Array(repeating: nil, count: 24)
]
home.dock = ["manzana:sidestore", "manzana:install"]
home.folders = []
home.hidden = []
assertTrue(home.removePage(at: 1), "Delete middle page")
assertTrue(home.pages.count == 2, "Page count decreased")
assertTrue(home.pages.flatMap { $0.compactMap { $0 } }.contains("B"), "Nonempty page relocates icons")
assertTrue(home.removePage(at: 1), "Remove empty page")
assertTrue(home.pages.count == 1, "Only one page remains")
assertTrue(!home.removePage(at: 0), "Cannot delete last page")
home.reconcile(["A", "B", "manzana:sidestore", "manzana:install"], favorites: [])
assertTrue(home.dock.contains("manzana:sidestore"), "SideStore stays in dock")
assertTrue(home.dock.contains("manzana:install"), "Installer stays in dock")
// Direct drop from a Home page into an empty Dock slot.
var dockTest = LiveBoardHomeLayout()
dockTest.pages = [["A", "B", "C", "D", "E"] + Array(repeating: nil, count: 19)]
dockTest.dock = ["manzana:sidestore", "manzana:install"]
dockTest.initialized = true
assertTrue(dockTest.moveToDock("A", at: 2), "Drop Home app into Dock")
assertTrue(dockTest.dock == ["manzana:sidestore", "manzana:install", "A"], "Dock inserted at target slot")
assertTrue(!dockTest.pages[0].contains("A"), "Dock app removed from Home grid")

// A full Dock swaps the target icon back into the dragged app's Home slot.
dockTest.putInDock("B")
assertTrue(dockTest.moveToDock("C", at: 1), "Drop onto full Dock")
assertTrue(dockTest.dock == ["manzana:sidestore", "C", "A", "B"], "Full Dock target replaced")
assertTrue(dockTest.pages[0][2] == "manzana:install", "Displaced pinned installer returns to Home")
assertTrue(dockTest.moveToDock("B", at: 0), "Reorder Dock icon")
assertTrue(dockTest.dock == ["B", "manzana:sidestore", "C", "A"], "Dock order changed")
assertTrue(!dockTest.moveToDock("folder:test", at: 0), "Folders disallowed in Dock")
assertTrue(!dockTest.moveToDock("A", at: 4), "Out of bounds Dock slot rejected")

// Regression: new installations must not end up exclusively on a hidden page.
var installTest = LiveBoardHomeLayout()
installTest.initialized = true
installTest.pages = [
    ["Old"] + Array(repeating: nil, count: 23),
    ["Hidden"] + Array(repeating: nil, count: 23)
]
installTest.dock = ["manzana:sidestore", "manzana:install"]
installTest.reconcile(["Old", "Hidden", "Fresh", "manzana:sidestore", "manzana:install"], favorites: [])
assertTrue(installTest.pages[1].contains("Fresh"), "Baseline: reconciliation places new apps on final page")
assertTrue(installTest.revealNewApps(["Fresh"], visiblePages: [0], preferredPage: 0) == 0,
           "Freshly installed app is moved to visible page")
assertTrue(installTest.pages[0].contains("Fresh"), "New icon visible on Home")
assertTrue(installTest.pages[1].contains("Hidden"), "Hidden page contents not moved")
assertTrue(installTest.dock == ["manzana:sidestore", "manzana:install"],
           "Pinned shortcuts and Dock layout unchanged")

// When all visible pages are full, make a fresh visible page rather than
// stealing space or leaving the newly installed icon inside a hidden page.
var fullTest = LiveBoardHomeLayout()
fullTest.initialized = true
fullTest.pages = [
    (0..<24).map { Optional("old-\($0)") },
    ["Secret"] + Array(repeating: nil, count: 23)
]
fullTest.reconcile((0..<24).map { "old-\($0)" } + ["Secret", "NewlyInstalled"], favorites: [])
let target = fullTest.revealNewApps(["NewlyInstalled"], visiblePages: [0], preferredPage: 0)
assertTrue(target == 2, "A new page is made when visible page is full")
assertTrue(fullTest.pages[2].contains("NewlyInstalled"), "New icon is on the created visible page")
assertTrue(fullTest.pages[1].contains("Secret"), "Hidden page retains all its icons")

print("Manzana Home layout checks passed: pages, Dock and visible new installations")
