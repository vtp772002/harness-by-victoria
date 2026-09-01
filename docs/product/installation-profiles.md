# Installation Contract

Harness has one product profile and one independent advisory add-on.

## Core

The exact core payload is declared in
`scripts/harness-install-files.txt`. It contains generic repository guidance,
working-memory structure, an invariant-encoding pattern and skill, and
explicit-only onboarding and improvement skills.

The platform bootstrap installs a checksum-verified `harness` binary under
`scripts/bin/` and delegates installation or update to that candidate.

The Bash `--claude` and PowerShell `-Claude` options install or refresh the
optional Claude Code shim. The shim imports the canonical `AGENTS.md` source,
preserves local Claude-only rules, backs up replacement bytes, and uses the
same marked block contract on both platforms. They also install four thin
Claude Code skill-discovery wrappers from
`scripts/claude-skill-install-files.txt`; the canonical skill bodies stay under
`.agents/skills/`. The engineering-wisdom wrapper is available only when both
Claude and engineering-wisdom are explicitly selected.

The wrappers are marked as managed compatibility loaders. Merge refreshes a
stale marked wrapper after backing up its prior bytes, while an unmarked
consumer skill remains untouched.

The Bash `--copilot` and PowerShell `-Copilot` options install or refresh the
optional `.github/copilot-instructions.md` loader. It points Copilot back to
`AGENTS.md`, preserves unmarked consumer instructions, backs up refreshes, and
does not install a duplicate `.github/skills/` tree.

The Bash `--gemini` and PowerShell `-Gemini` options install or refresh the
optional `GEMINI.md` loader. It uses Gemini's native `@./AGENTS.md` import,
preserves unmarked consumer instructions, backs up refreshes, and does not
install a duplicate `.gemini/skills/` tree.

Core installation:

- records exact upstream bytes under `.harness-core/`;
- preserves consumer files through merge or human-directed conflict handling;
- backs up replaced files;
- rejects symlink or reparse-point traversal in bootstrap-managed target paths;
- uses a fresh, repository-local backup directory for each invocation;
- does not install an application stack or product policy;
- does not install schemas, databases, orchestration, or background processes;
- does not delete pre-existing legacy Harness files.

## Engineering Wisdom Add-On

`--with-engineering-wisdom` or `-WithEngineeringWisdom` copies the
explicit-only advisory skill declared in
`scripts/engineering-wisdom-install-files.txt`.

Omitting the flag does not install or activate the skill. A later install
without the flag leaves an existing copy untouched. Removal is explicit and
stateless: delete only `.agents/skills/engineering-wisdom/`.

Advice cannot establish consumer policy or authorize an architecture rewrite.

## Merge And Override

- `--merge` / `-Merge`: preserve existing files and add missing managed
  paths.
- `--override` / `-Override`: back up and replace protected Harness paths.
- `--force` / `-Force`: overwrite individual managed files with backups.
- `--dry-run` / `-DryRun`: preview without writing.

## Update

`harness update` verifies release identity and checksum, compares installed
base, local bytes, and incoming bytes, and applies the complete plan
transactionally.

Overlapping text edits stage a frozen resolution session. Structural conflicts
must be corrected before replanning. Successful activation writes provenance
last and replaces only the selected repository's executable after core files
succeed.

## Removed Profile

The former `--with-cli`, `--upgrade-cli`, `-WithCli`, and `-UpgradeCli`
profiles ended with protocol v1. Current installers reject those options.
Existing consumer databases and binaries are not automatically deleted.
