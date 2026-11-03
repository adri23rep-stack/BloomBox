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
