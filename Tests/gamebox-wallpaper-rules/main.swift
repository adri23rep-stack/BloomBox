import Foundation

func encode(_ value: [String: Any]) -> Data {
    try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
}
func entry(_ id: String, _ bundles: [String], _ words: [String],
           _ provider: String, _ topic: String) -> [String: Any] {
    [
        "id": id, "bundleIDs": bundles, "keywords": words,
        "provider": provider, "query": topic, "note": "User-reviewed identification."
    ]
}
let valid: [String: Any] = [
    "schemaVersion": 1,
    "catalogID": "bloombox.gamebox.wallpaper-rules",
    "updatedAt": "2026-11-05",
    "rules": [
        entry("melonnx-switch", [], ["MeloNX", "MelonNX"], "wikipedia", "Nintendo Switch"),
        entry("dolphinios-gamecube", ["me.oatmealdome.DolphiniOS-njb-patreon-beta"],
              ["DolphiniOS"], "wikipedia", "Nintendo GameCube"),
        entry("delta-ds", [], ["Delta"], "wikipedia", "Nintendo DS"),
        entry("rdr-port", [], ["RDR - IOSVIZOR.COM"], "steam", "Red Dead Redemption")
    ]
]
guard let index = BloomBoxWallpaperRuleIndex.validated(from: encode(valid)) else {
    fatalError("Valid catalog rejected")
}
assert(index.rule(bundleID: "me.oatmealdome.DolphiniOS-njb-patreon-beta",
                  name: "Other Name")?.query == "Nintendo GameCube")
assert(index.rule(bundleID: nil, name: "mElOnNX")?.query == "Nintendo Switch")
assert(index.rule(bundleID: nil, name: "MelonNX 2.6")?.query == "Nintendo Switch")
assert(index.rule(bundleID: nil, name: "MelonNX Copycat") == nil)
assert(index.rule(bundleID: nil, name: "DolphiniOS Public Beta")?.query == "Nintendo GameCube")
assert(index.rule(bundleID: nil, name: "Delta Force") == nil)
assert(index.rule(bundleID: nil, name: "RDR - IOSVIZOR.COM")?.query == "Red Dead Redemption")
assert(index.rule(bundleID: "com.unknown.app", name: "Unknown") == nil)
func expectReject(_ mutate: (inout [String: Any]) -> Void) {
    var bad = valid
    mutate(&bad)
    assert(BloomBoxWallpaperRuleIndex.validated(from: encode(bad)) == nil)
}
expectReject { $0["unknownAction"] = "execute" }
expectReject { $0["schemaVersion"] = 7 }
expectReject { $0["catalogID"] = "untrusted.catalog" }
expectReject { root in
    var list = root["rules"] as! [[String: Any]]
    list[0]["imageURL"] = "https://example.com/spy.jpg"
    root["rules"] = list
}
expectReject { root in
    var list = root["rules"] as! [[String: Any]]
    list[0]["provider"] = "arbitraryURL"
    root["rules"] = list
}
expectReject { root in
    var list = root["rules"] as! [[String: Any]]
    list[0]["query"] = "https://example.com/unknown"
    root["rules"] = list
}
expectReject { root in
    var list = root["rules"] as! [[String: Any]]
    list[0]["keywords"] = ["Delta"]
    root["rules"] = list
}
expectReject { root in
    var list = root["rules"] as! [[String: Any]]
    list[0]["bundleIDs"] = ["me.oatmealdome.DolphiniOS-njb-patreon-beta"]
    root["rules"] = list
}
print("PASS: wallpaper rule schema, exact bundle > alias, unrelated title rejection, forbidden fields and duplicate safeguards")
