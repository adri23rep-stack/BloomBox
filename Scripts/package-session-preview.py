#!/usr/bin/env python3
"""Package a source-built standalone app; never present it as a combined SideStore build."""
from pathlib import Path
import plistlib
import sys
import zipfile


def package(app, output):
    app = Path(app)
    info = plistlib.loads((app / "Info.plist").read_bytes())
    executable = app / info["CFBundleExecutable"]
    if not executable.is_file():
        raise ValueError("Missing app executable")
    # A successful build without LiveProcess cannot satisfy session navigation.
    extensions = list((app / "PlugIns").glob("*.appex"))
    if not any("LiveProcess" in extension.name for extension in extensions):
        raise ValueError("LiveProcess extension missing; refusing incomplete preview")
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(app.rglob("*")):
            if path.is_file():
                archive.write(path, Path("Payload") / app.name / path.relative_to(app))


if __name__ == "__main__":
    package(sys.argv[1], sys.argv[2])
