import Foundation

/// Keep new BloomBox diagnostics independent of LiveContainer's current
/// application-group path implementation. If upstream changes its container
/// layout, only this adapter needs updating.
enum LiveContainerDiagnosticsAdapter {
    static var sharedDirectory: URL? {
        // The app group can be temporarily unavailable during first launch or
        // broken signing. Host breadcrumbs must remain usable in that case.
        let root = LCSharedUtils.appGroupPath() ??
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return root?.appendingPathComponent("Library/BloomBoxDiagnostics", isDirectory: true)
    }
}
