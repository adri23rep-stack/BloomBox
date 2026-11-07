import Foundation

let suite = "BloomBox.ReservedLauncher." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }

precondition(BloomBoxLaunchPreferences.preferredMode(defaults: defaults) == "ios")
defaults.set("keep-home-layout", forKey: "LiveBoardHomeLayout")
defaults.set("cinematic", forKey: BloomBoxLaunchPreferences.primaryKey)
defaults.set("cinematic", forKey: BloomBoxLaunchPreferences.sessionKey)
defaults.set(true, forKey: BloomBoxLaunchPreferences.pendingKey)
defaults.set("Game.app", forKey: BloomBoxLaunchPreferences.pendingAppKey)
precondition(BloomBoxLaunchPreferences.resetForNewProcess(defaults: defaults) == "ios")
precondition(defaults.string(forKey: BloomBoxLaunchPreferences.primaryKey) == "ios")
precondition(defaults.string(forKey: BloomBoxLaunchPreferences.sessionKey) == "ios")
precondition(defaults.bool(forKey: BloomBoxLaunchPreferences.pendingKey) == false)
precondition(defaults.string(forKey: BloomBoxLaunchPreferences.pendingAppKey) == nil)
precondition(defaults.string(forKey: "LiveBoardHomeLayout") == "keep-home-layout")

for oldMode in ["bigPicture", "reserved", "unknown", "cinematic"] {
    defaults.set(oldMode, forKey: BloomBoxLaunchPreferences.sessionKey)
    precondition(BloomBoxLaunchPreferences.resetForNewProcess(defaults: defaults) == "ios")
    precondition(defaults.string(forKey: BloomBoxLaunchPreferences.sessionKey) == "ios")
}
print("PASS: Retired launcher selections return to Home without removing user data.")

let firstProfile = "primary"
let gamesProfile = "second-" + UUID().uuidString
BloomBoxLaunchPreferences.setPreferredMode("hybrid", profileID: firstProfile, defaults: defaults)
BloomBoxLaunchPreferences.setPreferredMode("gamebox", profileID: gamesProfile, defaults: defaults)
precondition(BloomBoxLaunchPreferences.preferredMode(defaults: defaults, profileID: firstProfile) == "hybrid")
precondition(BloomBoxLaunchPreferences.preferredMode(defaults: defaults, profileID: gamesProfile) == "gamebox")
precondition(BloomBoxLaunchPreferences.preferredMode(defaults: defaults, profileID: "new-profile") == "ios")
precondition(BloomBoxLaunchPreferences.resetForNewProcess(defaults: defaults, profileID: firstProfile) == "ios")
precondition(defaults.string(forKey: BloomBoxLaunchPreferences.sessionKey) == "ios")
precondition(BloomBoxLaunchPreferences.resetForNewProcess(defaults: defaults, profileID: gamesProfile) == "gamebox")
precondition(defaults.string(forKey: BloomBoxLaunchPreferences.sessionKey) == "gamebox")
BloomBoxLaunchPreferences.setPreferredMode("reserved", profileID: firstProfile, defaults: defaults)
precondition(BloomBoxLaunchPreferences.preferredMode(defaults: defaults, profileID: firstProfile) == "hybrid")
BloomBoxLaunchPreferences.rememberGame("Husk", profileID: firstProfile, defaults: defaults)
BloomBoxLaunchPreferences.rememberGame("Husk", profileID: firstProfile, defaults: defaults)
BloomBoxLaunchPreferences.rememberGame("MelonNX", profileID: firstProfile, defaults: defaults)
precondition(BloomBoxLaunchPreferences.recentGames(profileID: firstProfile, defaults: defaults) == ["MelonNX", "Husk"])
precondition(BloomBoxLaunchPreferences.recentGames(profileID: gamesProfile, defaults: defaults).isEmpty)
precondition(defaults.string(forKey: "LiveBoardHomeLayout") == "keep-home-layout")
print("PASS: Hybrid/GameBox/iOS persist independently for each profile; no stale game sessions.")
