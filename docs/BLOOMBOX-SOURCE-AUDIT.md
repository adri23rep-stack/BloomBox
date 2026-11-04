# BloomBox launcher source audit

The reviewed branch replaces the retired Strata donor-IPA packaging path,
JIT worker and pairing classes, and the original Manzana/LiveBoard launcher
source files with BloomBox-owned modules.

**Important:** source reorganization does not establish clean-room authorship.
Some code remains historically derived and subject to the existing AGPL-3.0
license, upstream copyright and other third-party notices.

Compatibility keys such as LiveBoardHomeLayout, ManzanaMotionWallpaper and
manzana:* shortcut IDs are intentionally retained to preserve installed apps,
saved media, widgets, themes and folders.

Before merging, verify current-head CI tests, Xcode archive, IPA and RAM+
entitlements, then perform device tests of guest launches, JIT, RAM+, GameBox,
SideStore, custom icons and animated widgets.

Do not merge the draft branch or release an IPA until validated.