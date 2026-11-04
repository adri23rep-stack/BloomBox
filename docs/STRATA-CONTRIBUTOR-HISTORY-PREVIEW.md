# BloomBox — GitHub contributor-history migration

**Status: applied to `main` on 4 November 2026 with owner approval.**

## What happened

The default branch name remains `main`, but its content now begins with
an independent Git root snapshot. The prior history was **not reassigned or
rewritten into a false attribution**: all old commits and their authors remain
available under an archived branch and existing release references.

| Check | Verified value |
| --- | --- |
| Old `main` | `c6b08c309769b04bb00f19fba1bc2d65e02227b1` |
| Archived old history | `archive/bloombox-main-before-history-migration-20261104` |
| Audited source | `347257d0a84a1c4293e76c55742742ce1bd4c896` |
| Root now on `main` | `b2398735bccc99dbde22042dfdf945cd30c47fb4` |
| Root parent commits | **0** |
| Identical source/root tree | `18a22cddcc0d43259f7e1918b6df69494f0c4f9c` |
| Complete audited IPA build | [Actions #41800425509](https://github.com/adri23rep-stack/BloomBox/actions/runs/41800425509): **passed** |
| Preview creation check | [Actions #41800418671](https://github.com/adri23rep-stack/BloomBox/actions/runs/41800418671): **passed** |
| Original release tags/assets | **Untouched** |

The migration used an exact-expected-old-SHA ref update; it refused to proceed
if the archive, main head, source tree or compiled source had changed.
No releases were published as part of the migration.

## Consequences for GitHub

The three historical commits attributed to the Strata account are no longer
ancestors of the new `main` branch. That makes them ineligible to contribute
to the default-branch Git contributors graph once GitHub recalculates it.
GitHub may cache the contributors display, and this operation does not erase
historic commits, credits required by law, or past participation.

GitHub automatically closed two draft PRs when their branches stopped sharing
history with `main`:

- [#34 — independent launcher refactor](https://github.com/adri23rep-stack/BloomBox/pull/34):
  completed in the audited source snapshot, closed without a GitHub PR merge.
- [#16 — experimental DEB import kit](https://github.com/adri23rep-stack/BloomBox/pull/16):
  **not integrated** into the audited source. The experimental work remains at
  `feature/deb-import-test-kit`; reuse it via a fresh branch from current
  `main` plus a reviewed cherry-pick/reimplementation, not an unrelated-history merge.

The existing `refactor/bloombox-independent-core` and archive branches remain
intact. They document the original refactor and all earlier contributors,
including any rights that may continue to apply to derivative source.

## Licensing and maintenance

This changes Git ancestry **only**, not the ownership of upstream work.
`LICENSE`, `THIRD_PARTY_NOTICES.md`,
[the original source audit](STRATA-PROVENANCE-AUDIT.md) and
[technical closure](STRATA-TECHNICAL-CLOSURE.md) remain in the repository.
Future development must use the *new* `main` as its base.

The user confirmed the removal of GameBox and normal guest launching on
iPhone iOS 27 in the preceding successful build. The latest modified icon/JIT
implementation passed automated tests and Xcode packaging but has not been
separately device-tested yet.
