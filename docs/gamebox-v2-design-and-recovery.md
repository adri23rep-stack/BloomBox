# GameBox v2 — CardsNX-style console presentation

GameBox v2 is implemented as a standalone BloomBox SwiftUI view, mounted by the existing LiveContainer guest adapter. **The underlying app launcher, signing, JIT and guest orientation flows are unchanged.**

## Visual reference

Reference: [HomeNX / CardsNX](https://github.com/ad3333m/homenx), especially the `projects/cards` presentation and publicly shown screenshots. The interface follows the same layout language: a horizontal poster carousel, blurred selected-game background, round translucent toolbar icons, a compact status capsule, and a glass bottom panel with Play and game-specific options.

This branch uses original SwiftUI presentation code. No CardsNX binaries, source files, logos, screenshots or bundled game artwork are imported. The developer permission letter can be published separately when supplied.

## What ships on this branch

- Landscape carousel with safe centering at both ends and a highlighted selected card.
- Per-game cover and background selection from Photos **or Files**, stored outside guest app bundles.
- Bounded image decoding and 40 MB in-memory art-cache target to avoid abrupt memory growth.
- Battery/time/free-space status, favorites, launch with host JIT, and the host's existing app-management routes.
- Two **visual-only** controller icons (`BloomBoxNikaidoControllerSlot`), deliberately not interactive. Future controller logic should live behind a Nikaido bridge, not be embedded in this view.
- Full Home mode remains the boot default.

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
- On-device iOS 27: test normal launch/return, JIT-required guest, import of 20 MB and oversized artwork, rapid card switching, background/foreground, and simulated termination (user force quit) to verify conservative recovery.
- Do not merge PR until a stable device build has been exercised with real apps.
