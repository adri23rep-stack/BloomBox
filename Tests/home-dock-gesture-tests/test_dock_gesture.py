#!/usr/bin/env python3
"""Regression checks for the iOS Home Dock and user-controlled system gesture deferral."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
ui = root / "LiveContainerSwiftUI/Views/BloomBox"
home = (ui / "BloomBoxHomeScreen.swift").read_text()
visuals = (ui / "BloomBoxLauncherVisuals.swift").read_text()
launcher = (ui / "BloomBoxLauncherRoot.swift").read_text()

assert "private func dock(width: CGFloat, homePageIndex: Int)" in home
assert "layout.dock.indices.contains(slot)" in home
assert "ForEach(0..<4, id:" in home
assert "layout.moveToDock(key, at: slot, fallbackPage: homePageIndex)" in home
assert "bloomBoxHomeDockGlass(radius: 33)" in home
assert 'padding(.bottom, -22)' not in home, "Negative Dock padding makes its glass appear truncated"
assert "let panelWidth = max(240, width - 24)" in home
assert "let cellWidth = (panelWidth - 16) / 4" in home
assert "private struct BloomBoxHomeDockGlassSurface: ViewModifier" in visuals
assert ".glassEffect(.regular.interactive(false), in: shape)" in visuals

assert '"BloomBoxDeferBottomSystemGestures"' in launcher
assert "private var protectBottomGestures = true" in launcher
assert ".defersSystemGestures(on: protectBottomGestures ? .bottom : [])" in launcher
assert "Toggle(isOn: $protectBottomGestures)" in launcher
assert "second swipe" in launcher
print("BloomBox Dock geometry and switchable bottom-edge iOS gesture deferral are preserved.")
