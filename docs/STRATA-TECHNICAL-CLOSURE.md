# BloomBox — technical Strata source cleanup (4 November 2026)

**Technical status: CLOSED for the source-and-brand cleanup reviewed here.**
**Legal author-rights status: NOT a clean-room certification or independent legal opinion.**
**Repository integration: isolated in `refactor/bloombox-independent-core`; `main` and releases untouched.**

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

## Contributor-history migration prepared, not applied

The historical Git default branch contains three commits authored by the
Strata creator. GitHub derives its Contributors graph from the default branch
history. An unrelated-root **preview** is prepared by
`Scripts/create-independent-history-preview.sh`; that branch contains the
same final audited tree but not the old commit ancestry.

The project owner must approve a separate default-branch migration. Before
switching the default branch: retain backups of `main` and release tags;
review existing PRs, branches, external links and Actions; and validate that
new development targets the new independent root. Switching default history
is not the same as removing legally required code attribution. GitHub's graph
may take approximately a day to update; linked old commits can still exist
under backups/tags and must not be mislabeled as the new author's work.
