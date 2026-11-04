import Foundation
import CryptoKit

/// BloomBox's remote pairing validation. No private keys are logged or uploaded.
enum BloomBoxRemotePairingRecord {
    static let maximumBytes = 2_000_000

    enum PairingError: LocalizedError {
        case invalid
        case missing

        var errorDescription: String? {
            switch self {
            case .invalid:
                return "Choose a valid remote pairing file. A classic USB pairing file cannot be used for on-device JIT."
            case .missing:
                return "Import a remote pairing file in BloomBox JIT setup first."
            }
        }
    }

    static func validate(_ data: Data) throws {
        guard !data.isEmpty, data.count < maximumBytes,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let publicKey = plist["public_key"] as? Data, publicKey.count == 32,
              let privateKey = plist["private_key"] as? Data, privateKey.count == 32,
              let identifier = plist["identifier"] as? String,
              !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              identifier.count <= 256,
              let signingKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: privateKey),
              signingKey.publicKey.rawRepresentation == publicKey else {
            throw PairingError.invalid
        }
    }
}

/// Migrates pairing data from the previous launcher directory without losing it on updates.
/// The legacy file is retained for rollback; Remove pairing file deletes both copies.
struct BloomBoxJITPairingStorage {
    let documentsDirectory: URL

    init(documentsDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.documentsDirectory = documentsDirectory
    }

    var pairingURL: URL {
        documentsDirectory.appendingPathComponent("BloomBoxJIT/pairingFile.plist")
    }

    var legacyURL: URL {
        documentsDirectory.appendingPathComponent("StrataJIT/pairingFile.plist")
    }

    var hasRecord: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: pairingURL.path) || fm.fileExists(atPath: legacyURL.path)
    }

    func save(_ data: Data) throws {
        try BloomBoxRemotePairingRecord.validate(data)
        try FileManager.default.createDirectory(at: pairingURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: pairingURL, options: [.atomic, .completeFileProtection])
    }

    func load() throws -> Data {
        let fm = FileManager.default
        let source: URL
        if fm.fileExists(atPath: pairingURL.path) {
            source = pairingURL
        } else if fm.fileExists(atPath: legacyURL.path) {
            source = legacyURL
        } else {
            throw BloomBoxRemotePairingRecord.PairingError.missing
        }
        let data = try Data(contentsOf: source)
        try BloomBoxRemotePairingRecord.validate(data)
        if source == legacyURL { try save(data) }
        return data
    }

    func remove() throws {
        let fm = FileManager.default
        for file in [pairingURL, legacyURL] where fm.fileExists(atPath: file.path) {
            try fm.removeItem(at: file)
        }
    }
}
