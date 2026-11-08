#!/usr/bin/env python3
"""The ObjC host hook, Swift extension and plist helper must use the same JIT IPC."""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
hook = (root / "ShareExtension/EXExtensionContextImplementationHook.m").read_text()
worker = (root / "ShareExtension/BloomBoxJITWorker.swift").read_text()
embed = (root / "Scripts/embed-jit-helper.py").read_text()
assert 'launchOptions[@"bloomBoxJIT"]' in hook
assert 'input["bloomBoxJIT"]' in worker
assert 'NSClassFromString(@"BloomBoxJITRequestHandler")' in hook
assert '@objc(BloomBoxJITRequestHandler)' in worker
assert "'NSExtensionPrincipalClass': 'BloomBoxJITRequestHandler'" in embed
for stale in ('@"StrataJITRequestHandler"', 'launchOptions[@"strataJIT"]'):
    assert stale not in hook, "Stale extension bridge: " + stale
assert "if (!class) return;" in hook and "if (!method) return;" in hook
# The simple pairing screen must keep the original expert controls accessible.
setup = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxJITSetup.swift").read_text()
coordinator = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxJITCoordinator.swift").read_text()
assert 'bloombox.jit.automaticPairing' in setup
assert 'bloombox.jit.advancedOptions' in setup
assert 'private var advancedJITForm' in setup
for preserved in ('providerChooser', 'Replace pairing file', 'Remove pairing file',
                  'Remote Pairing port', 'Reset developer disk image cache',
                  'LCJITLessDiagnoseView', 'sharePrivateDataWithLiveProcess'):
    assert preserved in setup, preserved
assert 'BloomBoxJITPairingSync.synchronize()' in coordinator
assert 'try storage.save(bytes)' in coordinator
# The bundled SideStore stores RemoteRP pairing under the guest Documents folder.
assert '"PairingFile_RemoteRP.plist"' in coordinator
assert '"Documents/SideStore/Documents"' in coordinator
assert 'name == "PairingFile_RemoteRP.plist" || folder.lowercased().contains("sidestore")' in coordinator
assert 'if let destinationDate, candidate.date < destinationDate' in coordinator
print("BloomBox JIT cross-language IPC, principal class and guarded hook match")
