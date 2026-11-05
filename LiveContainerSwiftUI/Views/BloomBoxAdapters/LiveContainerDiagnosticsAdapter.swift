import Foundation

/// Keep new BloomBox diagnostics independent of LiveContainer's current
/// application-group path implementation. If upstream changes its container
/// layout, only this adapter needs updating.
enum LiveContainerDiagnosticsAdapter {
    static var sharedDirectory: URL? {
        LCSharedUtils.appGroupPath()?
            .appendingPathComponent("Library/BloomBoxDiagnostics", isDirectory: true)
    }
}
