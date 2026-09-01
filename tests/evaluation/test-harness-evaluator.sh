#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
evaluator="$root/scripts/evaluate-harness.sh"
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
report="$temporary_root/report.json"

evaluation_exit_code=0
set +e
"$evaluator" >"$report"
evaluation_exit_code=$?
set -e

if [ -n "${HARNESS_EVALUATION_REPORT:-}" ]; then
  cp "$report" "$HARNESS_EVALUATION_REPORT"
fi

if [ "$evaluation_exit_code" -ne 0 ]; then
  cat "$report"
  exit "$evaluation_exit_code"
fi

jq -e '(.schema == "repository-harness-evaluation/v1") and
  (.repository.revision | test("^[0-9a-f]{40}$")) and
  (.environment.os | type == "string" and length > 0) and
  (.environment.architecture | type == "string" and length > 0) and
  (.environment.rustc | startswith("rustc ")) and
  (.environment.cargo | startswith("cargo ")) and
  (.environment.jq | startswith("jq-")) and
  (.scope == "Harness-owned repository contracts only") and
  (.not_evaluated | length == 4) and
  (.checks | length == 6) and
  ([.checks[].id] | sort == [
    "authority_boundary",
    "core_lifecycle",
    "documentation_contract",
    "installer_safety",
    "release_integrity",
    "repository_workflow"
  ]) and
  (all(.checks[]; .status == "passed" and .exit_code == 0 and
       (.proof | length > 0) and .diagnostic == null and
       .next_action == "No action required.")) and
  (.summary.total == 6) and
  (.summary.passed == 6) and
  (.summary.failed == 0) and
  (.summary.all_passed == true)' "$report" >/dev/null

printf 'Harness behavior evaluation contract passed: six claim-matched checks\n'
