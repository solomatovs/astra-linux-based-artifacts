#!/usr/bin/env bash
# Download source tarballs from GitHub Release assets into their in-tree paths.
# Tarballs are intentionally NOT stored in git (see .gitignore + artifacts-manifest.tsv).
#
#   ./scripts/fetch-artifacts.sh            # fetch everything missing / mismatched
#   REPO=... RELEASE_TAG=... ./scripts/fetch-artifacts.sh
#
# Re-runnable: files whose sha256 already matches the manifest are skipped.
set -euo pipefail

REPO="${REPO:-solomatovs/astra-linux-based-artifacts}"
RELEASE_TAG="${RELEASE_TAG:-sources-v1}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/artifacts-manifest.tsv"
BASE="https://github.com/${REPO}/releases/download/${RELEASE_TAG}"

[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST" >&2; exit 1; }

ok=0; fetched=0; failed=0
# process substitution (not a pipe) so counters survive the loop
while IFS=$'\t' read -r path size sha asset; do
  [ -n "$path" ] || continue
  dest="$ROOT/$path"
  if [ -f "$dest" ] && [ "$(sha256sum "$dest" | cut -d' ' -f1)" = "$sha" ]; then
    ok=$((ok+1)); continue
  fi
  echo "-> $path"
  mkdir -p "$(dirname "$dest")"
  if curl -fL --retry 3 --retry-delay 2 -o "$dest.part" "$BASE/$asset"; then
    got="$(sha256sum "$dest.part" | cut -d' ' -f1)"
    if [ "$got" = "$sha" ]; then
      mv "$dest.part" "$dest"; fetched=$((fetched+1))
    else
      echo "   !! sha256 mismatch for $asset (want $sha got $got)" >&2
      rm -f "$dest.part"; failed=$((failed+1))
    fi
  else
    echo "   !! download failed: $BASE/$asset" >&2
    rm -f "$dest.part"; failed=$((failed+1))
  fi
done < <(tail -n +2 "$MANIFEST")

echo "done: $ok up-to-date, $fetched fetched, $failed failed."
[ "$failed" -eq 0 ]
