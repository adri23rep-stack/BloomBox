# GameBox v2 — CardsNX-style console presentation

GameBox v2 is implemented as a standalone BloomBox SwiftUI view, mounted by the existing LiveContainer guest adapter. **The underlying app launcher, signing, JIT and guest orientation flows are unchanged.**

## Visual reference

Reference: [HomeNX / CardsNX](https://github.com/ad3333m/homenx), especially the `projects/cards` presentation and publicly shown screenshots. The interface follows the same layout language: a horizontal row of large app icons, a blurred background for the **selected** game, round translucent toolbar icons, a compact status capsule, and a glass bottom panel with Play and game-specific options.

This branch uses original SwiftUI presentation code. No CardsNX binaries, source files, logos, screenshots or bundled game artwork are imported. The developer permission letter can be published separately when supplied.

## What ships on this branch

- Full-width **free-scrolling icon row** (no poster cards or names over the icons), with a subtle highlight on the selected icon. Scrolling is independent of selection: **only tapping an icon** changes the active game in the bottom panel.
- No snap-to-center, ScrollViewReader, or scroll-position binding. Smooth momentum is provided by the system scroll view; an additional light haptic fires once per drag, and a short selection click plays when the user actually chooses a different app.
- Double-tap an icon to toggle favorite; JIT is a small badge on the app icon. The bottom panel alone displays the selected app name and launch details.
- Per-game cover and background selection from Photos **or Files**, stored outside guest app bundles.
- Bounded image decoding and 40 MB in-memory art-cache target to avoid abrupt memory growth.
- Battery/time/free-space status, favorites, launch with host JIT, and the host's existing app-management routes.
- Two **visual-only** controller icons (`BloomBoxNikaidoControllerSlot`), deliberately not interactive. Future controller logic should live behind a Nikaido bridge, not be embedded in this view.
- Full Home mode remains the boot default.

## Automatic backgrounds: selected games and emulator platforms

GameBox can now look up the **selected** app's background automatically, with a
brief debounce so scrolling over dozens of icons does not trigger dozens of
network requests. Users can disable automatic backgrounds from an app's option
menu, search again, remove only downloaded art, or open the original source.

Priority (highest first):

1. Manually chosen background from Photos or Files.
2. Manually chosen cover image.
3. Cached automatic background in separate `autoGameBox` mode.
4. Existing app icon against GameBox's gradient if there is no confident result.

For games, the no-API-key Steam Store search is used only when an **exact game
title** matches (a few known port aliases are explicit). A wider Steam library
hero is preferred; the Steam detail header is a fallback. For known emulators
(DolphiniOS, MeloNX, MeloCafe, PPSSPP, etc.) a Wikimedia PageImages query for
the **emulated console's article** requests only freely licensed images. This
does **not** imply the emulator itself ships a specific game. Its source/link to
the image license is retained for users to open.

Privacy and safety: no app bundle ID, JIT credentials, installed-game list,
guest path, signing material or private data is sent in network requests.
Only a recognized selected title or a generic console topic is queried. URL
hosts and redirects are validated, downloaded images have a 12 MB limit, and
decoded images are downsampled. Missing/ambiguous results are cached as an
attempt for 24 hours; the app never chooses a merely similar game at random.
A manual background is never overwritten. No external copyrighted image is
bundled into a release.

Remote services are online dependencies and may stop responding or change
their public interfaces. The original local fallback always remains usable.

## Crash recovery and diagnostics

The local, opt-in-to-export journal lives in the app-group folder `Library/BloomBoxDiagnostics/`:

- `events.log`: GameBox/host lifecycle breadcrumbs with timestamps and PIDs, without guest paths or identifiers.
- `liveprocess.log`: cross-process guest boot milestones, including private-access failures and entry into the original LiveContainer launcher.
- `metric-*.json`: up to eight available native MetricKit diagnostic payloads, retained for on-device review and explicitly exported if desired.

The app marks GameBox visible on entering it and clears that marker on returning to Home/background. A subsequent host launch after an unfinished foreground GameBox session enters **graphic safe mode**, boots to ordinary Home, and offers **Diagnósticos y recuperación**. Safe mode disables custom artwork and its expensive blur; users can disable the safe-mode toggle after troubleshooting.

**Limits:** an unfinished session can result from force-quit or iOS termination as well as a crash; it is not proof of one. A sudden native fault cannot always execute code that writes its own stack. MetricKit can supply exception/signal/stack diagnostics when the OS has captured them. Keep these facts separate in bug reports. Never automatically upload private logs.

## Verification

- Run `Tests/reserved-section/test_contract.py` to guard the bridge, recovery and UI layout anchors.
- Confirm GitHub Actions produces an archive.
- On-device iOS 27: test normal launch/return, JIT-required guest, import of 20 MB and oversized artwork, fast free swiping without changing selection until tap, background/foreground, and simulated termination (user force quit) to verify conservative recovery.
- Do not merge PR until a stable device build has been exercised with real apps.
