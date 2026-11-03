import Foundation
func check(_ condition: @autoclosure () -> Bool, _ note: String) {
    precondition(condition(), note)
}
check(BloomBoxNewsCachePolicy.isHTTPS(URL(string: "https://example.com/news.gif")!),
      "HTTPS sources are accepted")
check(!BloomBoxNewsCachePolicy.isHTTPS(URL(string: "http://example.com/news.gif")!),
      "HTTP sources are rejected")
check(!BloomBoxNewsCachePolicy.isHTTPS(URL(string: "file:///private/test.gif")!),
      "Local files are not a remote News source")
let fm = FileManager.default
let folder = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
try fm.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: folder) }
let oldest = folder.appendingPathComponent("one.gif")
let second = folder.appendingPathComponent("two.gif")
let latest = folder.appendingPathComponent("three.gif")
let unrelated = folder.appendingPathComponent("personal.jpg")
for file in [oldest, second, latest, unrelated] {
    try Data(repeating: 7, count: 10).write(to: file)
}
for (date, url) in zip([Date(timeIntervalSince1970: 100),
                        Date(timeIntervalSince1970: 200),
                        Date(timeIntervalSince1970: 300)], [oldest, second, latest]) {
    try fm.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
}
let count = try BloomBoxNewsCachePolicy.prune(in: folder, keeping: latest, limitBytes: 19)
check(count == 10, "Cache must stay within the byte budget")
check(!fm.fileExists(atPath: oldest.path) && !fm.fileExists(atPath: second.path),
      "Old GIFs should be evicted first")
check(fm.fileExists(atPath: latest.path) && fm.fileExists(atPath: unrelated.path),
      "Pinned news image and unrelated media should survive")
print("BloomBox News GIF cache: HTTPS validation, eviction, pinned asset and unrelated files passed.")
