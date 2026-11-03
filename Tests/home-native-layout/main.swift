import Foundation

// The new BloomBox layout engine must handle older serialized layouts.
var model = BloomBoxHomeLayout()
model.initialized = true
model.pages = [
    ["A", "A", "Missing"] + Array(repeating: nil, count: 21),
    ["B"] + Array(repeating: nil, count: 23)
]
model.dock = ["A", "A", "manzana:sidestore"]
model.folders = [
    .init(id: "folder:test", name: "Tools", apps: ["B", "B", "C"])
]
model.reconcile(["A", "B", "C", "manzana:sidestore"], favorites: [])
assert(model.dock == ["A", "manzana:sidestore"])
assert(model.folders.first?.apps == ["B", "C"])
assert(model.pages.flatMap { $0.compactMap { $0 } }.contains("folder:test"))
assert(!model.pages.flatMap { $0.compactMap { $0 } }.contains("Missing"))
assert(model.encoded.contains("\"initialized\":true"))
assert(BloomBoxHomeLayout.decode(model.encoded) == model)

// A new folder should replace the app in the original cell, not jump to page 1.
var positions = BloomBoxHomeLayout()
positions.initialized = true
positions.pages = [
    ["A"] + Array(repeating: nil, count: 23),
    ["B", "C"] + Array(repeating: nil, count: 22)
]
positions.createFolder(name: "Work", app: "B")
let folder = positions.folders[0].id
assert(positions.pages[1][0] == folder)
assert(!positions.pages.flatMap { $0.compactMap { $0 } }.contains("B"))
positions.dissolveFolder(folder)
assert(positions.pages[1][0] == "B")
assert(positions.folders.isEmpty)

// A corrupt or future-incompatible layout must fall back safely.
assert(BloomBoxHomeLayout.decode("not JSON").pages.count == 1)
assert(BloomBoxHomeLayout.decode("").dock.isEmpty)
print("BloomBox native Home layout: migration, de-duplication, folder position and recovery passed.")
