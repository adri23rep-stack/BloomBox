#!/usr/bin/env python3
"""Fail before an iOS archive if new BloomBox code crosses the future host/signer boundary.

Legacy references are documented, not removed here. Dependencies must be
checksum-pinned and an update to an upstream artifact needs an explicit PR.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
POLICY = ROOT / "Scripts/upstream-boundaries.json"
DEPENDENCIES = ROOT / "Scripts/bundled-dependencies.json"
CODE_ROOT = ROOT / "LiveContainerSwiftUI/Views/BloomBox"
BUILD_SCRIPT = ROOT / ".github/build_github.sh"
CI = ROOT / ".github/workflows/build.yml"

def verify() -> None:
    policy = json.loads(POLICY.read_text(encoding="utf-8"))
    deps = json.loads(DEPENDENCIES.read_text(encoding="utf-8"))
    assert policy["schemaVersion"] == 1
    allowed = policy["allowedLegacyBloomBoxSwiftFiles"]
    assert len(set(allowed)) == len(allowed) and allowed == sorted(allowed), "Bad legacy file inventory"
    assert all(p.startswith("LiveContainerSwiftUI/Views/BloomBox/") and p.endswith(".swift")
               for p in allowed), "Legacy exception outside BloomBox UI"
    tokens = [re.compile(r"\b" + re.escape(token) + r"\b")
              for token in policy["directHostTokens"] + policy["directSignerTokens"]]
    for path in sorted(CODE_ROOT.glob("*.swift")):
        relative = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8")
        if relative not in allowed:
            hits = [token.pattern for token in tokens if token.search(text)]
            assert not hits, (
                f"New BloomBox UI directly accesses LiveContainer/SideStore internals: "
                f"{relative}: {hits}. Use a portable contract and adapter instead."
            )
    contracts = (CODE_ROOT / "BloomBoxIntegrationContracts.swift").read_text(encoding="utf-8")
    assert "protocol BloomBoxGuestHost" in contracts
    assert "protocol BloomBoxSigningService" in contracts
    assert "import Foundation" in contracts and "import SideStore" not in contracts
    assert "LCAppModel" not in contracts and "SideStoreSupport" not in contracts

    for name in policy["pinnedDependencyPaths"]:
        assert name in deps, f"Unpinned upstream dependency: {name}"
        item = deps[name]
        parsed = urlsplit(item["url"])
        assert parsed.scheme == "https" and parsed.hostname in ("github.com", "raw.githubusercontent.com")
        assert re.fullmatch(r"[0-9a-f]{64}", item["sha256"])
        assert 0 < int(item["max_bytes"]) <= 150_000_000
        assert "Strata" not in parsed.path and "Strata" not in parsed.hostname
    assert deps["tmp/SideStore.ipa"]["url"] == (
        "https://github.com/LiveContainer/SideStore/releases/download/nightly/SideStore.ipa"
    )
    assert deps["dylibify"]["url"] == (
        "https://github.com/LiveContainer/dylibify/releases/download/1.0/dylibify"
    )
    build = BUILD_SCRIPT.read_text(encoding="utf-8")
    assert "wget https://github.com/LiveContainer/SideStore" not in build
    assert "wget https://github.com/LiveContainer/dylibify" not in build
    assert "test -s SideStore.ipa" in build and "test -s dylibify" in build
    workflow = CI.read_text(encoding="utf-8")
    assert "python3 Scripts/fetch-bundled-dependencies.py" in workflow
    assert "python3 Tests/upstream-boundaries-tests/test_boundaries.py" in workflow
    for key in policy["protectedCompatibilityKeys"]:
        assert isinstance(key, str) and key, "Protected key must be nonempty"
    print("BloomBox boundary check passed: new UI stays host-independent; "
          "legacy imports acknowledged and upstream tools checksum-pinned.")


if __name__ == "__main__":
    try:
        verify()
    except (AssertionError, KeyError, ValueError, OSError) as exc:
        print("BloomBox upstream boundary failure:", exc, file=sys.stderr)
        sys.exit(1)
