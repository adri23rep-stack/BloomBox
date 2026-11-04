#!/usr/bin/env python3
"""Restore SHA-256-pinned dependencies directly from their original projects.

No binary is fetched from a launcher/fork release. When an upstream nightly
asset changes, the digest check fails closed instead of silently upgrading.
"""
from pathlib import Path
from urllib.parse import urlsplit
from urllib.request import Request, urlopen
import hashlib
import json
import os
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "Scripts/bundled-dependencies.json"
TRUSTED_HOSTS = {"github.com", "raw.githubusercontent.com"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def restore(root: Path, manifest: dict, opener=urlopen) -> list[str]:
    installed = []
    for name, spec in manifest.items():
        relative = Path(name)
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"Unsafe dependency path: {name}")
        url = spec["url"]
        parsed = urlsplit(url)
        if parsed.scheme != "https" or parsed.hostname not in TRUSTED_HOSTS:
            raise ValueError(f"Untrusted dependency source: {url}")
        expected = spec["sha256"].lower()
        if len(expected) != 64 or any(ch not in "0123456789abcdef" for ch in expected):
            raise ValueError(f"Invalid SHA-256 digest for {name}")
        maximum = int(spec["max_bytes"])
        if maximum <= 0 or maximum > 150_000_000:
            raise ValueError(f"Invalid download limit for {name}")
        destination = root / relative
        if destination.is_file() and sha256(destination) == expected:
            print(f"Verified local dependency: {name}")
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=".upstream-", delete=False) as output:
                temp_path = Path(output.name)
                request = Request(url, headers={"User-Agent": "BloomBox-dependency-restore/1"})
                with opener(request, timeout=120) as response:
                    count = 0
                    while chunk := response.read(1024 * 1024):
                        count += len(chunk)
                        if count > maximum:
                            raise ValueError(f"Dependency exceeds configured size limit: {name}")
                        output.write(chunk)
            if sha256(temp_path) != expected:
                raise ValueError(f"Upstream dependency checksum mismatch: {name}")
            if destination.suffix.lower() == ".ipa" and not zipfile.is_zipfile(temp_path):
                raise ValueError(f"Invalid IPA archive: {name}")
            os.replace(temp_path, destination)
            temp_path = None
            installed.append(name)
            print(f"Verified original upstream: {name}")
        finally:
            if temp_path is not None:
                temp_path.unlink(missing_ok=True)
    return installed


if __name__ == "__main__":
    restore(ROOT, json.loads(MANIFEST.read_text(encoding="utf-8")))
    print("Original-source dependencies ready.")
