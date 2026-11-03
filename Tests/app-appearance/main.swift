import Foundation

let suite = "BloomBoxCustomizationTests." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
defer { try? FileManager.default.removeItem(at: root) }

let oldFolder = root.appendingPathComponent("Strata/Icons")
try FileManager.default.createDirectory(at: oldFolder, withIntermediateDirectories: true)
let oldFilename = "older.png"
let oldData = Data("old icon".utf8)
try oldData.write(to: oldFolder.appendingPathComponent(oldFilename))
defaults.set(["app1": "Original Name"], forKey: "StrataAppNames")
defaults.set(["app1": oldFilename], forKey: "StrataAppIcons")
defaults.set(["app1": "Keep New Name"], forKey: "BloomBoxAppNames")
let store = BloomBoxAppAppearanceStorage(defaults: defaults, support: root)
store.migrateIfNeeded()
assert(store.names["app1"] == "Keep New Name", "Migrate must not overwrite new names")
assert(store.icons["app1"] == oldFilename, "Legacy icon mapping must migrate")
assert(store.iconURL(for: "app1")?.path.contains("BloomBox/Icons") == true)
assert(try Data(contentsOf: store.iconURL(for: "app1")!) == oldData)
assert(FileManager.default.fileExists(atPath: oldFolder.appendingPathComponent(oldFilename).path),
       "Old data remains available for a rollback")

store.updateName(" New Name ", for: "app1")
assert(store.names["app1"] == "New Name")
store.updateName("   ", for: "app1")
assert(store.names["app1"] == nil)
let newFile = try store.writeIcon(Data("new icon".utf8), for: "app1")
assert(newFile.hasSuffix(".png") && store.iconFilename(for: "app1") == newFile)
assert(store.iconURL(for: "app1") != nil)
store.removeIcon(for: "app1")
assert(store.iconFilename(for: "app1") == nil)
assert(!FileManager.default.fileExists(atPath: root.appendingPathComponent("BloomBox/Icons").appendingPathComponent(newFile).path))
assert(!BloomBoxAppAppearanceStorage.safeFilename("../escape.png"))
assert(!BloomBoxAppAppearanceStorage.safeFilename(".hidden.png"))
assert(BloomBoxAppAppearanceStorage.safeFilename("valid.png"))
print("PASS: app appearance migration preserves names and icons, uses safe local filenames, supports rollback and removal.")
