import Foundation

/// Manzana's user documents only. Guest bundles, certificates and app data are not exposed.
struct ManzanaFileStore {
    let root: URL
    private let fm = FileManager.default
    init(root: URL) throws {
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
        try fm.createDirectory(at: self.root, withIntermediateDirectories: true)
    }
    enum Failure: LocalizedError {
        case invalidName, outsideRoot, exists, invalidFile
        var errorDescription: String? {
            switch self {
            case .invalidName: return "Usa un nombre sin diagonales y que no empiece con punto."
            case .outsideRoot: return "Esta ubicación no pertenece a Archivos de Manzana."
            case .exists: return "Ya existe un elemento con ese nombre."
            case .invalidFile: return "Selecciona un archivo normal para importarlo."
            }
        }
    }
    func checked(_ url: URL) throws -> URL {
        let value = url.standardizedFileURL.resolvingSymlinksInPath()
        guard value.path == root.path || value.path.hasPrefix(root.path + "/") else { throw Failure.outsideRoot }
        return value
    }
    func contents(_ folder: URL) throws -> [URL] {
        let folder = try checked(folder)
        return try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: .skipsHiddenFiles)
            .filter { (try? checked($0)) != nil }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                let b = (try? $1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                return a == b ? $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending : a
            }
    }
    func destination(_ name: String, in folder: URL) throws -> URL {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.hasPrefix("."), !name.contains("/"), !name.contains("\\"), !name.contains("\0") else { throw Failure.invalidName }
        let url = try checked(folder).appendingPathComponent(name)
        guard !fm.fileExists(atPath: url.path) else { throw Failure.exists }
        return url
    }
    func createFolder(_ name: String, in folder: URL) throws {
        try fm.createDirectory(at: destination(name, in: folder), withIntermediateDirectories: false)
    }
    func rename(_ url: URL, to name: String) throws {
        let source = try checked(url)
        guard source != root else { throw Failure.outsideRoot }
        if name == source.lastPathComponent { return }
        try fm.moveItem(at: source, to: destination(name, in: source.deletingLastPathComponent()))
    }
    private func uniqueName(_ name: String, in folder: URL) throws -> URL {
        var candidate = name
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        var count = 2
        while fm.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            candidate = "\(stem) (\(count))" + (ext.isEmpty ? "" : ".\(ext)")
            count += 1
        }
        return try destination(candidate, in: folder)
    }
    func importFile(_ source: URL, into folder: URL) throws {
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw Failure.invalidFile }
        let folder = try checked(folder)
        try fm.copyItem(at: source, to: uniqueName(source.lastPathComponent, in: folder))
    }
    func trashFolder() throws -> URL {
        let folder = try checked(root.appendingPathComponent(".Trash"))
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
    func moveToTrash(_ url: URL) throws {
        let source = try checked(url)
        let trash = try trashFolder()
        guard source != root, source != trash, !source.path.hasPrefix(trash.path + "/") else { throw Failure.outsideRoot }
        try fm.moveItem(at: source, to: uniqueName(source.lastPathComponent, in: trash))
    }
    func restore(_ url: URL) throws {
        let source = try checked(url)
        guard source.deletingLastPathComponent() == (try trashFolder()) else { throw Failure.outsideRoot }
        try fm.moveItem(at: source, to: uniqueName(source.lastPathComponent, in: root))
    }
}
