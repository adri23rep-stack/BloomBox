import Foundation

func check(_ label: String, ram: Bool, ext: Bool, provider: Bool, debug: Bool, paired: Bool,
           expected: BloomBoxGameModeGate.Missing?) {
    let value = BloomBoxGameModeGate.firstMissing(ramConfirmed: ram, liveProcessSigned: ext,
        builtInJITSelected: provider, debuggingAvailable: debug, pairingPresent: paired)
    precondition(value == expected, "Game Mode gate: \(label) expected \(String(describing: expected)), got \(String(describing: value))")
}
check("No RAM", ram: false, ext: false, provider: false, debug: false, paired: false, expected: .ramPlus)
check("Host signed but LiveProcess missing", ram: true, ext: false, provider: true, debug: true, paired: true, expected: .ramPlus)
check("JIT setup not selected", ram: true, ext: true, provider: false, debug: true, paired: true, expected: .jit)
check("Developer debugging disabled", ram: true, ext: true, provider: true, debug: false, paired: true, expected: .jit)
check("No pairing", ram: true, ext: true, provider: true, debug: true, paired: false, expected: .jit)
check("Both configured", ram: true, ext: true, provider: true, debug: true, paired: true, expected: nil)
// Game Mode must not demand a debugger for a guest with its JIT switch OFF.
// RAM+ remains a separate Game Mode prerequisite.
precondition(BloomBoxGameModeGate.firstMissing(
    ramConfirmed: true, liveProcessSigned: true, builtInJITSelected: false,
    debuggingAvailable: false, pairingPresent: false, jitRequired: false) == nil,
    "Game Mode must launch no-JIT guests without any debugger prerequisites.")
precondition(BloomBoxGameModeGate.firstMissing(
    ramConfirmed: false, liveProcessSigned: false, builtInJITSelected: false,
    debuggingAvailable: false, pairingPresent: false, jitRequired: false) == .ramPlus,
    "Game Mode must still require RAM+ when JIT is disabled.")
precondition(BloomBoxGameModeGate.firstMissing(
    ramConfirmed: true, liveProcessSigned: true, builtInJITSelected: false,
    debuggingAvailable: false, pairingPresent: false, jitRequired: true) == .jit,
    "Apps with JIT enabled still need debugger setup.")
precondition(BloomBoxGameModeGate.jitOverride(explicitlyRequested: false) == nil,
    "Game Mode must not pass false or true as a forced JIT preference.")
precondition(BloomBoxGameModeGate.jitOverride(explicitlyRequested: true) == true,
    "Explicit Launch with JIT must still request a fresh JIT session.")
precondition(BloomBoxGameModeGate.requiresGameMode(bundleID: "com.husk.app", name: "Husk", landscapeLocked: false))
precondition(BloomBoxGameModeGate.requiresGameMode(bundleID: "com.example.other", name: "Some Game", landscapeLocked: true))
precondition(!BloomBoxGameModeGate.requiresGameMode(bundleID: "com.example.music", name: "Player", landscapeLocked: false))
// Launch-from-Game must remain Game even if @AppStorage still says iOS
// during an iOS 27 orientation/sheet transition.
precondition(!BloomBoxGameModeGate.shouldOfferGameSwitch(requiresGame: true, fromGameLauncher: true, persistedMode: "ios"))
precondition(!BloomBoxGameModeGate.shouldOfferGameSwitch(requiresGame: true, fromGameLauncher: false, persistedMode: "cinematic"))
precondition(BloomBoxGameModeGate.shouldOfferGameSwitch(requiresGame: true, fromGameLauncher: false, persistedMode: "ios"))
precondition(!BloomBoxGameModeGate.shouldOfferGameSwitch(requiresGame: false, fromGameLauncher: false, persistedMode: "ios"))
print("PASS: Game Mode respects per-app JIT choices, keeps RAM+, and avoids Game-to-Game loops")
