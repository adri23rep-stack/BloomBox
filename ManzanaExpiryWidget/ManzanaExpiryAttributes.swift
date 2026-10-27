import ActivityKit
import Foundation

// Shared source. Compiled both into the Manzana UI framework and its WidgetKit extension.
// Changing these fields requires updating both targets at the same time.
@available(iOS 16.2, *)
struct ManzanaExpiryAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var expiresAt: Date
        var earliestAppName: String
        var expiringAppCount: Int
    }

    var source: String
}

 
// A separate, short-lived Live Activity exposes the pairing PIN while
// the user is in iOS Settings. The PIN is kept in ActivityKit state only.
@available(iOS 16.2, *)
struct BloomBoxPairingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var pin: String?
    }

    var startedAt: Date
}
