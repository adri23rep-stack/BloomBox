import Foundation

/// A requested preference is never evidence of an entitlement being granted.
struct BloomBoxRAMValidation {
    static let entitlement = "com.apple.developer.kernel.increased-memory-limit"
    let runtimeGranted: Bool?
    let profileGranted: Bool?
    let profileCurrent: Bool
    let profileMatches: Bool

    var confirmed: Bool {
        runtimeGranted == true && profileGranted == true && profileCurrent && profileMatches
    }

    static func boolean(_ value: Any?) -> Bool? {
        // A string "true" or an integer must not masquerade as a signed boolean.
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    static func profile(from data: Data) -> [String: Any]? {
        // Extract only the plist payload; this does not authenticate a CMS signature.
        // The OS entitlement check is independently required for confirmation.
        guard data.count <= 4 * 1024 * 1024,
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                from: data.subdata(in: start.lowerBound..<end.upperBound), options: [], format: nil)
                as? [String: Any] else { return nil }
        return plist
    }

    static func inspect(runtime: Bool?, profile: [String: Any]?, applicationIdentifier: String?, now: Date = Date()) -> Self {
        let entitlements = profile?["Entitlements"] as? [String: Any]
        let expiration = profile?["ExpirationDate"] as? Date
        let creation = profile?["CreationDate"] as? Date
        let current = expiration.map { $0 > now } == true && creation.map { $0 <= now } == true
        let profileID = entitlements?["application-identifier"] as? String
        // Deliberately reject wildcard profiles rather than infer their entitlement scope.
        let matches = applicationIdentifier != nil && applicationIdentifier == profileID
        return Self(runtimeGranted: runtime,
                    profileGranted: boolean(entitlements?[entitlement]),
                    profileCurrent: current, profileMatches: matches)
    }
}

import CoreFoundation
