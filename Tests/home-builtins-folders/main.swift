import Foundation

// Regression checks for shortcuts stored in BloomBox folders.
// This test intentionally depends only on Foundation, not SwiftUI.
let builtIns = [
    "manzana:sidestore", "manzana:install", "manzana:tweakstore",
    "manzana:appstore", "manzana:modules", "manzana:themes"
]
var layout = LiveBoardHomeLayout()
layout.reconcile(builtIns, favorites: [])
layout.groupBuiltInShortcuts(Array(builtIns.prefix(5)))
layout.reconcile(builtIns, favorites: [])

let oldFolder = layout.folders.first(where: { $0.id == "folder:bloombox" })
assert(oldFolder?.apps.count == 5, "Legacy built-in folder lost its shortcuts")

// A user can create a separate folder for a built-in shortcut.
layout.createFolder(name: "Favorites", app: "manzana:themes")
let newFolder = layout.folders.first(where: { $0.name == "Favorites" })!.id
layout.put("manzana:modules", in: newFolder)
layout.put("manzana:sidestore", in: newFolder)
layout.reconcile(builtIns, favorites: [])
assert(layout.folders.first(where: { $0.id == newFolder })?.apps.count == 3)
assert(layout.folders.first(where: { $0.id == oldFolder?.id })?.apps.count == 3)

// Moving a shortcut back to Home must not duplicate or hide it.
layout.place("manzana:modules", on: 0)
layout.reconcile(builtIns, favorites: [])
assert(layout.pages.flatMap { $0 }.contains("manzana:modules"))
assert(!layout.folders.flatMap { $0.apps }.contains("manzana:modules"))
assert(layout.pages.flatMap { $0 }.filter { $0 == "manzana:modules" }.count == 1)

// Persistence must keep folder membership stable.
let restored = LiveBoardHomeLayout.decode(layout.encoded)
assert(restored.folders.first(where: { $0.id == newFolder })?.apps.contains("manzana:sidestore") == true)
assert(restored.folders.first(where: { $0.id == newFolder })?.apps.contains("manzana:themes") == true)
print("Built-in folder moves and layout restore passed.")
