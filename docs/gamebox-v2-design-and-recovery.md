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
A manual background is never overwritten. Curated public-domain photographs
are downloaded at runtime, not bundled as copyrighted release assets.

Remote services are online dependencies and may stop responding or change
their public interfaces. The original local fallback always remains usable.

### Curated app identification via BloomBox-Catalog

A separate `catalog/gamebox-wallpaper-rules.json` feed is now maintained in
[BloomBox-Catalog PR #6](https://github.com/adri23rep-stack/BloomBox-Catalog/pull/6).
Its rules map verified installed bundle IDs or explicitly listed whole-name
aliases (e.g. `MeloNX`/`MelonNX`) to a precise provider/topic. A displayed
app name with an innocent version suffix can match; a random substring cannot.

The portable GameBox view receives `app.bundleIdentifier` through its host
adapter, but passes **only** the approved console/game topic to Steam or
Wikipedia. The remote config is strictly decoded and rejects unknown fields,
arbitrary image hosts, executable material, invalid providers, duplicate aliases,
ambiguous IDs, and excessive size. Selected emulator rules may also contain an
explicit `imageURL` pointing to a verified public-domain photograph served by
`upload.wikimedia.org`, plus a matching Commons `sourceURL` and
`imageLicense`. The client downloads it **before** the ordinary console
search and keeps the source page available for attribution. The last validated copy is kept offline.
All manual artwork still takes precedence. When a remote rule changes, the
downloaded *automatic* background may be refreshed without touching manual art.

The catalog has been merged into **BloomBox-Catalog/main**, and the client now
uses that stable path. Run iPhone device QA before any BloomBox release.

### Startup mini loader (default on)

When opening GameBox, a small frosted-glass panel displays a five-icon
**BloomBox Alive-inspired wave**. This is functional wait time for the first
selected app's validated wallpaper lookup, **not** a fake loading percentage.
The remote rules refresh happens independently of the free-scrolling icon
selection, and the first automatic image lookup begins only after the rules
refresh completes. The mini loader closes after that first lookup (minimum
1.15 seconds to show the wave), or automatically after **six seconds** if the
network is slow. The artwork download can continue after the panel closes.
Users may tap **Saltar** immediately, and can disable or re-enable the intro
from GameBox's top menu. The intro is enabled by default on new installs and
respects Reduce Motion.

**SAFE warning:** if an earlier interrupted foreground session or memory
pressure triggered safe graphics, the same intro clearly says that background
downloads are paused. It offers **Activar fondos** as an explicit opt-in;
the SAFE badge in the header also opens a confirmation to reactivate images.
Once the user opts in, the wave panel transitions from the SAFE message into
normal wallpaper lookup with a renewed six-second limit. Neither the intro
nor the remote catalog silently disables crash protection.

### Root cause: complete catalog rejected by one legal Wikipedia title

A real-device report showed GameBox still rendering the app-icon gradient
after all seven curated images had been added. The earlier wallpaper validator
did not permit parentheses in topic queries. The actual BloomBox-Catalog feed
contained the correct article `Android (operating system)` for Husk, so
`BloomBoxWallpaperRuleIndex.validated` rejected **all 13 rules at once**.
The small original Swift unit test did not contain this article, so CI
incorrectly passed while the full feed failed.

Fixes:
- Accept `(` and `)` in the restricted article-topic character set (no arbitrary URLs).
- Run a **real-catalog integration test** over both a checked-in full JSON
  fixture and the live raw GitHub feed, asserting all seven direct pinned URLs
  and known emulator mappings decode successfully.
- Reset the verified remote rules cache to v2 and bypass old synchronization
  clock when there is no usable catalog.
- Provide a small **bundled, validated metadata-only fallback** for seven
  known emulator images, so a temporary GitHub fetch error does not prevent
  lookup. Remote catalog rules still win; actual images remain downloaded and
  cached on first use, not shipped in the IPA.
- Reset per-game failed lookup cooldown to v3 and offer **Actualizar catálogo
  de fondos** from the GameBox menu. A manual retry always re-fetches the
  catalog before re-attempting an image.

This fixes a concrete all-or-nothing metadata failure, but cannot guarantee
download success on offline devices; consult the visible wallpaper state and
local diagnostics if a CDN connection fails.

### Fix: wallpaper not appearing even with SAFE off

Earlier builds also hid the wallpaper whenever iOS **Low Power Mode**
was enabled (the `constrained` display flag), independently of SAFE.
That was unintended. Low Power Mode now reduces blur and animations only;
the selected background image stays visible. A previous in-flight image
request can no longer block the next selected icon's lookup.

The first automatic retry after this fix ignores the old 24-hour failed
lookup lockout. GameBox now displays a short status under the selected
app: **Buscando fondo**, **Fondo listo**, **Sin resultado · reintentar**,
or **Sin fondo identificado**. The per-app menu can manually retry.

If Wikipedia's free-license PageImages endpoint lacks a thumbnail for a
curated emulator platform, GameBox now tries a bounded Wikimedia Commons
file search for that *specific console* (not arbitrary game art), validates
the candidate's file name, image type and dimensions, and keeps the Commons
file-description link for credit and licensing. Sources can still be
unavailable offline or rate-limited; the gradient/app-icon fallback remains.

### Pinned images and corrected Husk identity

The seven initial pinned emulator wallpapers live in
[BloomBox-Catalog PR #6](https://github.com/adri23rep-stack/BloomBox-Catalog/pull/6):
MeloNX/MelonNX and LemoNX → Nintendo Switch, DolphiniOS → GameCube,
MeloCafe → Wii U, Vita3KiOS → PS Vita, PPSSPP → PSP, Husk → representative
Android gaming hardware (Sony Xperia Play). These six selected photographs
were created by Evan-Amos and released into the public domain.
Each entry retains a direct `upload.wikimedia.org` image link and the matching
file-description page. The app validates that these refer to the **same file**.

Husk was previously incorrectly treated as Minecraft Dungeons. Husk is an
Android runtime/emulator; that mapping has been removed from both the remote
rules and built-in fallback. Until a verified Android background is chosen,
Husk uses its icon or the user's custom image.

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
