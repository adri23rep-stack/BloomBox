import Foundation

/// Translate BloomBox's legacy storage keys to LiveContainer's current app
/// group without changing the suite or migrating data accidentally.
/// Future upstream updates only need to change this bridge.
enum LiveContainerPreferencesAdapter {
    static var defaults: UserDefaults {
        LCUtils.appGroupUserDefault
    }
}
