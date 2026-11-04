BloomBox retains applicable copyright and third-party license notices. It incorporates technology from LiveContainer and other separately licensed projects. Historical changes and licensing evidence are documented in [the source provenance audit](docs/STRATA-PROVENANCE-AUDIT.md); a new Git root does not change underlying copyright ownership.

**Original-work attribution terms:** [LICENSE-ADDITIONAL-TERMS.md](LICENSE-ADDITIONAL-TERMS.md) and [NOTICE.md](NOTICE.md) apply only to marked BloomBox-authored material; they do not change any upstream license.

# Third-party notices

- LiveContainer: https://github.com/LiveContainer/LiveContainer — AGPL-3.0; source base bdc07ed9d0fce19f79db78a4a1015d67d4312597. The upstream license is retained; the source base is identified above.
- SideStore: https://github.com/SideStore/SideStore — see its upstream license and source. The combined release preserves the original bundled SideStore executable and extensions.
- StikJIT: https://github.com/StikDebug/StikJIT — MPL-2.0; vendored from 32287268fa5824f9edce4cb359f5833ce0cf7b00. License and integration documentation are in Vendor/StikJIT. Modified Swift sources are in ShareExtension/StikJIT.
- Husk on-device pairing: https://github.com/Leviidev/Husk — GPL-2.0-or-later. Adapted Rust PairableHost adapter and Swift pairing coordinator are in Vendor/HuskRPPairing and LiveContainerSwiftUI/Views/BloomBox/BloomBoxOnDevicePairing.swift. Rust dependencies, including idevice 0.1.68 (MIT), are pinned in Cargo.lock; preserve their licenses when shipping the IPA.
- idevice: the FFI static library is downloaded directly from the pinned StikJIT commit `32287268fa5824f9edce4cb359f5833ce0cf7b00` and checked against SHA-256 `4db23fe1d342927b9480bb9a8577f219994365621dc28aa0018e23ea1990ecc8`; original source project https://github.com/jkcoxson/idevice. Retain its upstream license and dependency notices.
- LiveExec32: https://github.com/LiveContainer/LiveExec32 — Apache-2.0. The build fetches the upstream 2026-10-29 nightly IPA directly, pins SHA-256 `e690c6fdc97c249cb8b67f27cea753e7bb98ea7c874f8160844e58fe92e87dba`, and fails if that mutable nightly asset changes. The historical source snapshot for commit `c94c040018bab39aaceee71786c5b452f3e9f5b6` is retained as provenance only; see Resources/BundledRuntime for its original license and metadata.
- fishhook, litehook and OpenSSL: retained Git submodules; their own licenses apply.
- BloomBox's current app icon is drawn from its own flower-and-box vector generator at build time; the retired console audio and old bundled music icon image have been removed.

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
