import Foundation

/// Compatibility fixes for the known universal protocol, preserving guest-specific handlers.
enum StrataJITScriptSafety {
    static let bridge = #"""
    function send_command(command) {
        const reply = __strata_send_command(command);
        if (reply === null || reply === undefined) throw new Error(__strata_last_error());
        if ((command.startsWith('vAttach;') || command === 'c') && /^E[0-9a-f]+(?:;|$)/i.test(reply)) {
            const parts = reply.split(';');
            let detail = '';
            if (parts[1] && /^(?:[0-9a-f]{2})+$/i.test(parts[1])) {
                for (let i = 0; i < parts[1].length; i += 2)
                    detail += String.fromCharCode(parseInt(parts[1].slice(i, i + 2), 16));
            }
            throw new Error('Debugger rejected ' + command + ': ' + parts[0] + (detail ? ' — ' + detail : ''));
        }
        if (command === 'c' && /^[WX][0-9a-f]{2}/i.test(reply))
            throw new Error('Guest exited before JIT preparation: ' + reply);
        return reply;
    }
    function prepare_memory_region(address, length) {
        const reply = __strata_prepare_memory_region(address, length);
        if (reply === null || reply === undefined) throw new Error(__strata_last_error());
        return reply;
    }
    function strataReadRegister(reply, register, thread) {
        const match = new RegExp('(?:^|;)' + register + ':([0-9a-f]{16});', 'i').exec(reply);
        if (match) return match[1];
        const value = send_command('p' + register + ';thread:' + thread + ';');
        if (!/^[0-9a-f]{16}$/i.test(value))
            throw new Error('Debugger did not return register ' + register + ': ' + value);
        return value;
    }
    """#
    static func harden(_ source: String) -> String {
        guard source.contains("const CMD_DETACH = 0"), source.contains("const CMD_PREPARE_REGION = 1") else { return source }
        var result = source
        let start = "    let tmpMatch = /T[0-9a-f]+thread:(?<tid>[0-9a-f]+);/.exec(brkResponse);"
        if let a = result.range(of: start), let b = result.range(of: "    pc = littleEndianHexStringToNumber(pc);", range: a.upperBound..<result.endIndex) {
            result.replaceSubrange(a.lowerBound..<b.lowerBound, with: #"""
                let tmpMatch = /thread:((?:p[0-9a-f]+\.)?[0-9a-f]+);/i.exec(brkResponse);
                tid = tmpMatch ? tmpMatch[1] : null;
                if (!tid) {
                    const current = /^QC((?:p[0-9a-f]+\.)?[0-9a-f]+)$/i.exec(send_command('qC'));
                    tid = current ? current[1] : null;
                }
                if (!tid || !/^T[0-9a-f]{2}/i.test(brkResponse))
                    throw new Error('Unexpected debugger stop reply: ' + brkResponse);
                pc = strataReadRegister(brkResponse, '20', tid);
                x16 = strataReadRegister(brkResponse, '10', tid);
            
            """#)
        }
        let first = "        tmpMatch = /00:(?<reg>[0-9a-f]{16});/.exec(brkResponse);"
        if let a = result.range(of: first), let b = result.range(of: "        x0 = littleEndianHexStringToNumber(x0);", range: a.upperBound..<result.endIndex) {
            result.replaceSubrange(a.lowerBound..<b.lowerBound, with: "        x0 = strataReadRegister(brkResponse, '00', tid);\n        x1 = strataReadRegister(brkResponse, '01', tid);\n")
        }
        return result
    }
}
