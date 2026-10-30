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

## RAM+ protocol references

RAM+ uses an independently implemented Developer Services request flow informed by
[GetMoreRam](https://github.com/hugeBlack/GetMoreRam),
[StosSign](https://github.com/stossy11/StosSign), and
[SideSign](https://github.com/SideStore/SideSign). Authentication is performed by the
already-bundled SideStore. No GetMoreRam or StosSign authentication source is bundled.

## MeloNX 2.6 JIT profile

The embedded JavaScript in `BloomBoxMeloNXProfile.swift` is copied without changes
from `src/MeloNX/MeloNX/Common/JIT/EnableJIT.swift`, MeloNX tag 2.6,
commit `0b0800d37142a28efa24aa6444d47b1f331bfc2f`.
Copyright Stossy11 and MeloNX contributors; GPL-3.0 (see the upstream license).
Source: https://starforgejo.dev/projects/MeloNX/src/tag/2.6/src/MeloNX/MeloNX/Common/JIT/EnableJIT.swift
License: https://starforgejo.dev/projects/MeloNX/src/tag/2.6/LICENSE.txt
BloomBox's debugger adapter applies its existing register-parsing compatibility
fixes at runtime. The base64 string is the complete corresponding script source.
