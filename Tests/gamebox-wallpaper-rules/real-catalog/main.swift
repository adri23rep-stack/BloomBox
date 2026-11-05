import Foundation

guard CommandLine.arguments.count >= 2,
      let data = FileManager.default.contents(atPath: CommandLine.arguments[1]),
      let catalog = BloomBoxWallpaperRuleIndex.validated(from: data) else {
    fatalError("Actual GameBox wallpaper catalog failed full-file validation")
}
assert(catalog.rules.count >= 13)
let direct = catalog.rules.filter { $0.vettedArtworkURL != nil }
assert(direct.count >= 7, "Expected at least seven curated direct wallpapers")
let required: [(String, String)] = [
    ("MeloNX", "Nintendo Switch"),
    ("MelonNX 2.6", "Nintendo Switch"),
    ("LemoNX", "Nintendo Switch"),
    ("DolphiniOS", "Nintendo GameCube"),
    ("MeloCafe", "Wii U"),
    ("Vita3KiOS", "PlayStation Vita"),
    ("PPSSPP", "PlayStation Portable"),
    ("Husk", "Android (operating system)")
]
for (name, topic) in required {
    guard let rule = catalog.rule(bundleID: nil, name: name),
          rule.query == topic, rule.vettedArtworkURL != nil else {
        fatalError("Incorrect or non-downloadable direct wallpaper mapping for: \(name)")
    }
}
assert(catalog.rule(bundleID: nil, name: "Delta Force") == nil)
assert(catalog.rule(bundleID: nil, name: "Minecraft Dungeons") == nil)
print("PASS: \(catalog.rules.count) real-world wallpaper rules, \(direct.count) vetted images, safe aliases, no Husk game-cover mismatch")
