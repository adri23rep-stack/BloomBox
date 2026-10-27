# BloomBox 🌸

**BloomBox** is an independently maintained iOS launcher and application container, evolved from Manzana. It includes an iPhone-style desktop, Liquid Glass, customizable app icons, pages and widgets, video/GIF wallpapers, file management, experimental guest-app JIT, and SideStore expiration alerts in the Dynamic Island.

## Features

- Home screen with folders, widgets, drag-and-drop controls and page management
- Liquid Glass panels, customizable icons, themes and a new bloom-and-box icon
- Animated GIF and silent looping video wallpapers
- Integrated app and file management, using LiveContainer technology
- Experimental iOS 27 on-device JIT pairing for guest apps using LocalDevVPN
- Eight-hour SideStore expiration Live Activity and a manual three-minute test

## Installation

Open [BloomBox Actions](https://github.com/adri23rep-stack/BloomBox/actions), select the latest successful **BloomBox - Build** run, and download the **BloomBox-SideStore-unsigned.ipa** artifact. Sign with SideStore, retaining app extensions and the same bundle ID, team and account if updating a compatible Manzana install. Back up app data before reinstalling or changing signing accounts.

JIT compatibility and Live Activities still require tests on your physical iPhone; successful compilation does not prove on-device support.

## Source compatibility

BloomBox is now developed in this repository, not the former Manzana fork. Legacy internal names such as `ManzanaExpiryWidget`, `Strata*` and `LiveContainer*` are retained **where necessary** so existing user preferences, signing setup and guest-app data can remain compatible. New app display branding is **BloomBox**.

## License and credits

BloomBox is a separate GitHub project, not code written from scratch. Its Git history and copyright notices are preserved from [Manzana](https://github.com/adri23rep-stack/Manzana), with original foundations from [Strata](https://github.com/huzaifahshahid71-ops/Strata) and [LiveContainer](https://github.com/LiveContainer/LiveContainer). It remains under the source [AGPL-3.0 license](LICENSE). Husk pairing components are under their stated GPL-2.0-or-later license. See [third-party notices](THIRD_PARTY_NOTICES.md).
