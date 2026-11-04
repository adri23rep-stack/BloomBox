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
let commands: [BloomBoxHomeGuestCommand] = [
    .open(key: guest.stableKey, jit: false),
    .open(key: guest.stableKey, jit: true),
    .manage(key: guest.stableKey),
    .uninstall(key: guest.stableKey)
]
for command in commands {
    let encoded = try JSONEncoder().encode(command)
    let decoded = try JSONDecoder().decode(BloomBoxHomeGuestCommand.self, from: encoded)
    precondition(decoded == command, "Home action commands must survive a host boundary")
}
precondition(Set(commands).count == 4, "Action cases must remain distinct")
let homeGuest = BloomBoxHomeGuestSnapshot(
    stableKey: guest.stableKey,
    bundleIdentifier: guest.bundleIdentifier,
    displayName: guest.displayName,
    isShared: false, isRunning: false, isSigning: true,
    isEmbeddedSigner: false, isNetworkBlocked: false
)
precondition(homeGuest.stableKey == guest.stableKey)
precondition(homeGuest.isSigning && !homeGuest.isRunning)
precondition(homeGuest != BloomBoxHomeGuestSnapshot(
    stableKey: guest.stableKey, bundleIdentifier: guest.bundleIdentifier,
    displayName: guest.displayName, isShared: false, isRunning: true,
    isSigning: true, isEmbeddedSigner: false, isNetworkBlocked: false
))
print("BloomBox integration contracts are portable, Codable and host-independent.")
