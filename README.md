# BloomBox 🌸

### Your apps, your iPhone, your way — without the hassle.

**Install, organize, customize, and launch your apps from one familiar place.** BloomBox is an alternative iOS home screen and app container built around direct shortcuts and approachable controls, so everyday tasks don't require digging through technical menus.

> **Our mission:** Make everything easier for everyday users — app installation, JIT setup, tweaks, and personalization. Complex tools should work behind the scenes whenever possible, without forcing anyone to navigate advanced interfaces just to get things done.

[![Build](https://github.com/adri23rep-stack/BloomBox/actions/workflows/build.yml/badge.svg)](https://github.com/adri23rep-stack/BloomBox/actions/workflows/build.yml)
[![AGPL-3.0 License](https://img.shields.io/badge/license-AGPL--3.0-blue)](LICENSE)

## ✨ What can BloomBox do?

| Feature | What's included today |
| --- | --- |
| 🏠 **A familiar Home Screen** | iPhone-style pages, Dock, folders, App Library, search, and drag-and-drop icon arrangement. |
| 📲 **App installation and management** | Dedicated **SideStore** and **Install App** shortcuts on the Home Screen, plus guest-app management through LiveContainer. |
| 🎨 **Personalization** | Liquid Glass panels, light/dark appearances, **Original, Dark, Clear, and Tinted** icon styles, adjustable colors, and icon sizes. |
| 🌌 **Animated wallpapers** | Looping GIFs and silent MP4/MOV video backgrounds, with pause, fit, and dimming controls. |
| 🧩 **Built-in widgets** | Clock, Photos, and Notes widgets across multiple pages, with controls to add, move, or remove them. |
| 📁 **File management** | Import, search, preview, organize, copy, move, rename, share, and restore files from BloomBox's own trash. |
| 🛠️ **Tools and tweaks** | Convenient access to a dedicated tweaks section and management tools without cluttering the Home Screen. Available features depend on each tweak's compatibility. |
| ⚡ **Built-in JIT (experimental)** | On-device pairing assistance and JIT preparation for **guest apps**, using LocalDevVPN. |
| ⏳ **SideStore expiry reminders (experimental)** | An eight-hour Dynamic Island countdown, a one-hour notification, and a manual three-minute test. |

**The idea:** Launching an app, installing something new, or changing your wallpaper should feel like a normal part of using your phone — not a development project.

## 🧭 Our philosophy: simple on the outside, powerful on the inside

We build BloomBox around five principles:

1. **One tap beats ten menus.** Common actions such as *Install App* and *SideStore* should be easy to find.
2. **JIT without the headache.** Guide users through essential steps, while keeping diagnostics and advanced options available when needed.
3. **Approachable tweaks.** Help people find, manage, and understand tweak compatibility without requiring technical expertise.
4. **Personalization without breaking things.** Make it easy to try wallpapers, icons, widgets, themes, and layouts — and undo changes.
5. **Respect apps and user data.** Clearly separate *Remove from Home Screen* from *Uninstall*, preserve settings when possible, and warn before destructive actions.

The goal isn't to remove advanced capabilities. **It's to make them easier to use.**

## 📱 Installation

1. Open [BloomBox's GitHub Actions builds](https://github.com/adri23rep-stack/BloomBox/actions/workflows/build.yml).
2. Select the latest successful **BloomBox - Build** workflow run.
3. Download the **`BloomBox-SideStore-unsigned.ipa`** artifact.
4. Sign and install the IPA with SideStore, **keeping its bundled app extensions**.

> **Before updating:** Back up your data. When migrating from Manzana, keep the same app bundle identifier, signing team, and account where compatible to help preserve existing app data. GitHub Actions produces an **unsigned IPA**.

## 🧪 Experimental features and limitations

- **On-device JIT:** The pairing and preparation flows are included, but **a successful build does not prove JIT works on a real iPhone**. Pairing, LocalDevVPN, device preparation, and JIT attachment to a guest app each need device testing. It does not enable JIT for unrelated apps installed outside BloomBox. [Technical notes](docs/Manzana-OnDevice-JIT.md).
- **Dynamic Island:** Expiration reminders depend on data shared by SideStore, compatible signing and extensions, permissions, and reopening BloomBox after renewals. **BloomBox does not automatically renew or sign apps.** Real-device behavior still needs validation. [Technical notes](docs/Manzana-SideStore-8h-LiveActivity.md).
- **Widgets:** BloomBox currently offers its own built-in widgets. **Third-party apps' native WidgetKit widgets are not directly supported**, and free placement between individual icons is not yet available. [Current behavior](docs/WIDGETS-PAGES-ICON-STYLES.md).
- **Files and guest apps:** BloomBox manages its own document space and hosted apps. It **does not replace iOS SpringBoard** or bypass iOS permissions to access other apps' private files. [File management notes](docs/MANZANA-FILES.md).
- **Animated wallpapers:** Video backgrounds are muted, and playback pauses when appropriate to help manage resource usage. [Wallpaper notes](docs/ANIMATED-WALLPAPERS.md).

## 🚀 What's next?

- **Even simpler app installation:** Bring importing, installation, management, and updates into straightforward flows.
- **Guided JIT:** Check requirements, show understandable errors, and reduce manual steps where iOS allows it.
- **Easier tweak management:** Explain requirements and compatibility before applying changes, with a clear way to return to a stable setup.
- **More flexible Home Screen:** Freely positioned widgets, smoother gestures, better page organization, and additional customization.
- **An experience for everyone:** Fast, accessible interactions, plain-language messages, and advanced settings that stay out of the way until you need them.

These are **development goals**, not promises that every feature is finished or supported on all devices.

## 🌱 About BloomBox

BloomBox evolved from **Manzana** and now lives in [its own repository](https://github.com/adri23rep-stack/BloomBox). It builds on earlier open-source work including [Strata](https://github.com/huzaifahshahid71-ops/Strata) and [LiveContainer](https://github.com/LiveContainer/LiveContainer). It is an independently maintained derivative, **not a project written entirely from scratch**.

Some internal names such as `Manzana`, `Strata`, and `LiveContainer` remain for compatibility with older settings, code paths, and guest-app data. The app's public name is **BloomBox**. See the [migration notes](BLOOMBOX_MIGRATION.md).

**Open source · [AGPL-3.0](LICENSE)**. Third-party components retain their applicable licenses. See [credits and third-party notices](THIRD_PARTY_NOTICES.md).

---

**BloomBox 🌸 — Less configuring. More enjoying your iPhone.**
