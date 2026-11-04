#!/usr/bin/env python3
"""Guard author-attribution for marked original BloomBox contributions."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COVERED = (
    "Scripts/generate-bloombox-icon.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxReservedSection.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxLauncherPreferences.swift",
)
TERMS = (ROOT / "LICENSE-ADDITIONAL-TERMS.md").read_text(encoding="utf-8")
NOTICE = (ROOT / "NOTICE.md").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")
THIRD = (ROOT / "THIRD_PARTY_NOTICES.md").read_text(encoding="utf-8")
AGPL = (ROOT / "LICENSE").read_text(encoding="utf-8")
ATTRIBUTION = "Original BloomBox contributions (c) 2026 adri23rep-stack"

assert "GNU AFFERO GENERAL PUBLIC LICENSE" in AGPL
assert "7. Additional Terms." in AGPL
assert "AGPL-3.0-only" in TERMS and "section 7(b)" in TERMS
assert ATTRIBUTION in TERMS and ATTRIBUTION in NOTICE
assert "https://github.com/adri23rep-stack/BloomBox" in NOTICE
assert "original copyrightable material" in TERMS
assert "No new license or condition is asserted over third-party material" in TERMS
for key in ("LiveContainer", "SideStore", "StikJIT", "Husk"):
    assert key in THIRD, "Original upstream license notice missing: " + key
assert "LICENSE-ADDITIONAL-TERMS.md" in README and "LICENSE-ADDITIONAL-TERMS.md" in THIRD
for path in COVERED:
    content = (ROOT / path).read_text(encoding="utf-8")
    assert content.startswith("// SPDX-License-Identifier: AGPL-3.0-only\n"), path
    assert "Copyright (c) 2026 adri23rep-stack" in content, path
    assert "LICENSE-ADDITIONAL-TERMS.md" in content, path
    assert "`" + path + "`" in TERMS, path
print("PASS: AGPL intact, required author credit scoped, upstream licenses preserved.")
