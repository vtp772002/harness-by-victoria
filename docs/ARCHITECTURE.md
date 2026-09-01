# Architecture

`harness-by-victoria` has one Rust binary, `harness`, plus thin Bash and
PowerShell bootstraps.

## Product Boundary

```text
consumer repository truth
  <- installed repository protocol
  <- safely maintained by harness
```

Harness installs navigation, working-memory structure, and decision boundaries.
It does not own the consumer's product, runtime, orchestration, credentials,
logs, fixtures, or validation commands.

## Rust Dependency Direction

```text
domain <- application <- infrastructure
                    <- interface

main.rs composes interface and infrastructure
```

- Domain types represent paths, hashes, provenance, merge outcomes, and
  reports without filesystem, process, serialization, or CLI dependencies.
- Application use cases depend on ports and own install, update, status,
  doctor, self-update, version, conflict, and recovery policy.
- Infrastructure implements embedded release content, hashing, locks,
  filesystem transactions, Git three-way merge, candidate download, checksum,
  and executable replacement.
- Interface parses commands and renders reports.
- `main.rs` is the composition root.

Architecture tests reject outward dependencies from inner layers.

## Installation State

Consumer provenance lives under `.harness-core/`:

```text
.harness-core/
├── manifest.json
├── base/
├── transaction.json          # only while an apply is pending
├── update/                   # only while conflict resolution is pending
└── update-candidate/         # retained verified candidate when required
```

The manifest and base contain only Harness-managed core state. They are not a
task database or product-memory store.

## Update Transaction

```text
load installed base and candidate
  -> validate every managed path
  -> freeze current workspace inputs
  -> plan three-way changes
  -> stop and stage overlapping conflicts
  -> otherwise write journal and backups
  -> activate workspace files
  -> commit provenance last
  -> replace repository-local executable last
```

A later mutating command rolls back an interrupted apply before starting new
work. Symlinks in managed paths, candidate paths, and executable replacement
paths are rejected.

## Conflict Ownership

Harness preserves BASE, LOCAL, UPSTREAM, and RESOLVED but does not choose
policy. An agent may explain the difference; a human supplies direction when a
material product choice remains. Continuation rejects conflict markers,
candidate tampering, malformed sessions, and drift in any frozen managed file.

## Trust Boundary

Updates resolve the exact `harness-v*` release pointer, download the matching
platform binary and SHA-256 sidecar, require the binary-reported version to
equal the pointer, and reject downgrades.

SHA-256 verifies bytes relative to the GitHub release. It is not an independent
publisher-compromise trust root.

## Consumer Application Guidance

Harness does not prescribe a generic application architecture. A consumer
should document only its actual stack, domains, inputs, run commands, readiness,
state ownership, logs, validation, and cleanup behavior.

Use `docs/templates/application-runbook.md` when a real application operation
needs durable guidance. Do not invent commands, credentials, policies, or
cleanup ownership to complete the template.
