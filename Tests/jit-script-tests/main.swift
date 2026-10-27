import Foundation
import JavaScriptCore
let source = try String(contentsOfFile: "ShareExtension/universal.js", encoding: .utf8)
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
