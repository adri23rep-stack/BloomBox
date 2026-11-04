# BloomBox independent contributor-history preview

**Status:** optional, review-only migration preview. Not a new release or replacement for the current `main`.

## Why this exists

The GitHub Contributors view is based on commit authors in the default branch's
reachable history. Three ancestor commits on the existing `main` were authored
by the Strata account. Replacing code files or removing a README credit does not
change those historical records. There is no per-contributor hide switch.

This branch preview takes the existing **reviewed BloomBox tree** and creates a
new **root commit without any of the old ancestor commits**. It contains the same
files, including **third-party licenses** and provenance records. It is a
history-only experiment: it neither makes copied code original nor changes
copyright/licensing obligations.

## Safe and unsafe operations

- Safe automatic action: create `preview/bloombox-audited-history-20261104`
  with a single root commit, after validating the source audit and locale names.
  That new branch has **no shared commit ancestry** with `main`.
- Never automatically change `main`, default-branch settings, release tags,
  old build artifacts, contributor identities or past commit author metadata.
- Preserve `LICENSE`, `THIRD_PARTY_NOTICES.md`, historical evidence and
  `docs/STRATA-PROVENANCE-AUDIT.md`; do not attribute upstream works to BloomBox.
- The preview is not ready for adoption until iOS 27 on-device data-migration
  tests and the remaining modified-block licensing/provenance review finish.
- Switching the GitHub default branch to an unrelated-history root changes
  how comparisons, forks, PRs, commit links and future development behave.
  Existing releases and source history still exist, but may be harder to
  navigate. Prepare branch/tag backups and a PR migration plan first.

## Acceptance checklist

1. Confirm latest refactor source passed Xcode archive, IPA validation and tests.
2. Inspect the preview's tree against the refactor source commit: same tree SHA.
3. Confirm preview has one commit, zero parents, and original licenses in tree.
4. Confirm the current source passes the new build and that an IPA update preserves
   Home layouts, installed apps, widgets, themes, signing, RAM+ and JIT. The owner
   already tested removal of GameBox in a prior successful build.
5. Confirm the audit no longer finds Strata-only implementation requiring credit;
   if required notices remain, **keep them**.
6. Only with the owner's specific approval, decide whether to migrate default
   branch instead of merging the old historical branch.

There is no promise that GitHub's Contributors cache refreshes immediately after
an eventual approved default-branch migration. Contributor graph recalculation
and other GitHub profile features may be delayed or behave differently.


### Final replacement preview

Use `preview/bloombox-audited-history-20261104` for the **post-GameBox**
source, instead of the older `preview/bloombox-independent-history-20261104`
trial. The historical audit remains available under
[STRATA-TECHNICAL-CLOSURE.md](STRATA-TECHNICAL-CLOSURE.md).

Never make the new root look like it was authored by upstream developers or by
someone who did not actually create the snapshot. The new root is attributed
to automation and retains its original source-provenance documentation.
