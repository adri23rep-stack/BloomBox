#!/usr/bin/env python3
"""Brand an entirely NEW BloomBox IPA, preserving the latest native JIT + WidgetKit.

This post-processing step does not overlay an old Strata donor app. It modifies
only localized display names and icon PNGs inside the freshly compiled app.
SideStore remains responsible for final signing on the device.
"""
import argparse
import os
import pathlib
import plistlib
import tempfile
import zipfile

ROOT = "Payload/LiveContainer.app/"
ICON_FILES = ("AppIcon60x60@2x.png", "AppIcon76x76@2x~ipad.png")


def translated_name(data: bytes) -> bytes:
    binary = data.startswith(b"bplist00")
    try:
        values = plistlib.loads(data)
    except plistlib.InvalidFileException:
        # Xcode may copy .strings files as UTF-8 instead of compiling them.
        # Only accept our exact controlled source format; reject unexpected
        # strings syntax rather than silently dropping localized information.
        expected = '"CFBundleName" = "BloomBox";'
        if data.decode("utf-8-sig").strip() != expected:
            raise ValueError("Unexpected uncompiled InfoPlist.strings format")
        values = {"CFBundleName": "BloomBox"}
        binary = True
    values["CFBundleName"] = "BloomBox"
    values["CFBundleDisplayName"] = "BloomBox"
    return plistlib.dumps(values, fmt=plistlib.FMT_BINARY if binary else plistlib.FMT_XML)


def brand(ipa: pathlib.Path, assets: pathlib.Path):
    new_icons = {}
    for name in ICON_FILES:
        icon = assets / name
        data = icon.read_bytes()
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError(f"BloomBox RGB icon missing/invalid: {icon}")
        new_icons[ROOT + name] = data
    # SwiftUI's source phrases must be available in the actual signed host
    # bundle. Xcode's file-synchronized resources may otherwise leave out the
    # hand-maintained en.lproj table (or package a stale one).
    english_table = pathlib.Path("Resources/en.lproj/Localizable.strings").read_bytes()
    if english_table.count(b" = ") < 700:
        raise ValueError("The BloomBox English localization table is incomplete")
    english_target = ROOT + "en.lproj/Localizable.strings"
    fd, tmp = tempfile.mkstemp(prefix="manzana-build-", suffix=".ipa", dir=str(ipa.parent))
    os.close(fd)
    try:
        with zipfile.ZipFile(ipa) as src, zipfile.ZipFile(tmp, "w") as out:
            names = set(src.namelist())
            assert ROOT + "Info.plist" in names
            assert ROOT + "Frameworks/LiveContainerSwiftUI.framework/LiveContainerSwiftUI" in names
            assert ROOT + "PlugIns/ManzanaExpiryWidget.appex/ManzanaExpiryWidget" in names
            for entry in src.infolist():
                name = entry.filename
                data = src.read(name)
                if name == ROOT + "Info.plist":
                    data = translated_name(data)
                elif name.startswith(ROOT) and name.endswith(".lproj/InfoPlist.strings"):
                    data = translated_name(data)
                elif name in new_icons:
                    data = new_icons[name]
                elif name == english_target:
                    data = english_table
                out.writestr(entry, data)
            if english_target not in names:
                out.writestr(english_target, english_table)
        with zipfile.ZipFile(tmp) as check:
            if check.testzip() is not None:
                raise ValueError("Corrupt branded IPA")
            info = plistlib.loads(check.read(ROOT + "Info.plist"))
            if info.get("CFBundleDisplayName") != "BloomBox" or info.get("CFBundleName") != "BloomBox":
                raise ValueError("BloomBox branding is missing in the IPA")
            if check.read(english_target) != english_table:
                raise ValueError("Packaged BloomBox English phrases are missing or outdated")
            if not info.get("NSSupportsLiveActivities"):
                raise ValueError("ActivityKit disabled in final host Info.plist")
            for name, data in new_icons.items():
                if name in check.namelist() and check.read(name) != data:
                    raise ValueError("BloomBox RGB icon missing in final app")
        os.replace(tmp, ipa)
        print("Verified BloomBox display name, localized names, RGB icon, live activities and original compiled app.")
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=pathlib.Path)
    parser.add_argument("--branding-dir", default="Resources/Branding", type=pathlib.Path)
    args = parser.parse_args()
    brand(args.ipa, args.branding_dir)
