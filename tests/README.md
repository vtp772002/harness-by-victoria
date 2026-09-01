# Test Suite Map

The normal entrypoint is `scripts/validate-premerge.sh`.

## Rust Core

`crates/harness/` unit and integration tests protect:

- path, hash, provenance, and distribution validation;
- clean architecture;
- install, status, and doctor;
- three-way updates and conflict staging;
- complete-plan drift detection;
- checksum and release identity;
- symlink rejection;
- transaction rollback and executable recovery.

## Repository Contracts

| Location | Protects |
| --- | --- |
| `tests/workflow/` | Read-only, bounded, durable-plan, authority-stop, and no-hidden-control-plane behavior |
| `tests/installer/` | Fresh core installation, merge/override, shims, optional engineering advice, manifest integrity, and platform parity |
| `tests/evaluation/` | Claim-matched behavior scorecard plus metadata-only external trajectory evidence |
| `tests/docs/` | Current authority, links, EOL boundary, and validation entrypoints |
| `tests/maintenance/` | Core release classification and changelog rendering |
| `tests/release/` | Core workflow, exact assets, source identity, promotion, and post-merge recovery |

## Removed Compatibility Proof

SQLite schemas, snapshots, changesets, protocol-v1 commands, and
`harness-cli` release tests ended with decision 0027. Immutable historical
tags retain that proof; it is not run by the current product.

When adding a test, name the observable invariant and update this map. A
historical artifact alone is not a reason to keep an executable in pre-merge.
