#!/usr/bin/env python3
"""One-time rebrand of the imported Manzana codebase into the BloomBox repository.

Run in the IMPORTED Git worktree. Preserve internal persisted preference keys,
bundle identifiers, Swift type names and original copyright notices so existing
SideStore/LiveContainer installations can still read their data.
"""
from pathlib import Path
import re

root = Path(".")
required = [
    "LiveContainerSwiftUI/Views/Manzana/ManzanaDesktopView.swift",
    "LiveContainerSwiftUI/Views/Manzana/ManzanaAnimatedWallpaper.swift",
    "LiveContainerSwiftUI/Views/Manzana/ManzanaFilesView.swift",
    "ManzanaExpiryWidget/ManzanaExpiryWidget.swift",
    "Vendor/HuskRPPairing/src/lib.rs",
    "LiveContainerSwiftUI/Views/ManzanaOnDevicePairing.swift",
    "LICENSE",
]
for path in required:
    if not (root / path).exists():
        raise SystemExit("Refusing to migrate incomplete or wrong source branch: " + path)

def update(path, fn):
    file = root / path
    if not file.exists():
        raise SystemExit("Missing migration file: " + path)
    old = file.read_text(encoding="utf-8")
    new = fn(old)
    if old != new:
        file.write_text(new, encoding="utf-8")
        print("Rebranded", path)

def name_info(s):
    s = s.replace("<string>Manzana</string>", "<string>BloomBox</string>")
    s = s.replace("<string>Manzana Reminder</string>", "<string>BloomBox Reminder</string>")
    return s
update("LiveContainer/Info.plist", name_info)
update("ManzanaExpiryWidget/Info.plist", name_info)

# Preserve existing AppStorage keys and internal Swift classes for data continuity.
for path in [
    "LiveContainerSwiftUI/Views/ManzanaExpiryReminderCenter.swift",
    "LiveContainerSwiftUI/Views/ManzanaExpiryReminderSettings.swift",
    "ManzanaExpiryWidget/ManzanaExpiryWidget.swift",
    "LiveContainerSwiftUI/Views/LiveBoardJITSetup.swift",
    "LiveContainerSwiftUI/Views/ManzanaOnDevicePairing.swift",
    "LiveContainerSwiftUI/Views/Settings/LCSettingsView.swift",
]:
    def rename_ui(s):
        # Replace only visible UI phrases, not Swift identifiers, settings keys,
        # source identifiers, or persistent file paths.
        return (s.replace("Manzana · SideStore", "BloomBox · SideStore")
                 .replace("Manzana ·", "BloomBox ·")
                 .replace("Prueba de Manzana", "Prueba de BloomBox")
                 .replace("Pair with Manzana", "Pair with BloomBox")
                 .replace("Emparejar con Manzana", "Emparejar con BloomBox")
                 .replace("Start pairing with Manzana", "Start pairing with BloomBox")
                 .replace('Text("Manzana")', 'Text("BloomBox")')
                 .replace('Label("Manzana",', 'Label("BloomBox",')
                 .replace('"Manzana"', '"BloomBox"') if False else
                s.replace("Manzana · SideStore", "BloomBox · SideStore")
                 .replace("Prueba de Manzana", "Prueba de BloomBox")
                 .replace("Pair with Manzana", "Pair with BloomBox")
                 .replace("Emparejar con Manzana", "Emparejar con BloomBox")
                 .replace("Start pairing with Manzana", "Start pairing with BloomBox")
                 .replace('Text("Manzana")', 'Text("BloomBox")')
                 .replace('Label("Manzana",', 'Label("BloomBox",'))
    update(path, rename_ui)

# Strings used only for display. Never rename persisted Manzana* keys.
for file in (root / "LiveContainerSwiftUI" / "Views" / "Manzana").glob("*.swift"):
    update(str(file), lambda s: s.replace('Text("Manzana")', 'Text("BloomBox")')
                                .replace('"Manzana ·', '"BloomBox ·')
                                .replace('"Manzana"', '"BloomBox"'))

# Change the package display name in all translations, including binary plists.
import plistlib
for file in root.rglob("InfoPlist.strings"):
    if not (str(file).startswith("Resources/") or str(file).startswith("LiveContainer/")):
        continue
    original = file.read_bytes()
    try:
        data = plistlib.loads(original)
        if isinstance(data, dict) and ("CFBundleName" in data or "CFBundleDisplayName" in data):
            data["CFBundleName"] = "BloomBox"
            data["CFBundleDisplayName"] = "BloomBox"
            file.write_bytes(plistlib.dumps(data, fmt=plistlib.FMT_BINARY if original.startswith(b"bplist") else plistlib.FMT_XML))
    except Exception:
        for coding in ("utf-8", "utf-16"):
            try:
                txt = original.decode(coding)
                fixed = re.sub(r'(CFBundle(?:Display)?Name\s*=\s*")[^"]*(")', r'\g<1>BloomBox\2', txt)
                if fixed != txt:
                    file.write_bytes(fixed.encode(coding))
                break
            except UnicodeError:
                continue

# Build the same, freshly compiled app; rename/brand only after the IPA has
# been created. No old Strata donor IPA is used as the UI source.
workflow = ".github/workflows/build.yml"
def ci(s):
    s = s.replace("name: Xcode - Build", "name: BloomBox - Build", 1)
    s = re.sub(r"(?m)^      - feature/[^\n]*\n", "", s)
    s = s.replace("    branches:\n", "    branches:\n      - main\n", 1)
    s = s.replace("Scripts/generate-manzana-icon.swift", "Scripts/generate-bloombox-icon.swift")
    s = s.replace("Scripts/brand-manzana-final-ipa.py", "Scripts/brand-bloombox-final-ipa.py")
    s = s.replace("Scripts/verify-manzana-ipa.py", "Scripts/verify-bloombox-ipa.py")
    # Do not publish releases using the inherited AltStore/Strata update job.
    s = s.replace("if: inputs.release__nightly || github.event_name == 'push' && github.ref == format('refs/heads/{0}', github.event.repository.default_branch)", "if: inputs.release__nightly")
    return s
update(workflow, ci)

brand = root / "Scripts/brand-manzana-final-ipa.py"
if brand.exists():
    contents = brand.read_text()
    contents = contents.replace("Manzana", "BloomBox").replace("manzana", "bloombox")
    (root / "Scripts/brand-bloombox-final-ipa.py").write_text(contents)
    brand.unlink()

verify = root / "Scripts/verify-manzana-ipa.py"
if verify.exists():
    contents = verify.read_text()
    # Do not alter the internal Swift file and setting names being checked.
    contents = contents.replace('host.get("CFBundleName") != "Manzana"', 'host.get("CFBundleName") != "BloomBox"')
    contents = contents.replace('host.get("CFBundleDisplayName") != "Manzana"', 'host.get("CFBundleDisplayName") != "BloomBox"')
    contents = contents.replace("Wrong app! Latest Manzana display name", "Wrong app! BloomBox display name")
    contents = contents.replace("Manzana RGB app icon", "BloomBox app icon")
    contents = contents.replace("Validated {ipa.name}", "BloomBox verified: {ipa.name}")
    (root / "Scripts/verify-bloombox-ipa.py").write_text(contents)
    verify.unlink()

readme = """# BloomBox 🌸

**BloomBox** is an independent iOS launcher and app-container project developed from the
Manzana project. It combines an iPhone-style desktop, customizable app icons and pages,
Liquid Glass controls, GIF/video wallpapers, file management, experimental guest-app JIT
and SideStore expiration reminders in the Dynamic Island.

## Highlights

- Custom desktop with icon layout, folders, pages, dock, widget gallery and Liquid Glass
- Animated GIF and muted-loop video wallpapers
- Built-in file management and multi-app LiveContainer runtime
- Optional, **experimental** on-device JIT pairing using LocalDevVPN
- Live Activity reminder for SideStore expiration at the 8-hour threshold
- Manual **3-minute Dynamic Island test** in app Settings

JIT activation is **not guaranteed** on iOS 27 merely because a build succeeds.
Live Activities and permissions must also be tested on a physical iPhone.

## Builds and installation

Go to [GitHub Actions](https://github.com/adri23rep-stack/BloomBox/actions)
for the unsigned `LiveContainer+SideStore.ipa` build artifact.
Install using SideStore with all app extensions retained. To preserve existing local
data when updating Manzana, use the same developer team, signing identity and bundle
identifier; back up guest apps and settings before changing profiles.

The source code uses some historical `Manzana*`, `Strata*` and `LiveContainer*`
class, preference and executable names to maintain compatibility. **The installed
application is branded BloomBox.** These internal names do not imply that future
development happens in the old repositories.

## Attribution and license

BloomBox is a separate GitHub repository and development project, **not a claim of
entirely original code**. It derives from
[Manzana](https://github.com/adri23rep-stack/Manzana), itself developed from
[Strata](https://github.com/huzaifahshahid71-ops/Strata) and
[LiveContainer](https://github.com/LiveContainer/LiveContainer).

Existing authors' copyright notices, commit history, third-party notices and
[AGPL-3.0 license](LICENSE) are retained. The on-device JIT pairing code includes
GPL-2.0-or-later components adapted from [Husk](https://github.com/Leviidev/Husk).
SideStore and the corresponding signing infrastructure belong to their respective
projects. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Legacy migration

The source was imported with history from the fully featured
`feature/manzana-v011-jit-expiry-8h` branch of Manzana. The old repository is
kept only as an archive/reference; new development should target BloomBox.
"""
(root / "README.md").write_text(readme)
(root / "BLOOMBOX_MIGRATION.md").write_text("""# BloomBox migration

- Source: adri23rep-stack/Manzana
- Source branch: feature/manzana-v011-jit-expiry-8h
- New destination: adri23rep-stack/BloomBox (standalone repository)
- Original commit ancestry preserved with an unrelated-history merge
- Original copyright / AGPL-3.0 / third-party notices preserved
- UI branded BloomBox; persisted Manzana/Strata/LiveContainer identifiers intentionally
  retained to protect compatibility with already installed apps and saved settings
- The old repository is not modified by this migration

Do not restore the legacy donor-overlay pipeline in new development: build the
current source and ship the combined SideStore runtime with all extensions.
""")

(root / "Scripts/generate-manzana-icon.swift").unlink(missing_ok=True)
for legacy in (
    ".github/workflows/session-preview.yml",
    ".github/workflows/publish-manzana-v0.1.1-alpha.yml",
):
    (root / legacy).unlink(missing_ok=True)
print("BloomBox rebrand applied. Original internal classes and user data keys preserved.")
