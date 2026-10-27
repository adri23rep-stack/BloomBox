#!/usr/bin/env python3
"""Embed the SideStore-signable ActivityKit widget into the ad-hoc Manzana archive.

Xcode's ValidateEmbeddedBinary erroneously enforces certificate equality for the
unsigned host app and a newly-added widget target. Existing LiveProcess/JIT
extensions are packaged without a distribution certificate as well. We build
the widget through a target dependency, then copy/sign it as ad hoc during the
last host run-script phase. SideStore signs the entire IPA on installation.
"""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

if os.environ.get("PLATFORM_NAME") != "iphoneos":
    sys.exit(0)

name = "ManzanaExpiryWidget.appex"
product_dir = Path(os.environ["BUILT_PRODUCTS_DIR"])
target_dir = Path(os.environ["TARGET_BUILD_DIR"])
app = target_dir / os.environ.get("WRAPPER_NAME", "LiveContainer.app")
candidates = [
    product_dir / name,
    Path(os.environ.get("CONFIGURATION_BUILD_DIR", str(product_dir))) / name,
    product_dir.parent.parent / "UninstalledProducts/iphoneos" / name,
    target_dir.parent / "UninstalledProducts/iphoneos" / name,
]
src = next((path for path in candidates if path.is_dir()), None)
if src is None:
    raise SystemExit("Widget target was not built; looked in: " +
                     ", ".join(str(path) for path in candidates))
dst = app / "PlugIns" / name
dst.parent.mkdir(parents=True, exist_ok=True)
if dst.exists():
    shutil.rmtree(dst)
shutil.copytree(src, dst, symlinks=True)
info_path = dst / "Info.plist"
with info_path.open("rb") as f:
    info = plistlib.load(f)
with (app / "Info.plist").open("rb") as f:
    host = plistlib.load(f)
# Both versions must agree for a valid WidgetKit extension installation.
info["CFBundleExecutable"] = "ManzanaExpiryWidget"
info["CFBundleVersion"] = host["CFBundleVersion"]
info["CFBundleShortVersionString"] = host["CFBundleShortVersionString"]
with info_path.open("wb") as f:
    plistlib.dump(info, f)
subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none", str(dst)],
               check=True)
print("Embedded ManzanaExpiryWidget after build. Bundle version:",
      info["CFBundleVersion"], "at", dst)
