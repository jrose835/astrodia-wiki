#!/usr/bin/env bash
#
# publish.sh — one-command update loop for the Astrodia wiki.
#
# What it does:
#   1. rsync the Obsidian vault into content/, EXCLUDING everything in
#      exclude-list.txt (the spoiler firewall — secrets never enter the repo).
#   2. Copy the repo-maintained public overrides (e.g. the scrubbed Úlfr page)
#      on top of content/.
#   3. Run a hard SAFETY GATE that scans content/ for the murder secret and for
#      any excluded file/dir/image that slipped through. Aborts on any hit.
#   4. Commit and push to the v5 branch, which triggers the GitHub Actions deploy.
#
# Usage:  ./publish.sh "Session 8 recap"
#         (the argument becomes the commit message; defaults to "Update wiki")
#
# Before running: let Dropbox finish syncing the vault down to this machine so
# you don't publish a stale note.

set -euo pipefail

REPO_DIR="/Users/jimrose/Documents/Astrodia"
VAULT_DIR="/Users/jimrose/Dropbox/Personal/DnD/Astrodia/AstroObsVault/Astrodia_Vault"
BRANCH="v5"
COMMIT_MSG="${1:-Update wiki}"

cd "$REPO_DIR"

echo "==> [1/4] Syncing vault -> content/ (spoiler-filtered)"
rsync -a --delete \
  --exclude-from="$REPO_DIR/exclude-list.txt" \
  "$VAULT_DIR/" "$REPO_DIR/content/"

echo "==> [2/4] Applying public overrides"
if [ -d "$REPO_DIR/overrides" ]; then
  cp -a "$REPO_DIR/overrides/." "$REPO_DIR/content/"
fi

echo "==> [3/4] Safety gate: scanning content/ for spoilers"
FAIL=0

# (a) The murder secret, as phrases (case-insensitive). The names "Snorri"/"Kári"
#     alone are allowed — they appear as in-fiction dead links in public recaps
#     (e.g. Úlfr screamed "Kári!" in his sleep, which the party witnessed).
if grep -rniE "killed snorri|reliving the killing|murdered (his|adopted )?brother|murder of snorri|his other secret" "$REPO_DIR/content/"; then
  echo "!! Spoiler phrase found in content/ (see matches above)."
  FAIL=1
fi

# (b) Excluded files must be absent
for f in \
  "Characters/NPCs/Kári.md" \
  "Characters/NPCs/Snorri.md" \
  "Objects/Snorri's notebook.md" \
  "Astrodia/War Rock Mountains.md" \
  "Sessions/Session 3.md" "Sessions/Session 4.md" "Sessions/Session 5.md" \
  "Sessions/Session 6.md" "Sessions/Session 7.md" "Sessions/Session 0.md" \
  "Sessions/Session 1 (Episode 2) Notes.md"; do
  if [ -e "$REPO_DIR/content/$f" ]; then echo "!! Excluded file present: $f"; FAIL=1; fi
done

# (c) Excluded directories must be absent
for d in "MyCharacters" "DM meetings"; do
  if [ -e "$REPO_DIR/content/$d" ]; then echo "!! Excluded dir present: $d"; FAIL=1; fi
done

# (d) Secret images must be absent
for img in "Pasted image 20260202134910.png" "Pasted image 20260419232353.png"; do
  if [ -e "$REPO_DIR/content/$img" ]; then echo "!! Secret image present: $img"; FAIL=1; fi
done

if [ "$FAIL" -ne 0 ]; then
  echo ""
  echo "==> SAFETY GATE FAILED — nothing was committed or pushed."
  echo "    Fix the exclude-list or the offending note, then re-run."
  exit 1
fi
echo "    Safety gate passed."

echo "==> [4/4] Committing & pushing to origin/$BRANCH"
git add -A
if git diff --cached --quiet; then
  echo "    No changes to publish."
  exit 0
fi
git commit -m "$COMMIT_MSG"
git push origin "$BRANCH"
echo "==> Done. GitHub Actions will rebuild and redeploy the site shortly."
