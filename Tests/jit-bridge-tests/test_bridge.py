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
print("BloomBox JIT cross-language IPC, principal class and guarded hook match")
