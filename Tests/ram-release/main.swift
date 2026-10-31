import Foundation

let validDigest = "a" + String(repeating: "b", count: 63)
func fixture(tag: String = "v1.3.0", assetName: String = BloomBoxRAMRelease.assetName,
             digest: String? = nil, publishedSize: Int = 52335943,
             location: String? = nil, draft: Bool = false, prerelease: Bool = false) -> Data {
    let value: [String: Any] = [
        "tag_name": tag,
        "draft": draft,
        "prerelease": prerelease,
        "target_commitish": "4c1fb19c1a28c4c3f493d7081a9d1cc418432504",
        "assets": [
            ["name": assetName, "digest": digest ?? "sha256:" + validDigest,
             "size": publishedSize,
             "browser_download_url": location ?? "https://github.com/adri23rep-stack/BloomBox/releases/download/\(tag)/\(assetName)"]
        ]
    ]
    return try! JSONSerialization.data(withJSONObject: value)
}
func rejects(_ json: Data) -> Bool {
    do { _ = try BloomBoxRAMRelease.select(json: json); return false }
    catch { return true }
}

let found = try BloomBoxRAMRelease.select(json: fixture())
precondition(found.tag == "v1.3.0")
precondition(found.digest == validDigest)
precondition(found.size == 52335943)
precondition(found.url.host == "github.com")
precondition(found.commitish?.count == 40)

// Root cause: BloomBox's upstream internal app version is 3.8.10,
// whereas its GitHub public latest release tag is v1.3.0.
// The selector must not use the internal version to find the release.
let upstreamVersion = "3.8.10"
precondition(found.tag != "v" + upstreamVersion)

precondition(rejects(fixture(tag: "v1.4.0-rc1")))
precondition(rejects(fixture(draft: true)))
precondition(rejects(fixture(prerelease: true)))
precondition(rejects(fixture(digest: "sha256:tampered")))
precondition(rejects(fixture(digest: "sha256:" + String(repeating: "g", count: 64))))
precondition(rejects(fixture(publishedSize: 0)))
precondition(rejects(fixture(publishedSize: 1024 * 1024 * 1024)))
precondition(rejects(fixture(location: "https://evil.example/BloomBox-SideStore-unsigned.ipa")))
precondition(rejects(fixture(location: "http://github.com/adri23rep-stack/BloomBox/releases/download/v1.3.0/BloomBox-SideStore-unsigned.ipa")))
precondition(rejects(fixture(location: "https://github.com/adri23rep-stack/BloomBox/releases/download/v1.2.0/BloomBox-SideStore-unsigned.ipa")))
precondition(rejects(fixture(location: "https://github.com/adri23rep-stack/BloomBox/releases/download/v1.3.0/BloomBox-SideStore-unsigned.ipa?token=bad")))
precondition(rejects(fixture(assetName: "A-different-unsigned.ipa")))
precondition(rejects(Data("[]".utf8)))
precondition(rejects(Data("{}".utf8)))
precondition(rejects(Data("not-json".utf8)))

precondition(BloomBoxRAMRelease.compatibleIdentity(installed: "com.kdt.livecontainer", sourceBundle: "com.kdt.livecontainer"))
precondition(BloomBoxRAMRelease.compatibleIdentity(installed: "com.kdt.livecontainer.T449", sourceBundle: "com.kdt.livecontainer"))
precondition(!BloomBoxRAMRelease.compatibleIdentity(installed: "com.kdt.livecontainer.fake", sourceBundle: "com.kdt.livecontainerX"))
precondition(!BloomBoxRAMRelease.compatibleIdentity(installed: "com.evil", sourceBundle: "com.kdt.livecontainer"))

let core: Set<String> = ["LiveProcess.appex", "LiveWidgetExtension.appex"]
precondition(BloomBoxRAMRelease.preservesExtensions(installed: core, candidate: core.union(["NewExtension.appex"])))
precondition(!BloomBoxRAMRelease.preservesExtensions(installed: core, candidate: ["LiveProcess.appex"]))
precondition(!BloomBoxRAMRelease.preservesExtensions(installed: core, candidate: []))

// Signed ALTAppGroups may be rewritten by SideStore and must not be
// compared to the unsigned release's placeholder groups.
print("PASS: latest stable GitHub release validation, SHA/URL guard, identity and preserved extensions.")
