#!/usr/bin/env python3
"""Stage 1 safety contract: no LiveContainer guest model in new Home policy/menu."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
ui = root / "LiveContainerSwiftUI/Views/BloomBox"
home = (ui / "BloomBoxHomeScreen.swift").read_text()
policy = (ui / "BloomBoxHomeAppPolicy.swift").read_text()
menu = (ui / "BloomBoxHomeContextMenu.swift").read_text()
search = (ui / "BloomBoxHomeSearchPanel.swift").read_text()
dialogs = (ui / "BloomBoxHomeNameDialogs.swift").read_text()
tile = (ui / "BloomBoxHomeControlTile.swift").read_text()

for name, body in (("Home policy", policy), ("context-menu UI", menu), ("search overlay UI", search), ("Home rename dialogs", dialogs), ("Home settings tile", tile)):
    for token in ("LCAppModel", "LCUtils", "DataManager", "BuiltInSideStoreAppInfo", "runApp", "ShareExtension"):
        assert re.search(r"\b" + token + r"\b", body) is None, f"{name} imports host symbol {token}"

assert "BloomBoxHomeAppPolicy.matching(" in home
assert "BloomBoxHomeAppPolicy.favorites(from: favorites)" in home
assert "BloomBoxHomeAppPolicy.toggledFavorite(key, in: favorites)" in home
assert "BloomBoxHomeAppPolicy.assigningCategory(value, to: key, in: categories)" in home
assert "BloomBoxHomeAppPolicy.addingCategory(value, to: homeCategories)" in home
assert "BloomBoxHomeContextMenu(state: menuState, actions: actions)" in home
assert "BloomBoxHomeSearchPanel(" in home
assert ".modifier(BloomBoxHomeNameDialogs(" in home
# The old full-screen seven-card menu is retired: Home has a focused
# customization hub, while stores/JIT/apps remain available in their own areas.
assert "desktopHubTile(" in home
assert "requestDesktopAction(.edit)" in home
assert "requestDesktopAction(.interface)" in home
assert "case .widgets:" in home and "case .pages:" in home
assert "BloomBoxHomeControlTile(title: title, detail: detail" not in home
assert "onCreateFolder: { key, name in" in home
assert "onRename: { key, name in" in home
assert "searchMenu(key, app: app)" in home
assert "home.search.field" in search
assert "home.search.done" in search
assert "englishUI: englishUI" in home
assert "let englishUI: Bool" in menu
assert "let englishUI: Bool" in search
assert 'TextField("Search Apps", text: $query)' not in home
assert "private func appMenu(_ key: String, app: LCAppModel)" in home, "Existing host adapter went missing"

# Require the same user-facing capabilities, with closures implemented by the host
# adapter. Rename and cleanup may not remove user data or silently bypass signing.
required_actions = (
    "launch", "launchJIT", "editHome", "rename", "changeIcon",
    "toggleFavorite", "moveToHome", "moveToDock", "moveToPage",
    "newPage", "newFolder", "moveToFolder", "removeFromFolder",
    "setCategory", "newCategory", "toggleNetwork", "addTweak",
    "settings", "uninstall", "removeFromHome"
)
for action in required_actions:
    assert re.search(r"\blet " + action + r":", menu), f"Missing menu action contract: {action}"
    assert re.search(r"\b" + action + r":", home), f"Unwired app menu action: {action}"
for old in ('Button("Launch", systemImage:', 'Button("Rename", systemImage:',
            'Button("Change app icon", systemImage:'):
    assert old not in home, "Old Strata context-menu view is still in Home: " + old
for pref in ("LiveBoardHomeLayout", "LiveBoardFavorites", "LiveBoardCategories", "LiveBoardHomeCategories"):
    assert pref in home, "Legacy user preference was renamed: " + pref
# Profile favorite accent must stay linked to the wizard and live profile edits.
# Home, integrated stores and modules intentionally reuse one backdrop.
visuals = (ui / "BloomBoxProfileVisuals.swift").read_text()
wizard = (ui / "BloomBoxWizardWelcome.swift").read_text()
stores = (ui / "BloomBoxRemoteStores.swift").read_text()
modules = (ui / "BloomBoxModulesAndJIT.swift").read_text()
profiles = (ui / "BloomBoxProfiles.swift").read_text()
assert "struct BloomBoxProfileThemeBackdrop: View" in visuals
assert "BloomBoxWizardAmbientSymbols(isDark: dark, accentHex: hex)" in visuals
assert 'fallbackHex = "F064A7"' in visuals
assert "BloomBoxProfileStore.profilesKey" in visuals
assert "BloomBoxProfileStore.activeKey" in visuals
assert "BloomBoxWizardAmbientSymbols: View" in wizard
assert "func updateColor(_ hex: String, for id: String)" in profiles
assert "BloomBoxProfileThemeBackdrop()" in home
assert "BloomBoxProfileThemeBackdrop()" in modules
assert stores.count("BloomBoxProfileThemeBackdrop()") == 2
assert stores.count("symbolInk: BloomBoxProfileTheme.ink(for: profileAccentHex)") == 2
assert "BloomBoxProfileTheme.ink(for: profileAccentHex)" in home
assert "BloomBoxProfileTheme.color(activeID: themeActiveID" in modules
assert "accent: Color(red: 0.20, green: 0.55, blue: 0.77)" not in stores
assert "accent: Color(red: 0.48, green: 0.32, blue: 0.76)" not in stores

print("BloomBox Home Stage 1 boundary checks passed.")
