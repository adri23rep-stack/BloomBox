import Foundation
import CryptoKit
let key = Curve25519.Signing.PrivateKey()
let valid: [String: Any] = ["public_key": key.publicKey.rawRepresentation, "private_key": key.rawRepresentation, "identifier": UUID().uuidString]
for format in [PropertyListSerialization.PropertyListFormat.xml, .binary] {
    try BloomBoxRemotePairingRecord.validate(PropertyListSerialization.data(fromPropertyList: valid, format: format, options: 0))
}
func reject(_ value: [String: Any]) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    do { try BloomBoxRemotePairingRecord.validate(data); fatalError("Accepted invalid pairing") } catch {}
}
var invalid = valid; invalid["public_key"] = Data(repeating: 0, count: 32); try reject(invalid)
invalid = valid; invalid["identifier"] = " "; try reject(invalid)
invalid = valid; invalid.removeValue(forKey: "private_key"); try reject(invalid)
try reject(["HostID": "classic", "SystemBUID": "classic"])
do { try BloomBoxRemotePairingRecord.validate(Data(repeating: 1, count: 2_000_001)); fatalError("Accepted oversized data") } catch {}
print("PASS: XML/binary remote pairing; reject mismatched keys, missing keys, empty identity, classic format and oversized input.")


// Reuse previous pairing data, keep user credentials private, and prevent re-import after deletion.
let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("BloomBoxPairing-" + UUID().uuidString)
defer { try? FileManager.default.removeItem(at: tempRoot) }
let storage = BloomBoxJITPairingStorage(documentsDirectory: tempRoot)
try FileManager.default.createDirectory(at: storage.legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
let original = try PropertyListSerialization.data(fromPropertyList: valid, format: .binary, options: 0)
try original.write(to: storage.legacyURL)
precondition(storage.hasRecord)
precondition(try storage.load() == original)
precondition(FileManager.default.fileExists(atPath: storage.pairingURL.path))
try storage.remove()
precondition(!storage.hasRecord)
do { _ = try storage.load(); fatalError("Reused deleted pairing credentials") }
catch BloomBoxRemotePairingRecord.PairingError.missing { }
print("PASS: legacy pairing migration preserves bytes and deleting a pairing removes both records.")
