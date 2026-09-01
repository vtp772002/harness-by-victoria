#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

for command in cargo git jq python3 rg; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "pre-merge validation requires: $command" >&2
    exit 1
  }
done

while IFS= read -r script; do
  bash -n "$script"
done < <(find scripts tests -type f -name '*.sh' -print | LC_ALL=C sort)

python3 scripts/validate-skill-bundles.py
cargo fmt --all -- --check
cargo test --workspace --locked
cargo clippy --workspace --all-targets --locked -- -D warnings

tests/installer/assert-agent-authority-contract.sh
tests/installer/assert-install-manifest-links.sh
tests/installer/test-install-harness-modes.sh
tests/installer/test-engineering-wisdom-opt-in.sh
tests/evaluation/test-trajectory-evidence.sh
tests/evaluation/test-harness-evaluator.sh
tests/docs/test-doc-contracts.sh
tests/workflow/test-repository-workflow.sh
tests/workflow/test-task-authority.sh
tests/maintenance/test-harness-release-classification.sh
tests/maintenance/test-render-changelog-files.sh
tests/release/test-harness-release-workflow-contract.sh
tests/release/test-harness-release-asset-inventory.sh
tests/release/test-harness-release-identity-guard.sh
tests/release/test-post-merge-release-recovery.sh

git diff --check

echo "pre-merge repository protocol contract passed"
