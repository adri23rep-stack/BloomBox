# Migration from Manzana to BloomBox

- Source: `adri23rep-stack/Manzana` branch `feature/manzana-v011-jit-expiry-8h`.
- Destination: independently maintained `adri23rep-stack/BloomBox`.
- Original source ancestry is preserved as a parent of the initial BloomBox import commit.
- The original Manzana repository is left unchanged as a reference.
- New development and CI are in BloomBox.
- AGPL-3.0 copyright and required third-party notices remain.
- The app is branded BloomBox in its Info.plist and generated IPA; internal class names, AppStorage keys and bundle identifier may remain to preserve user data.
- Builds include the new WidgetKit extension, JIT helper, and SideStore.


## Independent core migration (in progress)

This migration is performed on a review branch. No release or main-branch replacement
occurs until the macOS build and on-device tests pass.

- JIT worker, protocol bridge, and pairing record code are maintained as BloomBox
  components, with stricter pairing validation and helper commands.
- Saved remote pairing records are imported from the legacy folder when needed,
  and removing a pairing record clears both current and legacy copies.
- Existing JIT history and developer disk image caches are migrated when possible.
- Upstream LiveContainer, SideStore, StikJIT and other bundled dependencies retain
  their licenses and author notices.
- **Historical checkpoint:** at this early phase, the original iOS Home and
  some LiveBoard implementation still existed. Later phases below moved the
  retired launcher modules into BloomBox-owned source paths. The latest branch
  requires device validation and remains historically derivative; code moves
  do not by themselves establish clean-room authorship.
- Git history and required copyright credits must remain intact even once the
  corresponding source has been fully replaced.

## Direct upstream dependencies (phase 2)

- Removed the inactive packaging script that overlaid compiled UI onto a Strata IPA and its obsolete donor-based tests. Current builds package their own compiled host instead.
- Binary prerequisites now download **directly from their respective upstream projects**, StikJIT and LiveExec32, with SHA-256 verification and atomic replacement. We no longer depend on a Strata release being available for CI downloads.
- The LiveExec32 nightly release is mutable: its exact SHA-256 is pinned and any change stops the build until reviewed. Device compatibility must be tested before merging.
- This change does not replace every inherited iOS Home implementation. Attribution and historical commits remain as legally required.

## BloomBox Home layout engine (phase 3)

- Replaced the inherited home-layout algorithm with BloomBox-maintained placement and reconciliation logic.
- Preserved the JSON format and persistent shortcut IDs so existing users keep their apps, folders, pages and Dock configuration.
- Added de-duplication of stale app IDs, page repair, safer folder placement and a separate regression suite.
- Only the layout engine is replaced here. The original iOS Home SwiftUI view, its widgets and other underlying components are still awaiting a complete independent rewrite.

## Independent app appearance storage (phase 4)

- Replaced the inherited app-name/icon manager with BloomBox-owned Foundation storage and a thin UI adapter.
- Existing icon filenames and renamed app data are imported from previous Strata preferences without overwriting newer BloomBox settings.
- Artwork is copied into BloomBox/Icons only when needed; previous files remain for rollback until the user explicitly replaces or resets a custom icon.
- Storage filenames reject directory traversal. App bundles and original IPA metadata are never rewritten.
- The presentation UI remains compatible with existing icon picker and settings screens.

## BloomBox wallpaper media (phase 5)

- Replaced the inherited media importer with BloomBox-owned file validation, bounded GIF decoding and new BloomBox/Wallpapers storage.
- Existing LiveBoard motion files remain readable without duplicating video data. Theme filenames and preferences stay compatible.
- The existing animated view remains temporarily while the playback implementation is being replaced.

## Independent animated rendering (phase 6)

- Replaced the inherited animated wallpaper view with a BloomBox playback surface shared by Home, widgets and News.
- Video loops are paused in background, muted and released on teardown. GIF frames decode off the main thread, with generation checks to reject stale loads.
- Respect Reduce Motion, preserve transparency for widget GIFs, and avoid intercepting touches.

## Native BloomBox icon styling (phase 7)

- Replaced the old launcher icon styling and settings sheet with BloomBox-owned SwiftUI components.
- Existing icon styles, tint hue, intensity, dark mode and size remain compatible through their saved preferences and theme files.
- The full legacy iOS Home view is not yet replaced; this is another component extracted from it.

## Independent console artwork (phase 8)

- The console cover, portrait and background store now belongs to BloomBox; artwork is saved into BloomBox/Artwork rather than older LiveBoard/Artwork folders.
- Existing artwork mappings migrate without replacing user choices, and old image files remain readable for rollback.
- New saves are bounded to 2400 pixels and cached images have a memory budget. No guest IPA files are modified.

## BloomBox Files engine (phase 9)

- New independent, Foundation-only file engine with path confinement, symlink checks, collision-safe names, folders, trash and restore.
- New installations use Documents/BloomBox Files. Existing Documents/Manzana Files users stay on their current folder: nothing is deleted or copied, and both names continue to resolve.
- The SwiftUI Files view is renamed to BloomBoxFilesView with a temporary compatibility alias for any old launcher references.
- User files, app signing, RAM+, guest executables and shared containers are unchanged.
- Existing Files regression checks are now run in CI together with boundary and migration tests.

## Media reference audit (phase 10)

- GameBox and Theme Store now use BloomBoxMotionMedia and BloomBoxAnimatedWallpaper instead of removed launcher types.
- CI rejects stale Swift references to the deleted media classes before running Xcode.

## BloomBox widget picker (phase 11)

- Replaced the inherited Home widget gallery view with BloomBox-owned SwiftUI cards, selection preview and controls.
- Preserves existing comma-separated widget order, photo preview, note text and per-page toggle callbacks.
- Gallery preference normalization is isolated in a Foundation policy with CI coverage; legacy saved keys remain readable.
- The old desktop screen still contains other widget presentation code to refactor separately.

## Launcher decomposition — remote stores (phase 12)

- Extracted TweakStore and AppStore views/catalog logic from the ~6,000-line iOS Home Swift file to `Views/BloomBox/BloomBoxRemoteStores.swift`.
- Preserved app IDs, stored catalog settings, download logic, JIT and signed guest launch plumbing; no changes to installed app containers.
- Made only the two cross-file model/catalog types accessible to the Home view. Private helpers remain private inside the new store module.
- Added CI checks preventing the remote stores from being inadvertently re-added to the Home source.

## Launcher decomposition — Modules and JIT UI (phase 13)

- Extracted the Modules panel, quick actions, per-app JIT controls, RAM+ links and Connectivity settings into `Views/BloomBox/BloomBoxModulesAndJIT.swift`.
- The Home surface now references these BloomBox screens as separate components rather than compiling their entire UI inside the launcher file.
- All `@AppStorage` preference names, existing guest launch hooks and module destinations remain unchanged.
- CI checks the new boundaries. Legacy JIT implementation itself was migrated in earlier phases.

## Launcher decomposition — reusable visual components (phase 14)

- Shared Home icon tiles, wobble, drag-and-drop proposal, icon renderer, wallpaper pickers, ribbon background and glass modifiers now live in `Views/BloomBox/BloomBoxLauncherVisuals.swift`.
- The original Home View retains interaction state, but its visual components can now be individually audited, rewritten and tested without touching JIT/RAM+ or guest launch.
- The Swift types and existing theme/saved-preference keys remain compatible; CI enforces the boundary.

## Independent widget placement core (phase 15)

- Moved persisted widget schema and grid logic into `Views/BloomBox/BloomBoxWidgetLayout.swift`, independent from iOS Home and UIKit.
- Replaced Home's inline move/resize behavior with a tested placement planner that preserves stable widget IDs, uses collision-safe fallback slots and removes stale duplicates.
- Widget movement continues to select the moved widget for subsequent editing. Existing JSON keys and theme exports remain compatible.
- New CI tests exercise moves, resizing, overlapping widgets, malformed dimensions and saved JSON round-trips.

## Independent App Library (phase 16)

- Moved category rules, suggestions, favorites, recently added ordering and search into `BloomBoxAppLibraryPolicy.swift`, a Foundation-only component.
- Home supplies only installed guest apps and its permanent built-in shortcuts. User-defined categories and saved favorites remain unchanged.
- Added tests for category ordering, duplicate filtering, case-insensitive name/bundle search and old shortcut keys.

## Native Home page navigation (phase 15)

- Replaced the legacy SwiftUI page visibility, active-page recovery and page-deletion bookkeeping with BloomBoxHomeNavigation.
- Page 0 (News), final App Library and saved LiveBoardHiddenPages remain compatible with previous settings and exported themes.
- Malformed/all-hidden page settings recover automatically; deleting a page adjusts visibility and redistributes widget metadata without dropping widget IDs.
- Foundation-only navigation and migration tests now run before the iOS archive in GitHub Actions.

## Launcher decomposition — animation and touch interactions (phase 17)

- Extracted the reusable BloomBox Alive intro, Living Widgets motion, widget drag handles, photo/GIF picker presentation and theme export helper from the main Home View.
- Existing gesture thresholds, haptic hooks, saved theme data, iOS lifecycle behavior, and accessible controls remain unchanged.
- This isolates the last reusable high-frequency widget animations for subsequent rewrite and profiling.

## BloomBox Home layout identity and batch installation (phase 16)

- Renamed the core iOS Home layout module to BloomBoxHomeLayout under Views/BloomBox, preserving the previous LiveBoardHomeLayout alias during transition.
- Existing app key strings, folder identifiers, Codable fields, page data and Dock ordering remain unchanged.
- Fixed repeated creation of a new page for every installed app when visible Home pages are full: new icons now share the new page until it fills.
- Regression tests verify folder migration, page retention and multiple new installations from full visible pages.

## Original BloomBox folder panel (phase 18)

- Replaced Home's inline folder-overlay view with a standalone `BloomBoxFolderPanel` that owns the iOS-style expanding folder UI, paginated 3x3 app tiles, rename and close controls.
- The new view receives a read-only folder, a page binding and action callbacks; only the Home coordinator can change the app layout or launch a guest.
- Existing folder identifiers, saved contents and editing menus stay unchanged. Accessibility labels and Reduce Motion behavior are preserved.

## Home widget placement improvements (phase 17)

- A Foundation-only placement policy now locates existing free space on visible Home pages before adding pages for new or relocated widgets.
- Deleting a Home page repairs its hidden-page indexes before relocating widgets; widget media and IDs are preserved.
- Invalid widget shapes cannot create a blank Home page. Regression tests cover hidden pages, full pages and geometry.

## Independent icon reflow around widgets (phase 18)

- Extracted Home icon/widget collision handling into BloomBoxHomeIconReflow, a Foundation-only component with no app launch or container writes.
- Reflow preserves dock and folder membership, keeps hidden pages untouched, and finds room on visible pages before creating a new one.
- Uses deterministic cell ordering, reuses new overflow pages for an entire icon batch and is idempotent when the widget grid is unchanged.
- CI tests cover full/hidden pages, preserved app IDs, overflow and repeat runs.

## BloomBox News desktop and widget source separation (phase 19)

- Replaced the old ManzanaDesktopView screen with a BloomBoxNewsPage and removed the former ManzanaDesktopView.swift source file. A compatibility alias remains for older compiled references.
- Remote News and widget rendering now live in separate BloomBox source modules; saved News feed URL and locale settings stay compatible.
- GIF downloads are capped at 10 MB each, validated before replacing an existing image, and stored in a bounded 64 MB cache rather than growing indefinitely. Existing user wallpaper and widget directories are never pruned.
- The News cache has offline regression tests for HTTPS links, oldest-first eviction, pinned active images and unrelated files.

## Native BloomBox Home entry and chrome (phase 20)

- The active SwiftUI launcher entry now resides at Views/BloomBox/BloomBoxHomeScreen.swift. A source compatibility alias keeps existing LiveContainer host callers working.
- Deleted the old LiveBoardHomeScreen.swift source path. This is a source/module transition, not a claim that all inherited Home source ancestry has been rewritten from scratch.
- Reimplemented the installer progress display, launch welcome overlay, and full-size (44pt minimum) Edit/Done toolbar as separate BloomBox-owned views.
- Home, all user preferences, launch actions, existing app folders and theme exports remain available without changing saved formats or installed guest data.
- Build workflow and IPA source checks now require the new source layout and reject reappearance of the old Home file.

## Native launcher host (phase 21)

- Replaced the original LiveBoard.swift mode host with BloomBoxLauncherRoot.swift and a source-compatibility alias LiveBoardRootView.
- The mode selector now presents native BloomBox cards and retains saved mode keys, controller lifecycle events and primary launcher preference.
- Launching GameBox still requests BloomBoxRequestGameMode after the picker dismisses; central RAM+/JIT checks remain in place.

## Source and provenance audit (phase 22)

- Added a source audit that checks for retired executable modules and validates that compatibility keys and third-party credits remain.
- See docs/BLOOMBOX-SOURCE-AUDIT.md. This work is not a claim of clean-room source independence.

## JIT host hook correction (phase 23)

- Fixed an overlooked live Objective-C share-extension host hook which was still listening for strataJIT and invoking a no-longer-present StrataJITRequestHandler. It now dispatches bloomBoxJIT to BloomBoxJITRequestHandler, matching the existing Swift worker and embedded NSExtensionPrincipalClass.
- Guarded missing Objective-C runtime class/method pointers before installing the hook.
- Added a cross-language CI contract test to stop this launch-blocking mismatch from returning.

## Wallpaper presets retirement (phase 24)

- Deleted the preinstalled red/blue procedural ribbon wallpaper generator and removed both presets from the Home wallpaper picker. No bundled wallpaper image files were found in the current assets catalog.
- Fresh installs default to a neutral black background until the owner supplies the new default .bbtheme. The supplied theme is NOT yet applied or configured.
- Existing personal photo/GIF/video files, exported themes, GameBox per-game art and saved wallpaper preferences remain untouched. Historical red/blue preference values safely render black instead of old stock artwork.

## GameBox source migration (phase 25)

- Moved GameBox screen, layout and category library implementations into Views/BloomBox, retaining thin Swift aliases so LiveContainer host references and current saved models continue to work.
- Historical StrataConsoleLayouts, LiveBoardModeLibraries and cinematic mode ID settings remain unchanged; deleting them would erase user-adjusted BigPicture layouts/categories.
- CI now compiles the GameBox layout compatibility tests directly, validates old saved categories and checks that the old GameBox source paths stay retired.
- File relocation does not prove clean-room authorship or waive existing upstream notices.

## BloomBox JIT and local pairing module identity (phase 26)

- Relocated the in-app JIT coordinator, setup screen and on-device pairing UI to Views/BloomBox and updated the implementation type names, keeping existing Swift aliases so guest launch callers continue to work.
- Older persisted pairing records, original StrataJIT/jit-history.json fallback, JIT status and user-selected scripts are deliberately preserved to avoid invalidating existing device pairing or losing logs. This is data migration, not active Strata code execution.
- The Objective-C extension and Swift worker remain paired to BloomBoxJITRequestHandler and bloomBoxJIT.
- A CI source-boundary test verifies old files are gone and compatibility paths remain.

## GameBox interaction and launcher support modules (phase 27)

- Separated app icon customization, controller input and focus navigation, icon cache/mask, synthesized audio, orientation ownership and launch helpers into BloomBox-owned source files.
- The old in-app generated WAV filename Strata-Navigation.wav is replaced by BloomBox-Navigation.wav. No downloaded or third-party navigation sound was used.
- Existing Swift names remain supported as typealiases while other LiveContainer host callers migrate. Serialized Home preferences, console layout JSON, guest data and app bundle IDs are not renamed.
- Added CI guards for the new module boundaries and removed old file paths.

## SideStore expiry reminder UI migration (phase 28)

- Relocated the reminder center and settings UI to BloomBox-owned source files while keeping compatibility aliases for existing host/WidgetKit callers.
- The ManzanaExpiryAttributes Live Activity schema, executable bundle name, existing notification identifiers and ManzanaSideStoreExpiryRemindersEnabled preference remain intentionally unchanged to avoid breaking reminders already scheduled on installed devices.
- No changes were made to RAM+, SideStore signing, JIT or user's installed apps.


## Current review status — November 3, 2026

- PR #34 (refactor/bloombox-independent-core) has a successful Xcode archive,
  source audit, JIT bridge verification, RAM+ entitlement verification,
  widget/layout tests and IPA packaging at commit
  `e3f3e8d88f19a7e91b3029c171a6ac6ce01fd358` (Actions run #370).
- The old executable launcher and visual module paths listed in
  `Scripts/audit-bloombox-independent-launcher.py` are absent in this branch.
  Legacy setting keys, bridge aliases and user-owned files remain to prevent
  loss of previously saved layouts, guest apps, wallpapers and pairing.
- The owner supplied both Kirby Pink and Yellow Bowser v2 `.bbtheme` files.
  This branch now bundles both exact files, verifies their SHA-256 digests in
  the IPA and shows image previews in the Theme Store.
- For a genuinely fresh installation with no Home preferences or wallpaper,
  BloomBox applies Kirby Pink automatically on the first Home appearance.
  Existing layouts, imported themes and personalized wallpapers are untouched.
  The included themes clear the original owner's exported hidden-app list
  before applying, so guest apps are not accidentally hidden on other devices.
- The future first-run tutorial/wizard will offer both presets; it is not
  implemented as part of this change.
- **Still unverified on-device (iOS 27):** first start and Home migration,
  existing folders/pages, widget editing and GIF/video playback, theme import,
  GameBox/game launch (including Husk), JIT with LocalDevVPN, RAM+ reinstall,
  SideStore signing, expiry notifications and retained app containers.
- **Provenance:** preserved Git history, the AGPL-3.0 license and required
  third-party notices remain. Do not claim all historically derived code has
  been independently rewritten merely because old module filenames are gone.
- Do not merge this draft PR into `main` or publish a release before the owner
  verifies the on-device behavior and explicitly approves.

## Owner-provided starter themes (phase 29)

- Kirby Pink: default on an untouched first install; includes wallpaper,
  animated wallpaper, clock and media widgets, and the original layout style.
- Yellow Bowser: shipped in the same app and selectable in Themes; includes
  the owner's larger animated GIF and alternative wallpaper/widget style.
- Git tracks the complete original Kirby file and nine unmodified text parts
  for the large Bowser file. The build reconstructs Bowser and verifies both
  against their original bytes and SHA-256 before packing them in the IPA.
- Starter assets are available offline. The Theme Store can apply either
  with a recovery copy of the current Home; the future onboarding wizard is
  explicitly deferred.
- Only new and unconfigured Home instances receive the automatic default.
  Existing user data, installed apps, Dock customizations and manual themes
  are not reset by app updates.
