#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

for command in cargo git jq rustc uname; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'Harness evaluation requires: %s\n' "$command" >&2
    exit 1
  }
done

temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
case_results="$temporary_root/cases.jsonl"
: >"$case_results"

run_case() {
  local case_id="$1"
  local dimension="$2"
  local command_label="$3"
  local proof_description="$4"
  shift 4

  local output_file="$temporary_root/$case_id.out"
  local exit_code
  local diagnostic_json=null
  set +e
  "$@" >"$output_file" 2>&1
  exit_code=$?
  set -e

  local case_status=failed
  [ "$exit_code" -eq 0 ] && case_status=passed
  local next_action='No action required.'
  if [ "$exit_code" -ne 0 ]; then
    next_action="Run $command_label directly to inspect the full diagnostic."
    # Preserve enough failure evidence for a CI artifact without turning the
    # scorecard into an unbounded log transport.
    diagnostic_json=$(tail -c 4096 "$output_file" | jq -Rs .)
  fi
  jq -cn \
    --arg id "$case_id" \
    --arg dimension "$dimension" \
    --arg command "$command_label" \
    --arg proof "$proof_description" \
    --arg status "$case_status" \
    --arg next_action "$next_action" \
    --argjson diagnostic "$diagnostic_json" \
    --argjson exit_code "$exit_code" \
    '{id: $id, dimension: $dimension, command: $command, status: $status,
      exit_code: $exit_code, proof: [$proof], diagnostic: $diagnostic,
      next_action: $next_action}' >>"$case_results"
}

run_case \
  authority_boundary \
  authority \
  tests/workflow/test-task-authority.sh \
  'read-only discovery, bounded mutation, durable plans, and ambiguity stops' \
  "$root/tests/workflow/test-task-authority.sh"

run_case \
  repository_workflow \
  workflow \
  tests/workflow/test-repository-workflow.sh \
  'positive and negative workflow scenarios without hidden control-plane state' \
  "$root/tests/workflow/test-repository-workflow.sh"

run_case \
  installer_safety \
  safety \
  tests/installer/test-install-harness-modes.sh \
  'fresh install, preservation, symlink rejection, checksum rejection, and release identity' \
  "$root/tests/installer/test-install-harness-modes.sh"

run_case \
  core_lifecycle \
  maintenance \
  'cargo test --workspace --locked' \
  'install, status, doctor, transactional updates, conflict staging, drift, rollback, and recovery' \
  cargo test --workspace --locked

run_case \
  release_integrity \
  release \
  'cargo test -p harness --test release_update --locked' \
  'candidate checksum, release identity, executable recovery, and human-directed continuation' \
  cargo test -p harness --test release_update --locked

run_case \
  documentation_contract \
  documentation \
  tests/docs/test-doc-contracts.sh \
  'current authority, product boundaries, evaluation map, and validation references' \
  "$root/tests/docs/test-doc-contracts.sh"

revision=$(git rev-parse HEAD)
branch=$(git branch --show-current)
worktree_dirty=false
[ -n "$(git status --porcelain)" ] && worktree_dirty=true
os=$(uname -s)
architecture=$(uname -m)
rustc_version=$(rustc --version)
cargo_version=$(cargo --version)
jq_version=$(jq --version)
checks=$(jq -s '.' "$case_results")
total=$(printf '%s\n' "$checks" | jq 'length')
passed=$(printf '%s\n' "$checks" | jq '[.[] | select(.status == "passed")] | length')
failed=$((total - passed))

jq -n \
  --arg schema 'repository-harness-evaluation/v1' \
  --arg revision "$revision" \
  --arg branch "$branch" \
  --arg os "$os" \
  --arg architecture "$architecture" \
  --arg rustc_version "$rustc_version" \
  --arg cargo_version "$cargo_version" \
  --arg jq_version "$jq_version" \
  --argjson worktree_dirty "$worktree_dirty" \
  --argjson checks "$checks" \
  --argjson total "$total" \
  --argjson passed "$passed" \
  --argjson failed "$failed" \
  '{schema: $schema,
    repository: {revision: $revision, branch: $branch, worktree_dirty: $worktree_dirty},
    environment: {os: $os, architecture: $architecture, rustc: $rustc_version,
                  cargo: $cargo_version, jq: $jq_version},
    scope: "Harness-owned repository contracts only",
    not_evaluated: [
      "LLM capability or model quality",
      "consumer application runtime behavior",
      "host-agent permissions or sandbox isolation",
      "provider telemetry, cost, or branch protection"
    ],
    checks: $checks,
    summary: {total: $total, passed: $passed, failed: $failed,
              all_passed: ($failed == 0)}}'

[ "$failed" -eq 0 ]
