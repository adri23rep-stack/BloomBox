BloomBox retains the original upstream copyright and third-party notices. This independent repository is a derivative of Manzana, Strata and LiveContainer under their respective licenses.

# Third-party notices

- LiveContainer: https://github.com/LiveContainer/LiveContainer — AGPL-3.0; source base bdc07ed9d0fce19f79db78a4a1015d67d4312597. The upstream license is retained; the source base is identified above.
- SideStore: https://github.com/SideStore/SideStore — see its upstream license and source. The combined release preserves the original bundled SideStore executable and extensions.
- StikJIT: https://github.com/StikDebug/StikJIT — MPL-2.0; vendored from 32287268fa5824f9edce4cb359f5833ce0cf7b00. License and integration documentation are in Vendor/StikJIT. Modified Swift sources are in ShareExtension/StikJIT.
- Husk on-device pairing: https://github.com/Leviidev/Husk — GPL-2.0-or-later. Adapted Rust PairableHost adapter and Swift pairing coordinator are in Vendor/HuskRPPairing and LiveContainerSwiftUI/Views/ManzanaOnDevicePairing.swift. Rust dependencies, including idevice 0.1.68 (MIT), are pinned in Cargo.lock; preserve their licenses when shipping the IPA.
- idevice: the FFI static library and headers are distributed by the pinned StikJIT upstream; source project https://github.com/jkcoxson/idevice. Retain its upstream license and dependency notices when rebuilding or redistributing.
- LiveExec32: https://github.com/LiveContainer/LiveExec32 — Apache-2.0; c94c040018bab39aaceee71786c5b452f3e9f5b6. Bundled IPA provenance and license are under Resources/BundledRuntime. Corresponding source archive accompanies the release.
- fishhook, litehook and OpenSSL: retained Git submodules; their own licenses apply.
- Console navigation audio is synthesized locally; no PlayStation or Steam sound recordings are included.
- Strata icon: adapted from artwork provided by the project owner. Apple Music artwork remains copyright Apple Inc.

No claim of endorsement or ownership of upstream trademarks is made. See each component's source for its complete dependency notices.
