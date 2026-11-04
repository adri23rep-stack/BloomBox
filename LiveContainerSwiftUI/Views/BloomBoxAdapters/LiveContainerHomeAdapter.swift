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
}
