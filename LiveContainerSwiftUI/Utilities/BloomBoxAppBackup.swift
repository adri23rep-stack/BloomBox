import Foundation
import Security

/// File work runs on a utility task. No guest executable or host configuration is imported.
enum BloomBoxAppBackup {
    struct Profile: Codable, Sendable {
        let name: String
        let isolatedGroups: Bool
        let spoofIDFV: Bool
        let idfv: String?
    }
    struct Manifest: Codable, Sendable {
        let format: String
        let version: Int
        let bundleID: String
        let appVersion: String
        let created: Date
        let defaultProfile: Int
        let profiles: [Profile]
        let groups: [String]
        var warnings: [String]
    }
    struct Source: Sendable {
        let url: URL
        let folder: String
        let profile: Profile
    }
    struct ExportRequest: Sendable {
        let bundleID: String
        let appVersion: String
        let executable: String?
        let sources: [Source]
        let defaultProfile: Int
        let groupRoot: URL
    }
    struct Prepared: Sendable {
        let root: URL
        let manifest: Manifest
    }
    struct Restored: Sendable {
        let folders: [String]
        let profiles: [Profile]
        let defaultProfile: Int
        let warnings: [String]
    }
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    private static let fm = FileManager.default
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure(message: message) }
    }
    private static func workspace() throws -> URL {
        let url = fm.temporaryDirectory.appendingPathComponent("BloomBoxBackup-" + UUID().uuidString)
        try fm.createDirectory(at: url, withIntermediateDirectories: false,
                               attributes: [.protectionKey: FileProtectionType.complete])
        return url
    }
    static func removeWorkspace(_ url: URL) { try? fm.removeItem(at: url) }
    private static func validGroup(_ name: String) -> Bool {
        name.hasPrefix("group.") && name.count < 240 &&
        name.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_").contains($0) } && !name.contains("..")
    }
    private static func running(_ sources: [Source]) -> Bool {
        sources.contains { LCSharedUtils.getContainerUsingLCScheme(withFolderName: $0.folder) != nil }
    }
    static func export(_ request: ExportRequest) throws -> URL {
        try require(!request.sources.isEmpty, "Abre la app una vez para que cree sus datos.")
        try require(!running(request.sources), "Cierra la app antes de exportar sus datos.")
        let root = try workspace()
        var finished = false
        defer { if !finished { removeWorkspace(root) } }
        let payload = root.appendingPathComponent("Payload")
        try fm.createDirectory(at: payload.appendingPathComponent("profiles"), withIntermediateDirectories: true)
        var warnings = ["Las claves protegidas por iOS, Face ID, compras y datos de servidores no se pueden garantizar. La copia no incluye el instalador de la app ni el enlace temporal de BloomBox, que se vuelve a crear al abrirla."]
        var groups: [String] = []
        if let executable = request.executable,
           let xml = getExecutableEntitlementXML(executable),
           let bytes = xml.data(using: .utf8),
           let entitlements = try? PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any] {
            groups = Array(Set((entitlements["com.apple.security.application-groups"] as? [String] ?? [])
                .filter { validGroup($0) && $0 != LCSharedUtils.appGroupID() })).sorted()
        }
        var exportedGroups: [String] = []
        if request.sources.contains(where: { !$0.profile.isolatedGroups }) {
            for group in groups {
                let source = request.groupRoot.appendingPathComponent(group)
                if fm.fileExists(atPath: source.path) {
                    try fm.createDirectory(at: payload.appendingPathComponent("groups"), withIntermediateDirectories: true)
                    try copyData(source, to: payload.appendingPathComponent("groups").appendingPathComponent(group))
                    exportedGroups.append(group)
                }
            }
            warnings.append("Se incluyen los grupos compartidos identificados en la firma de la app. Los grupos no declarados y archivos de proveedores externos no se incluyen.")
        }
        for (index, source) in request.sources.enumerated() {
            let scoped = source.url.startAccessingSecurityScopedResource()
            defer { if scoped { source.url.stopAccessingSecurityScopedResource() } }
            let target = payload.appendingPathComponent("profiles/\(index)")
            try fm.createDirectory(at: target, withIntermediateDirectories: true)
            try copyData(source.url, to: target.appendingPathComponent("data"), omitRuntimeTempLink: true)
            let credentials = try exportCredentials(folder: source.folder, warnings: &warnings)
            let bytes = try PropertyListSerialization.data(fromPropertyList: credentials, format: .binary, options: 0)
            try require(credentials.count <= 20000 && bytes.count <= 32 * 1024 * 1024, "Las credenciales exceden el tamaño admitido por esta versión.")
            try bytes.write(to: target.appendingPathComponent("credentials.plist"), options: .atomic)
        }
        try require(!running(request.sources), "La app se abrió durante la copia. Ciérrala y vuelve a intentarlo.")
        let manifest = Manifest(format: "BloomBox.AppData", version: 1, bundleID: request.bundleID,
                                appVersion: request.appVersion, created: Date(), defaultProfile: request.defaultProfile,
                                profiles: request.sources.map(\.profile), groups: exportedGroups, warnings: Array(Set(warnings)).sorted())
        try JSONEncoder().encode(manifest).write(to: payload.appendingPathComponent("manifest.json"), options: .atomic)
        let output = root.appendingPathComponent("BloomBox-\(UUID().uuidString.prefix(8)).bloomboxbackup")
        try BloomBoxArchive.pack(source: payload, destination: output)
        try fm.removeItem(at: payload)
        finished = true
        return output
    }
    /// Guest bootstrap always links top-level tmp to the host temporary folder.
    /// Never copy that shared runtime directory; all other links fail explicitly.
    private static func copyData(_ source: URL, to target: URL, omitRuntimeTempLink: Bool = false) throws {
        let source = source.resolvingSymlinksInPath().standardizedFileURL
        let attrs = try fm.attributesOfItem(atPath: source.path)
        try require(attrs[.type] as? FileAttributeType == .typeDirectory, "La carpeta de datos no está disponible.")
        try fm.createDirectory(at: target, withIntermediateDirectories: false)
        var walkError: Error?
        guard let walk = fm.enumerator(at: source, includingPropertiesForKeys: nil, errorHandler: { _, error in walkError = error; return false }) else {
            throw Failure(message: "No se pudieron leer los datos de la app.")
        }
        for case let url as URL in walk {
            let parts = url.standardizedFileURL.pathComponents
            let base = source.pathComponents
            try require(parts.count > base.count && Array(parts.prefix(base.count)) == base, "Una ruta no pertenece al perfil de datos.")
            let relative = parts.dropFirst(base.count).joined(separator: "/")
            let type = try fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
            if type == .typeSymbolicLink && omitRuntimeTempLink && relative == "tmp" {
                walk.skipDescendants()
                continue
            }
            try require(type == .typeRegular || type == .typeDirectory,
                        "La app usa enlaces a archivos externos o especiales (\(url.lastPathComponent)). No se creó una copia incompleta.")
            let destination = target.appendingPathComponent(relative)
            if type == .typeDirectory {
                try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            } else {
                try fm.copyItem(at: url, to: destination)
            }
        }
        if let walkError { throw walkError }
    }
    static func prepare(_ input: URL, bundleID: String, capacity: Int) throws -> Prepared {
        let scoped = input.startAccessingSecurityScopedResource()
        defer { if scoped { input.stopAccessingSecurityScopedResource() } }
        let root = try workspace()
        var finished = false
        defer { if !finished { removeWorkspace(root) } }
        // Copy provider-backed documents while coordinated, before opening a ZIP reader.
        let local = root.appendingPathComponent("input.zip")
        var coordinateError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: input, options: [], error: &coordinateError) { url in
            do { try fm.copyItem(at: url, to: local) } catch { copyError = error }
        }
        if let coordinateError { throw coordinateError }
        if let copyError { throw copyError }
        let payload = root.appendingPathComponent("Payload")
        try BloomBoxArchive.unpack(source: local, destination: payload)
        try fm.removeItem(at: local)
        let metadata = payload.appendingPathComponent("manifest.json")
        let size = try metadata.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        try require(size > 0 && size <= 1024 * 1024, "La información de la copia no es válida.")
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: metadata))
        try require(manifest.format == "BloomBox.AppData" && manifest.version == 1, "Esta versión de copia no es compatible.")
        try require(manifest.bundleID == bundleID, "Esta copia pertenece a otra app (\(manifest.bundleID)).")
        try require(!manifest.profiles.isEmpty && manifest.profiles.count <= capacity,
                    "No hay suficientes espacios de datos libres. Conserva tu copia y libera un perfil que ya no uses en Ajustes de la app.")
        try require(manifest.profiles.indices.contains(manifest.defaultProfile), "El perfil principal de la copia no es válido.")
        try require(manifest.groups.count <= 100 && Set(manifest.groups).count == manifest.groups.count && manifest.groups.allSatisfy(validGroup), "Los grupos de la copia no son válidos.")
        for (index, profile) in manifest.profiles.enumerated() {
            try require(profile.name.count <= 1000 && (profile.idfv == nil || UUID(uuidString: profile.idfv!) != nil), "Los ajustes de un perfil no son válidos.")
            var directory: ObjCBool = false
            try require(fm.fileExists(atPath: payload.appendingPathComponent("profiles/\(index)/data").path, isDirectory: &directory) && directory.boolValue, "Faltan datos de un perfil.")
            _ = try credentials(at: payload.appendingPathComponent("profiles/\(index)/credentials.plist"))
        }
        for group in manifest.groups {
            var directory: ObjCBool = false
            try require(fm.fileExists(atPath: payload.appendingPathComponent("groups/\(group)").path, isDirectory: &directory) && directory.boolValue, "Faltan datos compartidos.")
        }
        finished = true
        return Prepared(root: root, manifest: manifest)
    }
    static func restore(_ prepared: Prepared, dataRoot: URL, groupIDs: [Int], teamID: String) throws -> Restored {
        let manifest = prepared.manifest
        try require(groupIDs.count == manifest.profiles.count && !teamID.isEmpty, "No se pudieron reservar los perfiles de datos.")
        let payload = prepared.root.appendingPathComponent("Payload")
        try fm.createDirectory(at: dataRoot, withIntermediateDirectories: true)
        var folders: [String] = []
        var persistentRefs: [Data] = []
        var warnings = manifest.warnings
        var profiles: [Profile] = []
        var committed = false
        defer {
            if !committed {
                for folder in folders { try? fm.removeItem(at: dataRoot.appendingPathComponent(folder)) }
                for ref in persistentRefs { SecItemDelete([kSecValuePersistentRef as String: ref] as CFDictionary) }
            }
        }
        for (index, original) in manifest.profiles.enumerated() {
            let folder = UUID().uuidString
            let source = payload.appendingPathComponent("profiles/\(index)/data")
            let target = dataRoot.appendingPathComponent(folder)
            // Track even partial copies so a disk-full error leaves no orphan profile.
            folders.append(folder)
            try fm.copyItem(at: source, to: target)
            if !original.isolatedGroups && !manifest.groups.isEmpty {
                let root = target.appendingPathComponent("LCAppGroup")
                try fm.createDirectory(at: root, withIntermediateDirectories: true)
                for group in manifest.groups {
                    let destination = root.appendingPathComponent(group)
                    if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
                    try fm.copyItem(at: payload.appendingPathComponent("groups/\(group)"), to: destination)
                }
            }
            // Isolate restored shared files to avoid replacing data belonging to another app.
            let profile = Profile(name: original.name + " · Restaurado", isolatedGroups: original.isolatedGroups || !manifest.groups.isEmpty,
                                  spoofIDFV: original.spoofIDFV, idfv: original.idfv)
            profiles.append(profile)
            var info: [String: Any] = ["appIdentifier": manifest.bundleID, "name": profile.name, "keychainGroupId": groupIDs[index],
                                      "isolateAppGroup": profile.isolatedGroups, "spoofIdentifierForVendor": profile.spoofIDFV]
            if let idfv = profile.idfv { info["spoofedIdentifierForVendor"] = idfv }
            try PropertyListSerialization.data(fromPropertyList: info, format: .binary, options: 0)
                .write(to: target.appendingPathComponent("LCContainerInfo.plist"), options: .atomic)
            let items = try credentials(at: payload.appendingPathComponent("profiles/\(index)/credentials.plist"))
            let group = teamID + ".com.kdt.livecontainer.shared" + (groupIDs[index] == 0 ? "" : ".\(groupIDs[index])")
            try restoreCredentials(items, folder: folder, group: group, inserted: &persistentRefs, warnings: &warnings)
        }
        committed = true
        return Restored(folders: folders, profiles: profiles, defaultProfile: manifest.defaultProfile, warnings: Array(Set(warnings)).sorted())
    }
    private static let credentialAttributes: Set<String> = Set([
        kSecAttrAccount, kSecAttrService, kSecAttrServer, kSecAttrSecurityDomain, kSecAttrProtocol,
        kSecAttrAuthenticationType, kSecAttrPort, kSecAttrPath, kSecAttrLabel, kSecAttrDescription,
        kSecAttrComment, kSecAttrGeneric, kSecValueData, kSecClass
    ].map { $0 as String })
    private static func exportCredentials(folder: String, warnings: inout [String]) throws -> [[String: Any]] {
        var exported: [[String: Any]] = []
        for kind in [kSecClassGenericPassword, kSecClassInternetPassword] {
            var result: CFTypeRef?
            let query: [String: Any] = [kSecClass as String: kind, "alis": folder,
                kSecMatchLimit as String: kSecMatchLimitAll, kSecReturnAttributes as String: true,
                kSecReturnData as String: true, kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound { continue }
            if status != errSecSuccess {
                warnings.append("Algunas credenciales no se pudieron leer (iOS \(status)). Puede ser necesario iniciar sesión otra vez.")
                continue
            }
            for record in result as? [[String: Any]] ?? [] {
                guard record[kSecValueData as String] is Data, record[kSecAttrAccessControl as String] == nil else {
                    warnings.append("Una credencial protegida no es exportable."); continue
                }
                var item = record.filter { credentialAttributes.contains($0.key) }
                item[kSecClass as String] = kind as String
                exported.append(item)
            }
        }
        return exported
    }
    private static func credentials(at url: URL) throws -> [[String: Any]] {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        try require(size <= 32 * 1024 * 1024, "Las credenciales de la copia son demasiado grandes.")
        guard let items = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [[String: Any]], items.count <= 20000 else {
            throw Failure(message: "Las credenciales de la copia no son válidas.")
        }
        for item in items {
            let kind = item[kSecClass as String] as? String
            try require(kind == kSecClassGenericPassword as String || kind == kSecClassInternetPassword as String, "Tipo de credencial incompatible.")
            try require(Set(item.keys).isSubset(of: credentialAttributes) && item[kSecValueData as String] is Data, "La copia contiene atributos de credenciales no válidos.")
        }
        return items
    }
    private static func restoreCredentials(_ items: [[String: Any]], folder: String, group: String,
                                           inserted: inout [Data], warnings: inout [String]) throws {
        for record in items {
            var item = record
            item["alis"] = folder
            item[kSecAttrAccessGroup as String] = group
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            item[kSecReturnPersistentRef as String] = true
            var result: CFTypeRef?
            let status = SecItemAdd(item as CFDictionary, &result)
            if status == errSecDuplicateItem {
                warnings.append("Una credencial ya existía y se conservó sin sobrescribirla. Revisa el inicio de sesión.")
            } else if status == errSecSuccess, let ref = result as? Data {
                inserted.append(ref)
            } else {
                throw Failure(message: "No se pudieron restaurar las credenciales (iOS \(status)). Los perfiles actuales se conservaron.")
            }
        }
    }
}
