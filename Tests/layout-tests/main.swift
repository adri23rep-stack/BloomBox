import Foundation

// Verify GameBox's current model while keeping older layouts readable.
// The saved identifiers below are intentionally NOT rebranded or migrated.
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

let fresh = BloomBoxGameBoxLayout()
check(fresh.launchY == 0.72, "Default launch button position changed")
check(fresh.launchScale == 1, "Default launch button scale changed")

var console = BloomBoxGameBoxLayout()
console.iconScale = 2.3
console.launchScale = 1.7
console.launchX = 0.8
console.launchY = 0.25

let serialized = BloomBoxGameBoxLayout.save(console, mode: "cinematic", in: "{}")
check(BloomBoxGameBoxLayout.decode(serialized, mode: "cinematic") == console,
      "GameBox settings did not survive encoding")
check(BloomBoxGameBoxLayout.decode(serialized, mode: "bigPicture") == fresh,
      "Another GameBox mode received unrequested settings")

var alternate = BloomBoxGameBoxLayout()
alternate.iconScale = 0.75
alternate.launchX = 0.1
let combined = BloomBoxGameBoxLayout.save(alternate, mode: "bigPicture", in: serialized)
check(BloomBoxGameBoxLayout.decode(combined, mode: "cinematic") == console,
      "Saving a second mode overwrote the first")
check(BloomBoxGameBoxLayout.decode(combined, mode: "bigPicture") == alternate,
      "Second mode settings were not saved")

// Older installs did not have a launchScale field. Keep reading those JSON bytes.
let savedV1 = #"{"cinematic":{"iconScale":1.6,"launchX":0.8,"launchY":0.2}}"#
let legacy = BloomBoxGameBoxLayout.decode(savedV1, mode: "cinematic")
check(legacy.launchScale == 1 && legacy.launchX == 0.8,
      "Previously saved GameBox positions cannot be loaded")
var updated = legacy
updated.launchScale = 1.75
let migrated = BloomBoxGameBoxLayout.save(updated, mode: "cinematic", in: savedV1)
check(BloomBoxGameBoxLayout.decode(migrated, mode: "cinematic") == updated,
      "Legacy settings failed to migrate without data loss")

var unsafe = BloomBoxGameBoxLayout()
unsafe.iconScale = .infinity
unsafe.launchScale = -.infinity
unsafe.launchX = -99
unsafe.launchY = .nan
unsafe.clamp()
check(unsafe.iconScale == 1 && unsafe.launchScale == 1,
      "Non-finite scales should revert to defaults")
check(unsafe.launchX == 0 && unsafe.launchY == 0.72,
      "Invalid coordinates should be clamped or defaulted")
check(BloomBoxGameBoxLayout.decode("invalid JSON", mode: "cinematic") == fresh,
      "Malformed saved state should fail safely")

// Host compatibility callers still use this type name.
let compatibility: LiveBoardConsoleLayout = fresh
check(compatibility == fresh, "Legacy Swift type alias must stay available")
print("PASS: BloomBox GameBox persistence, mode isolation, legacy JSON, safety bounds.")
