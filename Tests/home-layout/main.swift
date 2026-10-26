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
dockTest.dock.append("B")
assertTrue(dockTest.moveToDock("C", at: 1), "Drop onto full Dock")
assertTrue(dockTest.dock == ["manzana:sidestore", "C", "A", "B"], "Full Dock target replaced")
assertTrue(dockTest.pages[0][2] == "manzana:install", "Displaced pinned installer returns to Home")
assertTrue(dockTest.moveToDock("B", at: 0), "Reorder Dock icon")
assertTrue(dockTest.dock == ["B", "manzana:sidestore", "C", "A"], "Dock order changed")
assertTrue(!dockTest.moveToDock("folder:test", at: 0), "Folders disallowed in Dock")
assertTrue(!dockTest.moveToDock("A", at: 4), "Out of bounds Dock slot rejected")

print("Manzana Home layout checks passed: pages, pinned shortcuts, Dock drop and swaps")
