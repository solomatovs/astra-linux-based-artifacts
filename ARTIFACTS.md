# Source artifacts

This repository is a **git-only transport for build artifacts**: everything must be
retrievable with `git clone` alone (no GitHub Releases / LFS, which are served from
separate hosts that the build environment cannot reach).

All source tarballs are therefore committed **into git**. To respect GitHub's hard
**100 MB-per-file** limit, tarballs larger than that are split into
`<file>.part-000`, `<file>.part-001`, … and only the pieces are committed.
[`artifacts-manifest.tsv`](artifacts-manifest.tsv) lists every tarball with its
path, size, sha256, and part count (`parts=0` means stored whole).

## On the build machine

```bash
git clone https://github.com/solomatovs/astra-linux-based-artifacts.git
cd astra-linux-based-artifacts
./scripts/assemble-artifacts.sh   # rebuild split tarballs + verify all sha256
```

Whole tarballs are already in place after clone; the script only reassembles the
split ones and checks integrity. Safe to re-run.

## Publishing (maintainer, needs push access)

Large tarballs make the total push exceed GitHub's ~2 GB single-push limit, so the
push is done in size-bounded batches:

```bash
./scripts/split-artifacts.sh      # (re)generate .part-* pieces + manifest for files >95 MB
./scripts/push-artifacts.sh       # commit + push in <1.2 GB batches
```

## Adding a new tarball

1. Drop the file at its path under the relevant `*/artifacts/src/` directory.
2. Run `./scripts/split-artifacts.sh` (splits it if >95 MB and refreshes the manifest).
3. Run `./scripts/push-artifacts.sh`.

Override `BATCH_MB` (default 1200) to change push batch size.
