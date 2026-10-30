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
let confirmedZeroSnapshot = try snapshot(zeroTotal)
assert(zeroSnapshot.sameCapabilities(as: confirmedZeroSnapshot))
let changedSnapshot = try snapshot(fixture([cap("APP_GROUPS", enabled: false)]))
assert(!zeroSnapshot.sameCapabilities(as: changedSnapshot))
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
let originalOrder = try snapshot(fixture([existing, cap(portal.capability, enabled: true)]))
assert(reordered.sameCapabilities(as: originalOrder))
assert(reordered.preservesUnrelatedCapabilities(from: priorWithRAM))
let lostUnrelated = try snapshot(fixture([cap(portal.capability, enabled: true)]))
assert(!lostUnrelated.preservesUnrelatedCapabilities(from: priorWithRAM))
let mutatedUnrelated = try snapshot(fixture([cap("APP_GROUPS", enabled: false), cap(portal.capability, enabled: true)]))
assert(!mutatedUnrelated.preservesUnrelatedCapabilities(from: priorWithRAM))
print("RAM+ portal: scoping, exact App ID, team match, permission preservation and readback cases passed")

// Equivalent grants may arrive with different relationship URLs, paging
// metadata, and order. Those changes must not block the zero-total reread.
var linkedA = existing
var relationsA = linkedA["relationships"] as! [String: Any]
relationsA["appGroups"] = ["data": [["type": "appGroups", "id": "KEEP"], ["type": "appGroups", "id": "SECOND"]], "links": ["related": "https://example.test/a"], "meta": ["paging": ["total": 0]]]
linkedA["relationships"] = relationsA
var linkedB = linkedA
var relationsB = relationsA
relationsB["appGroups"] = ["data": [["type": "appGroups", "id": "SECOND"], ["type": "appGroups", "id": "KEEP"]], "links": ["related": "https://example.test/b"], "meta": ["paging": ["total": 2]]]
linkedB["relationships"] = relationsB
let stableA = try snapshot(fixture([linkedA]))
let stableB = try snapshot(fixture([linkedB]))
assert(stableA.sameCapabilities(as: stableB))
assert(stableB.preservesUnrelatedCapabilities(from: stableA))
var changedLink = linkedB
relationsB["appGroups"] = ["data": [["type": "appGroups", "id": "OTHER"]]]
changedLink["relationships"] = relationsB
let changedLinkSnapshot = try snapshot(fixture([changedLink]))
assert(!stableA.sameCapabilities(as: changedLinkSnapshot))
assert(!changedLinkSnapshot.preservesUnrelatedCapabilities(from: stableA))
var changedSettings = linkedB
var changedAttributes = changedSettings["attributes"] as! [String: Any]
changedAttributes["settings"] = []
changedSettings["attributes"] = changedAttributes
let changedSettingsSnapshot = try snapshot(fixture([changedSettings]))
assert(!stableA.sameCapabilities(as: changedSettingsSnapshot))
print("RAM+ relationship comparison regressions passed")

// Use actual JSON-decoded Foundation objects, not only Swift literals.
func decoded(_ value: [String: Any]) throws -> [String: Any] {
    let bytes = try JSONSerialization.data(withJSONObject: value)
    return try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
}
var nullable = linkedA
var nullableAttrs = nullable["attributes"] as! [String: Any]
nullableAttrs["optional"] = NSNull()
nullable["attributes"] = nullableAttrs
let decodedA = try snapshot(decoded(fixture([nullable])))
let decodedB = try snapshot(decoded(fixture([nullable])))
assert(decodedA.sameCapabilities(as: decodedB))
let decodedOrderA = try snapshot(decoded(fixture([linkedA])))
let decodedOrderB = try snapshot(decoded(fixture([linkedB])))
assert(decodedOrderA.sameCapabilities(as: decodedOrderB))
assert(stableA.differenceSummary(as: changedSettingsSnapshot) == "permiso 1: configuración settings")
assert(stableA.differenceSummary(as: changedLinkSnapshot) == "permiso 1: relación appGroups")
var changedID = existing
changedID["id"] = "PRIVATE_VALUE_MUST_NOT_APPEAR"
let changedIDSnapshot = try snapshot(fixture([changedID]))
assert(before.differenceSummary(as: changedIDSnapshot) == "identificador del registro 1")
assert(before.differenceSummary(as: approved) == "cantidad de permisos: 1 → 2")
assert(before.differenceSummary(as: changedSnapshot) == "permiso 1: estado enabled")
assert(before.differenceSummary(as: before) == nil)
print("RAM+ JSON decoding and redacted diagnostics passed")

// Device RP3 regression: enabled/settings match, but another response
// attribute changes. Server-owned attributes are not capability edit inputs.
var responseA = existing
var responseB = existing
var attrsA = responseA["attributes"] as! [String: Any]
var attrsB = responseB["attributes"] as! [String: Any]
attrsA["serverMetadata"] = ["timestamp": "first", "value": 1]
attrsB["serverMetadata"] = ["timestamp": "second", "value": 2]
attrsB["additionalResponseField"] = NSNull()
responseA["attributes"] = attrsA
responseB["attributes"] = attrsB
let stateA = try snapshot(decoded(fixture([responseA])))
let stateB = try snapshot(decoded(fixture([responseB])))
assert(stateA.sameCapabilities(as: stateB))
assert(stateB.preservesUnrelatedCapabilities(from: stateA))
let projected = portal.payload(stateB, id: "ABC123", bundle: "app.bloom", team: "TEAM")
let projectedData = projected["data"] as! [String: Any]
let projectedRelations = projectedData["relationships"] as! [String: Any]
let projectedCaps = (projectedRelations["bundleIdCapabilities"] as! [String: Any])["data"] as! [[String: Any]]
let preserved = projectedCaps[0]
let preservedAttributes = preserved["attributes"] as! [String: Any]
assert(Set(preservedAttributes.keys) == Set(["enabled", "settings"]))
assert(NSDictionary(dictionary: preservedAttributes).isEqual(to: existing["attributes"] as! [String: Any]))
assert(NSDictionary(dictionary: preserved["relationships"] as! [String: Any]).isEqual(to: existing["relationships"] as! [String: Any]))
attrsB["enabled"] = false
responseB["attributes"] = attrsB
let realStateChange = try snapshot(decoded(fixture([responseB])))
assert(!stateA.sameCapabilities(as: realStateChange))
assert(!realStateChange.preservesUnrelatedCapabilities(from: stateA))
attrsB["enabled"] = true
attrsB["settings"] = []
responseB["attributes"] = attrsB
let realSettingsChange = try snapshot(decoded(fixture([responseB])))
assert(!stateA.sameCapabilities(as: realSettingsChange))
assert(!realSettingsChange.preservesUnrelatedCapabilities(from: stateA))
print("RAM+ RP4: response-only attributes ignored; enabled, settings and relationships preserved")
