#!/usr/bin/env python3
"""Prevent the BloomBox Home UI from reabsorbing LiveContainer internals.

Legacy guest launch hooks are still being migrated. This test verifies the
first adapter cut without claiming all UI code is independent yet.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
VIEWS = ROOT / "LiveContainerSwiftUI/Views"
HOME = (VIEWS / "BloomBox/BloomBoxHomeScreen.swift").read_text(encoding="utf-8")
GUEST = (VIEWS / "BloomBoxAdapters/LiveContainerHomeAdapter.swift").read_text(encoding="utf-8")
PREFS = (VIEWS / "BloomBoxAdapters/LiveContainerPreferencesAdapter.swift").read_text(encoding="utf-8")
CONTRACTS = (VIEWS / "BloomBox/BloomBoxIntegrationContracts.swift").read_text(encoding="utf-8")

for symbol in (
    "LCUtils.appGroupUserDefault",
    "BuiltInSideStoreAppInfo",
    "liveBoardAppKey",
    "app.uiNetworkBlocked",
    "app.uiIsShared",
    "app.isAppRunning",
    "app.isSigningInProgress",
):
    assert symbol not in HOME, f"Guest host detail leaked into Home: {symbol}"
assert HOME.count("LiveContainerPreferencesAdapter.defaults") >= 30
assert "LCUtils.appGroupUserDefault" in PREFS
assert "static var defaults: UserDefaults" in PREFS

for term in (
    "LiveContainerHomeAdapter.visibleKeys(apps)",
    "LiveContainerHomeAdapter.modelsByKey(apps)",
    "LiveContainerHomeAdapter.searchModelsByKey(apps)",
    "LiveContainerHomeAdapter.snapshot(app, displayName: title(key))",
    "LiveContainerHomeAdapter.toggleNetwork(app)",
    "LiveContainerHomeAdapter.builtInSignerIcon(dark: darkIcons)",
    "LiveContainerHomeAdapter.isEmbeddedSigner(app)",
):
    assert term in HOME, f"Expected adapter integration absent: {term}"

assert "struct BloomBoxHomeGuestSnapshot" in CONTRACTS
for host_symbol in ("LCAppModel", "LCUtils", "BuiltInSideStoreAppInfo", "SideStoreSupport"):
    assert re.search(r"\b" + host_symbol + r"\b", CONTRACTS) is None, (
        f"Host symbol in public contracts: {host_symbol}"
    )
for interface in (
    "static func eligibleGuests(",
    "static func visibleKeys(",
    "static func modelsByKey(",
    "static func searchModelsByKey(",
    "static func snapshot(",
    "static func toggleNetwork(",
    "static func builtInSignerIcon(",
):
    assert interface in GUEST, f"Guest adapter missing method: {interface}"

# Persisted preference names stay unchanged despite the backend refactor.
for key in (
    "LiveBoardHomeLayout", "LiveBoardFavorites", "LiveBoardCategories",
    "ManzanaPageWidgets", "BloomBoxPlacedWidgetsV2", "ManzanaMotionWallpaper",
):
    assert key in HOME, f"Saved preferences changed unexpectedly: {key}"

print("Home guest adapter boundary passed; persisted preferences remain compatible.")
