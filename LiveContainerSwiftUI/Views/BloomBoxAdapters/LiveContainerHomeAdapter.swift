import Foundation
import UIKit

/// The only Home-specific translation layer that knows LiveContainer's
/// concrete guest model. Home UI consumes stable keys and value snapshots.
/// Move this adapter with upstream changes; do not copy LC internals into UI.
@MainActor
enum LiveContainerHomeAdapter {
    static func isEmbeddedSigner(_ app: LCAppModel) -> Bool {
        app.appInfo is BuiltInSideStoreAppInfo
    }

    static func eligibleGuests(_ apps: [LCAppModel]) -> [LCAppModel] {
        apps.filter { !isEmbeddedSigner($0) }
    }

    static func key(_ app: LCAppModel) -> String {
        // Preserve historical IDs used by Home layouts, folders and themes.
        liveBoardAppKey(app)
    }

    static func visibleKeys(_ apps: [LCAppModel]) -> [String] {
        BloomBoxHomeGuestIndex.keys(
            apps, key: { key($0) }, isEmbeddedSigner: { isEmbeddedSigner($0) }
        )
    }

    static func modelsByKey(_ apps: [LCAppModel]) -> [String: LCAppModel] {
        BloomBoxHomeGuestIndex.firstByKey(
            apps, key: { key($0) }, isEmbeddedSigner: { isEmbeddedSigner($0) }
        )
    }

    static func searchModelsByKey(_ apps: [LCAppModel]) -> [String: LCAppModel] {
        // Search intentionally mirrors the old Home and includes embedded
        // shortcuts, while the actual desktop app map excludes the signer.
        BloomBoxHomeGuestIndex.firstByKey(
            apps, key: { key($0) }, isEmbeddedSigner: { _ in false }
        )
    }

    static func isShared(_ app: LCAppModel) -> Bool {
        app.uiIsShared
    }

    static func snapshot(_ app: LCAppModel, displayName: String) -> BloomBoxHomeGuestSnapshot {
        BloomBoxHomeGuestSnapshot(
            stableKey: key(app),
            bundleIdentifier: app.bundleIdentifier,
            displayName: displayName,
            isShared: isShared(app),
            isRunning: app.isAppRunning,
            isSigning: app.isSigningInProgress,
            isEmbeddedSigner: isEmbeddedSigner(app),
            isNetworkBlocked: app.uiNetworkBlocked
        )
    }

    static func displayName(_ app: LCAppModel, using customization: BloomBoxAppCustomization) -> String {
        customization.name(app)
    }

    static func rename(_ app: LCAppModel, to name: String, using customization: BloomBoxAppCustomization) {
        customization.rename(app, to: name)
    }

    @discardableResult
    static func toggleNetwork(_ app: LCAppModel) -> Bool {
        app.uiNetworkBlocked.toggle()
        return app.uiNetworkBlocked
    }

    static func builtInSignerIcon(dark: Bool) -> UIImage? {
        BuiltInSideStoreAppInfo.shared.iconIsDarkIcon(dark)
    }

    static func moduleGuests(_ apps: [LCAppModel], sharedModel: SharedModel) -> [LCAppModel] {
        let showHidden = !LiveContainerPreferencesAdapter.defaults.bool(forKey: "LCStrictHiding")
            || sharedModel.isHiddenAppUnlocked
        return apps + (showHidden ? sharedModel.hiddenApps : [])
    }
    /// Import selected dylibs into this app's assigned tweak folder.
    /// Existing associations stay unchanged, and Files originals remain intact.
    static func installTweakFiles(_ urls: [URL], for app: LCAppModel,
                                  sharedModel: SharedModel) -> String? {
        guard !urls.isEmpty else { return nil }
        let fm = FileManager.default
        let folderName = app.uiTweakFolder ?? ("BloomBox-" + String(UUID().uuidString.prefix(12)))
        let root = isShared(app) ? LCPath.lcGroupTweakPath : LCPath.tweakPath
        let folder = root.appendingPathComponent(folderName, isDirectory: true)
        var imported = 0
        var failures: [String] = []

        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let name = url.lastPathComponent
                guard url.isFileURL, !name.isEmpty, name != ".", name != "..",
                      !name.contains("/"), !name.contains("\\") else {
                    throw CocoaError(.fileReadInvalidFileName)
                }
                let dylib = name.lowercased().hasSuffix(".dylib")
                let framework = name.lowercased().hasSuffix(".framework")
                guard dylib || framework else {
                    throw NSError(domain: "BloomBox.Tweaks", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Solo admite .dylib y .framework"])
                }
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                let destination = folder.appendingPathComponent(name)
                guard !fm.fileExists(atPath: destination.path) else {
                    throw NSError(domain: "BloomBox.Tweaks", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Ya existe \(name) en la carpeta de la app"])
                }
                try fm.copyItem(at: url, to: destination)
                if dylib {
                    LCParseMachO((destination.path as NSString).utf8String, false) { path, header, _, _ in
                        LCPatchAddRPath(path, header)
                    }
                }
                imported += 1
            } catch {
                failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if imported > 0 {
            if app.uiTweakFolder == nil { app.uiTweakFolder = folderName }
            if !isShared(app) && !sharedModel.tweakFolderNames.contains(folderName) {
                sharedModel.tweakFolderNames.append(folderName)
            }
        }
        return failures.isEmpty ? nil : failures.joined(separator: "\n")
    }

}
