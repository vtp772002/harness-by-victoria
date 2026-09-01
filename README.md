# harness-by-victoria

[![Pre-Merge Contract](https://github.com/vtp772002/harness-by-victoria/actions/workflows/premerge.yml/badge.svg?branch=main)](https://github.com/vtp772002/harness-by-victoria/actions/workflows/premerge.yml)

Turn a software repository into a legible, agent-ready workspace with
`harness-by-victoria`.

`harness-by-victoria` is a repository-centered Harness distribution maintained
in this repository. It installs a small repository protocol and a safe updater.
The repository remains the system of record: product documents, decisions,
plans, code, tests, CI, and runtime evidence define the work.

This repository is a personal downstream of the
[`repository-harness` upstream project](https://github.com/hoangnb24/repository-harness).
Its local improvements, evaluation contracts, and installer hardening live
here under the `harness-by-victoria` name.

It is not a task database, story tracker, agent orchestrator, or application
runtime.

## What It Solves

Coding agents often fail for ordinary engineering reasons:

- important intent exists only in chat;
- the repository does not identify authoritative documents;
- small changes acquire unnecessary process;
- long changes lose decisions and recovery context;
- completion is claimed without behavior-level proof; and
- an agent invents product policy when the request leaves a material choice
  open.

Harness provides a compact entrypoint, a navigable repository map, durable plans
only when work needs them, explicit judgment boundaries, and mechanical
validation.

## Default Workflow

```text
read-only request
  -> inspect the smallest authoritative surface
  -> answer with evidence

bounded change
  -> inspect authority and affected behavior
  -> implement the smallest coherent change
  -> run relevant proof

multi-session or coordinated change
  -> create docs/plans/active/<plan>.md
  -> keep decisions, progress, recovery, and validation current
  -> move the validated plan to docs/plans/completed/

material product ambiguity
  -> stop before mutation
  -> present the concrete choice and consequences
```

A typo does not need a plan. A migration spanning sessions does. A request to
“add rate limiting” without a quota, identity key, enforcement owner, shared
state topology, or response contract must stop before implementation.

Start with [`AGENTS.md`](AGENTS.md), then
[`docs/WORKFLOW.md`](docs/WORKFLOW.md).

## What Gets Installed

The default core contains:

- a compact `AGENTS.md` entrypoint;
- the repository workflow and documentation map;
- product, decision, and execution-plan structure;
- optional templates for durable plans, decisions, application runbooks, and
  evidence-backed Harness improvements; and
- an invariant-encoding pattern and skill, plus explicit-only onboarding and
  proposal-audit skills.

It does not install application architecture, product policy, validation
commands, credentials, a database, schemas, orchestration, or background
processes.

The exact payload is declared in
[`scripts/harness-install-files.txt`](scripts/harness-install-files.txt).

## Install

From a target repository:

```bash
curl -fsSL "https://raw.githubusercontent.com/vtp772002/harness-by-victoria/main/scripts/install-harness.sh?$(date +%s)" |
  bash -s -- --yes
```

On PowerShell:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/vtp772002/harness-by-victoria/main/scripts/install-harness.ps1"))) -Yes
```

Use `--merge` / `-Merge` to preserve existing files and add only missing
Harness paths. Use `--override` / `-Override` only when replacement is
intentional. Use `--dry-run` / `-DryRun` to preview.

For Claude Code, add `--claude` to the Bash installer or `-Claude` to the
PowerShell installer. Both options preserve local `CLAUDE.md` rules and import
the canonical `AGENTS.md` instructions through one managed block.

The bootstrap downloads a versioned `harness` binary and checksum, verifies
release identity, and delegates installation to that candidate. Until this
repository publishes its own versioned binary release, the bootstrap's core
binary channel remains the upstream release channel; set
`HARNESS_CORE_CLI_BASE_URL` when using another authorized release source.

## Maintain An Installation

```bash
scripts/bin/harness status
scripts/bin/harness doctor
scripts/bin/harness update --dry-run
scripts/bin/harness update
```

The updater stores the exact upstream base under `.harness-core/`, performs a
three-way merge, backs up changed files, and activates the result
transactionally.

If local and upstream edits overlap, no managed file or executable changes.
Harness retains BASE, LOCAL, UPSTREAM, and RESOLVED copies plus the frozen
managed input set. After a human resolves the semantic choice:

```bash
scripts/bin/harness update --continue --dry-run
scripts/bin/harness update --continue
```

Use `scripts/bin/harness update --abort` to discard only the staged resolution.

## Optional Skills

Invariant enforcement routes accepted rules through repository-native
validation:

```text
$encode-invariant
```

Brownfield onboarding is explicit and read-only first:

```text
$onboard-repository
```

Harness improvement is also explicit and requires baseline-to-rerun evidence:

```text
$improve-harness
```

Engineering advice is a separate opt-in payload:

```bash
scripts/install-harness.sh --with-engineering-wisdom --yes /path/to/project
```

No skill runs during installation. Onboarding and Harness improvement remain
explicit-only; invariant encoding responds only to matching work requests.

## What We Prove

Harness owns three release-evidence boundaries:

1. **Fresh installation:** the declared core is installed without fabricated
   application truth or hidden lifecycle state.
2. **Repository navigation:** an agent follows repository authority, avoids
   speculative product policy, and can stop at a real decision boundary.
3. **Safe maintenance:** updates verify identity and checksum, preserve local
   edits, stage conflicts, reject drift, and recover interrupted transactions.

Operating an arbitrary consumer application end to end remains consumer-owned
research. Harness does not claim that installation alone supplies runtimes,
fixtures, credentials, logs, or interface automation.

## Evaluate Harness

Run the repository-owned behavior scorecard:

```bash
scripts/evaluate-harness.sh
```

It emits versioned JSON for authority, workflow, installer safety, core
lifecycle, release integrity, and documentation contracts. The report states
what it does not evaluate: LLM quality, consumer runtime behavior, host-agent
permissions or sandboxing, provider telemetry, cost, and branch protection.

External runners can optionally submit metadata-only trajectory evidence for
validation:

```bash
python3 scripts/validate-trajectory-evidence.py trajectory.json
```

This adapter checks authority ordering and outcome proof without executing a
model or accepting prompts, transcripts, file contents, tool payloads, or
secrets. It is not installed in the default core.

## Protocol V1 End Of Life

The former SQLite `harness-cli` and machine protocol v1 ended support on
2026-08-10. The last published compatibility release is
`harness-cli-v0.1.22`. Existing consumers may pin that immutable release, but
the current repository no longer builds, installs, tests, or publishes it.

Harness does not automatically delete legacy binaries, databases, schemas, or
state from consumer repositories.

See
[`decision 0027`](docs/decisions/0027-end-protocol-v1-and-focus-repository-protocol.md).

## Development

```bash
scripts/validate-premerge.sh
```

The contract runs Rust formatting, tests, Clippy, installer and workflow
checks, release guards, documentation checks, shell syntax, and
`git diff --check`.
