#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
validator="$root/scripts/validate-trajectory-evidence.py"
fixtures="$root/tests/evaluation/fixtures"
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT

python3 "$validator" "$fixtures/valid-completed-trajectory.json" >"$temporary_root/completed.json"
jq -e '.schema == "repository-harness-trajectory-validation/v1" and
  .valid == true and (.errors | length == 0) and
  .summary.events == 7 and .summary.mutations == 1 and
  .summary.validations == 1 and .summary.error_count == 0' \
  "$temporary_root/completed.json" >/dev/null

python3 "$validator" "$fixtures/valid-authority-stop-trajectory.json" >"$temporary_root/stop.json"
jq -e '.valid == true and (.errors | length == 0) and
  .summary.events == 4 and .summary.mutations == 0' \
  "$temporary_root/stop.json" >/dev/null

if python3 "$validator" "$fixtures/invalid-mutation-before-authority.json" >"$temporary_root/mutation.json"; then
  echo 'trajectory validator accepted mutation before authority' >&2
  exit 1
fi
jq -e '(.valid == false) and
  ([.errors[].code] | index("missing_authority_before_mutation") != null) and
  (.summary.error_count > 0)' "$temporary_root/mutation.json" >/dev/null

if python3 "$validator" "$fixtures/invalid-completed-without-proof.json" >"$temporary_root/proof.json"; then
  echo 'trajectory validator accepted completed evidence without proof' >&2
  exit 1
fi
jq -e '(.valid == false) and
  ([.errors[].code] | index("missing_proof_reference") != null)' \
  "$temporary_root/proof.json" >/dev/null

if python3 "$validator" "$fixtures/invalid-sensitive-payload.json" >"$temporary_root/sensitive.json"; then
  echo 'trajectory validator accepted a forbidden payload field' >&2
  exit 1
fi
jq -e '(.valid == false) and
  ([.errors[].code] | index("forbidden_field") != null) and
  ([.errors[].code] | index("invalid_metadata_label") != null) and
  (tostring | contains("must-not-be-recorded") | not)' \
  "$temporary_root/sensitive.json" >/dev/null

printf 'External trajectory evidence contract passed: metadata boundary, authority ordering, and outcome proof\n'
