import Foundation

let fm = FileManager.default
let temporary = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: temporary) }
let store = try ManzanaFileStore(root: temporary.appendingPathComponent("Documents", isDirectory: true))
func check(_ condition: Bool) { assert(condition) }
func rejects(_ action: () throws -> Void) {
    do { try action(); fatalError("Operation should have been rejected") } catch {}
}
let source = temporary.appendingPathComponent("example.txt")
let bytes = Data("Manzana document".utf8)
try bytes.write(to: source)
try store.importFile(source, into: store.root)
try store.importFile(source, into: store.root)
check(try Data(contentsOf: source) == bytes)
let original = store.root.appendingPathComponent("example.txt")
let duplicate = store.root.appendingPathComponent("example (2).txt")
check(try Data(contentsOf: duplicate) == bytes)
rejects { try store.rename(original, to: "example (2).txt") }
try store.rename(original, to: "renamed.txt")
let renamed = store.root.appendingPathComponent("renamed.txt")
check(try Data(contentsOf: renamed) == bytes)
try store.createFolder("Projects", in: store.root)
check(try store.contents(store.root).first?.lastPathComponent == "Projects")
for name in ["", "..", ".hidden", "../escape", "a/b", "a\\b"] {
    rejects { try store.createFolder(name, in: store.root) }
}
rejects { _ = try store.checked(temporary) }
rejects { try store.moveToTrash(store.root) }
rejects { try store.rename(store.root, to: "moved") }
let link = store.root.appendingPathComponent("outside")
try fm.createSymbolicLink(at: link, withDestinationURL: temporary)
rejects { try store.createFolder("escape", in: link) }
check(try !store.contents(store.root).contains { $0.lastPathComponent == "outside" })
try store.moveToTrash(renamed)
assert(!fm.fileExists(atPath: renamed.path))
let trash = try store.trashFolder()
try store.restore(trash.appendingPathComponent("renamed.txt"))
check(try Data(contentsOf: renamed) == bytes)
let folder = store.root.appendingPathComponent("Projects", isDirectory: true)
try store.importFile(source, into: folder)
try store.moveToTrash(folder)
try store.restore(trash.appendingPathComponent("Projects", isDirectory: true))
check(try Data(contentsOf: folder.appendingPathComponent("example.txt")) == bytes)
// Moving and copying remain confined to user documents, and collisions preserve data.
let nested = folder.appendingPathComponent("Nested", isDirectory: true)
try store.createFolder("Nested", in: folder)
try store.copy(renamed, into: folder)
try store.copy(renamed, into: folder)
check(try Data(contentsOf: folder.appendingPathComponent("renamed.txt")) == bytes)
check(try Data(contentsOf: folder.appendingPathComponent("renamed (2).txt")) == bytes)
try store.move(renamed, into: folder)
check(!fm.fileExists(atPath: renamed.path))
check(try Data(contentsOf: folder.appendingPathComponent("renamed (3).txt")) == bytes)
try store.move(folder.appendingPathComponent("renamed (3).txt"), into: folder)
check(try Data(contentsOf: folder.appendingPathComponent("renamed (3).txt")) == bytes)
rejects { try store.move(folder, into: nested) }
rejects { try store.copy(folder, into: nested) }
rejects { try store.copy(folder, into: folder) }
rejects { try store.move(store.root, into: folder) }
rejects { try store.copy(duplicate, into: trash) }
rejects { try store.move(duplicate, into: trash) }
rejects { try store.move(duplicate, into: temporary) }
rejects { try store.copy(duplicate, into: link) }
check(try Data(contentsOf: duplicate) == bytes)
rejects { try store.restore(duplicate) }
print("Manzana storage checks passed: import, collisions, rename, folders, move, copy, confinement, trash and restore")
