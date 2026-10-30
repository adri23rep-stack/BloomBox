import Foundation
let now = Date()
let key = BloomBoxRAMValidation.entitlement
let profile: [String: Any] = ["Entitlements": [key: true, "application-identifier": "TEAM.com.example"], "CreationDate": now.addingTimeInterval(-100), "ExpirationDate": now.addingTimeInterval(100)]
func check(_ runtime: Bool?, _ p: [String: Any]? = profile, _ id: String? = "TEAM.com.example") -> Bool {
    BloomBoxRAMValidation.inspect(runtime: runtime, profile: p, applicationIdentifier: id, now: now).confirmed
}
assert(check(true))
assert(!check(false))
assert(!check(nil))
assert(!check(true, nil))
assert(!check(true, profile, "OTHER.com.example"))
var expired = profile; expired["ExpirationDate"] = now.addingTimeInterval(-1)
assert(!check(true, expired))
var future = profile; future["CreationDate"] = now.addingTimeInterval(1)
assert(!check(true, future))
var missing = profile; missing["Entitlements"] = ["application-identifier": "TEAM.com.example"]
assert(!check(true, missing))
assert(BloomBoxRAMValidation.boolean("true") == nil)
assert(BloomBoxRAMValidation.boolean(1) == nil)
assert(BloomBoxRAMValidation.boolean(true) == true)
assert(BloomBoxRAMValidation.profile(from: Data("broken".utf8)) == nil)
let xml = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
let wrapped = Data([0x30, 0x80, 0xff]) + xml + Data([0, 0])
assert(check(true, BloomBoxRAMValidation.profile(from: wrapped)))
print("RAM+ validation: 13 cases passed")
