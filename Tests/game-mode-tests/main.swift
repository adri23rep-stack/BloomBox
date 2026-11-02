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
precondition(BloomBoxGameModeGate.requiresGameMode(bundleID: "com.husk.app", name: "Husk", landscapeLocked: false))
precondition(BloomBoxGameModeGate.requiresGameMode(bundleID: "com.example.other", name: "Some Game", landscapeLocked: true))
precondition(!BloomBoxGameModeGate.requiresGameMode(bundleID: "com.example.music", name: "Player", landscapeLocked: false))
// Launch-from-Game must remain Game even if @AppStorage still says iOS
// during an iOS 27 orientation/sheet transition.
precondition(!BloomBoxGameModeGate.shouldOfferGameSwitch(requiresGame: true, fromGameLauncher: true, persistedMode: "ios"))
precondition(!BloomBoxGameModeGate.shouldOfferGameSwitch(requiresGame: true, fromGameLauncher: false, persistedMode: "cinematic"))
precondition(BloomBoxGameModeGate.shouldOfferGameSwitch(requiresGame: true, fromGameLauncher: false, persistedMode: "ios"))
precondition(!BloomBoxGameModeGate.shouldOfferGameSwitch(requiresGame: false, fromGameLauncher: false, persistedMode: "ios"))
print("PASS: Game Mode prerequisites, landscape routing and no Game-to-Game launch loop")
