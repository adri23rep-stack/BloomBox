import Foundation
var cinematic = LiveBoardConsoleLayout()
cinematic.iconScale = 2.3; cinematic.launchX = 0.8; cinematic.launchY = 0.25
let saved = LiveBoardConsoleLayout.save(cinematic, mode: "cinematic", in: "{}")
precondition(LiveBoardConsoleLayout.decode(saved, mode: "cinematic") == cinematic)
precondition(LiveBoardConsoleLayout.decode(saved, mode: "bigPicture") == LiveBoardConsoleLayout())
var invalid = LiveBoardConsoleLayout(); invalid.iconScale = 99; invalid.launchX = -1; invalid.launchY = .infinity; invalid.clamp()
precondition(invalid.iconScale == 2.5 && invalid.launchX == 0 && invalid.launchY == 0.72)
let both = LiveBoardConsoleLayout.save(LiveBoardConsoleLayout(), mode: "bigPicture", in: saved)
precondition(LiveBoardConsoleLayout.decode(both, mode: "cinematic") == cinematic)
precondition(LiveBoardConsoleLayout.decode("bad json", mode: "cinematic") == LiveBoardConsoleLayout())
print("PASS: layout persistence, mode isolation, malformed preference recovery and coordinate/scale bounds.")
let oldSaved = "{\"cinematic\":{\"iconScale\":1.6,\"launchX\":0.8,\"launchY\":0.2}}"
let migrated = LiveBoardConsoleLayout.decode(oldSaved, mode: "cinematic")
precondition(migrated.iconScale == 1.6 && migrated.launchX == 0.8 && migrated.launchY == 0.2 && migrated.launchScale == 1)
var resized = migrated; resized.launchScale = 1.7
let resizedSaved = LiveBoardConsoleLayout.save(resized, mode: "cinematic", in: oldSaved)
precondition(LiveBoardConsoleLayout.decode(resizedSaved, mode: "cinematic").launchScale == 1.7)
precondition(LiveBoardConsoleLayout.decode(resizedSaved, mode: "bigPicture").launchScale == 1)
print("PASS: Play-control size persistence and backward-compatible layout migration.")
