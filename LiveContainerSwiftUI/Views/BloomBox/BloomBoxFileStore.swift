import Foundation

/// BloomBox-only document operations. Never touches guest apps, signing or RAM+.
/// A pre-existing "Manzana Files" folder stays usable to avoid losing user data.
struct BloomBoxFileStore {
    let root: URL
    private let fm = FileManager.default

    enum Failure: LocalizedError {
        case invalidName, outsideRoot, exists, invalidFile
        var errorDescription: String? {
            switch self {
            case .invalidName:
                return "Usa un nombre válido, sin diagonales, controles ni punto inicial."
            case .outsideRoot:
                return "Esta operación debe permanecer dentro de Archivos de BloomBox."
            case .exists:
                return "Ya existe un archivo o carpeta con ese nombre."
            case .invalidFile:
                return "Selecciona un archivo o carpeta válido."
            }
        }
    }

    /// An existing user folder takes priority; new installations use BloomBox.
    /// No large, error-prone file copy or rename occurs during migration.
    static func preferredRoot(in documents: URL, fm: FileManager = .default) -> URL {
        let modern = documents.appendingPathComponent("BloomBox Files", isDirectory: true)
        let previous = documents.appendingPathComponent("Manzana Files", isDirectory: true)
        if fm.fileExists(atPath: modern.path) { return modern }
        if fm.fileExists(atPath: previous.path) { return previous }
        return modern
    }

    init(root: URL) throws {
        let candidate = root.standardizedFileURL
        try fm.createDirectory(at: candidate, withIntermediateDirectories: true)
        let resolved = candidate.resolvingSymlinksInPath()
        let info = try resolved.resourceValues(forKeys: [.isDirectoryKey])
        guard info.isDirectory == true else { throw Failure.invalidFile }
        self.root = resolved
    }

    /// Resolving symbolic links before checking the boundary prevents escape.
    func checked(_ url: URL) throws -> URL {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        guard resolved.path == root.path || resolved.path.hasPrefix(root.path + "/") else {
            throw Failure.outsideRoot
        }
        return resolved
    }

    private func checkedFolder(_ url: URL) throws -> URL {
        let resolved = try checked(url)
        let values = try resolved.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw Failure.invalidFile }
        return resolved
    }

    func contents(_ folder: URL) throws -> [URL] {
        let folder = try checkedFolder(folder)
        return try fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: .skipsHiddenFiles
        ).filter {
            guard (try? checked($0)) != nil else { return false }
            // Avoid showing shortcuts that escape or resolve back into themselves.
            return (try? $0.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true
        }.sorted { lhs, rhs in
            let lhsFolder = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            let rhsFolder = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if lhsFolder != rhsFolder { return lhsFolder }
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }
    }

    private func safeName(_ raw: String) throws -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.hasPrefix("."),
              name.utf8.count <= 255,
              !name.contains("/"), !name.contains("\\"),
              name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw Failure.invalidName
        }
        return name
    }

    func destination(_ raw: String, in folder: URL) throws -> URL {
        let name = try safeName(raw)
        let parent = try checkedFolder(folder)
        let target = parent.appendingPathComponent(name)
        guard !fm.fileExists(atPath: target.path) else { throw Failure.exists }
        return target
    }

    private func uniqueDestination(_ name: String, in folder: URL) throws -> URL {
        let parent = try checkedFolder(folder)
        let clean = try safeName(name)
        let ext = (clean as NSString).pathExtension
        let stem = (clean as NSString).deletingPathExtension
        for number in 1...10_000 {
            let proposed = number == 1 ? clean :
                stem + " (" + String(number) + ")" + (ext.isEmpty ? "" : "." + ext)
            let target = parent.appendingPathComponent(proposed)
            if !fm.fileExists(atPath: target.path) { return try destination(proposed, in: parent) }
        }
        throw Failure.exists
    }

    func createFolder(_ name: String, in folder: URL) throws {
        try fm.createDirectory(at: destination(name, in: folder),
                               withIntermediateDirectories: false)
    }

    func rename(_ url: URL, to name: String) throws {
        let source = try checked(url)
        let trash = root.appendingPathComponent(".Trash", isDirectory: true)
        guard source != root, source != trash, !source.path.hasPrefix(trash.path + "/") else {
            throw Failure.outsideRoot
        }
        let newName = try safeName(name)
        if newName == source.lastPathComponent { return }
        try fm.moveItem(at: source, to: destination(newName, in: source.deletingLastPathComponent()))
    }

    func importFile(_ source: URL, into folder: URL) throws {
        let properties = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard properties.isRegularFile == true, properties.isSymbolicLink != true else {
            throw Failure.invalidFile
        }
        let parent = try checkedFolder(folder)
        guard !inTrash(parent) else { throw Failure.outsideRoot }
        try fm.copyItem(at: source, to: uniqueDestination(source.lastPathComponent, in: parent))
    }

    private func inTrash(_ url: URL) -> Bool {
        let trash = root.appendingPathComponent(".Trash", isDirectory: true)
        return url.path == trash.path || url.path.hasPrefix(trash.path + "/")
    }

    func trashFolder() throws -> URL {
        let folder = try checked(root.appendingPathComponent(".Trash", isDirectory: true))
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func moveToTrash(_ url: URL) throws {
        let source = try checked(url)
        guard source != root, !inTrash(source) else { throw Failure.outsideRoot }
        try fm.moveItem(at: source, to: uniqueDestination(source.lastPathComponent, in: trashFolder()))
    }

    func restore(_ url: URL) throws {
        let source = try checked(url)
        let trash = try trashFolder()
        guard source.deletingLastPathComponent() == trash else { throw Failure.outsideRoot }
        try fm.moveItem(at: source, to: uniqueDestination(source.lastPathComponent, in: root))
    }

    private func transfer(_ url: URL, into folderURL: URL, copying: Bool) throws {
        let source = try checked(url)
        let folder = try checkedFolder(folderURL)
        guard source != root, !inTrash(source), !inTrash(folder),
              folder != source, !folder.path.hasPrefix(source.path + "/") else {
            throw Failure.outsideRoot
        }
        let sourceProperties = try source.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard sourceProperties.isSymbolicLink != true else { throw Failure.invalidFile }
        if !copying && source.deletingLastPathComponent() == folder { return }
        let target = try uniqueDestination(source.lastPathComponent, in: folder)
        if copying { try fm.copyItem(at: source, to: target) }
        else { try fm.moveItem(at: source, to: target) }
    }

    func move(_ url: URL, into folder: URL) throws {
        try transfer(url, into: folder, copying: false)
    }
    func copy(_ url: URL, into folder: URL) throws {
        try transfer(url, into: folder, copying: true)
    }
}
