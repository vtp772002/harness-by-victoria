# External Trajectory Evidence Contract v1

## Purpose

`scripts/validate-trajectory-evidence.py` is an optional interoperability
adapter for an external agent/evaluation runner. It validates whether a
metadata-only trajectory follows the repository workflow and returns a stable
machine-readable result. It does not run an agent, invoke tools, collect
transcripts, or replace the repository-owned six-check scorecard.

The boundary is authorized by
[`decision 0029`](../decisions/0029-metadata-only-external-trajectory-evidence.md).
The behavior rules come from
[`docs/WORKFLOW.md`](../WORKFLOW.md): inspect authority, stop before material
ambiguity, validate bounded changes, and claim completion only with proof.

## Invocation

```bash
python3 scripts/validate-trajectory-evidence.py trajectory.json
python3 scripts/validate-trajectory-evidence.py - < trajectory.json
```

Exit code `0` means the artifact is structurally valid. Exit code `1` means it
is invalid. Both outcomes emit one JSON report on stdout. Input or schema
failures never echo the submitted payload.

## Privacy boundary

The input must contain:

```json
"privacy": {
  "mode": "metadata_only",
  "payloads_redacted": true
}
```

Only bounded identifiers and references are accepted. The validator rejects
prompt, transcript, content, stdout/stderr, tool input/output, secret, token,
credential, and arbitrary unknown fields. The input is bounded at 2 MB and the
trajectory at 10,000 events.

## Input shape

The top-level schema is `repository-harness-trajectory/v1`:

- `run`: `run_id`, lowercase 40-character `repository_revision`, `client`, and
  optional bounded `model`, `runner`, and `started_at`;
- `events`: ordered metadata events; each has contiguous `seq`, a v1 `type`,
  and only the fields allowed for that event; and
- `outcome`: `status`, boolean `changed`, and bounded `proof_refs`.

The event types are:

| Type | Required meaning |
| --- | --- |
| `request` | First event, with `ref: "request"`. |
| `authority_read` | The agent inspected an authority reference. |
| `behavior_read` | The agent inspected affected behavior or proof context. |
| `decision_stop` | Work stopped for a declared authority/prerequisite reason. |
| `mutation` | A bounded change, with its governing `authority` reference. |
| `validation` | A proof command/reference with `passed` or `failed` result. |
| `completion` | Final event; result matches the outcome status. |

The validator enforces these trajectory rules:

- a mutation must follow an earlier `authority_read`;
- `stopped_for_authority` cannot contain a mutation;
- every completed trajectory must have a proof reference;
- a completed mutation must also have a later passed validation;
- a failed-validation outcome must record a failed validation; and
- exactly one request and one completion event are required.

## Output shape

The output schema is `repository-harness-trajectory-validation/v1`:

```json
{
  "schema": "repository-harness-trajectory-validation/v1",
  "valid": true,
  "errors": [],
  "summary": {
    "events": 7,
    "mutations": 1,
    "validations": 1,
    "error_count": 0
  }
}
```

Invalid reports contain stable `code`, `path`, and actionable `message`
objects. The validator does not attest that a runner honestly recorded its
events, that the referenced command actually ran, or that a model succeeded
on a task. Those require runner-owned provenance and outcome evidence.

## Scope limits

This adapter is not part of the default installed core. It does not provide
provider telemetry, cost accounting, permissions, sandboxing, branch
protection, raw trace retention, or a hosted evaluation service. A runner that
needs those capabilities must establish a separate authority, privacy, and
retention contract before integration.
