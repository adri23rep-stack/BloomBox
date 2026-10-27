# Migration from Manzana to BloomBox

- Source: `adri23rep-stack/Manzana` branch `feature/manzana-v011-jit-expiry-8h`.
- Destination: independently maintained `adri23rep-stack/BloomBox`.
- Original source ancestry is preserved as a parent of the initial BloomBox import commit.
- The original Manzana repository is left unchanged as a reference.
- New development and CI are in BloomBox.
- AGPL-3.0 copyright and required third-party notices remain.
- The app is branded BloomBox in its Info.plist and generated IPA; internal class names, AppStorage keys and bundle identifier may remain to preserve user data.
- Builds include the new WidgetKit extension, JIT helper, and SideStore.
