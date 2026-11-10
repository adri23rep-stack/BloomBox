# GameBox Playnite theme bridge (experimental)

## Current status

This branch adds an **opt-in, native Nintendo Switch-inspired GameBox skin** alongside the existing Liquid Glass skin.

- In GameBox, open the ellipsis menu > **GameBox theme** > **Nintendo Switch-ish · Beta**.
- Toggle back to **GameBox · Liquid Glass** at any time.
- Preference is kept in `BloomBoxGameBoxThemeID` (value `glass` or `switch-ish`).
- The GameBox host still owns installed apps, JIT, RAM+, game launching, profiles and controllers. The skin only changes appearance.
- Does not modify the Home desktop, theme store (.bbtheme), app containers, signers or update mechanisms.

## Playnite compatibility limits

Playnite's fullscreen themes use WPF/XAML. iOS/SwiftUI **cannot execute XAML directly**. The Switch-ish variant is a native first pass, **not yet an importer for Playnite .pthm files** or a pixel-perfect port.

Proposed follow-on phases:

1. **Theme packaging**: build a bounded decoder for `.pthm` (ZIP), rejecting unsafe paths, symlinks, excessive file counts, and expanded-size bombs; never execute scripts, plugins or XML actions.
2. **Visual converter**: whitelist image assets, manifest fields, supported colors and spacing; map known layout families into native SwiftUI components. Unsupported visual properties get a clear warning; never claim 100% conversion.
3. **Theme browser**: import, preview, apply/revert, remove themes inside GameBox without changing the desktop; create a recovery path.
4. **Community catalog**: signed or checksum-verified manifests with author credits, licenses and user-triggered downloads. No automatic external code execution.

## Acknowledgments and trademark note

Visual reference: [Nintendo-Switch-ish](https://github.com/davidkgriggs/Nintendo-Switch-ish) by davidkgriggs, an independent Playnite fullscreen theme. No upstream artwork or XAML is redistributed in this first native skin.

The Nintendo Switch name and appearance are associated with Nintendo; this is an unofficial, independently developed GameBox presentation option and is not affiliated with or endorsed by Nintendo or Playnite.

## Validation checklist

- Build with Xcode in a GitHub Actions macOS runner.
- Start GameBox on iPhone landscape; select both skins and relaunch to verify persistence.
- Check icons, selection, favorites, long-press and free scrolling.
- Verify opening a regular app, a JIT-required game, changing profile, DualSense panel and both SAFE graphics modes.
- Check small landscape viewport, VoiceOver and Reduce Motion.
- Confirm Home/Desktop, other themes, apps and storage remain unchanged.

No merge or release should occur until actual device validation.
