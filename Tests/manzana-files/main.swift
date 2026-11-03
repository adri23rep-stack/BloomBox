import Foundation

let fm = FileManager.default
let temporary = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: temporary) }
let store = try BloomBoxFileStore(root: temporary.appendingPathComponent("Documents", isDirectory: true))
func check(_ condition: Bool) { assert(condition) }
func rejects(_ action: () throws -> Void) {
    do { try action(); fatalError("Operation should have been rejected") } catch {}
}
let source = temporary.appendingPathComponent("example.txt")
let bytes = Data("BloomBox document".utf8)
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
print("BloomBox storage checks passed: import, collisions, rename, folders, move, copy, confinement, trash and restore")


// New BloomBox install writes to its own root; old documents remain in place.
let docs = temporary.appendingPathComponent("Migration", isDirectory: true)
try fm.createDirectory(at: docs, withIntermediateDirectories: true)
let preferred = BloomBoxFileStore.preferredRoot(in: docs)
check(preferred.lastPathComponent == "BloomBox Files")
let oldRoot = docs.appendingPathComponent("Manzana Files", isDirectory: true)
try fm.createDirectory(at: oldRoot, withIntermediateDirectories: true)
check(BloomBoxFileStore.preferredRoot(in: docs) == oldRoot)
let newRoot = docs.appendingPathComponent("BloomBox Files", isDirectory: true)
try fm.createDirectory(at: newRoot, withIntermediateDirectories: true)
check(BloomBoxFileStore.preferredRoot(in: docs) == newRoot)

// A file may not escape by using an alias to a directory outside the vault.
let insideFolder = store.root.appendingPathComponent("inner", isDirectory: true)
try store.createFolder("inner", in: store.root)
let escaped = insideFolder.appendingPathComponent("escape")
try fm.createSymbolicLink(at: escaped, withDestinationURL: temporary)
rejects { try store.copy(duplicate, into: escaped) }
rejects { try store.importFile(source, into: escaped) }
let symlinkFile = store.root.appendingPathComponent("shortcut.txt")
try fm.createSymbolicLink(at: symlinkFile, withDestinationURL: source)
rejects { try store.copy(symlinkFile, into: insideFolder) }
check(try !store.contents(store.root).contains { $0.lastPathComponent == "shortcut.txt" })
for invalid in [".", "..", "bad\nname", String(repeating: "x", count: 256)] {
    rejects { try store.createFolder(invalid, in: store.root) }
}
print("BloomBox independent document root and symlink boundary tests passed")
