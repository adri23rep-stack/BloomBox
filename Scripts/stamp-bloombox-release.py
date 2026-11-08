#!/usr/bin/env python3
"""Stamp BloomBox's own release tag, separate from LiveContainer's bundle version.

Only an explicit stable release ref or release commit may opt into automatic
replacement. A normal development/Actions build always stays "development".
"""
import os
import plistlib
import re
from pathlib import Path

TAG_PATTERN = re.compile(r"^v[0-9]+\.[0-9]+\.[0-9]+$")
RELEASE_MESSAGE = re.compile(r"^release: BloomBox (v[0-9]+\.[0-9]+\.[0-9]+)(?:\s|$)")
PLIST_PATH = Path("LiveContainer/Info.plist")


def tag_for_build(ref: str, event: str, message: str) -> str:
    if ref.startswith("refs/tags/"):
        candidate = ref.removeprefix("refs/tags/")
        return candidate if TAG_PATTERN.fullmatch(candidate) else "development"
    if ref == "refs/heads/main" and event == "push":
        match = RELEASE_MESSAGE.match(message)
        if match:
            return match.group(1)
    return "development"


def stamp(tag: str, path: Path = PLIST_PATH) -> None:
    with path.open("rb") as stream:
        plist = plistlib.load(stream)
    plist["BloomBoxReleaseTag"] = tag
    with path.open("wb") as stream:
        plistlib.dump(plist, stream, sort_keys=False)


if __name__ == "__main__":
    tag = tag_for_build(os.getenv("GITHUB_REF", ""), os.getenv("GITHUB_EVENT_NAME", ""),
                        os.getenv("BLOOMBOX_HEAD_COMMIT_MESSAGE", ""))
    stamp(tag)
    print(f"Stamped BloomBoxReleaseTag={tag}")
