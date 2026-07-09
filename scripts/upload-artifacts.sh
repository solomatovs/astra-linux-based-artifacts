#!/usr/bin/env bash
# Upload source tarballs (listed in artifacts-manifest.tsv) to a GitHub Release.
# Run this ONCE after the light repo is pushed, then again whenever tarballs change.
#
# Auth: either `gh auth login` (preferred) OR export GITHUB_TOKEN=<PAT with repo scope>.
#
#   ./scripts/upload-artifacts.sh
#   REPO=... RELEASE_TAG=... ./scripts/upload-artifacts.sh
#
# Re-runnable: existing assets are overwritten.
set -euo pipefail

REPO="${REPO:-solomatovs/astra-linux-based-artifacts}"
RELEASE_TAG="${RELEASE_TAG:-sources-v1}"
RELEASE_TITLE="${RELEASE_TITLE:-Source tarballs ($RELEASE_TAG)}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/artifacts-manifest.tsv"
[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST" >&2; exit 1; }

# ---- gh path -------------------------------------------------------------
if command -v gh >/dev/null 2>&1; then
  echo "using gh CLI"
  if ! gh release view "$RELEASE_TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release create "$RELEASE_TAG" --repo "$REPO" --title "$RELEASE_TITLE" \
      --notes "Source tarballs for offline builds. Fetch with scripts/fetch-artifacts.sh."
  fi
  while IFS=$'\t' read -r path size sha asset; do
    [ -n "$path" ] || continue
    echo "-> $asset"
    gh release upload "$RELEASE_TAG" --repo "$REPO" --clobber "$ROOT/$path#$asset"
  done < <(tail -n +2 "$MANIFEST")
  echo "done."
  exit 0
fi

# ---- curl + token fallback ----------------------------------------------
: "${GITHUB_TOKEN:?install gh, or export GITHUB_TOKEN with a repo-scoped PAT}"
API="https://api.github.com/repos/$REPO"
UPLOADS="https://uploads.github.com/repos/$REPO"
auth=(-H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json")

echo "using curl + GITHUB_TOKEN"
rel_id="$(curl -fsS "${auth[@]}" "$API/releases/tags/$RELEASE_TAG" 2>/dev/null | grep -m1 '"id"' | grep -oE '[0-9]+' || true)"
if [ -z "$rel_id" ]; then
  rel_id="$(curl -fsS "${auth[@]}" -X POST "$API/releases" \
    -d "{\"tag_name\":\"$RELEASE_TAG\",\"name\":\"$RELEASE_TITLE\",\"body\":\"Source tarballs for offline builds.\"}" \
    | grep -m1 '"id"' | grep -oE '[0-9]+')"
fi
[ -n "$rel_id" ] || { echo "could not resolve release id" >&2; exit 1; }
echo "release id: $rel_id"

while IFS=$'\t' read -r path size sha asset; do
  [ -n "$path" ] || continue
  echo "-> $asset"
  # delete a pre-existing asset of the same name so upload doesn't 422
  old="$(curl -fsS "${auth[@]}" "$API/releases/$rel_id/assets?per_page=100" \
    | grep -B1 "\"name\": \"$asset\"" | grep '"id"' | grep -oE '[0-9]+' | head -1 || true)"
  [ -n "$old" ] && curl -fsS "${auth[@]}" -X DELETE "$API/releases/assets/$old" >/dev/null || true
  curl -fsS "${auth[@]}" -H "Content-Type: application/octet-stream" \
    --data-binary @"$ROOT/$path" \
    "$UPLOADS/releases/$rel_id/assets?name=$asset" >/dev/null
done < <(tail -n +2 "$MANIFEST")
echo "done."
