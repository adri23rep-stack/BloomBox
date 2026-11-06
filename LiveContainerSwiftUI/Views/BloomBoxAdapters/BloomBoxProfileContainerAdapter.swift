import Foundation

/// Host-only adapter: a BloomBox profile maps to an existing LiveContainer container
/// per guest. We never move, empty or rename an app's primary data directory.
enum BloomBoxProfileContainerAdapter {
    static func containerForLaunch(app: LCAppModel, explicitlyRequested: String?) throws -> String? {
        if let explicitlyRequested {
            // An explicit deep link or container action stays authoritative.
            return explicitlyRequested
        }
        if app.appInfo is BuiltInSideStoreAppInfo {
            return nil
        }

        let profile = BloomBoxProfileStore.active
        if profile.id == BloomBoxUserProfile.primaryID {
            // Switching back to profile 1 restores the original default, not
            // the last container used by profile 2.
            return app.uiDefaultDataFolder ?? app.appInfo.dataUUID
        }

        guard let bundleID = app.appInfo.bundleIdentifier(), !bundleID.isEmpty else {
            throw BloomBoxProfileContainerError.missingBundle
        }
        guard let relativePath = app.appInfo.relativeBundlePath, !relativePath.isEmpty else {
            throw BloomBoxProfileContainerError.missingBundle
        }

        let guestKey = (app.uiIsShared ? "shared/" : "private/") + relativePath + "/" + bundleID
        if let folder = BloomBoxProfileStore.mapping(for: profile.id, appKey: guestKey),
           app.uiContainers.contains(where: {
               $0.folderName == folder && $0.appIdentifier == bundleID
           }) {
            return folder
        }

        // Recover an existing profile-owned directory when app metadata was
        // rewritten but its container survived. Never adopt an unrelated folder.
        let tag = "[BloomBox:\(profile.id)]"
        if let existing = app.uiContainers.first(where: {
            $0.name.hasPrefix(tag) && $0.appIdentifier == bundleID
        }) {
            BloomBoxProfileStore.rememberContainer(existing.folderName,
                                                   profileID: profile.id, appKey: guestKey)
            return existing.folderName
        }

        let assigned = Set(app.uiContainers.compactMap { container -> Int? in
            let key = container.keychainGroupId
            return key >= 0 ? key : nil
        })
        guard let freeGroup = (0..<SharedModel.keychainAccessGroupCount).first(where: { !assigned.contains($0) }) else {
            throw BloomBoxProfileContainerError.noKeychainGroup
        }

        let folderName = UUID().uuidString
        let container = LCContainer(folderName: folderName,
                                    name: tag + " " + profile.name,
                                    isShared: app.uiIsShared)
        let path = container.containerURL
        var createdHere = false
        do {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
            createdHere = true
            container.makeLCContainerInfoPlist(appIdentifier: bundleID, keychainGroupId: freeGroup)
            guard FileManager.default.fileExists(
                atPath: path.appendingPathComponent("LCContainerInfo.plist").path
            ) else {
                throw BloomBoxProfileContainerError.failedToCreate
            }
        } catch {
            // A collision or failed directory creation must never remove old data.
            if createdHere { try? FileManager.default.removeItem(at: path) }
            throw error
        }

        app.uiContainers.append(container)
        app.appInfo.containers = app.uiContainers
        if !DataManager.shared.model.appDataFolderNames.contains(folderName) {
            DataManager.shared.model.appDataFolderNames.append(folderName)
        }
        BloomBoxProfileStore.rememberContainer(folderName, profileID: profile.id,
                                               appKey: guestKey)
        return folderName
    }
}

private enum BloomBoxProfileContainerError: LocalizedError {
    case missingBundle
    case noKeychainGroup
    case failedToCreate

    var errorDescription: String? {
        switch self {
        case .missingBundle:
            return "Esta app no tiene un identificador válido para crear su contenedor de perfil."
        case .noKeychainGroup:
            return "Esta app alcanzó el límite de contenedores. Revisa sus contenedores antes de crear otro perfil."
        case .failedToCreate:
            return "No se pudo preparar el contenedor de este perfil. Tus otros datos siguen intactos."
        }
    }
}
