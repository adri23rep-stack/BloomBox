#!/usr/bin/env python3
"""Validate pinned provenance evidence without downloading or modifying sources.

This is a SNAPSHOT, not a blocker against future legitimate code rewrites.
Use --drift to report (but not fail on) files changed since the snapshot.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/STRATA-PROVENANCE-MANIFEST.json"
HEX40 = re.compile(r"^[0-9a-f]{40}$")
EXPECTED_REPOS = ("bloombox", "strata", "livecontainer", "stikjit")
CATEGORIES = {
    "B_LIVECONTAINER_EXACT",
    "B_STIKJIT_EXACT",
    "E_STRATA_EXACT_ORIGIN_PENDING",
    "E_MODIFIED_OR_NEW_UNCLASSIFIED",
}


def verify(rows: list[dict], expected: dict[str, int], label: str) -> None:
    counts: dict[str, int] = {}
    seen: set[str] = set()
    for record in rows:
        path, sha, kind = record["path"], record["sha"], record["classification"]
        if path in seen or not path or Path(path).is_absolute() or ".." in Path(path).parts:
            raise ValueError(f"invalid/duplicate {label} path: {path!r}")
        seen.add(path)
        if not HEX40.fullmatch(sha) or record["bytes"] < 0 or kind not in CATEGORIES:
            raise ValueError(f"invalid {label} snapshot entry: {path}")
        matches = record["matches"]
        if not isinstance(matches, dict) or any(
            repo not in ("strata", "livecontainer", "stikjit")
            for repo in matches
        ):
            raise ValueError(f"unknown upstream for {path}")
        if kind == "B_LIVECONTAINER_EXACT" and "livecontainer" not in matches:
            raise ValueError(f"LiveContainer evidence missing: {path}")
        if kind == "B_STIKJIT_EXACT" and (
            "stikjit" not in matches or "livecontainer" in matches
        ):
            raise ValueError(f"StikJIT evidence missing: {path}")
        if kind == "E_STRATA_EXACT_ORIGIN_PENDING" and (
            "strata" not in matches or "livecontainer" in matches
            or "stikjit" in matches
        ):
            raise ValueError(f"Strata-only evidence missing: {path}")
        if kind == "E_MODIFIED_OR_NEW_UNCLASSIFIED" and matches:
            raise ValueError(f"unclassified file already has exact upstream: {path}")
        counts[kind] = counts.get(kind, 0) + 1
    if counts != expected:
        raise ValueError(f"{label} classification totals drifted: {counts} != {expected}")


def git_blob_sha(path: Path) -> str:
    raw = path.read_bytes()
    return hashlib.sha1(b"blob " + str(len(raw)).encode("ascii") + b"\\0" + raw).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--drift", action="store_true",
                        help="report local byte differences from the fixed snapshot")
    options = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("schemaVersion") != 1:
        raise ValueError("unsupported provenance schema")
    revisions = manifest.get("revisions", {})
    for name in EXPECTED_REPOS:
        info = revisions.get(name)
        if not isinstance(info, dict) or not HEX40.fullmatch(info.get("commit", "")):
            raise ValueError(f"missing immutable upstream commit: {name}")
    counts = manifest["counts"]
    sources, assets = manifest["sourceFiles"], manifest["mediaAssets"]
    if len(sources) != counts["sources"] or len(assets) != counts["assets"]:
        raise ValueError("file count changed without updating manifest totals")
    verify(sources, counts["sourceClassification"], "source")
    verify(assets, counts["assetClassification"], "media")
    if set(item["path"] for item in sources).intersection(
        item["path"] for item in assets
    ):
        raise ValueError("source/media path conflict")
    print(f"Provenance baseline validated: {len(sources)} source files, "
          f"{len(assets)} media assets; no license conclusions implied.")
    if options.drift:
        changed = []
        for item in sources + assets:
            path = ROOT / item["path"]
            if not path.is_file() or git_blob_sha(path) != item["sha"]:
                changed.append(item["path"])
        for path in changed:
            print("Snapshot changed:", path)
        print(f"Changed since pinned BloomBox snapshot: {len(changed)}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, TypeError, OSError) as exc:
        print("Provenance snapshot invalid:", exc, file=sys.stderr)
        sys.exit(1)
