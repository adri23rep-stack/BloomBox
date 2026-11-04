#!/usr/bin/env bash
# Produce an orphan-commit PREVIEW of BloomBox's already reviewed source tree.
# Never force-push or change main, tags, releases, or the default branch.
set -euo pipefail

SOURCE_COMMIT="${GITHUB_SHA:-$(git rev-parse HEAD)}"
PREVIEW_BRANCH="preview/bloombox-independent-history-20261104"

test -f LICENSE
test -f THIRD_PARTY_NOTICES.md
test -f docs/STRATA-PROVENANCE-AUDIT.md
test -f Scripts/audit-bloombox-independent-launcher.py

# This tool can be executed only on the designated refactor branch.
SOURCE_REF="${GITHUB_REF_NAME:-$(git branch --show-current)}"
if [[ "$SOURCE_REF" != "refactor/bloombox-independent-core" ]]; then
  echo "::error::Only the isolated refactor branch may create this preview."
  exit 1
fi

# Protect the default branch, existing refs, and previous preview results.
if git ls-remote --exit-code --heads origin "refs/heads/$PREVIEW_BRANCH" >/dev/null 2>&1; then
  echo "Preview branch already exists; refusing to overwrite it."
  exit 0
fi

SOURCE_TREE="$(git rev-parse "$SOURCE_COMMIT^{tree}")"
export GIT_AUTHOR_NAME="BloomBox snapshot automation"
export GIT_AUTHOR_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
SNAPSHOT_COMMIT="$(git commit-tree "$SOURCE_TREE" <<EOF
chore: review-only BloomBox independent-history snapshot

Source snapshot of $SOURCE_COMMIT on $SOURCE_REF.
This is a packaging history reset for contributor display, NOT a claim that
all bundled sources are authored by BloomBox or free of original licenses.
See LICENSE, THIRD_PARTY_NOTICES.md and docs/STRATA-PROVENANCE-AUDIT.md.
The original ancestry remains preserved in main and existing Git tags.
EOF
)"

if [[ "$(git rev-list --count "$SNAPSHOT_COMMIT")" != "1" ]]; then
  echo "::error::Generated preview still has historical parent commits."
  exit 1
fi
if [[ "$(git rev-parse "$SNAPSHOT_COMMIT^{tree}")" != "$SOURCE_TREE" ]]; then
  echo "::error::Preview tree does not match the reviewed source snapshot."
  exit 1
fi

git push origin "$SNAPSHOT_COMMIT:refs/heads/$PREVIEW_BRANCH"

echo "Review-only, unrelated-history branch: $PREVIEW_BRANCH"
echo "Snapshot root commit: $SNAPSHOT_COMMIT"
echo "Source tree: $SOURCE_TREE"
echo "Neither main nor any release/tag was modified."
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## BloomBox independent-history preview"
    echo "New preview branch: \`$PREVIEW_BRANCH\`"
    echo "Reviewed source commit: \`$SOURCE_COMMIT\`"
    echo "Root commit: \`$SNAPSHOT_COMMIT\` (one commit, no parents)"
    echo "Default branch, release tags, and attribution notices: unchanged."
  } >> "$GITHUB_STEP_SUMMARY"
fi
