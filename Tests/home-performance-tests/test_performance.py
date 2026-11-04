"""Guard Dock navigation and expensive Home effects against regressions.

Behavioral touch/thermal smoothness still needs physical iOS 27 testing.
This test protects the architecture that makes those tests meaningful.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "LiveContainerSwiftUI/Views/BloomBox"
home = (VIEW / "BloomBoxHomeScreen.swift").read_text()
visuals = (VIEW / "BloomBoxLauncherVisuals.swift").read_text()
news = (VIEW / "BloomBoxNewsPage.swift").read_text()
wallpaper = (VIEW / "BloomBoxAnimatedWallpaper.swift").read_text()

# The Dock is a physical part of the Home page inside the native pager.
# It slides offscreen WITH Home toward News or App Library, never fading.
assert home.count("dock(width: geometry.size.width, homePageIndex: index)") == 1
pager = home.split("TabView(selection: $page) {", 1)[1].split(".tabViewStyle(.page(indexDisplayMode: .never))", 1)[0]
assert pager.index("BloomBoxNewsPage(") < pager.index("ForEach(visiblePageIndices")
assert pager.index("ForEach(visiblePageIndices") < pager.index("appLibrary(width:")
home_pages = pager.split("ForEach(visiblePageIndices", 1)[1].split("appLibrary(width:", 1)[0]
assert "dock(width: geometry.size.width, homePageIndex: index)" in home_pages
assert "pageControl" in home_pages
assert "ZStack(alignment: .bottom)" in home_pages
news_page = pager.split("BloomBoxNewsPage(", 1)[1].split("ForEach(visiblePageIndices", 1)[0]
library_page = pager.split("appLibrary(width:", 1)[1]
assert "dock(" not in news_page and "dock(" not in library_page
assert "opacity(page == libraryPageIndex" not in pager
assert "opacity(librarySearchFocused" not in pager
assert "fallbackPage: homePageIndex" in home
assert "BloomBoxNewsPage(openSettings: { desktopSettings = true }, active: page == 0)" in home
assert "homePageIndex" in home

# No decode-per-cell hot loop. Cached JSON still invalidates on imported themes.
assert "let occupied = occupiedCells(on: index)" in home
assert "if let key, !occupied.contains(slot)" in home
assert "if let key, !occupiedCells(on: index).contains(slot)" not in home
assert "if placedWidgetsCacheSource == placedWidgetsJSON" in home
assert "if livingSettingsCacheSource == livingWidgetSettingsJSON" in home
assert ".onChange(of: placedWidgetsJSON)" in home
assert ".onChange(of: livingWidgetSettingsJSON)" in home

# Power/heat reduces decorative work, NEVER disables native swipes or touches.
assert "ProcessInfo.processInfo.isLowPowerModeEnabled" in visuals or "info.isLowPowerModeEnabled" in visuals
assert "info.thermalState == .serious" in visuals
assert "info.thermalState == .critical" in visuals
assert "Notification.Name.NSProcessInfoPowerStateDidChange" in visuals
assert "ProcessInfo.thermalStateDidChangeNotification" in visuals
assert "decorativeMotionDisabled" in home
assert "paused: pauseWallpaper || decorativeMotionDisabled || paused" in home
assert "playing: appeared && scenePhase == .active && !paused && !reduceMotion && !performanceBudget.constrained" in wallpaper

# One animation per edit icon, not a SwiftUI TimelineView body every 33 ms.
wobble = visuals.split("struct LiveBoardEditWobble:", 1)[1].split("struct LiveBoardHomePressStyle", 1)[0]
assert "TimelineView" not in wobble
assert ".repeatForever" in wobble
assert "DispatchQueue.main.async" in wobble

# Only the News tab fetches remote feed, and media stays lazy/offscreen paused.
assert "BloomBoxRemoteNewsSection(active: active)" in news
assert "LazyVStack(alignment: .leading, spacing: 13)" in news
assert "guard active else { return }" in news
assert "Date().timeIntervalSince($0) < 600" in news
assert "CGImageSourceGetCount(source) > 0" in news
assert "prepareGIFPreview(url)" in wallpaper
assert "else if isGIF && playing && framesAnimation == nil && !preparingGIF" in wallpaper

# Thermal pressure also cuts expensive glass compositing, per-widget glows,
# and 30fps timelines that would otherwise redraw offscreen tiles.
widgets = (VIEW / "BloomBoxWidgetViews.swift").read_text()
interactions = (VIEW / "BloomBoxLauncherInteractions.swift").read_text()
assert "if reduceTransparency || performanceBudget.constrained" in visuals
assert "if performanceBudget.constrained" in widgets
assert "(living.glow ?? false) && !editing && !performanceBudget.constrained" in home
assert "if enabled && mode != \"none\"" in interactions
assert "TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused:" not in interactions

print("Dock slides with Home, and Home caches data and adapts to thermal/power pressure.")
