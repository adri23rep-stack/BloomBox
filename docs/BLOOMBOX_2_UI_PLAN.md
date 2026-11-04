# BloomBox 2.0 — UI and release plan

Status: **work in progress / preview branch only**. Target: `v2.0.0` after validation; no production release or merge authorized by this document.

## Product direction

BloomBox should feel like a standalone, approachable iPhone launcher and app container, not a technical front end for LiveContainer. Keep the familiar desktop and user-selected appearance while simplifying discovery.

Design principles:

- **Fast and calm:** smooth paging, short transitions, conservative live blur and shadows; never sacrifice touch responsiveness.
- **User-controlled:** Liquid Glass is optional. The **Modules** area uses translucent *color* surfaces rather than Liquid Glass, as requested.
- **Visible actions:** installation, storage, connectivity, RAM+, JIT and app data management must be easy to locate.
- **Consistent:** shared card rhythm, typography, icons, margins and navigation across the desktop, Modules, App Store, Tweak Store and Settings.
- **Accessible:** Dynamic Type, Reduce Motion, high-contrast readability and clear controls.
- **No regressions:** protect the current SideStore session, guest app data, RAM+ validation and JIT setup and launch paths.

## Planned workstreams

### A — Home / desktop

1. Polish page transitions, gesture thresholds, widget-to-library navigation and Dock visibility without changing iOS system gestures.
2. Consistent edit-mode labels, edit controls, folders and icon feedback. Preserve dragging and custom pages.
3. Keep motion wallpaper and Liquid Glass optional, with Reduce Motion and game-performance fallback.
4. Show installation progress and installed app appearance without requiring a restart.
5. NoDesk remains a user choice, not a new default.

### B — Modules

1. Accessible responsive cards, consistent icons and colored translucent surfaces (**not** Liquid Glass).
2. Inline **real** status for RAM+ where the code can verify it; never fake JIT/RAM+ success.
3. JIT panel fully visible inside its module; Desktop shortcuts for Interface / Wallpaper / Apps.
4. Connectivity per-app switches and unmistakable no-internet indicators.
5. Experiments visually separated from stable features, with safety explanations.

### C — App Store / Tweak Store

1. Unified, lightweight storefront headers and cards with clear app/developer metadata.
2. Install, Installed, Release, and third-party warning states made easy to tell apart.
3. Keep remote catalogs: BloomBox does not redistribute external IPAs, ROMs, keys or tweaks.
4. SHA-256 confirms exact release bytes, not that the publisher is trustworthy.

### D — Settings and first-run usability

1. Group settings by interface, installed apps and storage, modules, security and advanced/experimental controls.
2. Make import/export backups and storage consumption discoverable.
3. Short explanations in Spanish without jargon; preserve existing English localization.

## Release gates

- Every UI change stays on a feature branch; `main` remains untouched until review.
- GitHub Actions **Build** must succeed and produce an installable test artifact.
- On-device acceptance on iPhone 14 Pro / iOS 27: cold launch, install/open a guest app, SideStore sign-in, RAM+ status, JIT setup, per-app internet switches, widgets, Dock, library, app stores, data persistence, light/dark appearance and orientation.
- Performance and storage check; avoid unexplained storage growth and forced app restarts.
- All known critical regressions either fixed or explicitly documented before `v2.0.0`.
- After user approval: merge the validated PR(s) to `main`, tag `v2.0.0`, attach the build and publish release notes **in English**.

## First patch in this branch

- Responsive one/two-column Modules tiles depending on Dynamic Type size.
- Lightweight translucent color tile treatment and genuine RAM+ status display.
- Shared visual header component for App Store and Tweak Store.
- Spanish “Editar” label on the desktop.

This is a **foundation**, not the finished 2.0 redesign. Keep experimental .deb support, unverified Wii U keys, and unrelated pending PRs out of the release until reviewed separately.
