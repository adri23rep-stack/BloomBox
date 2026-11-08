import Foundation

/// BloomBox release versions are independent of LiveContainer's 3.8.x bundle version.
/// Only an explicitly stamped, stable app is eligible for unattended replacement.
enum BloomBoxAutoUpdatePolicy {
    enum Decision: Equatable {
        case none
        case offerOnly
        case eligible
    }

    static func components(_ tag: String) -> [Int]? {
        guard tag.range(of: #"^v[0-9]+\.[0-9]+\.[0-9]+$"#,
                        options: .regularExpression) != nil else { return nil }
        let numbers = tag.dropFirst().split(separator: ".").compactMap { Int($0) }
        guard numbers.count == 3, numbers.allSatisfy({ $0 >= 0 && $0 < 100_000 }) else { return nil }
        return numbers
    }

    static func compare(_ lhs: String, _ rhs: String) -> Int? {
        guard let a = components(lhs), let b = components(rhs) else { return nil }
        for i in 0..<3 {
            if a[i] < b[i] { return -1 }
            if a[i] > b[i] { return 1 }
        }
        return 0
    }

    static func decision(installedTag: String?, availableTag: String) -> Decision {
        guard components(availableTag) != nil else { return .none }
        guard let installedTag, let comparison = compare(installedTag, availableTag) else {
            // Legacy / development builds lack trustworthy BloomBox release metadata.
            return .offerOnly
        }
        return comparison < 0 ? .eligible : .none
    }

    static func shouldAutomaticallyInstall(decision: Decision, automatic: Bool,
                                           alreadyAttempted: Bool) -> Bool {
        decision == .eligible && automatic && !alreadyAttempted
    }

    static let source = "https://api.github.com/repos/adri23rep-stack/BloomBox/releases/latest"
    static let installerScheme = "sidestore"

    static func installURL(for assetURL: URL) -> URL? {
        guard assetURL.scheme == "https", assetURL.host == "github.com",
              assetURL.user == nil, assetURL.password == nil, assetURL.port == nil else { return nil }
        var components = URLComponents()
        components.scheme = installerScheme
        components.host = "install"
        components.queryItems = [URLQueryItem(name: "url", value: assetURL.absoluteString)]
        return components.url
    }
}
