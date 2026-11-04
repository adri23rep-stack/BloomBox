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
        eligibleGuests(apps).map { key($0) }
    }

    static func modelsByKey(_ apps: [LCAppModel]) -> [String: LCAppModel] {
        var result: [String: LCAppModel] = [:]
        for guest in eligibleGuests(apps) {
            let id = key(guest)
            // A duplicate guest key keeps the first model, like the old Home.
            if result[id] == nil { result[id] = guest }
        }
        return result
    }

    static func snapshot(_ app: LCAppModel, displayName: String) -> BloomBoxHomeGuestSnapshot {
        BloomBoxHomeGuestSnapshot(
            stableKey: key(app),
            bundleIdentifier: app.bundleIdentifier,
            displayName: displayName,
            isShared: app.uiIsShared,
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
