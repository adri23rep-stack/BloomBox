import Foundation

let suiteID = "BloomBoxGameBoxTests.startup." + UUID().uuidString
let defaults = UserDefaults(suiteName: suiteID)!
defer { defaults.removePersistentDomain(forName: suiteID) }

precondition(BloomBoxLaunchPreferences.preferredMode(defaults: defaults) == "ios",
    "An existing user's default must be the iOS launcher.")
defaults.set("cinematic", forKey: BloomBoxLaunchPreferences.sessionKey)
defaults.set(true, forKey: BloomBoxLaunchPreferences.pendingKey)
defaults.set("RDR.app", forKey: BloomBoxLaunchPreferences.pendingAppKey)
precondition(BloomBoxLaunchPreferences.resetForNewProcess(defaults: defaults) == "ios",
    "GameBox entered temporarily must not survive a fresh launch.")
precondition(defaults.string(forKey: BloomBoxLaunchPreferences.sessionKey) == "ios")
precondition(!defaults.bool(forKey: BloomBoxLaunchPreferences.pendingKey))
precondition(defaults.string(forKey: BloomBoxLaunchPreferences.pendingAppKey) == nil)

defaults.set("cinematic", forKey: BloomBoxLaunchPreferences.primaryKey)
defaults.set("ios", forKey: BloomBoxLaunchPreferences.sessionKey)
precondition(BloomBoxLaunchPreferences.resetForNewProcess(defaults: defaults) == "cinematic",
    "User-selected GameBox primary must survive a fresh launch.")
precondition(defaults.string(forKey: BloomBoxLaunchPreferences.sessionKey) == "cinematic")

defaults.set("future-mode", forKey: BloomBoxLaunchPreferences.primaryKey)
precondition(BloomBoxLaunchPreferences.resetForNewProcess(defaults: defaults) == "ios",
    "Unknown preferences must be safely reset to iOS Home.")
var categories = LiveBoardModeLibrary()
categories.categories = ["Games", "Ports", "Tools", "Retro", "Emuladores"]
categories.assignments["OldEmulator.app"] = "Tools"
categories.assignments["CustomGame.app"] = "Retro"
categories.migrateGameBoxCategories()
precondition(categories.categories == ["Games", "Ports", "Emuladores", "Retro"],
    "Migrate Tools to Emuladores without duplicating existing tabs.")
precondition(categories.assignments["OldEmulator.app"] == "Emuladores",
    "Retain all existing emulator category assignments.")
precondition(categories.assignments["CustomGame.app"] == "Retro",
    "Preserve the user's custom categories.")
categories.migrateGameBoxCategories()
precondition(categories.categories == ["Games", "Ports", "Emuladores", "Retro"],
    "Migrating a second time must not change the library.")
print("PASS: GameBox startup honors the user's primary launcher and clears temporary mode state, emulator categories")
