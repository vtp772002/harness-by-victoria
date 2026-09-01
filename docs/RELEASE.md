# Core Release Runbook

This runbook is the authority for publishing a `harness-by-victoria` core
binary release. The release workflow is deliberately proof-first: it verifies
the exact source commit, builds all supported platforms, checks each checksum,
smokes the core lifecycle, attests each binary, and only then promotes the tag
and publishes the release.

## Preconditions

Before starting a release:

- the release-bearing commit is on this repository's `main` branch;
- `crates/harness/Cargo.toml`, `Cargo.lock`, and `scripts/harness-release-tag`
  agree on the intended version;
- `scripts/validate-premerge.sh` passes on that commit;
- the requested tag does not already exist;
- a maintainer is authorized to publish a GitHub Release for
  `vtp772002/harness-by-victoria`.

Do not publish from an unmerged pull-request branch. The identity guard rejects
that path so the published tag and evidence remain traceable to `main`.

## Manual Release

Run the workflow from the exact `main` commit to be released:

```bash
gh workflow run harness-release.yml \
  --repo vtp772002/harness-by-victoria \
  --ref main \
  --field release_tag=harness-vX.Y.Z \
  --field checkout_ref=<main-commit-sha>
```

Replace `harness-vX.Y.Z` and `<main-commit-sha>` with the approved version and
the full commit SHA on `main`. Do not reuse an existing tag or force-push a
release tag.

After a merged pull request changes the core, `post-merge-maintenance.yml`
updates the version metadata and calls the same release workflow. The workflow
still owns the proof boundary; maintenance does not bypass verification.

## What the Workflow Proves

The release has five platform jobs:

1. verify source identity and run the repository pre-merge contract;
2. build macOS arm64/x64, Linux x64/arm64, and Windows x64 artifacts;
3. verify every SHA-256 sidecar and smoke install, update, status, and doctor;
4. generate a GitHub artifact attestation for each binary;
5. verify the exact ten-file asset inventory, promote the proven tag, and create
   the immutable GitHub Release.

The attestation covers the binary. The `.sha256` sidecar remains an independent
byte-integrity check. GitHub's hosted attestation service is the current trust
path; this repository does not claim an offline or independent publisher key.

## Verify a Published Release

Download the assets into a fresh directory, then verify the exact inventory and
all sidecars:

```bash
release_dir="$(mktemp -d)"
gh release download harness-vX.Y.Z \
  --repo vtp772002/harness-by-victoria \
  --dir "$release_dir"

scripts/verify-harness-release-assets.sh "$release_dir"

cd "$release_dir"
for checksum in *.sha256; do
  sha256sum -c "$checksum"
done
for binary in harness-*; do
  gh attestation verify "$binary" \
    -R vtp772002/harness-by-victoria
done
```

On macOS, replace `sha256sum -c` with `shasum -a 256 -c`. A consumer can use
the same attestation command after downloading one platform binary.

## Recovery and Non-Goals

- A failed platform build, checksum, smoke test, attestation, or asset check
  blocks publication.
- An existing tag or release is never mutated by this workflow.
- Do not delete evidence, force-push tags, or manually upload replacement
  assets to work around a failed proof step.
- If publication stops after tag promotion, preserve the tag and workflow run
  as evidence and obtain an authorized maintainer decision before any repair.
- Branch protection, required checks, Dependabot, vulnerability alerts, and
  repository settings are external GitHub controls; this document does not
  claim that they are enabled.

## Current Bootstrap Status

As of 2026-09-01, the release workflow and its local contract are implemented,
but this repository has not yet published its first own core binary release.
The bootstrap therefore still defaults to the upstream binary channel until an
authorized maintainer completes the first release. The migration to this
repository's binary channel must happen only after that release exists and its
assets, checksums, and attestations have been verified.
