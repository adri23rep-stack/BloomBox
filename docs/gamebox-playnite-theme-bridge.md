# GameBox × Playnite: original theme import roadmap

Status: **planned**, not implemented. Working branch: feature/gamebox-playnite-theme-bridge-20261109. No changes to main or public release.

## Goal and important limitation

Import the **original Playnite Fullscreen .pthm package** into GameBox without manually recreating each theme. Playnite themes use WPF/XAML layouts, not SwiftUI; iOS cannot directly execute them. We will read the original assets and a **supported subset** of XAML, translate them into native GameBox UI, and clearly report anything that cannot be converted. Visual fidelity cannot be guaranteed for every theme; unsafe code and Playnite plugins will never run on iOS.

## Milestone 0 — UI proof of concept (already committed)

- [x] Optional native Nintendo Switch-inspired GameBox styling and selection; Liquid Glass stays default.
- [ ] Verify iPhone landscape build and device behavior.
- NOTE: this first native skin is **not** yet a Playnite importer.

## Milestone 1 — Secure .pthm import from Files

- [ ] Add GameBox > Themes > Import Playnite theme. Do not mix with desktop .bbtheme import.
- [ ] Read original .pthm archive; put all extracted data in a private folder.
- [ ] Validate size, item count and paths; reject directory traversal, symlinks, duplicate archive entries, excessive decompression, scripts and executable code.
- [ ] Parse theme.yaml (Id, Name, Author, Version, Mode, ThemeApiVersion and Links). First support Fullscreen mode.
- [ ] Extract safe images, resources and XAML documents. Preserve attribution, version, provenance and license. Do not alter the source package.
- [ ] Show a theme preview before user confirms Apply; support Remove and Revert.

**Acceptance:** unmodified official Nintendo Switch-ish v2.0 .pthm imported from Files, inspected and saved. Bad packages rejected with friendly messages.

## Milestone 2 — General native layout translator

- [ ] Securely parse approved XAML without executing code, external XML entities, scripts, event handlers or arbitrary resources.
- [ ] Interpret a supported layout subset: Grid, StackPanel, Border, Image, TextBlock, ItemsControl, Buttons, brushes, styles, spacing, resources and simple state animations.
- [ ] Resolve recognized game data references to GameBox-owned fields (game title, icon, cover, background, favorite, selection). Host controls launching, JIT, RAM+, profiles and controller operations.
- [ ] Render native SwiftUI views from the parsed theme tree, **not a one-off hardcoded replica**.
- [ ] Respect landscape size, battery, low memory, Reduce Motion and safe graphics.
- [ ] Report unsupported components and plugin dependencies; keep a fallback UI with one-tap revert.

**Acceptance:** visual hierarchy, assets and colors for the first theme come from its original imported package; no manual recreation of that individual theme.

## Milestone 3 — Community catalog and direct downloading

- [ ] Create GameBox > Themes > Playnite Community with preview cards, author/license, version and compatibility grade.
- [ ] Research/use the public Playnite add-on catalog and installer manifests subject to their documented terms and available endpoints.
- [ ] Support HTTPS direct-link installs from public .pthm URLs / GitHub releases (no PC transfer).
- [ ] Download > Validate > Preview > Apply with explicit confirmation; no hidden code execution or silent activation.
- [ ] Cache packages safely; cap storage; offer uninstall, update and rollback.
- [ ] Validate publisher-provided hashes if available; do not claim cryptographic trust when unavailable.

**Acceptance:** browse or paste a supported theme link directly in BloomBox, install and apply without manually copying/rebuilding it.

## Milestone 4 — Broader Playnite themes and quality

- [ ] Test multiple structurally different Fullscreen themes, not just Nintendo Switch-ish.
- [ ] Expand layout, resource and animations support based on repeated patterns; classify unsupported cases honestly.
- [ ] Plugins such as DKG Theme Modifier, Extra Metadata Loader and SuccessStory are NOT executed on iOS; adapt only their safe visual fallbacks.
- [ ] Regression-test GameBox launch/JIT/RAM+, user profiles, DualSense/Nikaido, SAFE mode, memory pressure, low storage, localization, VoiceOver and Reduce Motion.
- [ ] Require a passing GitHub Actions build and real-device tests before any merge or release.

## First test package (public — user upload NOT required)

- Theme: Nintendo Switch-ish by David Griggs (MIT license; preserve copyright and MIT text on reuse).
- Source: https://github.com/davidkgriggs/Nintendo-Switch-ish
- Official original Fullscreen v2.0 .pthm: https://github.com/davidkgriggs/Nintendo-Switch-ish/releases/download/v2.0.0/Nintendo_Switch-ish_0d020ed5-0f3c-4c1a-bf9a-c983ef7d74b7_2_0_0.pthm
- Installer manifest: https://github.com/davidkgriggs/Nintendo-Switch-ish/blob/main/Manifests/Installer_Manifest.yaml
- Source theme.yaml: https://github.com/davidkgriggs/Nintendo-Switch-ish/blob/main/source/theme.yaml

## What the user should send

1. **Nintendo Switch-ish:** nothing else needed to locate the public theme.
2. **Another theme:** send the theme page, GitHub release, or direct .pthm link. One link is enough if public.
3. **Private/unlisted theme:** upload original .pthm (not unpacked) instead.
4. **Optional:** screenshot/video of actual Playnite appearance to assess conversion accuracy, plus desired priorities.

Never need passwords, accounts, GitHub tokens or remote PC access.

## References

- https://api.playnite.link/docs/tutorials/themes/manifestFile.html
- https://api.playnite.link/docs/tutorials/themes/distributionAndUpdates.html
- https://api.playnite.link/docs/tutorials/toolbox.html
- https://api.playnite.link/docs/tutorials/themes/manualEditing.html
- https://api.playnite.link/docs/manual/features/themesSupport/installingThemes.html
