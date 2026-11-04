# BloomBox — technical Strata source cleanup (4 November 2026)

**Technical status: CLOSED for the source-and-brand cleanup reviewed here.**
**Legal author-rights status: NOT a clean-room certification or independent legal opinion.**
**Repository status as of 4 November 2026: audited source adopted as the new `main` history; existing releases/tags were not modified.**

## Scope and evidence

The reference commit for the historical Strata source is
[`9b9c86324395e484c4078e1d2883cc49b4a17dad`](https://github.com/huzaifahshahid71-ops/Strata/tree/9b9c86324395e484c4078e1d2883cc49b4a17dad).
We compared complete Git blob trees against pinned LiveContainer
[`bdc07ed9`](https://github.com/LiveContainer/LiveContainer/tree/bdc07ed9d0fce19f79db78a4a1015d67d4312597)
and StikJIT
[`32287268`](https://github.com/StikDebug/StikJIT/tree/32287268fa5824f9edce4cb359f5833ce0cf7b00)
rather than labeling all files seen in Strata as Strata-authored.

In the current cleaned source snapshot:
- **0 byte-identical source-code files uniquely matching Strata** versus both upstream references.
- Four remaining exact Strata-only Git blob matches are **not source code**:
  `Resources/BundledRuntime/LiveExec32-LICENSE`,
  `Resources/BundledRuntime/LiveExec32-source.json`,
  `Vendor/StikJIT/UPSTREAM.txt`, and
  `Vendor/StikJIT/idevice/LICENSE.txt`.
  These belong to the pinned *other upstream projects* and must stay.
- The retired console screen, controller-specific GameBox code, old layout and
  audio files, 39 translated `CFBundleName = Strata` entries, old icon binaries,
  and Apple Music image override have been removed or replaced.
- Current app icons are generated during the build from
  `Scripts/generate-bloombox-icon.swift`, a first-party flower-and-box vector.
- The remaining explicitly reviewed Home, icon-edge, JIT setup/coordinator,
  orientation and customization equivalents were substantially reorganized.
  Common SwiftUI control-flow and immutable storage/protocol keys are not in
  themselves proof of common creative authorship.

## Validation

- `BloomBox - Build` on the GameBox-removal branch compiled, validated and
  uploaded an iOS IPA successfully ([run 41795820324](https://github.com/adri23rep-stack/BloomBox/actions/runs/41795820324)).
- The owner tested that build on iPhone iOS 27 and confirmed the replacement
  **“Espacio reservado”** entry exists and formerly GameBox-routed apps open
  directly; remaining Home behavior was reported working.
- The **latest refactor HEAD**, including final icon/JIT edits and this report,
  must also complete an IPA build and automated tests before being merged.
  The owner's earlier test does not verify the newly changed icon/JIT paths.
- Preserve existing `LiveBoard*` and other persisted user-setting keys and
  the original guest signing/bundle compatibility. Removal of a console
  presentation is not removal of guest runtime features.

## Credits and legal boundary

README promotional branding and obsolete Strata-icon acknowledgments were
removed. Third-party LiveContainer, SideStore, StikJIT, Husk, idevice,
LiveExec32, GetMoreRam and MeloNX notices remain intact. The project's
AGPL-3.0 license remains in `LICENSE`.

**No exact SHA match does not prove independent copyright ownership.**
The repository was historically developed from a project line involving Strata,
and some behavior, designs or altered snippets could still be derivative.
Historical authorship, prior Git commits and source-provenance evidence are
**preserved** in [the initial audit](STRATA-PROVENANCE-AUDIT.md).
Do not use the independently rooted preview to falsify past author names,
erase mandatory copyright notices or claim the entire product was developed
from scratch. Legal attribution obligations need a separate rights review if
a definitive zero-derivation claim is desired.

## GitHub contributor-history migration — applied on 4 November 2026

Following explicit owner approval, the reviewed tree was installed as the
**single-root history of `main`**, using a force-with-lease ref update.
The new initial commit is `b2398735bccc99dbde22042dfdf945cd30c47fb4`
with **no parents** and tree `18a22cddcc0d43259f7e1918b6df69494f0c4f9c`.
That tree exactly matches the completed source-audit commit
`347257d0a84a1c4293e76c55742742ce1bd4c896`, which passed the full
[Xcode + IPA build and tests](https://github.com/adri23rep-stack/BloomBox/actions/runs/41800425509).

The old default-branch commit `c6b08c309769b04bb00f19fba1bc2d65e02227b1`
is retained at
[`archive/bloombox-main-before-history-migration-20261104`](https://github.com/adri23rep-stack/BloomBox/tree/archive/bloombox-main-before-history-migration-20261104).
Past Git authors and their contributions remain accessible there. No tag,
release artifact, outside dependency or third-party copyright attribution was
removed or reassigned.

GitHub automatically closed draft PRs
[#34](https://github.com/adri23rep-stack/BloomBox/pull/34) and
[#16](https://github.com/adri23rep-stack/BloomBox/pull/16) without merging them
into the new root. Their source branches were retained; for new work they must
be reapplied deliberately to the new `main`, not merged across unrelated Git
histories. The original closed PR discussion remains accessible.

Contributors is a derived GitHub UI view and can stay cached for some time.
Moving `main` to an independent root changes commit reachability in its
default history but is **not** a legal declaration of independent authorship.
Preserve the historical audit and legally required upstream notices.
