import Foundation
import JavaScriptCore
let source = CommandLine.arguments.contains("melonx")
    ? String(data: Data(base64Encoded: BloomBoxMeloNXProfile.scriptBase64)!, encoding: .utf8)!
    : try String(contentsOfFile: "ShareExtension/universal.js", encoding: .utf8)
precondition(BloomBoxMeloNXProfile.matches(bundleID: "com.stossy11.MeloNX", version: "2.6"))
precondition(!BloomBoxMeloNXProfile.matches(bundleID: "com.stossy11.MeloNX", version: "2.7"))
precondition(!BloomBoxMeloNXProfile.matches(bundleID: "other", version: "2.6"))

let originalScript = "my-own-compatible-script"
func routed(_ custom: String? = nil, _ melon: Bool = false,
            _ builtIn: Bool = true, _ requested: Bool = true,
            _ experimental: Bool = false) -> String? {
    BloomBoxMeloNXProfile.scriptForLaunch(custom: custom,
        isMeloNX26: melon, isBuiltInProvider: builtIn,
        jitRequested: requested, crossAppExperiment: experimental)
}
precondition(routed() == nil, "Other guests must default to no MeloNX script")
precondition(routed(nil, false, true, true, true) == BloomBoxMeloNXProfile.scriptBase64,
             "Opt-in built-in JIT must reuse the exact MeloNX script")
precondition(routed(nil, false, false, true, true) == nil,
             "External JIT providers must not receive the experimental script")
precondition(routed(nil, false, true, false, true) == nil,
             "The switch must never force JIT on a normal guest")
precondition(routed(nil, true, false, false, false) == BloomBoxMeloNXProfile.scriptBase64,
             "MeloNX 2.6 automatic script must remain unchanged")
precondition(routed(originalScript, false, true, true, true) == originalScript,
             "Existing app scripts must take precedence")
precondition(routed(originalScript, true, true, true, true) == originalScript,
             "A custom MeloNX script must still take precedence")
print("PASS: MeloNX script routing is opt-in, limited to built-in JIT, and preserves app overrides.")

// Saved, per-installed-app policy: no global script blast radius.
do {
    let suite = "BloomBoxJITPolicyTests." + UUID().uuidString
    guard let defaults = UserDefaults(suiteName: suite) else { fatalError("Cannot create test defaults") }
    defer { defaults.removePersistentDomain(forName: suite) }
    let appA = "GuestA.app"
    let appB = "GuestB.app"
    precondition(BloomBoxJITGuestPolicy.mode(for: appA, defaults: defaults) == .automatic)
    precondition(BloomBoxJITGuestPolicy.wantsJIT(automatic: true, forced: nil, mode: .automatic))
    precondition(!BloomBoxJITGuestPolicy.wantsJIT(automatic: false, forced: nil, mode: .automatic))
    precondition(BloomBoxJITGuestPolicy.wantsJIT(automatic: false, forced: true, mode: .automatic))
    precondition(BloomBoxJITGuestPolicy.wantsJIT(automatic: false, forced: nil, mode: .enabled))
    precondition(!BloomBoxJITGuestPolicy.wantsJIT(automatic: true, forced: false, mode: .enabled))
    precondition(!BloomBoxJITGuestPolicy.wantsJIT(automatic: true, forced: true, mode: .disabled))

    BloomBoxJITGuestPolicy.setMode(.disabled, for: appA, defaults: defaults)
    precondition(BloomBoxJITGuestPolicy.mode(for: appA, defaults: defaults) == .disabled)
    precondition(BloomBoxJITGuestPolicy.mode(for: appB, defaults: defaults) == .automatic)
    BloomBoxJITGuestPolicy.setMode(.enabled, for: appB, defaults: defaults)
    precondition(BloomBoxJITGuestPolicy.mode(for: appB, defaults: defaults) == .enabled)
    BloomBoxJITGuestPolicy.setMode(.automatic, for: appA, defaults: defaults)
    precondition(BloomBoxJITGuestPolicy.mode(for: appA, defaults: defaults) == .automatic)

    precondition(!BloomBoxJITGuestPolicy.shouldTryMeloNXScript(
        appKey: appA, isMeloNX26: false, enabled: true, defaults: defaults))
    BloomBoxJITGuestPolicy.setExperimentSelected(true, for: appA, defaults: defaults)
    precondition(BloomBoxJITGuestPolicy.isExperimentSelected(for: appA, defaults: defaults))
    precondition(!BloomBoxJITGuestPolicy.isExperimentSelected(for: appB, defaults: defaults))
    precondition(!BloomBoxJITGuestPolicy.shouldTryMeloNXScript(
        appKey: appA, isMeloNX26: false, enabled: false, defaults: defaults))
    precondition(!BloomBoxJITGuestPolicy.shouldTryMeloNXScript(
        appKey: appA, isMeloNX26: true, enabled: true, defaults: defaults))
    let selected = BloomBoxJITGuestPolicy.shouldTryMeloNXScript(
        appKey: appA, isMeloNX26: false, enabled: true, defaults: defaults)
    precondition(selected)
    precondition(routed(nil, false, true, true, selected) == BloomBoxMeloNXProfile.scriptBase64)
    precondition(routed("my-script", false, true, true, selected) == "my-script")
    precondition(routed(nil, false, true, false, selected) == nil)
    precondition(routed(nil, false, false, true, selected) == nil)
    BloomBoxJITGuestPolicy.setExperimentSelected(false, for: appA, defaults: defaults)
    precondition(!BloomBoxJITGuestPolicy.isExperimentSelected(for: appA, defaults: defaults))
    precondition(!BloomBoxJITGuestPolicy.shouldTryMeloNXScript(
        appKey: appA, isMeloNX26: false, enabled: true, defaults: defaults))
    print("PASS: per-app JIT policies remain isolated, reversible and script opt-in is explicit.")
}


func run(_ mode: String) -> (String?, [String]) {
    let context = JSContext()!
    var commands: [String] = []
    let pid: @convention(block) () -> Int = { 123 }
    let send: @convention(block) (String) -> String? = { command in
        commands.append(command)
        if command.hasPrefix("vAttach;") { if mode == "detail" { return "E96;6e6f20737563682070726f63657373" }; return mode == "reject" ? "E96" : "T05thread:2a;" }
        if command == "c" {
            if mode == "disconnect" { return nil }
            if mode == "exit" { return "W00" }
            if mode == "missing-thread" { return "T05reason:breakpoint;" }
            return "T05thread:p7b.2A;"
        }
        if command == "qC" { return "QCp7b.2A" }
        if command.hasPrefix("p20;") { return "0010000000000000" }
        if command.hasPrefix("p10;") || command.hasPrefix("p00;") || command.hasPrefix("p01;") { return "0000000000000000" }
        if command.hasPrefix("m1000,") { return "a0013ed4" }
        if command.hasPrefix("P20=") || command == "D" { return "OK" }
        return "E01"
    }
    let prepare: @convention(block) (Double, Double) -> String? = { _, _ in "OK" }
    let error: @convention(block) () -> String = { "Debugger transport closed" }
    let log: @convention(block) (JSValue?) -> Void = { _ in }
    context.setObject(pid, forKeyedSubscript: "get_pid" as NSString)
    context.setObject(send, forKeyedSubscript: "__strata_send_command" as NSString)
    context.setObject(prepare, forKeyedSubscript: "__strata_prepare_memory_region" as NSString)
    context.setObject(error, forKeyedSubscript: "__strata_last_error" as NSString)
    context.setObject(log, forKeyedSubscript: "log" as NSString)
    context.evaluateScript(StrataJITScriptSafety.bridge)
    context.evaluateScript(StrataJITScriptSafety.harden(source))
    return (context.exception?.toString(), commands)
}
for mode in ["minimal", "missing-thread"] {
    let (error, commands) = run(mode)
    precondition(error == nil, error ?? "")
    precondition(commands.contains("D"))
    precondition(commands.contains { $0.hasPrefix("p20;thread:p7b.2A;") })
}
let reject = run("reject")
precondition(reject.0?.contains("E96") == true && reject.1.count == 1)
let disconnect = run("disconnect")
precondition(disconnect.0?.contains("transport closed") == true && disconnect.1.count == 2)
let exit = run("exit")
precondition(exit.0?.contains("Guest exited") == true && exit.1.count == 2)
print("PASS: real universal script handles qualified threads and missing registers; rejects attach errors, disconnects and exited guests without retry loops.")

let detail = run("detail")
precondition(detail.0?.contains("no such process") == true && detail.1.count == 1)
print("Detailed debugger rejection: PASS")
