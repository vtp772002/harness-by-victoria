# 0030 Node 24 GitHub Actions Runtime

Date: 2026-09-01

## Status

Accepted.

## Context

The first real GitHub Actions run for `harness-by-victoria` passed on Linux and
Windows but reported that `actions/checkout@v4` and
`actions/upload-artifact@v4` were being forced onto the Node 24 runtime because
Node 20 is being removed from hosted runners. GitHub's migration notice sets
the final Node 20 removal date to 2026-09-23.

## Decision

1. Use `actions/checkout@v7` throughout checked-in workflows.
2. Use `actions/upload-artifact@v7` and `actions/download-artifact@v8` for
   artifact exchange.
3. Keep the existing GitHub-hosted runner matrix and workflow permissions;
   this decision changes action compatibility, not merge policy or branch
   protection.
4. The release-workflow contract must reject supported action references below
   these major versions so a later maintenance edit cannot silently restore a
   Node 20-era action.

The selected versions are based on the official action releases:
[`actions/checkout`](https://github.com/actions/checkout/releases),
[`actions/upload-artifact`](https://github.com/actions/upload-artifact/releases),
and [`actions/download-artifact`](https://github.com/actions/download-artifact/releases).
The runtime migration is documented by
[GitHub's Node 20 deprecation notice](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/).

## Consequences

- New CI runs use actions compatible with the current hosted-runner runtime.
- The repository no longer emits the observed Node 20 action warnings.
- Older self-hosted runners that cannot execute Node 24 actions are outside
  the supported CI environment and must be upgraded rather than worked around
  by downgrading the workflow.
- Action references remain major tags; immutable SHA pinning is a separate
  supply-chain decision and is not implied here.

## Verification

`tests/release/test-harness-release-workflow-contract.sh` and the documentation
contract assert the selected action majors. The pre-merge workflow itself is
the runtime proof and must be rerun after this decision is pushed.
