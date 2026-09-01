#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
release="$root/.github/workflows/harness-release.yml"
post_merge="$root/.github/workflows/post-merge-maintenance.yml"

[[ "$(grep -Ec '^          - platform: (macos-arm64|macos-x64|linux-x64|linux-arm64|windows-x64)$' "$release")" == 5 ]]
for platform in macos-arm64 macos-x64 linux-x64 linux-arm64 windows-x64; do
  grep -Fq -- "- platform: $platform" "$release"
done
grep -Fq 'run: scripts/validate-premerge.sh' "$release"
! grep -Fq 'scripts/bootstrap-harness.sh' "$release"
! grep -Fq 'scripts/verify-materialized-core-parity.sh' "$release"
! grep -Fq 'sqlite3' "$release"
! grep -Fq 'harness-cli' "$release"
grep -Fq 'scripts/build-harness-release.sh' "$release"
grep -Fq 'scripts/verify-harness-release-identity.sh' "$release"
grep -Fq 'scripts/promote-harness-release-tag.sh' "$release"
grep -Fq -- '--verify-tag' "$release"
grep -Fq 'name: harness-core-${{ matrix.platform }}' "$release"
grep -Fq 'pattern: harness-core-*' "$release"
! grep -Fq 'pattern: harness-*' "$release"
inventory_line=$(grep -n 'Verify exact core artifact inventory before tag promotion' "$release" | cut -d: -f1)
promotion_line=$(grep -n 'Promote proven source to immutable tag' "$release" | cut -d: -f1)
[[ -n "$inventory_line" && "$inventory_line" -lt "$promotion_line" ]]
grep -Fq 'scripts/verify-harness-release-assets.sh dist' "$release"
grep -Fq 'test "$(gh release view "$RELEASE_TAG"' "$release"
! grep -Fq -- '--clobber' "$release"
! grep -Eq '^  push:' "$release"
! grep -Fq 'git tag ' "$release"

attestation_contract() {
  local workflow=$1
  local build_job
  build_job=$(awk '
    /^  build:/ { in_build=1 }
    /^  publish:/ { in_build=0 }
    in_build { print }
  ' "$workflow")
  grep -Fq 'contents: read' <<<"$build_job" || return 1
  grep -Fq 'id-token: write' <<<"$build_job" || return 1
  grep -Fq 'attestations: write' <<<"$build_job" || return 1
  grep -Fq 'uses: actions/attest@v4' <<<"$build_job" || return 1
  grep -Fq 'subject-path: dist/${{ matrix.binary }}' <<<"$build_job" || return 1
}

attestation_contract "$release"
attestation_fixture=$(mktemp)
cp "$release" "$attestation_fixture"
sed -i.bak '/uses: actions\/attest@v4/d' "$attestation_fixture"
if attestation_contract "$attestation_fixture"; then
  echo "workflow unexpectedly accepted without artifact attestation" >&2
  exit 1
fi
rm -f "$attestation_fixture" "$attestation_fixture.bak"
grep -Fq 'id-token: write' "$post_merge"
grep -Fq 'attestations: write' "$post_merge"
grep -Fq 'harness_changed: ${{ steps.maintenance.outputs.harness_changed }}' "$post_merge"
grep -Fq 'uses: ./.github/workflows/harness-release.yml' "$post_merge"
grep -Fq 'harness_release_tag="harness-v$new_version"' "$post_merge"
grep -Fq 'checkout_ref: ${{ needs.prepare.outputs.maintenance_ref }}' "$post_merge"

for workflow in "$release" "$post_merge"; do
  grep -Fq 'actions/checkout@v7' "$workflow"
  ! grep -Eq 'actions/(checkout|upload-artifact|download-artifact)@v[1-6]' "$workflow"
done
grep -Fq 'actions/upload-artifact@v7' "$release"
grep -Fq 'actions/download-artifact@v8' "$release"

echo "Harness core five-platform proof-before-promotion workflow contract passed"
