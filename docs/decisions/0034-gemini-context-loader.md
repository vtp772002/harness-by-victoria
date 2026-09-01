# 0034 Gemini Context Loader

Date: 2026-09-01

## Status

Accepted.

## Context

Gemini CLI uses `GEMINI.md` as its default repository context file and
supports importing another file with the `@file.md` syntax. The repository
already has one canonical instruction source and must not create a second
policy document.

## Decision

Provide an optional `--gemini` / `-Gemini` compatibility loader that creates or
updates `GEMINI.md`. The loader contains a managed import of the canonical
`AGENTS.md` source. It must:

1. preserve existing unmarked Gemini instructions;
2. refresh only a block with the exact
   `HARNESS:GEMINI-CONTEXT:BEGIN:v1` / `END:v1` marker pair;
3. back up replaced bytes before refresh;
4. reject malformed marker pairs rather than guessing ownership; and
5. remain outside the default core payload unless explicitly selected.

The repository itself carries the same thin loader so Gemini CLI uses the
current project authority. `.agents/skills/` remains the canonical skill
location; no duplicate Gemini skill tree is introduced.

## Authority And Scope

The context filename, import syntax, and skill discovery behavior follow
Gemini CLI's [official GEMINI.md documentation](https://geminicli.com/docs/cli/gemini-md/)
and [Agent Skills documentation](https://geminicli.com/docs/cli/using-agent-skills/).
The loader scope is only instruction discovery. It does not grant permissions,
enforce a sandbox, authorize tools, or replace host-agent controls.

## Verification

The native installer mode contracts prove creation, preservation, marked-block
refresh, backup, idempotence, and malformed-marker rejection on Bash and
PowerShell. `tests/installer/assert-agent-authority-contract.sh` verifies the
loader imports `AGENTS.md`. The normal pre-merge contract runs both repository
and Windows installer checks.
