// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack (original BloomBox material only).
import Foundation
import UIKit

/// Wizard only presents once per installation, then one page per new build.
enum BloomBoxWizardMode {
    case firstRun, update
}

enum BloomBoxWizardGate {
    static let completedBuildKey = "BloomBoxWizardLastSeenBuild"
    static let stepKey = "BloomBoxWizardDraftStep"
    static let countKey = "BloomBoxWizardDraftProfileCount"

    static var build: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "0"
        let number = info["CFBundleVersion"] as? String ?? "0"
        let commit = info["BloomBoxBuildCommit"] as? String ?? ""
        return version + " (" + number + ")" + (commit.isEmpty ? "" : " " + commit)
    }

    static func pending(defaults: UserDefaults = LCUtils.appGroupUserDefault) -> BloomBoxWizardMode? {
        if let seen = defaults.string(forKey: completedBuildKey) {
            return seen == build ? nil : .update
        }
        // Existing installations must never receive a destructive first-run flow.
        let hasExistingHome = defaults.bool(forKey: BloomBoxBundledThemes.initializedKey)
            || !(defaults.string(forKey: "LiveBoardHomeLayout") ?? "").isEmpty
            || FileManager.default.fileExists(atPath: LCPath.docPath.appendingPathComponent("LiveBoardWallpaper.jpg").path)
        let hasOldHostSettings = UserDefaults.standard.bool(forKey: "LCBundleIdChecked")
            || UserDefaults.standard.string(forKey: "LCCertificateTeamId") != nil
        let hasExistingGuests = !DataManager.shared.model.apps.isEmpty
            || !DataManager.shared.model.hiddenApps.isEmpty
        return hasExistingHome || hasExistingGuests || hasOldHostSettings ? .update : .firstRun
    }

    static func finish(defaults: UserDefaults = LCUtils.appGroupUserDefault) {
        defaults.set(build, forKey: completedBuildKey)
        defaults.removeObject(forKey: stepKey)
        defaults.removeObject(forKey: countKey)
    }
}

/// A BloomBox profile is not a second iOS user. Each guest app gets its
/// own LiveContainer data directory; the original app data is never copied or deleted.
/// SideStore is explicitly excluded from guest profile switching.
enum BloomBoxProfiles {
    static let countKey = "BloomBoxProfileCount"
    static let activeKey = "BloomBoxActiveProfile"
    private static let mappingKey = "BloomBoxSecondaryGuestContainersV1"
    private static let names = ["BloomBoxProfileName1", "BloomBoxProfileName2"]

    static var count: Int {
        max(1, min(2, LCUtils.appGroupUserDefault.integer(forKey: countKey)))
    }

    static var active: Int {
        count == 2 && LCUtils.appGroupUserDefault.integer(forKey: activeKey) == 2 ? 2 : 1
    }

    static func name(_ index: Int) -> String {
        let key = names[index == 2 ? 1 : 0]
        let saved = LCUtils.appGroupUserDefault.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return saved.isEmpty ? (index == 2 ? "Player 2" : "Player 1") : saved
    }

    static func setName(_ value: String, for index: Int) {
        let normalized = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        LCUtils.appGroupUserDefault.set(normalized, forKey: names[index == 2 ? 1 : 0])
    }

    static func photoURL(for index: Int) -> URL {
        LCPath.docPath.appendingPathComponent("BloomBoxProfiles", isDirectory: true)
            .appendingPathComponent("avatar-\(index == 2 ? 2 : 1).jpg")
    }

    static func storePhoto(_ data: Data, for index: Int) throws {
        guard data.count < 20_000_000,
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.78)
        else {
            throw NSError(domain: "BloomBoxProfiles", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "La foto no es válida o es demasiado grande."
            ])
        }
        let destination = photoURL(for: index)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try jpeg.write(to: destination, options: .atomic)
    }

    private static func key(for app: LCAppModel) -> String {
        (app.uiIsShared ? "shared:" : "private:") +
        (app.appInfo.bundleIdentifier() ?? app.appInfo.relativeBundlePath ?? "")
    }

    private static func mapped() -> [String: String] {
        LCUtils.appGroupUserDefault.dictionary(forKey: mappingKey) as? [String: String] ?? [:]
    }

    static func validGuest(_ app: LCAppModel) -> Bool {
        !(app.appInfo is BuiltInSideStoreAppInfo)
            && !(app.appInfo.relativeBundlePath ?? "").isEmpty
    }

    @discardableResult
    private static func ensurePrimary(for app: LCAppModel) throws -> LCContainer {
        if let current = app.uiContainers.first(where: {
            $0.folderName == app.uiDefaultDataFolder
        }) ?? app.uiContainers.first {
            return current
        }
        guard let bundleID = app.appInfo.bundleIdentifier() else {
            throw NSError(domain: "BloomBoxProfiles", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Esta app no tiene identificador válido."
            ])
        }
        let folder = UUID().uuidString
        let primary = LCContainer(folderName: folder, name: "Default", isShared: app.uiIsShared)
        primary.makeLCContainerInfoPlist(appIdentifier: bundleID, keychainGroupId: 0)
        app.uiContainers.append(primary)
        app.appInfo.containers = app.uiContainers
        app.appInfo.dataUUID = folder
        app.uiDefaultDataFolder = folder
        app.uiSelectedContainer = primary
        return primary
    }

    @discardableResult
    static func ensureSecondary(for app: LCAppModel) throws -> LCContainer {
        guard validGuest(app) else {
            throw NSError(domain: "BloomBoxProfiles", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Solo las apps invitadas usan perfiles."
            ])
        }
        _ = try ensurePrimary(for: app)
        let id = key(for: app)
        var map = mapped()
        if let folder = map[id],
           let existing = app.uiContainers.first(where: { $0.folderName == folder }) {
            return existing
        }
        // Recovery if a profile container exists but its stored mapping was lost.
        if let existing = app.uiContainers.first(where: { $0.name == "BloomBox · Profile 2" }) {
            map[id] = existing.folderName
            LCUtils.appGroupUserDefault.set(map, forKey: mappingKey)
            return existing
        }
        let used = Set(app.uiContainers.map(\.keychainGroupId))
        guard app.uiContainers.count < SharedModel.keychainAccessGroupCount,
              let group = (0..<SharedModel.keychainAccessGroupCount).first(where: { !used.contains($0) }),
              let bundleID = app.appInfo.bundleIdentifier()
        else {
            throw NSError(domain: "BloomBoxProfiles", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "No quedan contenedores disponibles para esta app. Libera uno desde sus ajustes de LiveContainer."
            ])
        }
        let folder = UUID().uuidString
        let container = LCContainer(folderName: folder, name: "BloomBox · Profile 2",
                                    isShared: app.uiIsShared, isolateAppGroup: true)
        container.makeLCContainerInfoPlist(appIdentifier: bundleID, keychainGroupId: group)
        app.uiContainers.append(container)
        app.appInfo.containers = app.uiContainers
        map[id] = folder
        LCUtils.appGroupUserDefault.set(map, forKey: mappingKey)
        return container
    }

    static func setCount(_ value: Int, guests: [LCAppModel]) throws {
        let next = value == 2 ? 2 : 1
        if next == 2 {
            // Make a real guest container for every already-installed app.
            // Never remove containers when the user switches back to one profile.
            for guest in guests where validGuest(guest) {
                _ = try ensureSecondary(for: guest)
            }
        }
        LCUtils.appGroupUserDefault.set(next, forKey: countKey)
        if next == 1 { LCUtils.appGroupUserDefault.set(1, forKey: activeKey) }
        try select(next == 1 ? 1 : active, guests: guests)
    }

    static func select(_ index: Int, guests: [LCAppModel]) throws {
        let next = index == 2 && count == 2 ? 2 : 1
        // Provision before committing the active selection to avoid silent
        // fallback to another person's data when one guest cannot be isolated.
        if next == 2 {
            for guest in guests where validGuest(guest) {
                _ = try ensureSecondary(for: guest)
            }
        }
        LCUtils.appGroupUserDefault.set(next, forKey: activeKey)
        for guest in guests where validGuest(guest) {
            if next == 2 {
                guest.uiSelectedContainer = try ensureSecondary(for: guest)
            } else {
                guest.uiSelectedContainer = guest.uiContainers.first {
                    $0.folderName == guest.uiDefaultDataFolder
                } ?? guest.uiContainers.first
            }
        }
    }

    /// Called before normal guest launch so apps installed after onboarding also
    /// receive their private profile-2 directory automatically.
    static func selectForLaunch(_ app: LCAppModel) throws {
        guard validGuest(app), count == 2 else { return }
        if active == 2 {
            app.uiSelectedContainer = try ensureSecondary(for: app)
        } else {
            app.uiSelectedContainer = app.uiContainers.first {
                $0.folderName == app.uiDefaultDataFolder
            } ?? app.uiContainers.first
        }
    }
}
