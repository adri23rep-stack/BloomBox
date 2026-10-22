import Foundation
import CryptoKit

/// Validates the remote-pairing format consumed by the bundled idevice engine.
enum StrataPairingRecord {
    static func validate(_ data: Data) throws {
        guard data.count < 2_000_000,
              let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let publicKey = plist["public_key"] as? Data, publicKey.count == 32,
              let privateKey = plist["private_key"] as? Data, privateKey.count == 32,
              let identifier = plist["identifier"] as? String, !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: privateKey),
              key.publicKey.rawRepresentation == publicKey else {
            throw NSError(domain: "StrataJIT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Choose a valid remote pairing file. A classic USB pairing file needs to be replaced with a remote pairing file."])
        }
    }
}
