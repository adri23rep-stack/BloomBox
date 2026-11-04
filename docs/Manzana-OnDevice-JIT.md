# Manzana: self-pairing + built-in JIT (experimental)

Scope: **only guest apps launched inside Manzana** (LiveContainer / LiveProcess).
This branch does not request JIT for normal, separately installed iPhone apps.

## One-time setup (iOS 27)

1. Install this build through SideStore, preserving **all app extensions**.
2. In Manzana, open **JIT setup**, choose **Use built-in JIT**, tap **Start pairing with Manzana**.
3. Allow Local Network and optionally notifications.
4. Open **iPhone Settings > Privacy & Security > Developer Mode** and choose **Pair with Manzana**.
5. Enter the one-time pairing PIN. When complete, the RPPairing file is validated and stored at
   `Documents/StrataJIT/pairingFile.plist` (same path the existing helper expects).
6. Open **LocalDevVPN** and connect it. SideStore can keep using the same LocalDevVPN.
7. In Manzana choose **Prepare device**; then launch an installed *guest* app through **Launch with JIT**.

Existing pairing-file import is retained as fallback. No StikDebug, SideJITServer or computer
is required for the **pairing** flow; LocalDevVPN remains an external prerequisite.

## How it works

- Derived from [Leviidev/Husk](https://github.com/Leviidev/Husk) on-device pairing
  (`src/app/Husk/JITPairing.swift`; `src/rppairing-ios`, GPL-2.0-or-later).
- The vendored Rust library implements [idevice](https://github.com/jkcoxson/idevice)
  `PairableHost` (idevice MIT), and Bonjour advertises
  `_remotepairing-pairable-host._tcp`.
- A `BGContinuedProcessingTask` attempts to keep the pairing service alive
  while the user switches to iPhone Settings. If iOS denies it, time in background
  is limited and the UI warns the user.
- On success the plist is validated with existing `StrataPairingRecord.validate`;
  only the host and its private extension receive it. Do **not** share or log this file.
- The existing `ShareExtension/StrataJITWorker` uses StikJIT, LocalDevVPN and
  the LiveProcess guest PID to request JIT. A pairing success does **not**
  imply actual JIT success.

## Build

Requires macOS, Xcode compatible with iOS 26+ SDK, rustup/cargo and internet access
to download the pinned Rust dependencies. Run:

```sh
bash Scripts/build-ondevice-pairing.sh
python3 Scripts/fetch-bundled-dependencies.py
xcodebuild -project LiveContainer.xcodeproj -scheme LiveContainer -configuration Release \
    -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions runs the Rust build step before `xcodebuild`.
The generated `Vendor/HuskRPPairing/libhusk_rppairing.a` is **not** checked in.

## Validation still required

- On a real iOS 27 device, confirm that `Pair with Manzana` appears, the PIN is displayed
  while Manzana is backgrounded, the pairing file passes validation and survives app restarts.
- Confirm the re-signed IPA preserves the JITHelper and LiveProcess extensions
  and their `get-task-allow` entitlement.
- With LocalDevVPN connected, verify Prepare device and JIT attach separately.
  The previous `E96` debugger rejection is **not** claimed fixed by adding pairing.
- Test a JIT-compatible guest engine and its required iOS 26/27 script.
  TXM/SPTM requires preparing executable regions, not merely setting `CS_DEBUGGED`.
- After reboot / iOS update, recheck LocalDevVPN and DDI cache; re-pair only
  if the remote pairing became invalid.
- Simulator builds may require an architecture-specific pairing library or
  disabling this feature for the simulator (the current native library is iOS arm64).

## Attribution

`Vendor/HuskRPPairing` and `LiveContainerSwiftUI/Views/ManzanaOnDevicePairing.swift`
are adapted from Husk (GPL-2.0-or-later), retained with license headers.
The Rust `Cargo.lock` pins `idevice` 0.1.68 and other dependencies. When distributing
an IPA include the dependency notices / corresponding licenses.
