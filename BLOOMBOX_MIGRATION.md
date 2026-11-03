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
