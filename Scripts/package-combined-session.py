#!/usr/bin/env python3
"""Overlay the newly compiled UI on the pinned combined Strata runtime.

All session-navigation changes belong to LiveContainerSwiftUI.framework.
Keep the donor's main runtime, guest extensions and SideStore byte-for-byte.
This produces an IPA to be re-signed by SideStore, not an install-signed app.
"""
from pathlib import Path
import argparse
import hashlib
import io
import json
import urllib.request
import zipfile

TEMPLATE_URL = 'https://github.com/huzaifahshahid71-ops/Strata/releases/download/v3.8.11-r11/Strata%2BSideStore-3.8.11-r11.ipa'
TEMPLATE_SHA256 = '2bf47ba4ce23714aa88c82e9aec33000747e9895fee70c9bf46f33cbecfad802'
ROOT = 'Payload/LiveContainer.app/'
UI = ROOT + 'Frameworks/LiveContainerSwiftUI.framework/'
BINARY = UI + 'LiveContainerSwiftUI'
REQUIRED = [ROOT + 'LiveContainer', ROOT + 'PlugIns/LiveProcess.appex/LiveProcess',
            ROOT + 'Frameworks/SideStoreApp.framework/SideStore',
            ROOT + 'Frameworks/SideStoreSupport.framework/SideStoreSupport',
            ROOT + 'PlugIns/LiveWidgetExtension.appex/LiveWidgetExtension']


def combine(preview, template_bytes, output, expected_hash=TEMPLATE_SHA256):
    if hashlib.sha256(template_bytes).hexdigest() != expected_hash:
        raise ValueError('Combined runtime checksum mismatch')
    with zipfile.ZipFile(io.BytesIO(template_bytes)) as donor, zipfile.ZipFile(preview) as built:
        for name in REQUIRED:
            if name not in donor.namelist():
                raise ValueError('Combined runtime missing ' + name)
        if BINARY not in built.namelist():
            raise ValueError('Compiled UI framework missing')
        if built.read(BINARY)[:4] not in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'):
            raise ValueError('UI framework is not a Mach-O binary')
        changed = [entry for entry in built.infolist()
                   if entry.filename.startswith(UI) and '/_CodeSignature/' not in entry.filename]
        with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as result:
            for entry in donor.infolist():
                if entry.filename.startswith(UI) or entry.filename.startswith(ROOT + '_CodeSignature/'):
                    continue
                result.writestr(entry, donor.read(entry.filename))
            for entry in changed:
                result.writestr(entry, built.read(entry.filename))
        with zipfile.ZipFile(output) as result:
            if result.testzip() is not None:
                raise ValueError('Corrupt combined archive')
            if result.read(BINARY) != built.read(BINARY):
                raise ValueError('Compiled UI did not reach final IPA')
            # Check every preserved file, not just the SideStore executable.
            preserved = 0
            for entry in donor.infolist():
                if entry.filename.startswith(UI) or entry.filename.startswith(ROOT + '_CodeSignature/'):
                    continue
                if result.read(entry.filename) != donor.read(entry.filename):
                    raise ValueError('Runtime changed unexpectedly: ' + entry.filename)
                preserved += 1
        return {'template_sha256': expected_hash, 'preserved_entries': preserved,
                'ui_sha256': hashlib.sha256(built.read(BINARY)).hexdigest(),
                'ipa_sha256': hashlib.sha256(Path(output).read_bytes()).hexdigest(),
                'device_tested': False, 'requires_resigning': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('preview')
    parser.add_argument('output')
    parser.add_argument('--template')
    args = parser.parse_args()
    if args.template:
        template = Path(args.template).read_bytes()
    else:
        with urllib.request.urlopen(TEMPLATE_URL, timeout=180) as response:
            template = response.read()
    report = combine(args.preview, template, args.output)
    Path(args.output + '.verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
