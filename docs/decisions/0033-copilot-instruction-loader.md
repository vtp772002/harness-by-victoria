# 0033 Copilot Instruction Loader

Date: 2026-09-01

## Status

Accepted.

## Context

GitHub Copilot supports `AGENTS.md` for several agent surfaces, but its
repository-wide `copilot-instructions.md` surface also applies to Copilot
experiences that do not consume agent instructions in the same way. The
repository already has one canonical instruction source and must not create a
second policy document or a duplicate `.github/skills/` tree.

## Decision

Provide an optional `--copilot` / `-Copilot` compatibility loader that creates
or updates `.github/copilot-instructions.md`. The loader contains only a
managed pointer to the canonical `AGENTS.md` source. It must:

1. preserve existing unmarked Copilot instructions;
2. refresh only a block with the exact
   `HARNESS:COPILOT-INSTRUCTIONS:BEGIN:v1` / `END:v1` marker pair;
3. back up replaced bytes before refresh;
4. reject malformed marker pairs rather than guessing ownership; and
5. remain outside the default core payload unless explicitly selected.

The repository itself carries the same thin loader so its Copilot surfaces use
the current project authority. `.agents/skills/` remains the canonical skill
location; no `.github/skills/` copy is introduced.

## Authority And Scope

The compatibility location and supported Copilot surfaces follow GitHub's
[official custom-instructions documentation](https://docs.github.com/en/copilot/reference/custom-instructions-support)
and [Agent Skills documentation](https://docs.github.com/en/copilot/concepts/agents/about-agent-skills).
The loader scope is only instruction discovery. It does not grant
permissions, enforce a sandbox, authorize tools, or replace host-agent
controls.

## Verification

The native installer mode contracts prove creation, preservation, marked-block
refresh, backup, idempotence, and malformed-marker rejection on Bash and
PowerShell. `tests/installer/assert-agent-authority-contract.sh` verifies the
loader points to `AGENTS.md`. The normal pre-merge contract runs both the
repository and Windows installer checks.
