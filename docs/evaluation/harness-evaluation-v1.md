# Harness Evaluation Contract v1

## Purpose

`scripts/evaluate-harness.sh` is the repository-native scorecard for the
claims Harness makes about its own repository protocol and maintenance core.
It runs deterministic tests and emits one JSON document for CI, release
review, or an external evaluation runner to consume.

This is a contract for Harness-owned behavior. It is not an LLM benchmark and
does not measure a model, a host agent, an arbitrary consumer application, or
an external enforcement system.

## Invocation

```bash
scripts/evaluate-harness.sh
```

Exit code `0` means every declared check passed. A non-zero exit code means at
least one check failed. The JSON report is emitted in both cases; each failed
check includes a `next_action` directing the operator to run its owning command
directly for the full diagnostic.

The repository pre-merge workflow also writes the report as
`harness-evaluation.json` and uploads it as the `harness-evaluation-report`
artifact when the evaluation stage is reached. The upload is evidence
availability, not proof that external branch protection requires the check.

## Output

The top-level `schema` is `repository-harness-evaluation/v1`. The report has:

- `repository`: the evaluated Git revision, branch, and whether the worktree
  was dirty at report time;
- `environment`: the operating-system, architecture, and tool versions needed
  to reproduce the run;
- `scope`: the fixed statement that only Harness-owned repository contracts are
  evaluated;
- `not_evaluated`: explicit boundaries for LLM quality, consumer runtime,
  host-agent permissions/sandboxing, provider telemetry/cost, and branch
  protection;
- `checks`: six deterministic checks, each with `id`, `dimension`, `command`,
  `status`, `exit_code`, `proof`, `diagnostic`, and `next_action`; and
- `summary`: `total`, `passed`, `failed`, and `all_passed`.

The six check IDs are fixed in v1:

| ID | Dimension | Claim-matched proof |
| --- | --- | --- |
| `authority_boundary` | authority | Read-only discovery, bounded mutation, durable plans, and ambiguity stops behave as documented. |
| `repository_workflow` | workflow | Positive and negative workflow scenarios preserve the no-hidden-control-plane boundary. |
| `installer_safety` | safety | Installation preserves consumer content, rejects unsafe paths, validates checksum, and validates release identity. |
| `core_lifecycle` | maintenance | Core install/status/doctor and transactional update/recovery behavior pass. |
| `release_integrity` | release | Candidate checksum, identity, executable recovery, and human-directed continuation pass. |
| `documentation_contract` | documentation | Current authority, product boundary, evaluation map, and validation references are coherent. |

`status` is `passed` or `failed`. `proof` describes the behavior exercised by
the owning command; it is not a model-generated self-score. `diagnostic` is
`null` for a passing check and contains at most the final 4096 bytes of the
captured command output when a check fails. This bounded excerpt makes a CI
artifact useful without turning the scorecard into an unbounded log transport.
A passing report is therefore evidence that the declared Harness contracts
passed on the reported repository state, not evidence for any item in
`not_evaluated`.

## Maintenance rule

When a Harness claim changes, update the owning test, this contract, the
evaluation runner, and the normal `scripts/validate-premerge.sh` gate together.
Add positive and negative proof for new invariant behavior. Do not add a check
for a consumer-specific command, credential, runtime, or policy to this
generic scorecard.
