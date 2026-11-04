#!/usr/bin/env bash
# Compile Husk's GPL-2.0-or-later on-device RPPairing adapter for Manzana.
# Uses the pinned idevice 0.1.68 dependency and requires a macOS host and iOS SDK.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE="$ROOT/Vendor/HuskRPPairing"
OUT="$CRATE/libhusk_rppairing.a"
export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-17.5}"

if ! rustup target list --installed | grep -qx aarch64-apple-ios; then
  rustup target add aarch64-apple-ios
fi
cargo build --manifest-path "$CRATE/Cargo.toml" --release --locked --target aarch64-apple-ios
cp "$CRATE/target/aarch64-apple-ios/release/libhusk_rppairing.a" "$OUT"
echo "Built $OUT for iOS arm64. This archive is an intermediate build artifact, not an IPA."
