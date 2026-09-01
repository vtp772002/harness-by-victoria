# Execution Plan: World-Class Repository Harness

Date: 2026-08-31

## Status

Active

## Outcome

Make `harness-by-victoria` the strongest repository-centered harness for
agent-ready software work: portable across major agent clients, explicit about
authority and permissions, safe across interrupted maintenance, and measurable
through reproducible behavior-level evidence.

“Best” is evaluated against observable guarantees and fresh-agent outcomes,
not feature count or claims of universal agent orchestration.

## Context

- Current product and boundaries: `README.md`, `docs/ARCHITECTURE.md`, and
  `docs/WORKFLOW.md`.
- Accepted invariant method: `docs/decisions/0028-authoritative-invariant-encoding.md`
  and `docs/patterns/encoding-invariants.md`.
- Current implementation/proof: `crates/harness/`, `scripts/`, and `tests/`.
- External landscape sweep (2026-08-31): OpenHands SDK, Inspect AI, METR Task
  Standard, OpenAI Agents SDK, Claude Code, LangGraph, Google ADK, AutoGen,
  Agent Skills, AGENTS.md, MCP, SWE-bench, BrowserGym, OSWorld, and AgentBench.

## Scope

In scope:

- repository authority, context discovery, and cross-agent instruction/skill
  portability;
- deterministic checks for safety, provenance, update recovery, and proof;
- evidence bundles and evaluation scenarios that measure repository behavior and
  outcome, with a bounded path for external trajectory data;
- release integrity and compatibility diagnostics;
- focused documentation and behavior-level tests for every new guarantee.

Out of scope:

- a task database, orchestration control plane, or application runtime;
- silently choosing consumer product policy, quotas, credentials, or CI merge
  rules;
- claiming branch protection or external platform enforcement without observing
  it;
- independent release signatures or a new publisher trust root until a lasting
  repository decision authorizes the trust model.

## Approach

1. Benchmark the current repository against leading agent harness patterns:
   context portability, tool/permission boundaries, durable recovery,
   behavior/outcome evaluation, sandboxing, observability, and release
   provenance.
2. Convert only accepted repository rules into the smallest native checks, with
   positive and negative proof.
3. Add a repository-owned benchmark/evidence contract so a fresh agent can be
   tested on discovery, authority stops, bounded changes, recovery, and
   completion claims.
4. Strengthen release and installer diagnostics without changing the current
   trust model.
5. Re-run focused tests and `scripts/validate-premerge.sh`; document local,
   CI, and external-enforcement limits separately.

## Risks And Recovery

- Risk: importing a framework feature would create an unapproved product
  policy. Mitigation: stop at the authority gate and keep the capability
  optional or research-only.
- Risk: evaluation fixtures drift from the workflow. Mitigation: keep fixtures
  repository-local, assert the intended diagnostic, and validate them in the
  normal pre-merge entrypoint.
- Risk: maintenance changes leave a partial workspace. Mitigation: preserve
  transactional operations and run interrupted-update recovery tests.
- Recovery: revert only this branch's tracked changes; preserve the existing
  `codex/archive-local-audit` branch and unrelated untracked artifacts.

## Progress

- [x] Fetch and fast-forward review of the authoritative upstream history;
  branch local work safely.
- [x] Sweep leading agent harness, evaluation, interoperability, and safety
  patterns using primary sources.
- [x] Harden Bash and PowerShell bootstrap checksum parsing and proof.
- [x] Publish the durable landscape benchmark and prioritized gap map.
- [x] Add the first repository-owned behavior/evidence benchmark.
- [x] Publish the scorecard as a CI artifact while preserving failure evidence.
- [x] Add bounded failure diagnostics and toolchain metadata so scorecard
      artifacts are reproducible and actionable after CI failure.
- [x] Close bootstrap broken-symlink traversal across Bash and PowerShell,
      including optional payload, shims, protected paths, and `.gitignore`.
- [x] Make the repository executable handoff use an exclusive temporary file
      rather than a predictable process-ID path.
- [x] Choose and implement the metadata-only external trajectory evidence
      adapter, with fail-closed privacy, authority ordering, and outcome proof.
- [x] Constrain trajectory producer labels to portable identifier-like metadata
      so permitted fields cannot carry free-form payload syntax.
- [x] Run full validation and record measured limits for this phase.

## Decisions

- 2026-08-31: Keep the product repository-centered. The external frameworks
  inform capabilities and proof, but do not authorize adding orchestration,
  databases, or consumer application policy.
- 2026-08-31: Treat trajectory plus outcome evidence as a first-class benchmark
  dimension; a passing final answer alone is insufficient.
- 2026-08-31: Keep release SHA-256 verification strict at the bootstrap layer,
  while leaving independent publisher trust-root design for a separate decision.
- 2026-09-01: Following the user's selection of option 1, accept only an
  optional metadata-only external trajectory adapter. The external runner and
  all raw prompts, transcripts, content, tool payloads, credentials, tokens,
  telemetry, and retention remain outside Harness.

## Validation

- Focused proof: installer Bash test, including uppercase valid and malformed
  checksum sidecars.
- Integration or end-to-end proof: Rust lifecycle, update conflict/recovery,
  release identity, installer, workflow, and documentation contracts.
- External evidence proof: metadata-only trajectory fixtures cover a completed
  mutation, an authority-boundary stop, mutation-before-authority rejection,
  forbidden sensitive payload rejection, and free-form metadata-label rejection.
- Repository-required checks: `bash scripts/validate-premerge.sh`.

## Result

Phase result (2026-09-01): the repository now has a dated capability gap map,
strict cross-platform bootstrap checksum parsing, a six-check machine-readable
behavior scorecard included in pre-merge validation, and an optional
metadata-only external trajectory validator. Each scorecard report records
reproduction metadata and retains bounded failure diagnostics. Bootstrap-
managed writes now fail closed on broken symlinks and reparse points. The plan
remains active for future authority-gated work such as wiring a specific
external runner, defining a machine-facing CLI error contract, or adding
client portability; none of those choices are implied by the current adapter.
