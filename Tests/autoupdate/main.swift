import Foundation

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ name: String) {
    guard a == b else { fatalError("AutoUpdate policy failed: \(name). \(a) != \(b)") }
}
assertEqual(BloomBoxAutoUpdatePolicy.compare("v2.0.0", "v2.1.0"), -1, "upgrade")
assertEqual(BloomBoxAutoUpdatePolicy.compare("v2.10.0", "v2.9.9"), 1, "numeric comparison")
assertEqual(BloomBoxAutoUpdatePolicy.compare("v2.0.0", "v2.0.0"), 0, "same version")
assertEqual(BloomBoxAutoUpdatePolicy.compare("v2.1.0-beta.1", "v2.1.0"), nil, "no prerelease")
assertEqual(BloomBoxAutoUpdatePolicy.compare("v2.1.0", "3.8.10"), nil, "no upstream versions")
assertEqual(BloomBoxAutoUpdatePolicy.decision(installedTag: nil, availableTag: "v2.1.0"), .offerOnly, "legacy build")
assertEqual(BloomBoxAutoUpdatePolicy.decision(installedTag: "development", availableTag: "v2.1.0"), .offerOnly, "dev build")
assertEqual(BloomBoxAutoUpdatePolicy.decision(installedTag: "v2.0.0", availableTag: "v2.1.0"), .eligible, "eligible")
assertEqual(BloomBoxAutoUpdatePolicy.decision(installedTag: "v2.1.0", availableTag: "v2.0.0"), .none, "prevent downgrade")
assertEqual(BloomBoxAutoUpdatePolicy.shouldAutomaticallyInstall(decision: .eligible, automatic: true, alreadyAttempted: false), true, "auto")
assertEqual(BloomBoxAutoUpdatePolicy.shouldAutomaticallyInstall(decision: .offerOnly, automatic: true, alreadyAttempted: false), false, "legacy not auto")
assertEqual(BloomBoxAutoUpdatePolicy.shouldAutomaticallyInstall(decision: .eligible, automatic: true, alreadyAttempted: true), false, "no loop")
let asset = URL(string: "https://github.com/adri23rep-stack/BloomBox/releases/download/v2.1.0/BloomBox-SideStore-unsigned.ipa")!
assertEqual(BloomBoxAutoUpdatePolicy.installURL(for: asset)?.scheme, "sidestore", "deeplink scheme")
assertEqual(BloomBoxAutoUpdatePolicy.installURL(for: URL(string:"http://evil.example/ipa")!), nil, "untrusted host")
print("BloomBox AutoUpdate policy tests passed")
