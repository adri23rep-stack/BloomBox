import Foundation
let portal = BloomBoxRAMPortal.self
assert(portal.isListRequest(URL(string: "https://developerservices2.apple.com/services/QH65B2/ios/listAppIds.action?clientId=test")))
for url in ["http://developerservices2.apple.com/services/QH65B2/ios/listAppIds.action", "https://developerservices2.apple.com.evil.test/services/QH65B2/ios/listAppIds.action", "https://developerservices2.apple.com/services/QH65B2/listTeams.action", "https://developerservices2.apple.com:444/services/QH65B2/ios/listAppIds.action"] { assert(!portal.isListRequest(URL(string: url))) }
let body = try PropertyListSerialization.data(fromPropertyList: ["teamId": "TEAM"], format: .xml, options: 0)
assert(portal.matchesTeam(body: body, team: "TEAM"))
assert(!portal.matchesTeam(body: body, team: "OTHER"))
assert(!portal.matchesTeam(body: nil, team: "TEAM"))
let list: [String: Any] = ["resultCode": 0, "appIds": [["appIdId": "ABC123", "identifier": "app.bloom"]]]
let matched = try portal.appID(in: list, bundle: "app.bloom"); assert(matched == "ABC123")
let missing = try portal.appID(in: list, bundle: "other"); assert(missing == nil)
assert(!portal.validID("../other"))
func cap(_ name: String, enabled: Bool) -> [String: Any] {
    ["id": "ABC123_" + name, "type": "bundleIdCapabilities", "attributes": ["enabled": enabled, "settings": [["key": "retain", "options": ["keep"]]]], "relationships": ["capability": ["data": ["type": "capabilities", "id": name]], "appGroups": ["data": [["type": "appGroups", "id": "KEEP"]]]]]
}
let existing = cap("APP_GROUPS", enabled: true)
func fixture(_ caps: [[String: Any]]) -> [String: Any] {
    ["data": ["id": "ABC123", "type": "bundleIds", "attributes": ["identifier": "app.bloom", "name": "Bloom", "teamId": "TEAM"], "relationships": ["bundleIdCapabilities": ["data": caps.map { ["id": $0["id"]!, "type": "bundleIdCapabilities"] }]]], "included": caps]
}
func snapshot(_ response: [String: Any]) throws -> BloomBoxRAMPortal.Snapshot { try portal.snapshot(response, id: "ABC123", bundle: "app.bloom", team: "TEAM") }
let before = try snapshot(fixture([existing]))
assert(!before.enabled)
let payload = portal.payload(before, id: "ABC123", bundle: "app.bloom", team: "TEAM")
let resource = payload["data"] as! [String: Any]
let relation = (resource["relationships"] as! [String: Any])["bundleIdCapabilities"] as! [String: Any]
let changed = relation["data"] as! [[String: Any]]
assert(changed.count == 2)
assert(NSDictionary(dictionary: changed[0]).isEqual(to: existing))
let approved = try snapshot(fixture([existing, cap(portal.capability, enabled: true)])); assert(approved.enabled)
let refused = try snapshot(fixture([existing, cap(portal.capability, enabled: false)])); assert(!refused.enabled)
let disabled = try snapshot(fixture([existing, cap(portal.capability, enabled: false)]))
let enabledPayload = portal.payload(disabled, id: "ABC123", bundle: "app.bloom", team: "TEAM")
let enabledData = enabledPayload["data"] as! [String: Any]
let enabledRelation = (enabledData["relationships"] as! [String: Any])["bundleIdCapabilities"] as! [String: Any]
assert((enabledRelation["data"] as! [[String: Any]]).count == 2)
var incomplete = fixture([existing]); incomplete["included"] = []
do { _ = try snapshot(incomplete); fatalError("Accepted incomplete capability list") } catch { }
do { _ = try portal.snapshot(fixture([existing]), id: "ABC123", bundle: "other.app", team: "TEAM"); fatalError("Accepted another app") } catch { }
do { _ = try portal.snapshot(fixture([existing]), id: "ABC123", bundle: "app.bloom", team: "OTHER"); fatalError("Accepted another team") } catch { }
var errors = fixture([existing]); errors["errors"] = [["status": "403"]]
do { _ = try snapshot(errors); fatalError("Accepted server error") } catch { }
print("RAM+ portal: scoping, exact App ID, team match, permission preservation and readback cases passed")
