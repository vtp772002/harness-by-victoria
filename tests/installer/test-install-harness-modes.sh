#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
installer="$root/scripts/install-harness.sh"
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

cargo build --quiet --manifest-path "$root/Cargo.toml" -p harness --locked
harness_core_binary="$root/target/debug/harness"
harness_core_version=$("$harness_core_binary" --version | awk '{ print $NF; exit }')

install() {
  HARNESS_CORE_BINARY="$harness_core_binary" "$installer" "$@"
}

extract_block() {
  awk '
    /<!-- HARNESS:BEGIN -->/ { in_block = 1 }
    in_block { print }
    /<!-- HARNESS:END -->/ { exit }
  ' "$1"
}

assert_rejected_flag() {
  local flag="$1"
  local output="$temp/rejected-${flag#--}.out"
  if install "$flag" --directory "$temp/rejected-${flag#--}" --yes >"$output" 2>&1; then
    echo "installer unexpectedly accepted removed flag $flag" >&2
    exit 1
  fi
  grep -Fq "Unknown option: $flag" "$output"
  [[ ! -e "$temp/rejected-${flag#--}" ]]
}

# Fresh install is core-only: it installs the Rust maintenance CLI and never
# creates protocol-v1 CLI, schema, bootstrap, or database artifacts.
fresh="$temp/fresh"
install --directory "$fresh" --yes >"$temp/fresh.out"
grep -Fq 'Harness profile: core' "$temp/fresh.out"
[[ -x "$fresh/scripts/bin/harness" ]]
[[ -f "$fresh/.harness-core/manifest.json" ]]
[[ -f "$fresh/docs/WORKFLOW.md" ]]
[[ -f "$fresh/docs/patterns/encoding-invariants.md" ]]
[[ -f "$fresh/.agents/skills/encode-invariant/SKILL.md" ]]
cmp -s <(extract_block "$fresh/AGENTS.md") "$root/scripts/agent-harness-block.md"
grep -Fq 'docs/patterns/encoding-invariants.md' "$fresh/AGENTS.md"
grep -Fq 'Does The Work Encode An Invariant?' "$fresh/docs/WORKFLOW.md"
grep -Fq 'Positive proof' "$fresh/docs/patterns/encoding-invariants.md"
grep -Fq 'Negative proof' "$fresh/docs/patterns/encoding-invariants.md"
grep -Fq 'prevent a documented violation from recurring' \
  "$fresh/.agents/skills/encode-invariant/SKILL.md"
grep -Fq "Reuse the repository's existing test, build, task, lint, scan, or validation" \
  "$fresh/.agents/skills/encode-invariant/SKILL.md"
grep -Fq 'Choose the lowest deterministic layer that sees the complete accepted' \
  "$fresh/.agents/skills/encode-invariant/SKILL.md"
grep -Fq 'authority source, and a concrete compliant next action' \
  "$fresh/.agents/skills/encode-invariant/SKILL.md"
for level in \
  'local validation command and observed result' \
  'optional hook availability, if any' \
  'CI invocation discovered or absent' \
  'branch-protection enforcement verified or unverified'; do
  grep -Fq "$level" "$fresh/.agents/skills/encode-invariant/SKILL.md"
done
grep -Fq 'Compare documented invariants with executable checks' \
  "$fresh/.agents/skills/onboard-repository/SKILL.md"
grep -Fq 'allow_implicit_invocation: true' \
  "$fresh/.agents/skills/encode-invariant/agents/openai.yaml"
grep -Fxq 'scripts/bin/harness' "$fresh/.gitignore"
for legacy in \
  scripts/bin/harness-cli \
  scripts/bootstrap-harness.sh \
  scripts/bootstrap-harness.ps1 \
  scripts/schema \
  docs/contracts/harness-orchestration-v1.md \
  harness.db; do
  [[ ! -e "$fresh/$legacy" ]]
done
! grep -Fxq 'harness.db' "$fresh/.gitignore"
[[ ! -e "$fresh/.agents/skills/engineering-wisdom" ]]

# Engineering wisdom remains explicit-only.
wisdom="$temp/wisdom"
install --directory "$wisdom" --with-engineering-wisdom --yes >"$temp/wisdom.out"
grep -Fq 'Engineering wisdom: included (explicit opt-in)' "$temp/wisdom.out"
[[ -f "$wisdom/.agents/skills/engineering-wisdom/SKILL.md" ]]
grep -Fq 'allow_implicit_invocation: false' \
  "$wisdom/.agents/skills/engineering-wisdom/agents/openai.yaml"

# Broken symlinks are still filesystem objects. The optional payload must fail
# closed instead of treating one as a missing file and following it on write.
broken_payload="$temp/broken-payload"
broken_sink="$temp/broken-payload-sink"
mkdir -p "$broken_payload/.agents/skills/engineering-wisdom" "$broken_sink"
ln -s "$broken_sink/skill.md" \
  "$broken_payload/.agents/skills/engineering-wisdom/SKILL.md"
if install --directory "$broken_payload" --with-engineering-wisdom --yes >"$temp/broken-payload.out" 2>&1; then
  echo 'installer unexpectedly followed a broken payload symlink' >&2
  exit 1
fi
grep -Fq 'refusing symlink for Harness path .agents/skills/engineering-wisdom/SKILL.md' \
  "$temp/broken-payload.out"
[[ ! -e "$broken_sink/skill.md" ]]

# Force still overwrites an opted-in advisory file and backs up its old bytes.
force="$temp/force"
mkdir -p "$force/.agents/skills/engineering-wisdom"
printf 'consumer mutation\n' >"$force/.agents/skills/engineering-wisdom/SKILL.md"
install --directory "$force" --with-engineering-wisdom --force --yes >"$temp/force.out"
! grep -Fq 'consumer mutation' "$force/.agents/skills/engineering-wisdom/SKILL.md"
force_backup=$(find "$force/.harness-backup" -path '*/.agents/skills/engineering-wisdom/SKILL.md' -type f | head -n 1)
grep -Fxq 'consumer mutation' "$force_backup"

# Claude shim appends one canonical block, keeps local text, and backs it up.
claude="$temp/claude"
mkdir -p "$claude"
printf '# Local Claude Rules\n\nKeep this Claude-only rule.\n' >"$claude/CLAUDE.md"
claude_before=$(shasum -a 256 "$claude/CLAUDE.md" | awk '{ print $1 }')
install --directory "$claude" --claude --yes >"$temp/claude.out"
grep -Fq 'Keep this Claude-only rule.' "$claude/CLAUDE.md"
cmp -s <(extract_block "$claude/CLAUDE.md") "$root/scripts/claude-harness-block.md"
[[ "$(grep -Fc '@AGENTS.md' "$claude/CLAUDE.md")" == 1 ]]
claude_backup=$(find "$claude/.harness-backup" -name CLAUDE.md -type f | head -n 1)
[[ "$(shasum -a 256 "$claude_backup" | awk '{ print $1 }')" == "$claude_before" ]]

# Merge fills missing core files but never deletes or rewrites legacy protocol
# files, a pre-existing database, or unrelated scripts.
merge="$temp/merge"
mkdir -p "$merge/docs/contracts" "$merge/scripts/schema" "$merge/scripts/bin"
printf 'project agents\n' >"$merge/AGENTS.md"
printf 'project harness doc\n' >"$merge/docs/HARNESS.md"
printf 'legacy contract\n' >"$merge/docs/contracts/harness-orchestration-v1.md"
printf 'legacy bootstrap\n' >"$merge/scripts/bootstrap-harness.sh"
printf 'legacy schema\n' >"$merge/scripts/schema/001.sql"
printf 'legacy cli\n' >"$merge/scripts/bin/harness-cli"
printf 'legacy database\n' >"$merge/harness.db"
install --directory "$merge" --merge --yes >"$temp/merge.out"
grep -Fq 'Continuing with merge.' "$temp/merge.out"
[[ -f "$merge/docs/WORKFLOW.md" && -x "$merge/scripts/bin/harness" ]]
grep -Fxq 'project agents' "$merge/AGENTS.md"
grep -Fxq 'legacy contract' "$merge/docs/contracts/harness-orchestration-v1.md"
grep -Fxq 'legacy bootstrap' "$merge/scripts/bootstrap-harness.sh"
grep -Fxq 'legacy schema' "$merge/scripts/schema/001.sql"
grep -Fxq 'legacy cli' "$merge/scripts/bin/harness-cli"
grep -Fxq 'legacy database' "$merge/harness.db"
! grep -Fxq 'harness.db' "$merge/.gitignore"

# Override owns AGENTS.md and docs only; scripts remain in place and replaced
# protected paths are recoverable from the backup.
override="$temp/override"
mkdir -p "$override/docs" "$override/scripts"
printf 'old agents\n' >"$override/AGENTS.md"
printf 'old docs\n' >"$override/docs/private.md"
printf 'old scripts\n' >"$override/scripts/private.sh"
install --directory "$override" --override --yes >"$temp/override.out"
override_backup=$(find "$override/.harness-backup" -mindepth 1 -maxdepth 1 -type d | head -n 1)
grep -Fxq 'old agents' "$override_backup/AGENTS.md"
grep -Fxq 'old docs' "$override_backup/docs/private.md"
[[ ! -e "$override/docs/private.md" ]]
grep -Fxq 'old scripts' "$override/scripts/private.sh"

# Agent refresh replaces only the marked/legacy authority and backs up the
# exact prior file. Malformed markers still fail closed.
shim="$temp/shim"
mkdir -p "$shim/docs"
printf 'local rule\n\n<!-- HARNESS:BEGIN -->\nstale\n<!-- HARNESS:END -->\n' >"$shim/AGENTS.md"
shim_before=$(shasum -a 256 "$shim/AGENTS.md" | awk '{ print $1 }')
install --directory "$shim" --merge --refresh-agent-shim --yes >"$temp/shim.out"
grep -Fq 'local rule' "$shim/AGENTS.md"
! grep -Fq 'stale' "$shim/AGENTS.md"
shim_backup=$(find "$shim/.harness-backup" -name AGENTS.md -type f | head -n 1)
[[ "$(shasum -a 256 "$shim_backup" | awk '{ print $1 }')" == "$shim_before" ]]

malformed="$temp/malformed"
mkdir -p "$malformed/docs"
printf 'custom\n<!-- HARNESS:BEGIN -->\nstale without end\n' >"$malformed/AGENTS.md"
if install --directory "$malformed" --merge --refresh-agent-shim --yes >"$temp/malformed.out" 2>&1; then
  echo 'installer unexpectedly accepted malformed Harness markers' >&2
  exit 1
fi
grep -Fq 'exactly one complete Harness marker pair' "$temp/malformed.out"

# Dry-run reports core intent without creating the target.
dry="$temp/dry"
install --directory "$dry" --dry-run --yes >"$temp/dry.out"
[[ ! -e "$dry" ]]
grep -Fq 'Dry run: no files will be written.' "$temp/dry.out"
grep -Fq 'Harness profile: core' "$temp/dry.out"

# Removed protocol-v1 switches fail during argument parsing.
assert_rejected_flag --with-cli
assert_rejected_flag --upgrade-cli
assert_rejected_flag --ref

# The core executable path still refuses symlink traversal.
symlink_target="$temp/symlink-target"
symlink_sink="$temp/symlink-sink"
mkdir -p "$symlink_target" "$symlink_sink"
ln -s "$symlink_sink" "$symlink_target/scripts"
if install --directory "$symlink_target" --yes >"$temp/symlink.out" 2>&1; then
  echo 'installer unexpectedly followed a scripts symlink' >&2
  exit 1
fi
grep -Fq 'refusing symlink for repository scripts directory' "$temp/symlink.out"
[[ -z "$(find "$symlink_sink" -mindepth 1 -print -quit)" ]]

# A broken protected-path symlink must fail before any bootstrap write.
broken_protected="$temp/broken-protected"
broken_protected_sink="$temp/broken-protected-sink"
mkdir -p "$broken_protected" "$broken_protected_sink"
ln -s "$broken_protected_sink/agents.md" "$broken_protected/AGENTS.md"
if install --directory "$broken_protected" --yes >"$temp/broken-protected.out" 2>&1; then
  echo 'installer unexpectedly accepted a broken protected-path symlink' >&2
  exit 1
fi
grep -Fq 'refusing symlink for AGENTS.md' "$temp/broken-protected.out"
[[ ! -e "$broken_protected_sink/agents.md" ]]

# The backup root is also installer-owned. A symlink there must not redirect
# backups outside the target repository.
backup_symlink="$temp/backup-symlink"
backup_sink="$temp/backup-sink"
mkdir -p "$backup_symlink" "$backup_sink"
ln -s "$backup_sink" "$backup_symlink/.harness-backup"
if install --directory "$backup_symlink" --yes >"$temp/backup-symlink.out" 2>&1; then
  echo 'installer unexpectedly followed a backup-root symlink' >&2
  exit 1
fi
grep -Fq 'refusing symlink for Harness backup directory' "$temp/backup-symlink.out"
[[ -z "$(find "$backup_sink" -mindepth 1 -print -quit)" ]]

# Remote bootstrap verifies the core checksum and release/binary version tuple.
remote_installer="$temp/install-harness.sh"
cp "$installer" "$remote_installer"
core_source="$temp/core-source"
core_assets="$temp/core-assets"
mkdir -p "$core_source/scripts" "$core_assets"
printf 'harness-v%s\n' "$harness_core_version" >"$core_source/scripts/harness-release-tag"
cp "$harness_core_binary" "$core_assets/harness-fixture-core"
(cd "$core_assets" && shasum -a 256 harness-fixture-core | tr '[:lower:]' '[:upper:]' >harness-fixture-core.sha256)
remote="$temp/remote"
HARNESS_SOURCE_BASE_URL="file://$root" \
HARNESS_CORE_SOURCE_BASE_URL="file://$core_source" \
HARNESS_CORE_CLI_BASE_URL="file://$core_assets" \
HARNESS_CORE_CLI_PLATFORM=fixture-core \
  "$remote_installer" --directory "$remote" --yes >"$temp/remote.out"
[[ -x "$remote/scripts/bin/harness" && -f "$remote/.harness-core/manifest.json" ]]

bad_assets="$temp/bad-core-assets"
mkdir -p "$bad_assets"
cp "$harness_core_binary" "$bad_assets/harness-fixture-core"
printf 'bad-checksum\n' >"$bad_assets/harness-fixture-core.sha256"
if HARNESS_SOURCE_BASE_URL="file://$root" \
  HARNESS_CORE_SOURCE_BASE_URL="file://$core_source" \
  HARNESS_CORE_CLI_BASE_URL="file://$bad_assets" \
  HARNESS_CORE_CLI_PLATFORM=fixture-core \
  "$remote_installer" --directory "$temp/bad-checksum" --yes >"$temp/bad-checksum.out" 2>&1; then
  echo 'installer unexpectedly accepted a bad core checksum' >&2
  exit 1
fi
grep -Fq 'Invalid SHA-256 checksum for harness-fixture-core' "$temp/bad-checksum.out"

mismatch_assets="$temp/mismatch-assets"
mkdir -p "$mismatch_assets"
printf '#!/usr/bin/env sh\necho "harness 999.0.0"\n' >"$mismatch_assets/harness-fixture-core"
chmod 755 "$mismatch_assets/harness-fixture-core"
(cd "$mismatch_assets" && shasum -a 256 harness-fixture-core >harness-fixture-core.sha256)
if HARNESS_SOURCE_BASE_URL="file://$root" \
  HARNESS_CORE_SOURCE_BASE_URL="file://$core_source" \
  HARNESS_CORE_CLI_BASE_URL="file://$mismatch_assets" \
  HARNESS_CORE_CLI_PLATFORM=fixture-core \
  "$remote_installer" --directory "$temp/bad-identity" --yes >"$temp/bad-identity.out" 2>&1; then
  echo 'installer unexpectedly accepted a mismatched core version' >&2
  exit 1
fi
grep -Fq 'Harness core release identity mismatch' "$temp/bad-identity.out"

# A conflicted core update retains the candidate and installed binary. A rerun
# continues the resolution, swaps binaries, and leaves the prior binary backed up.
conflict="$temp/core-conflict"
fake_candidate="$temp/fake-harness-candidate"
mkdir -p "$conflict/.harness-core" "$conflict/scripts/bin"
printf '{"schema_version":1,"core_version":"0.1.3","files":[]}\n' >"$conflict/.harness-core/manifest.json"
printf 'old executable\n' >"$conflict/scripts/bin/harness"
chmod 755 "$conflict/scripts/bin/harness"
old_binary_hash=$(shasum -a 256 "$conflict/scripts/bin/harness" | awk '{ print $1 }')
cat >"$fake_candidate" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
target=""
continuing=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --directory) target=$2; shift 2 ;;
    --continue) continuing=1; shift ;;
    *) shift ;;
  esac
done
if [ "$continuing" -eq 1 ]; then
  cp "$target/.harness-core/update/resolved/AGENTS.md" "$target/AGENTS.md"
  rm -rf "$target/.harness-core/update"
  exit 0
fi
mkdir -p "$target/.harness-core/update/resolved"
printf 'resolved content required\n' >"$target/.harness-core/update/resolved/AGENTS.md"
printf '{"schema_version":2,"from_version":"0.1.3","to_version":"0.1.4","conflicts":[],"frozen_files":[]}\n' >"$target/.harness-core/update/session.json"
exit 2
EOF
chmod 755 "$fake_candidate"
if HARNESS_CORE_BINARY="$fake_candidate" \
  "$installer" --directory "$conflict" --merge --yes >"$temp/core-conflict.out" 2>&1; then
  echo 'installer unexpectedly reported a conflicted core update as successful' >&2
  exit 1
fi
[[ "$(shasum -a 256 "$conflict/scripts/bin/harness" | awk '{ print $1 }')" == "$old_binary_hash" ]]
[[ -x "$conflict/.harness-core/update-candidate/harness" ]]
printf 'human-approved result\n' >"$conflict/.harness-core/update/resolved/AGENTS.md"
HARNESS_CORE_BINARY="$fake_candidate" \
  "$installer" --directory "$conflict" --merge --yes >"$temp/core-continue.out"
grep -Fxq 'human-approved result' "$conflict/AGENTS.md"
cmp -s "$fake_candidate" "$conflict/scripts/bin/harness"
[[ ! -e "$conflict/.harness-core/update" && ! -e "$conflict/.harness-core/update-candidate" ]]
core_backup=$(find "$conflict/.harness-backup" -path '*/scripts/bin/harness' -type f | head -n 1)
[[ "$(shasum -a 256 "$core_backup" | awk '{ print $1 }')" == "$old_binary_hash" ]]

echo 'Bash core install/update, safety, shims, opt-in, and removed-flag modes passed'
