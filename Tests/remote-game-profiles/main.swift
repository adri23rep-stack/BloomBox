import Foundation

let good = """
{
  "schemaVersion": 1,
  "catalogID": "bloombox.game-compatibility",
  "updatedAt": "2026-11-02",
  "profiles": [
    {
      "bundleID": "com.husk.app", "name": "Husk", "revision": 1,
      "gameMode": true, "requiresRAMPlus": true, "requiresJIT": true,
      "compatibility": { "orientation": "landscape", "jitNeeded": true }
    }
  ]
}
"""
func parse(_ text: String) -> BloomBoxGameProfileIndex? {
    BloomBoxGameProfileIndex.validated(from: Data(text.utf8))
}
precondition(parse(good)?.profiles.first?.bundleID == "com.husk.app")
precondition(parse(good.replacingOccurrences(of: "com.husk.app", with: "com.*")) == nil)
precondition(parse(good.replacingOccurrences(of: "landscape", with: "upsideDown")) == nil)
precondition(parse(good.replacingOccurrences(of: "bloombox.game-compatibility", with: "other")) == nil)
precondition(parse(good.replacingOccurrences(of: "\"jitNeeded\": true", with: "\"jitNeeded\": true, \"executeScript\": \"evil\"")) == nil)
precondition(parse(good.replacingOccurrences(of: "\"gameMode\": true", with: "\"gameMode\": true, \"downloadURL\": \"https://bad.invalid\"")) == nil)
precondition(parse(good.replacingOccurrences(of: "\"orientation\": \"landscape\"", with: "\"orientation\": \"landscape\", \"classicMode\": true")) == nil)
let duplicate = good.replacingOccurrences(of: """
    }
  ]
}
""", with: """
    },
    {
      "bundleID": "com.husk.app", "name": "Husk duplicate", "revision": 2,
      "gameMode": true, "requiresRAMPlus": true, "requiresJIT": true
    }
  ]
}
""")
precondition(parse(duplicate) == nil)
precondition(BloomBoxGameProfileIndex.validated(from: Data(repeating: 0, count: 100_001)) == nil)
print("PASS: exact bundle matching, strict allowlist, invalid orientation, unsafe flags, duplicates and payload limit")
