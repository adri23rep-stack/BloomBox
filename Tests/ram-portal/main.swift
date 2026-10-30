import Foundation
let portal = BloomBoxRAMPortal.self
assert(portal.isListRequest(URL(string: "https://developerservices2.apple.com/services/QH65B2/ios/listAppIds.action?clientId=test")))
for url in ["http://developerservices2.apple.com/services/QH65B2/ios/listAppIds.action", "https://developerservices2.apple.com.evil.test/services/QH65B2/ios/listAppIds.action", "https://developerservices2.apple.com/services/QH65B2/listTeams.action", "https://developerservices2.apple.com:444/services/QH65B2/ios/listAppIds.action"] { assert(!portal.isListRequest(URL(string: url))) }
let body = try PropertyListSerialization.data(fromPropertyList: ["teamId": "TEAM"], format: .xml, options: 0)
assert(portal.matchesTeam(body: body, team: "TEAM"))
assert(!portal.matchesTeam(body: body, team: "OTHER"))
assert(!portal.matchesTeam(body: nil, team: "TEAM"))
let readBody = try portal.readParameters(team: "TEAM")
let readJSON = try JSONSerialization.jsonObject(with: readBody) as! [String: String]
assert(readJSON.count == 1) // No unexpected top-level credentials or team fields.
assert(readJSON["urlEncodedQueryParams"]?.contains("teamId=TEAM") == true)
assert(readJSON["urlEncodedQueryParams"]?.contains("bundleIdCapabilities") == true)
assert(readJSON["urlEncodedQueryParams"]?.contains("limit%5BbundleIdCapabilities%5D=200") == true || readJSON["urlEncodedQueryParams"]?.contains("limit[bundleIdCapabilities]=200") == true)
do { _ = try portal.readParameters(team: ""); fatalError("Accepted empty team") } catch { }
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

var oversized = fixture(Array(0..<60).map { cap("EXISTING_\($0)", enabled: true) })
let oversizedCaps = try snapshot(oversized)
assert(oversizedCaps.capabilities.count == 60)
var paged = fixture([existing])
var pagedResource = paged["data"] as! [String: Any]
var pagedRelations = pagedResource["relationships"] as! [String: Any]
var pagedCapabilities = pagedRelations["bundleIdCapabilities"] as! [String: Any]
pagedCapabilities["meta"] = ["paging": ["total": 2]]
pagedRelations["bundleIdCapabilities"] = pagedCapabilities
pagedResource["relationships"] = pagedRelations
paged["data"] = pagedResource
do { _ = try snapshot(paged); fatalError("Accepted partial capability page") } catch let failure as BloomBoxRAMPortal.Failure {
    assert(failure.message.contains("1 permisos"))
    assert(failure.message.contains("2 en total"))
}
pagedCapabilities["meta"] = ["paging": ["total": 1]]
pagedCapabilities["links"] = ["next": "https://developerservices2.apple.com/next"]
pagedRelations["bundleIdCapabilities"] = pagedCapabilities
pagedResource["relationships"] = pagedRelations
paged["data"] = pagedResource
do { _ = try snapshot(paged); fatalError("Accepted next-page link") } catch let failure as BloomBoxRAMPortal.Failure {
    assert(failure.message.contains("más páginas"))
}
var incomplete = fixture([existing]); incomplete["included"] = []
do { _ = try snapshot(incomplete); fatalError("Accepted incomplete capability list") } catch { }
do { _ = try portal.snapshot(fixture([existing]), id: "ABC123", bundle: "other.app", team: "TEAM"); fatalError("Accepted another app") } catch { }
do { _ = try portal.snapshot(fixture([existing]), id: "ABC123", bundle: "app.bloom", team: "OTHER"); fatalError("Accepted another team") } catch { }
var errors = fixture([existing]); errors["errors"] = [["status": "403"]]
do { _ = try snapshot(errors); fatalError("Accepted server error") } catch { }

// Apple v1 may acknowledge a successful capability PATCH with zero response bytes.
// It still requires an independent, complete readback before activation is claimed.
let emptyPatch = try portal.validatedResponse(Data(), statusCode: 204, method: "PATCH")
assert(emptyPatch.isEmpty)
let jsonPatch = try portal.validatedResponse(Data("{}".utf8), statusCode: 200, method: "PATCH")
assert(jsonPatch.isEmpty)
do { _ = try portal.validatedResponse(Data(), statusCode: 204, method: "POST"); fatalError("Accepted empty readback") } catch { }
do { _ = try portal.validatedResponse(Data(), statusCode: 403, method: "PATCH"); fatalError("Accepted rejection") } catch { }
let serverErrors = try JSONSerialization.data(withJSONObject: ["errors": [["status": "409"]]])
do { _ = try portal.validatedResponse(serverErrors, statusCode: 200, method: "PATCH"); fatalError("Accepted Apple errors") } catch { }

// Device regression: Apple returned one capability but meta.paging.total=0.
// Accept its validated entry only when no more pages exist, and require a
// second identical read before the caller can submit a PATCH.
var zeroTotal = fixture([existing])
var zeroResource = zeroTotal["data"] as! [String: Any]
var zeroRelations = zeroResource["relationships"] as! [String: Any]
var zeroCapabilities = zeroRelations["bundleIdCapabilities"] as! [String: Any]
zeroCapabilities["meta"] = ["paging": ["total": 0]]
zeroRelations["bundleIdCapabilities"] = zeroCapabilities
zeroResource["relationships"] = zeroRelations
zeroTotal["data"] = zeroResource
let zeroSnapshot = try snapshot(zeroTotal)
assert(zeroSnapshot.capabilities.count == 1 && zeroSnapshot.needsStableRead)
assert(zeroSnapshot.sameCapabilities(as: try snapshot(zeroTotal)))
assert(!zeroSnapshot.sameCapabilities(as: try snapshot(fixture([cap("APP_GROUPS", enabled: false)]))))
var zeroWithNext = zeroTotal
var zeroNextResource = zeroResource
var zeroNextRelations = zeroRelations
var zeroNextCaps = zeroCapabilities
zeroNextCaps["links"] = ["next": "https://developerservices2.apple.com/more"]
zeroNextRelations["bundleIdCapabilities"] = zeroNextCaps
zeroNextResource["relationships"] = zeroNextRelations
zeroWithNext["data"] = zeroNextResource
do { _ = try snapshot(zeroWithNext); fatalError("Accepted a zero-total paginated page") } catch let failure as BloomBoxRAMPortal.Failure {
    assert(failure.message.contains("más páginas"))
}
var fullZero = fixture((0..<200).map { cap("EXISTING_\($0)", enabled: true) })
var fullResource = fullZero["data"] as! [String: Any]
var fullRelations = fullResource["relationships"] as! [String: Any]
var fullCaps = fullRelations["bundleIdCapabilities"] as! [String: Any]
fullCaps["meta"] = ["paging": ["total": 0]]
fullRelations["bundleIdCapabilities"] = fullCaps
fullResource["relationships"] = fullRelations
fullZero["data"] = fullResource
do { _ = try snapshot(fullZero); fatalError("Accepted a full page with untrusted count") } catch is BloomBoxRAMPortal.Failure { }
let reordered = try snapshot(fixture([cap(portal.capability, enabled: true), existing]))
let priorWithRAM = try snapshot(fixture([existing, cap(portal.capability, enabled: false)]))
assert(reordered.sameCapabilities(as: try snapshot(fixture([existing, cap(portal.capability, enabled: true)]))))
assert(reordered.preservesUnrelatedCapabilities(from: priorWithRAM))
let lostUnrelated = try snapshot(fixture([cap(portal.capability, enabled: true)]))
assert(!lostUnrelated.preservesUnrelatedCapabilities(from: priorWithRAM))
let mutatedUnrelated = try snapshot(fixture([cap("APP_GROUPS", enabled: false), cap(portal.capability, enabled: true)]))
assert(!mutatedUnrelated.preservesUnrelatedCapabilities(from: priorWithRAM))
print("RAM+ portal: scoping, exact App ID, team match, permission preservation and readback cases passed")
