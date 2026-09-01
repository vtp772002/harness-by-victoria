#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

fail() {
  printf 'documentation contract failed: %s\n' "$*" >&2
  exit 1
}

require() {
  local file=$1
  local text=$2
  rg -Fq -- "$text" "$root/$file" || fail "$file omits: $text"
}

current_files=(
  README.md
  AGENTS.md
  docs/WORKFLOW.md
  docs/ARCHITECTURE.md
  docs/HARNESS.md
  docs/README.md
  docs/patterns/encoding-invariants.md
  docs/product/README.md
  docs/product/installation-profiles.md
  docs/plans/README.md
  docs/plans/active/README.md
  docs/plans/completed/README.md
  docs/decisions/README.md
  docs/templates/application-runbook.md
  docs/templates/decision.md
  docs/templates/exec-plan.md
  docs/templates/harness-improvement.md
  docs/decisions/0019-repository-centered-default-workflow.md
  docs/decisions/0020-installation-profile-and-knowledge-boundaries.md
  docs/decisions/0024-rust-harness-core-maintenance-cli.md
  docs/decisions/0025-latest-release-self-update-and-human-directed-conflicts.md
  docs/decisions/0026-explicit-onboarding-skills-in-default-core.md
  docs/decisions/0027-end-protocol-v1-and-focus-repository-protocol.md
  docs/decisions/0028-authoritative-invariant-encoding.md
  docs/research/application-legibility.md
  docs/research/agent-harness-landscape.md
  docs/evaluation/harness-evaluation-v1.md
  docs/evaluation/trajectory-evidence-v1.md
  docs/decisions/0029-metadata-only-external-trajectory-evidence.md
  docs/decisions/0030-node24-github-actions-runtime.md
  docs/decisions/0031-portable-agent-skills-bundle-contract.md
  docs/plans/active/world-class-harness.md
  scripts/evaluate-harness.sh
  scripts/validate-trajectory-evidence.py
  scripts/validate-skill-bundles.py
  tests/skills/test-skill-bundles.sh
  tests/evaluation/test-harness-evaluator.sh
  tests/evaluation/test-trajectory-evidence.sh
  scripts/claude-skill-install-files.txt
  scripts/claude-engineering-wisdom-shim.md
  .claude/skills/audit-onboarding-proposal/SKILL.md
  .claude/skills/encode-invariant/SKILL.md
  .claude/skills/improve-harness/SKILL.md
  .claude/skills/onboard-repository/SKILL.md
  .github/ISSUE_TEMPLATE/real-world-example.md
)
for file in "${current_files[@]}"; do
  [[ -f "$root/$file" ]] || fail "missing current artifact: $file"
done

require AGENTS.md 'Start with the requested outcome'
require AGENTS.md 'configurable defaults are not authority'
require docs/WORKFLOW.md '### Bounded Change'
require docs/WORKFLOW.md '### Durable Planned Change'
require docs/WORKFLOW.md '### Operate The Application'
require docs/WORKFLOW.md '### Improve The Harness'
require docs/WORKFLOW.md '### Does The Work Encode An Invariant?'
require docs/patterns/encoding-invariants.md '## 1. Establish Authority'
require docs/patterns/encoding-invariants.md '## 4. Prove Both Directions'
require docs/patterns/encoding-invariants.md '## 5. Discover And Report Enforcement'
require docs/patterns/encoding-invariants.md '| Scope | Files, modules, configuration, or runtime objects covered |'
require docs/patterns/encoding-invariants.md 'Find the repository'
require docs/patterns/encoding-invariants.md '| Diagnostic | Violating item, broken rule, authority pointer, and next action |'
require docs/patterns/encoding-invariants.md '**Positive proof:**'
require docs/patterns/encoding-invariants.md '**Negative proof:**'
require docs/patterns/encoding-invariants.md '| Local validation |'
require docs/patterns/encoding-invariants.md '| Optional hook |'
require docs/patterns/encoding-invariants.md '| CI |'
require docs/patterns/encoding-invariants.md '| Branch protection |'
require docs/decisions/0028-authoritative-invariant-encoding.md 'Matching requests may invoke it implicitly'
require docs/ARCHITECTURE.md 'one Rust binary'
require README.md '## What We Prove'
require README.md '## Evaluate Harness'
require README.md '## Protocol V1 End Of Life'
require README.md '--claude'
require README.md '-Claude'
require README.md '.claude/skills/'
require README.md 'canonical skill bodies'
require docs/research/application-legibility.md 'research, not a release gate'
require docs/decisions/0027-end-protocol-v1-and-focus-repository-protocol.md '`harness-cli-v0.1.22`'
require .github/ISSUE_TEMPLATE/real-world-example.md '`docs/WORKFLOW.md`'
require .github/ISSUE_TEMPLATE/real-world-example.md '`docs/ARCHITECTURE.md`'

for heading in Outcome Context Scope Approach 'Risks And Recovery' Progress Decisions Validation Result; do
  require docs/templates/exec-plan.md "## $heading"
done

while IFS= read -r payload; do
  [[ -f "$root/$payload" ]] || fail "core manifest target is missing: $payload"
done < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$root/scripts/harness-install-files.txt")

compatibility_paths=(
  crates/harness-cli
  scripts/schema
  scripts/harness-cli-install-files.txt
  .github/workflows/harness-cli-release.yml
  docs/contracts/harness-orchestration-v1.md
  docs/compatibility
  docs/stories
  .harness/core-state
  .harness/changesets
)
for compatibility_path in "${compatibility_paths[@]}"; do
  target="$root/$compatibility_path"
  if [[ -d "$target" ]]; then
    [[ -z "$(find "$target" -type f -print -quit)" ]] ||
      fail "EOL compatibility files remain: $compatibility_path"
  else
    [[ ! -e "$target" ]] || fail "EOL compatibility path remains: $compatibility_path"
  fi
done

executables=(
  scripts/validate-premerge.sh
  tests/workflow/test-repository-workflow.sh
  tests/workflow/test-task-authority.sh
  tests/installer/test-install-harness-modes.sh
  scripts/evaluate-harness.sh
  scripts/validate-trajectory-evidence.py
  scripts/validate-skill-bundles.py
  tests/evaluation/test-harness-evaluator.sh
  tests/evaluation/test-trajectory-evidence.sh
  tests/skills/test-skill-bundles.sh
)
for executable in "${executables[@]}"; do
  [[ -x "$root/$executable" ]] || fail "documented gate is not executable: $executable"
done

required_gates=(
  'cargo fmt --all -- --check'
  'cargo test --workspace --locked'
  'cargo clippy --workspace --all-targets --locked -- -D warnings'
  'tests/installer/test-install-harness-modes.sh'
  'tests/evaluation/test-harness-evaluator.sh'
  'tests/evaluation/test-trajectory-evidence.sh'
  'python3 scripts/validate-skill-bundles.py'
  'tests/docs/test-doc-contracts.sh'
  'tests/workflow/test-repository-workflow.sh'
  'tests/workflow/test-task-authority.sh'
  'tests/release/test-harness-release-workflow-contract.sh'
)
for gate in "${required_gates[@]}"; do
  require scripts/validate-premerge.sh "$gate"
done

require .github/workflows/premerge.yml 'run: scripts/validate-premerge.sh'
require .github/workflows/premerge.yml 'HARNESS_EVALUATION_REPORT: harness-evaluation.json'
require .github/workflows/premerge.yml 'name: harness-evaluation-report'
require .github/workflows/premerge.yml 'if: ${{ always() }}'
require .github/workflows/premerge.yml 'actions/checkout@v7'
require .github/workflows/premerge.yml 'actions/upload-artifact@v7'
require docs/decisions/0030-node24-github-actions-runtime.md 'Node 20 deprecation notice'
require docs/evaluation/harness-evaluation-v1.md 'final 4096 bytes'
require scripts/README.md 'bounded failure diagnostics'
require .github/workflows/premerge.yml 'tests/installer/test-install-harness-modes.ps1'
require .github/workflows/harness-release.yml 'run: scripts/validate-premerge.sh'
require docs/product/installation-profiles.md 'rejects symlink or reparse-point traversal'
require scripts/README.md 'optional payloads,'
require scripts/README.md 'agent shims'
require scripts/README.md '`--claude`'
require scripts/README.md '`-Claude`'
require scripts/README.md 'claude-skill-install-files.txt'
require scripts/README.md 'skill-discovery wrappers'
require docs/product/installation-profiles.md 'skill-discovery wrappers'
require README.md 'metadata-only trajectory evidence'
require scripts/README.md 'validate-trajectory-evidence.py'
require docs/README.md 'metadata-only boundary for external agent trajectory evidence'
require docs/evaluation/trajectory-evidence-v1.md 'repository-harness-trajectory/v1'
require docs/decisions/0031-portable-agent-skills-bundle-contract.md 'Agent Skills specification'
require scripts/README.md 'validate-skill-bundles.py'

"$root/tests/installer/assert-agent-authority-contract.sh" >/dev/null
"$root/tests/installer/assert-install-manifest-links.sh" >/dev/null

echo "current product, EOL boundary, manifest, authority, and validation references passed"
