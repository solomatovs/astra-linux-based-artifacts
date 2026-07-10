#!/usr/bin/env bash
# Maintainer helper: split any tarball >95 MB into <100 MB .part-* pieces and
# (re)generate artifacts-manifest.tsv with path, size, sha256, and part count.
#
#   ./scripts/split-artifacts.sh
#
# Idempotent: re-splits from the current whole files and rewrites the manifest.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
CHUNK="${CHUNK:-90M}"
MANIFEST="artifacts-manifest.tsv"

# find whole tarballs (exclude the .part-* pieces themselves)
mapfile -t TARBALLS < <(find . -type f \( -name '*.tar' -o -name '*.tar.*' -o -name '*.tgz' \) \
  ! -name '*.part-*' | sed 's|^\./||' | sort)

printf 'path\tsize\tsha256\tparts\n' > "$MANIFEST"
for f in "${TARBALLS[@]}"; do
  size=$(stat -c %s "$f")
  sha=$(sha256sum "$f" | cut -d' ' -f1)
  rm -f "$f".part-*
  if [ "$size" -gt $((95*1024*1024)) ]; then
    split -b "$CHUNK" -d -a 3 "$f" "$f.part-"
    parts=$(ls "$f".part-* | wc -l)
  else
    parts=0
  fi
  printf '%s\t%s\t%s\t%s\n' "$f" "$size" "$sha" "$parts" >> "$MANIFEST"
done

# .gitignore: ignore only the assembled originals of split tarballs
{
  echo "# Assembled originals of split tarballs are NOT committed — their .part-* pieces are."
  echo "# Rebuild them on the build machine with scripts/assemble-artifacts.sh (after git clone)."
  awk -F'\t' 'NR>1 && $4>0 {print "/"$1}' "$MANIFEST"
} > .gitignore

split=$(awk -F'\t' 'NR>1 && $4>0' "$MANIFEST" | wc -l)
echo "manifest: $(( $(wc -l < "$MANIFEST") - 1 )) tarballs, $split split."
