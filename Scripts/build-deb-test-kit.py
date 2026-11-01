#!/usr/bin/env python3
"""Build an IPA + Debian tweak test kit on a macOS Xcode runner."""
import hashlib
import io
from pathlib import Path
import plistlib
import subprocess
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "deb-test-kit"
OUTPUT.mkdir(exist_ok=True)
SDK = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
CLANG = ["xcrun", "--sdk", "iphoneos", "clang", "-arch", "arm64", "-isysroot", SDK,
         "-miphoneos-version-min=15.0", "-fobjc-arc", "-fmodules",
         "-framework", "UIKit", "-framework", "Foundation"]
APP = OUTPUT / "Payload" / "BloomBoxDebTest.app"
APP.mkdir(parents=True, exist_ok=True)
BIN = APP / "BloomBoxDebTest"
LIB = OUTPUT / "BloomBoxDebProbe.dylib"
subprocess.run(CLANG + [str(ROOT / "Tests/deb-kit/TestApp.m"), "-o", str(BIN)], check=True)
subprocess.run(CLANG + [str(ROOT / "Tests/deb-kit/DebProbe.m"), "-dynamiclib",
                        "-Wl,-install_name,@rpath/BloomBoxDebProbe.dylib",
                        "-o", str(LIB)], check=True)

info = {
    "CFBundleDevelopmentRegion": "en",
    "CFBundleExecutable": "BloomBoxDebTest",
    "CFBundleIdentifier": "dev.bloombox.debtest",
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": "BloomBoxDebTest",
    "CFBundleDisplayName": "DEB Test",
    "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": "1.0",
    "CFBundleVersion": "1",
    "CFBundleSupportedPlatforms": ["iPhoneOS"],
    "LSRequiresIPhoneOS": True,
    "MinimumOSVersion": "15.0",
    "UIDeviceFamily": [1, 2],
    "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
}
with (APP / "Info.plist").open("wb") as stream:
    plistlib.dump(info, stream)
subprocess.run(["codesign", "--force", "--sign", "-", "--timestamp=none", str(APP)], check=True)

ipa = OUTPUT / "BloomBoxDebTest.ipa"
with zipfile.ZipFile(ipa, "w", zipfile.ZIP_DEFLATED) as target:
    for path in APP.rglob("*"):
        if path.is_file():
            target.write(path, str(path.relative_to(OUTPUT)))
with zipfile.ZipFile(ipa) as archive:
    if archive.testzip() is not None:
        raise SystemExit("IPA is corrupt")

def mk_tar(files):
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode="w:gz") as package:
        for path, contents in files:
            item = tarfile.TarInfo(name="./" + path)
            item.size = len(contents)
            item.mtime = 0
            item.mode = 0o644
            package.addfile(item, io.BytesIO(contents))
    return data.getvalue()

def make_deb(path, files):
    control = (b"Package: dev.bloombox.debprobe\n"
               b"Name: BloomBox DEB Test\n"
               b"Version: 1.0\n"
               b"Architecture: iphoneos-arm64\n"
               b"Maintainer: BloomBox Test Kit\n"
               b"Description: Safe self-contained tweak injection test\n")
    members = [
        ("debian-binary", b"2.0\n"),
        ("control.tar.gz", mk_tar([("control", control)])),
        ("data.tar.gz", mk_tar(files)),
    ]
    with path.open("wb") as dest:
        dest.write(b"!<arch>\n")
        for name, contents in members:
            label = (name + "/").ljust(16).encode("ascii")
            header = (label + b"0".ljust(12) + b"0".ljust(6) + b"0".ljust(6)
                      + b"100644".ljust(8) + str(len(contents)).encode().ljust(10) + bytes([96, 10]))
            assert len(header) == 60, len(header)
            dest.write(header)
            dest.write(contents)
            if len(contents) % 2:
                dest.write(b"\n")

base = "Library/MobileSubstrate/DynamicLibraries/BloomBoxDebProbe"
filter_plist = plistlib.dumps({"Filter": {"Bundles": ["dev.bloombox.debtest"]}})
deb = OUTPUT / "BloomBoxDebProbe.deb"
make_deb(deb, [(base + ".dylib", LIB.read_bytes()), (base + ".plist", filter_plist)])
# Deliberately malicious fixture: the importer must reject the entire package.
make_deb(OUTPUT / "UnsafeTraversalFixture.deb",
         [("../../escape.dylib", LIB.read_bytes())])
for item in [ipa, deb]:
    print(item.name, item.stat().st_size, hashlib.sha256(item.read_bytes()).hexdigest())
print("No external IPA or tweak binaries were downloaded.")
