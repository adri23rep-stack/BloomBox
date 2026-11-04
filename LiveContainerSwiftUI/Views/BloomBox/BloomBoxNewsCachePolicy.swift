import Foundation

/// Limit downloaded News GIFs without deleting user wallpaper or widget media.
enum BloomBoxNewsCachePolicy {
    static let maxBytes = 64 * 1024 * 1024

    static func isHTTPS(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" &&
        (url.host?.isEmpty == false) &&
        url.user == nil && url.password == nil
    }

    @discardableResult static func prune(
        in folder: URL, keeping pinned: URL? = nil, limitBytes: Int = maxBytes
    ) throws -> Int {
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey,
                                        .isRegularFileKey, .isSymbolicLinkKey],
            options: .skipsHiddenFiles
        )
        let entries: [(url: URL, bytes: Int, modified: Date)] = files.compactMap { url in
            guard url.pathExtension.lowercased() == "gif",
                  let values = try? url.resourceValues(forKeys: [
                    .fileSizeKey, .contentModificationDateKey,
                    .isRegularFileKey, .isSymbolicLinkKey
                  ]), values.isRegularFile == true,
                  values.isSymbolicLink != true else { return nil }
            return (url, max(0, values.fileSize ?? 0),
                    values.contentModificationDate ?? .distantPast)
        }
        var total = entries.reduce(0) { $0 + $1.bytes }
        let budget = max(0, limitBytes)
        for file in entries.sorted(by: {
            $0.modified == $1.modified ? $0.url.path < $1.url.path :
                $0.modified < $1.modified
        }) where total > budget {
            if file.url == pinned { continue }
            try fm.removeItem(at: file.url)
            total -= file.bytes
        }
        return total
    }
}
