import Foundation

// Stable, host-independent payloads for future BloomBox ↔ LiveContainer/SideStore adapters.
// This file deliberately has no imports or references to either host's implementation.
// Actual bridges are introduced separately and tested before the old direct calls go away.

enum BloomBoxLaunchMode: String, Codable, Sendable {
    case normal
    case game
    case multitask
}

enum BloomBoxJITPreference: String, Codable, Sendable {
    case automatic
    case requested
    case off
}

struct BloomBoxGuestDescriptor: Codable, Hashable, Sendable {
    /// Persistent launcher key; the host adapter translates it to its internal app model.
    let stableKey: String
    let bundleIdentifier: String
    let displayName: String
    let isShared: Bool
}

struct BloomBoxLaunchRequest: Codable, Hashable, Sendable {
    let guestKey: String
    let mode: BloomBoxLaunchMode
    let jit: BloomBoxJITPreference

    /// A requested JIT attach cannot silently reuse a running guest.
    var requiresFreshAttach: Bool { jit == .requested }
}

enum BloomBoxRefreshState: String, Codable, Sendable {
    case unavailable
    case submitted
    case verified
}

struct BloomBoxRefreshRequest: Codable, Hashable, Sendable {
    let bundleIdentifier: String
    let preserveExtensions: Bool
}

/// LiveContainer owns executable loading, guest containers and runtime hooks.
@MainActor
protocol BloomBoxGuestHost: AnyObject {
    func installedGuests() async throws -> [BloomBoxGuestDescriptor]
    func launch(_ request: BloomBoxLaunchRequest) async throws
}

/// SideStore (or another signer) owns authentication, certificates and signing.
/// No credential, session token or pairing-record types cross this boundary.
@MainActor
protocol BloomBoxSigningService: AnyObject {
    func refresh(_ request: BloomBoxRefreshRequest) async throws -> BloomBoxRefreshState
}

enum BloomBoxIntegrationProtocol {
    static let majorVersion = 1
}
