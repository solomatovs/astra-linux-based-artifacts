# Source artifacts

Large source tarballs are **not** stored in git (GitHub blocks files >100 MB and
pushes near ~2 GB). They live as **GitHub Release assets** and are described by
[`artifacts-manifest.tsv`](artifacts-manifest.tsv) — one row per tarball with its
in-tree path, size, sha256, and release asset name.

## Fetch tarballs (for a build)

```bash
./scripts/fetch-artifacts.sh
```

Downloads every tarball listed in the manifest into its expected path and verifies
sha256. Already-present, matching files are skipped, so it is safe to re-run.

## Publish/refresh tarballs (maintainers)

```bash
gh auth login                 # or: export GITHUB_TOKEN=<PAT with repo scope>
./scripts/upload-artifacts.sh
```

Creates the `sources-v1` release if needed and uploads/overwrites all assets.

## Adding a new tarball

1. Drop the file at its path (it is git-ignored automatically).
2. Append a row to `artifacts-manifest.tsv` (path, size, sha256, asset). The asset
   name is the path with `/` replaced by `_`.
3. Run `./scripts/upload-artifacts.sh`.

Override `REPO` / `RELEASE_TAG` via environment variables in any script.
