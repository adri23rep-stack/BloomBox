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
print("Manzana Home layout checks passed")
