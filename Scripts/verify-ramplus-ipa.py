#!/usr/bin/env python3
"""Fail CI if the unsigned test IPA cannot request RAM+ when SideStore signs it.

The app-id capability, provisioning profile and installed process entitlement are
separate stages. This only checks the *source* Mach-O entitlement request; it
cannot claim that Apple approved or that a device has the permission.
"""
import argparse
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import zipfile

RAM_KEY = "com.apple.developer.kernel.increased-memory-limit"
TARGETS = ("Payload/LiveContainer.app", "Payload/LiveContainer.app/PlugIns/LiveProcess.appex")


def requested_entitlements(ipa: zipfile.ZipFile, target: str, work: pathlib.Path) -> dict:
    info = plistlib.loads(ipa.read(f"{target}/Info.plist"))
    name = info["CFBundleExecutable"]
    member = f"{target}/{name}"
    if member not in ipa.namelist():
        raise ValueError(f"Missing executable: {member}")
    destination = work / pathlib.Path(member).name
    destination.write_bytes(ipa.read(member))
    result = subprocess.run(["ldid", "-e", str(destination)], capture_output=True, check=False)
    if result.returncode:
        raise ValueError(f"Cannot inspect code signature of {member}: {result.stderr.decode(errors='replace')[:250]}")
    data = result.stdout.strip()
    try:
        entitlements = plistlib.loads(data)
    except (ValueError, TypeError, plistlib.InvalidFileException) as exc:
        raise ValueError(f"Missing or unreadable signed entitlements for {member}") from exc
    if not isinstance(entitlements, dict):
        raise ValueError(f"Entitlements are not a dictionary: {member}")
    return entitlements


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa", type=pathlib.Path)
    args = parser.parse_args()
    try:
        with zipfile.ZipFile(args.ipa) as ipa, tempfile.TemporaryDirectory() as temporary:
            for number, target in enumerate(TARGETS):
                work = pathlib.Path(temporary) / str(number)
                work.mkdir()
                entitlements = requested_entitlements(ipa, target, work)
                if entitlements.get(RAM_KEY) is not True:
                    raise ValueError(f"{target}: {RAM_KEY} is not explicitly true in signed source")
                print(f"RAM+ IPA request OK: {target}")
    except (OSError, KeyError, ValueError, zipfile.BadZipFile) as exc:
        print(f"RAM+ IPA request FAILED: {exc}", file=sys.stderr)
        return 1
    print("RAM+ source requests verified. Apple approval and installed signatures still require device tests.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
