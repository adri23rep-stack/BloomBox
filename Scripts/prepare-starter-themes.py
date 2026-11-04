#!/usr/bin/env python3
"""Rebuild and validate the two user-supplied BloomBox starter themes.

Yellow Bowser's original plaintext .bbtheme is checked into Git as smaller
unmodified chunks, avoiding an oversized single-file connector upload.
The original theme bytes are reassembled before every iOS archive.
"""
from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESETS = ROOT / "Resources" / "StarterThemes"
SOURCE = ROOT / "ThemeSources"
EXPECTED = {
    "KirbyPink": ("307754522eedd7d152d9a74e4eb4b881ec0f466c3cdf962834601942ebacfa78", 1328515),
    "YellowBowser": ("fa20237daf39266247eb9a5fc8d003da4bde87c235e0affef287d0f8d6e0a82a", 5520302),
}


def verify(name: str) -> None:
    path = PRESETS / (name + ".bbtheme")
    raw = path.read_bytes()
    digest, length = EXPECTED[name]
    if len(raw) != length or hashlib.sha256(raw).hexdigest() != digest:
        raise SystemExit(f"{name} starter theme is incomplete or modified.")
    theme = json.loads(raw)
    if theme.get("format") != "bbtheme" or theme.get("version") != 2:
        raise SystemExit(f"{name} starter theme is not a supported v2 .bbtheme.")
    media = theme.get("mediaBase64")
    settings = theme.get("settings")
    if not isinstance(media, dict) or not isinstance(settings, dict):
        raise SystemExit(f"{name} starter theme is missing its media or settings.")
    if not {"wallpaper.jpg", "motion-wallpaper"}.issubset(media):
        raise SystemExit(f"{name} starter theme has no complete backgrounds.")
    placements = json.loads(settings["BloomBoxPlacedWidgetsV2"])
    used = {w.get("mediaName") for widgets in placements.values()
            for w in widgets if w.get("mediaName")}
    if not used.issubset(media.keys()):
        raise SystemExit(f"{name} starter theme is missing widget artwork.")
    for filename, encoded in media.items():
        if filename not in {"wallpaper.jpg", "motion-wallpaper"} and not (
            filename.startswith("widget-") and filename.endswith((".gif", ".jpg", ".png", ".webp"))
        ):
            raise SystemExit(f"{name} contains unsafe media: {filename}")
        data = base64.b64decode(encoded, validate=True)
        if not data or len(data) > 30 * 1024 * 1024:
            raise SystemExit(f"{name} contains empty or oversized media: {filename}")
    print(f"Validated starter theme: {name} ({len(raw)} bytes)")


def prepare_bowser() -> None:
    chunks = sorted(SOURCE.glob("YellowBowser.part*"))
    if [p.name for p in chunks] != [
        f"YellowBowser.part{i:02d}" for i in range(1, 10)
    ]:
        raise SystemExit("The Yellow Bowser source chunks are incomplete.")
    PRESETS.mkdir(parents=True, exist_ok=True)
    output = PRESETS / "YellowBowser.bbtheme"
    temp = PRESETS / "YellowBowser.bbtheme.tmp"
    try:
        with temp.open("wb") as dst:
            for chunk in chunks:
                with chunk.open("rb") as src:
                    for block in iter(lambda: src.read(262144), b""):
                        dst.write(block)
        os.replace(temp, output)
    finally:
        temp.unlink(missing_ok=True)


if __name__ == "__main__":
    prepare_bowser()
    for preset in EXPECTED:
        verify(preset)
