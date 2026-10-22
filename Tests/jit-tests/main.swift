import Foundation
import CryptoKit
let key = Curve25519.Signing.PrivateKey()
let valid: [String: Any] = ["public_key": key.publicKey.rawRepresentation, "private_key": key.rawRepresentation, "identifier": UUID().uuidString]
for format in [PropertyListSerialization.PropertyListFormat.xml, .binary] {
    try StrataPairingRecord.validate(PropertyListSerialization.data(fromPropertyList: valid, format: format, options: 0))
}
func reject(_ value: [String: Any]) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    do { try StrataPairingRecord.validate(data); fatalError("Accepted invalid pairing") } catch {}
}
var invalid = valid; invalid["public_key"] = Data(repeating: 0, count: 32); try reject(invalid)
invalid = valid; invalid["identifier"] = " "; try reject(invalid)
invalid = valid; invalid.removeValue(forKey: "private_key"); try reject(invalid)
try reject(["HostID": "classic", "SystemBUID": "classic"])
do { try StrataPairingRecord.validate(Data(repeating: 1, count: 2_000_001)); fatalError("Accepted oversized data") } catch {}
print("PASS: XML/binary remote pairing; reject mismatched keys, missing keys, empty identity, classic format and oversized input.")
