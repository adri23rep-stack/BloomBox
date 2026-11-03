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
- **Not yet independent:** the original Strata-derived iOS Home and some LiveBoard
  implementation are still present. They must be replaced and tested separately,
  preserving users' folders, widgets, installed guests and settings.
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
