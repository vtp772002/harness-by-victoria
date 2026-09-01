# Security Policy

## Scope

The security surface of this repository is the current Harness source,
installer, release workflow, and any harness-v* binary release published from
this repository. The historical harness-cli-v* protocol and its SQLite
control plane are end-of-life and are not supported.

Report issues involving:

- Bash or PowerShell bootstrap downloads, checksum verification, or path
  traversal;
- executable replacement, backup, transaction recovery, or symlink/reparse
  handling;
- accidental disclosure through evaluation reports or installer diagnostics;
  and
- release workflow permissions, artifact substitution, or provenance.

The consumer application's code, credentials, runtime sandbox, provider
telemetry, and third-party agent host remain outside this repository's
security ownership.

## Reporting

Please do not open a public issue for a suspected vulnerability. Use GitHub's
private Security Advisory reporting for this repository when available. If
private reporting is unavailable, contact the repository owner privately
through the GitHub profile associated with this repository and include
harness-by-victoria security report in the subject.

Include:

1. the affected commit, release, platform, and installer mode;
2. a minimal reproduction that contains no secrets or personal data;
3. the expected and observed behavior; and
4. the smallest safe mitigation or workaround, if known.

Allow the maintainer reasonable time to investigate before public disclosure.
Do not upload credentials, tokens, private source, or weaponized payloads to
issues, pull requests, logs, or evaluation artifacts.

## Current trust limitations

The bootstrap verifies the SHA-256 sidecar and reported version for the
selected release. This proves bytes relative to that GitHub release; it is not
an independent publisher-compromise defense. The repository does not claim
that installing Harness supplies a host-agent sandbox, permission boundary,
secret isolation, or production telemetry.
