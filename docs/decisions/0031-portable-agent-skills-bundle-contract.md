# 0031 Portable Agent Skills Bundle Contract

Date: 2026-09-01

## Status

Accepted.

## Context

This repository distributes Agent Skills to multiple compatible clients. The
canonical skill bundles live under .agents/skills/; Claude Code compatibility
wrappers live under .claude/skills/. A malformed metadata field, missing
manifest entry, broken relative reference, or wrapper drift can make a skill
invisible or cause a client to load a different policy than the canonical
source.

The external Agent Skills specification
(https://agentskills.io/specification) defines the portable SKILL.md shape,
required name and description metadata, naming limits, and relative resource
references. GitHub Copilot's official customization documentation confirms
that .agents/skills/, .claude/skills/, and .github/skills/ are supported
project locations.

## Decision

Every skill bundle declared by this repository's installer manifests must:

1. contain a UTF-8 SKILL.md with valid required metadata;
2. use a lowercase, hyphenated name that matches its directory and the Agent
   Skills limits;
3. keep description non-empty and within the 1024-character limit;
4. resolve every internal Markdown link within the repository without
   traversing a symlink or escaping the repository;
5. appear in exactly one installer payload manifest; and
6. keep each Claude wrapper's name and description equal to its canonical
   skill, carry the explicit
   `<!-- HARNESS:CLAUDE-SKILL-WRAPPER:v1 -->` ownership marker, and point its
   instructions back to that canonical file.

The four core Claude wrappers are compatibility discovery artifacts, not a
second policy source. The engineering-wisdom wrapper remains explicit-only.
No .github/skills/ copy or client runtime is added by this decision.

## Consequences

- A client can discover the same skill identity and activation description
  through the supported Agent Skills locations.
- Manifest and wrapper drift fails before merge with an actionable path and
  rule diagnostic.
- The check does not prove model activation quality, tool permission safety,
  sandboxing, or production telemetry.

## Verification

scripts/validate-skill-bundles.py is the repository-native validator.
tests/skills/test-skill-bundles.sh proves a conforming bundle, invalid metadata
names, and malformed quoted, flow-collection, and flow-mapping values.
scripts/validate-premerge.sh runs the validator, and the checked-in pre-merge
workflow invokes that entrypoint. Bash and PowerShell installer tests prove
that only an explicitly marked Claude wrapper is refreshable; a consumer file
with the historical heading remains unchanged.
