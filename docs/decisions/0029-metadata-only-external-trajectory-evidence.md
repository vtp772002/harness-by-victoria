# 0029 Metadata-Only External Trajectory Evidence

Date: 2026-09-01

## Status

Accepted for the world-class Harness upgrade.

## Context

The repository scorecard proves Harness-owned behavior, but it cannot observe
whether an external agent actually discovered authority, stopped at an
ambiguous decision, made a bounded change, or produced behavior-level proof.
Leading evaluation systems separate the runner from the evidence and compare
trajectory with outcome. Harness needs an interoperability boundary for that
evidence without becoming an agent runtime, task database, or hosted telemetry
service.

## Decision

1. Harness provides an optional, repository-local validator for a versioned
   external trajectory artifact. It consumes evidence; it does not execute a
   model, choose a client, invoke tools, or orchestrate tasks.
2. The v1 artifact is metadata-only. It must declare redaction and may contain
   only bounded identifiers, repository revision, event kinds, references,
   authority references, validation results, and outcome metadata.
3. Prompts, transcript text, file contents, command output, tool inputs or
   outputs, credentials, tokens, and arbitrary payload fields are forbidden.
   The validator fails closed when the artifact violates this boundary.
4. A valid trajectory starts with a request, reads authority before mutation,
   records any authority stop before ending, validates a completed mutation,
   and ends with one outcome-matching completion event.
5. The adapter remains outside the default installed core and does not change
   the consumer repository's runtime, permissions, sandbox, network, secrets,
   telemetry, or merge policy.
6. The schema and privacy boundary are versioned. A runner that needs raw
   transcripts, provider-specific events, or a new retention rule requires a
   separate accepted decision and must not overload this artifact.

## Consequences

- Inspect-, ADK-, OpenHands-, or custom runners can emit one small contract
  without importing a Harness control plane.
- CI and review can distinguish a structurally valid trajectory from a passing
  repository scorecard, while keeping sensitive content outside the generic
  repository artifact.
- The adapter cannot prove that a client honestly recorded its events; runner
  provenance and external attestation remain outside this repository.
- Real model quality, task success, cost, permissions, sandboxing, and branch
  protection remain explicitly unmeasured by Harness.

## Verification

`tests/evaluation/test-trajectory-evidence.sh` proves accepted completed and
authority-stop trajectories, rejects mutation before authority, rejects
forbidden payload fields, and checks the versioned validation report. The test
is part of `scripts/validate-premerge.sh` but the adapter is not part of the
installed core payload.
