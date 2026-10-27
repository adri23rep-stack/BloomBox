#!/usr/bin/env python3
"""Overlay the newly compiled UI on the pinned combined Strata runtime.

All session-navigation changes belong to LiveContainerSwiftUI.framework.
Keep the donor's main runtime, guest extensions and SideStore byte-for-byte.
This produces an IPA to be re-signed by SideStore, not an install-signed app.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import io
import json
import plistlib
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

BRANDED_ROOT_ASSETS = {
    ROOT + 'AppIcon60x60@2x.png': 'AppIcon60x60@2x.png',
    ROOT + 'AppIcon76x76@2x~ipad.png': 'AppIcon76x76@2x~ipad.png',
}
BRANDED_INFO = ROOT + 'Info.plist'
BRANDED_ASSET_CAR = ROOT + 'Assets.car'


def rename_plist(data):
    is_binary = data.startswith(b'bplist00')
    info = plistlib.loads(data)
    info['CFBundleName'] = 'Manzana'
    info['CFBundleDisplayName'] = 'Manzana'
    return plistlib.dumps(info, fmt=plistlib.FMT_BINARY if is_binary else plistlib.FMT_XML)


def is_localized_info(name):
    return name.startswith(ROOT) and name.endswith('.lproj/InfoPlist.strings')



def combine(preview, template_bytes, output, expected_hash=TEMPLATE_SHA256, branding_dir=None):
    if hashlib.sha256(template_bytes).hexdigest() != expected_hash:
        raise ValueError('Combined runtime checksum mismatch')
    branding = Path(branding_dir) if branding_dir is not None else None
    icon_assets = {}
    if branding is not None:
        for entry, filename in BRANDED_ROOT_ASSETS.items():
            data = (branding / filename).read_bytes()
            if not data.startswith(b'\x89PNG\r\n\x1a\n'):
                raise ValueError('Manzana icon PNG missing or invalid: ' + filename)
            icon_assets[entry] = data
    with zipfile.ZipFile(io.BytesIO(template_bytes)) as donor, zipfile.ZipFile(preview) as built:
        for name in REQUIRED:
            if name not in donor.namelist():
                raise ValueError('Combined runtime missing ' + name)
        if BINARY not in built.namelist():
            raise ValueError('Compiled UI framework missing')
        if built.read(BINARY)[:4] not in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'):
            raise ValueError('UI framework is not a Mach-O binary')
        if branding is not None:
            if BRANDED_ASSET_CAR not in built.namelist():
                raise ValueError('Compiled Manzana Assets.car missing')
            source_info = plistlib.loads(built.read(BRANDED_INFO))
            if source_info.get('CFBundleDisplayName') != 'Manzana':
                raise ValueError('Compiled Manzana display name is not correct')
        changed = [entry for entry in built.infolist()
                   if entry.filename.startswith(UI) and '/_CodeSignature/' not in entry.filename]
        with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as result:
            for entry in donor.infolist():
                name = entry.filename
                if name.startswith(UI) or name.startswith(ROOT + '_CodeSignature/'):
                    continue
                data = donor.read(name)
                if branding is not None:
                    if name == BRANDED_INFO or is_localized_info(name):
                        data = rename_plist(data)
                    elif name == BRANDED_ASSET_CAR:
                        data = built.read(BRANDED_ASSET_CAR)
                    elif name in icon_assets:
                        data = icon_assets[name]
                result.writestr(copy.copy(entry), data)
            for entry in changed:
                result.writestr(copy.copy(entry), built.read(entry.filename))
        with zipfile.ZipFile(output) as result:
            if result.testzip() is not None:
                raise ValueError('Corrupt combined archive')
            if result.read(BINARY) != built.read(BINARY):
                raise ValueError('Compiled UI did not reach final IPA')
            # Every donor binary and extension stays bit-identical; only the
            # host branding metadata/icon and fresh compiled UI may differ.
            preserved = 0
            branded = 0
            for entry in donor.infolist():
                name = entry.filename
                if name.startswith(UI) or name.startswith(ROOT + '_CodeSignature/'):
                    continue
                if branding is not None and (name == BRANDED_INFO or
                        name == BRANDED_ASSET_CAR or name in icon_assets or
                        is_localized_info(name)):
                    branded += 1
                    continue
                if result.read(name) != donor.read(name):
                    raise ValueError('Runtime changed unexpectedly: ' + name)
                preserved += 1
            if branding is not None:
                info = plistlib.loads(result.read(BRANDED_INFO))
                if info.get('CFBundleDisplayName') != 'Manzana' or info.get('CFBundleName') != 'Manzana':
                    raise ValueError('Final IPA still contains Strata name')
                if result.read(BRANDED_ASSET_CAR) != built.read(BRANDED_ASSET_CAR):
                    raise ValueError('Manzana icon catalog did not reach IPA')
                for name, data in icon_assets.items():
                    if name in donor.namelist() and result.read(name) != data:
                        raise ValueError('Manzana standalone icon mismatch: ' + name)
        return {'template_sha256': expected_hash, 'preserved_entries': preserved,
                'branded_entries': branded, 'display_name': 'Manzana' if branding else None,
                'icon_catalog_updated': bool(branding),
                'ui_sha256': hashlib.sha256(built.read(BINARY)).hexdigest(),
                'ipa_sha256': hashlib.sha256(Path(output).read_bytes()).hexdigest(),
                'device_tested': False, 'requires_resigning': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('preview')
    parser.add_argument('output')
    parser.add_argument('--template')
    parser.add_argument('--branding-dir', help='Compiled Manzana RGB PNGs; updates host name/icon without changing SideStore binaries')
    args = parser.parse_args()
    if args.template:
        template = Path(args.template).read_bytes()
    else:
        with urllib.request.urlopen(TEMPLATE_URL, timeout=180) as response:
            template = response.read()
    report = combine(args.preview, template, args.output, branding_dir=args.branding_dir)
    Path(args.output + '.verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
