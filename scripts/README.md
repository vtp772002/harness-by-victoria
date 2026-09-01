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
- `copilot-harness-block.md`: the optional GitHub Copilot instruction loader
  that points back to the canonical `AGENTS.md` source.
- `gemini-harness-block.md`: the optional Gemini CLI context loader that uses
  Gemini's native `@./AGENTS.md` import to point back to the canonical source.
- `agent-harness-block.md` and `claude-harness-block.md`: managed entrypoint
  shims. `--claude` / `-Claude` enables the Claude Code shim through the Bash
  / PowerShell bootstrap respectively, including the thin Claude Code
  skill-discovery wrappers. Marked wrappers refresh with backups during merge; unmarked
  consumer skill files remain untouched.

`--copilot` / `-Copilot` appends or refreshes the managed block in
`.github/copilot-instructions.md`. It is separate from the default core and
preserves an existing unmarked Copilot instruction file. The block uses the
exact `HARNESS:COPILOT-INSTRUCTIONS:BEGIN:v1` / `END:v1` ownership markers.

`--gemini` / `-Gemini` appends or refreshes the managed block in `GEMINI.md`.
It is separate from the default core and preserves an existing unmarked Gemini
instruction file. The block uses the exact
`HARNESS:GEMINI-CONTEXT:BEGIN:v1` / `END:v1` ownership markers.

Claude skill wrappers carry an explicit
`<!-- HARNESS:CLAUDE-SKILL-WRAPPER:v1 -->` ownership marker. The installers
refresh only files with that marker; a consumer file that merely reuses the
old wrapper heading is preserved.

The bootstraps require a 64-character hexadecimal SHA-256 sidecar, normalize
its case, verify the candidate checksum and reported version before delegating
install or update. The source payload defaults to this repository. Until this
repository publishes its own versioned binary release, the core binary still
comes from the upstream release channel; `HARNESS_CORE_CLI_BASE_URL` can point
to an authorized alternative. Before bootstrap-managed writes, they reject
symlink or reparse-point traversal in managed target paths, including optional payloads,
agent shims, and `.gitignore`. Selected optional paths are preflighted before
the core candidate is allowed to write. They do not contain a database or
compatibility profile.

## Core Release

- `build-harness-release.sh`: build one platform artifact and checksum.
- `harness-release-changed.sh`: classify changes that require a core release.
- `harness-release-tag`: current core release pointer.
- `verify-harness-release-identity.sh`: pretag and published-source identity
  guard.
- `verify-harness-release-assets.sh`: exact cross-platform asset inventory.
- `promote-harness-release-tag.sh`: promote a proven source commit.
- `render-changelog-files.py`: render bounded changed-file lists.

The release build generates a GitHub artifact attestation for each platform
binary after checksum and lifecycle smoke proof. The sidecar checksum remains
independently verified. Consumers can verify a published binary with
`gh attestation verify`; the repository has not yet published its own binary
release, so hosted verification is not yet observed here.

Release commands are called by GitHub workflows. Local development should use
the pre-merge entrypoint rather than publishing commands.

## Historical CLI

Protocol v1 and `harness-cli` are end-of-life. Their build, schema,
materialization, snapshot, changeset, release, and bootstrap scripts remain
available only through historical Git tags.
