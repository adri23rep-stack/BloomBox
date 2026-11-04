import Foundation

let guest = BloomBoxGuestDescriptor(
    stableKey: "local:sample.ipa", bundleIdentifier: "org.example.sample",
    displayName: "Sample", isShared: false)
let launch = BloomBoxLaunchRequest(guestKey: guest.stableKey,
                                   mode: .game, jit: .requested)
let decodedLaunch = try JSONDecoder().decode(
    BloomBoxLaunchRequest.self, from: JSONEncoder().encode(launch))
precondition(decodedLaunch == launch)
precondition(launch.requiresFreshAttach)
precondition(!BloomBoxLaunchRequest(guestKey: guest.stableKey, mode: .normal,
                                   jit: .automatic).requiresFreshAttach)

let decodedGuest = try JSONDecoder().decode(
    BloomBoxGuestDescriptor.self, from: JSONEncoder().encode(guest))
precondition(decodedGuest == guest)

let refresh = BloomBoxRefreshRequest(bundleIdentifier: guest.bundleIdentifier,
                                     preserveExtensions: true)
let decodedRefresh = try JSONDecoder().decode(
    BloomBoxRefreshRequest.self, from: JSONEncoder().encode(refresh))
precondition(decodedRefresh == refresh && decodedRefresh.preserveExtensions)
precondition(BloomBoxIntegrationProtocol.majorVersion == 1)
print("BloomBox integration contracts are portable, Codable and host-independent.")
