# Scripts

The normal validation entrypoint is:

```bash
scripts/validate-premerge.sh
```

The claim-matched behavior scorecard is available independently:

```bash
scripts/evaluate-harness.sh
```

It emits `repository-harness-evaluation/v1` JSON for six deterministic
Harness-owned checks, including explicit `not_evaluated` boundaries,
reproduction metadata, and bounded failure diagnostics. It does not run an
LLM, persist task state, measure a consumer application, or claim host-agent
telemetry.

External trajectory evidence is validated separately with
`validate-trajectory-evidence.py`. The adapter is metadata-only, versioned,
fail-closed on forbidden payloads, and intentionally excluded from the
installed core. Its contract test is part of pre-merge validation.

Portable skill bundles are checked with validate-skill-bundles.py. It validates
Agent Skills metadata, manifest closure, internal references, and parity between
canonical .agents/skills/ bodies and Claude discovery wrappers. Its negative
contract test is tests/skills/test-skill-bundles.sh.

## Installation

- `install-harness.sh`: Bash bootstrap for the versioned Rust `harness`
  candidate.
- `install-harness.ps1`: PowerShell bootstrap with the same product contract.
- `harness-install-files.txt`: exact embedded core payload.
- `engineering-wisdom-install-files.txt`: independent optional advisory
  payload.
- `claude-skill-install-files.txt`: the four optional Claude Code
  skill-discovery wrapper paths. Their canonical policy bodies remain under
  `.agents/skills/`.
- `claude-engineering-wisdom-shim.md`: the explicit-only Claude discovery
  wrapper for the engineering-wisdom add-on.
- `agent-harness-block.md` and `claude-harness-block.md`: managed entrypoint
  shims. `--claude` / `-Claude` enables the Claude Code shim through the Bash
  / PowerShell bootstrap respectively, including the thin Claude Code
  skill-discovery wrappers. Marked wrappers refresh with backups during merge; unmarked
  consumer skill files remain untouched.

The bootstraps require a 64-character hexadecimal SHA-256 sidecar, normalize
its case, verify the candidate checksum and reported version before delegating
install or update. The source payload defaults to this repository. Until this
repository publishes its own versioned binary release, the core binary still
comes from the upstream release channel; `HARNESS_CORE_CLI_BASE_URL` can point
to an authorized alternative. Before bootstrap-managed writes, they reject
symlink or reparse-point traversal in managed target paths, including optional payloads,
agent shims, and `.gitignore`. They do not contain a database or compatibility
profile.

## Core Release

- `build-harness-release.sh`: build one platform artifact and checksum.
- `harness-release-changed.sh`: classify changes that require a core release.
- `harness-release-tag`: current core release pointer.
- `verify-harness-release-identity.sh`: pretag and published-source identity
  guard.
- `verify-harness-release-assets.sh`: exact cross-platform asset inventory.
- `promote-harness-release-tag.sh`: promote a proven source commit.
- `render-changelog-files.py`: render bounded changed-file lists.

Release commands are called by GitHub workflows. Local development should use
the pre-merge entrypoint rather than publishing commands.

## Historical CLI

Protocol v1 and `harness-cli` are end-of-life. Their build, schema,
materialization, snapshot, changeset, release, and bootstrap scripts remain
available only through historical Git tags.
