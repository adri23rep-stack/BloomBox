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

for name, body in (("Home policy", policy), ("context-menu UI", menu), ("search overlay UI", search), ("Home rename dialogs", dialogs)):
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
print("BloomBox Home Stage 1 boundary checks passed.")
