#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
installer="$root/scripts/install-harness.sh"
manifest="$root/scripts/engineering-wisdom-install-files.txt"
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

cargo build --quiet --manifest-path "$root/Cargo.toml" -p harness --locked
core_binary="$root/target/debug/harness"

install() {
  HARNESS_CORE_BINARY="$core_binary" "$installer" "$@"
}

# Cause: no advisory flag. Effect: the neutral core contains no wisdom pack and
# the optional manifest remains outside the core declaration.
default_target="$temp/default"
install --directory "$default_target" --yes >"$temp/default.out"
grep -Fq 'Engineering wisdom: excluded' "$temp/default.out"
[[ ! -e "$default_target/.agents/skills/engineering-wisdom" ]]
! grep -Fq '.agents/skills/engineering-wisdom/' \
  "$root/scripts/harness-install-files.txt"

# Cause: explicit advisory flag. Effect: every optional-manifest member is
# installed, but metadata still requires explicit skill invocation.
opt_in_target="$temp/opt-in"
install --directory "$opt_in_target" --with-engineering-wisdom --yes \
  >"$temp/opt-in.out"
grep -Fq 'Engineering wisdom: included (explicit opt-in)' "$temp/opt-in.out"
while IFS= read -r relative || [[ -n "$relative" ]]; do
  relative="${relative%$'\r'}"
  case "$relative" in
    ""|\#*) continue ;;
  esac
  [[ -f "$opt_in_target/$relative" ]]
done <"$manifest"
grep -Fq 'allow_implicit_invocation: false' \
  "$opt_in_target/.agents/skills/engineering-wisdom/agents/openai.yaml"
grep -Fq '**Observation:**' \
  "$opt_in_target/.agents/skills/engineering-wisdom/SKILL.md"
grep -Fq '**Trade-off:**' \
  "$opt_in_target/.agents/skills/engineering-wisdom/SKILL.md"
grep -Fq '**Proposed repository-owned enforcement:**' \
  "$opt_in_target/.agents/skills/engineering-wisdom/SKILL.md"
grep -Fq 'Do not rewrite application architecture' \
  "$opt_in_target/.agents/skills/engineering-wisdom/SKILL.md"
grep -Fq 'Exercise composition roots and shipped artifacts' \
  "$opt_in_target/.agents/skills/engineering-wisdom/references/heuristics.md"
grep -Fq 'Decode, validate, and recover at input boundaries' \
  "$opt_in_target/.agents/skills/engineering-wisdom/references/heuristics.md"
grep -Fq 'Preserve semantics across adapters' \
  "$opt_in_target/.agents/skills/engineering-wisdom/references/heuristics.md"
grep -Fq 'Make automation failure honest' \
  "$opt_in_target/.agents/skills/engineering-wisdom/references/heuristics.md"
grep -Fq 'Bound cumulative state at its consumption boundary' \
  "$opt_in_target/.agents/skills/engineering-wisdom/references/heuristics.md"

# The optional skill is exposed to Claude only when both opt-ins are explicit.
claude_opt_in_target="$temp/claude-opt-in"
install --directory "$claude_opt_in_target" --claude --with-engineering-wisdom --yes \
  >"$temp/claude-opt-in.out"
grep -Fq '.agents/skills/engineering-wisdom/SKILL.md' \
  "$claude_opt_in_target/.claude/skills/engineering-wisdom/SKILL.md"

# A later normal merge is non-activation, not removal.
before=$(shasum -a 256 \
  "$opt_in_target/.agents/skills/engineering-wisdom/SKILL.md" | awk '{print $1}')
install --directory "$opt_in_target" --merge --yes >"$temp/reinstall.out"
after=$(shasum -a 256 \
  "$opt_in_target/.agents/skills/engineering-wisdom/SKILL.md" | awk '{print $1}')
[[ "$before" == "$after" ]]
grep -Fq 'Engineering wisdom: excluded' "$temp/reinstall.out"

# PowerShell exposes the same named selection and consumes the same manifest.
grep -Fq '[switch]$WithEngineeringWisdom' "$root/scripts/install-harness.ps1"
grep -Fq \
  '$script:EngineeringWisdomPayloadManifest = "scripts/engineering-wisdom-install-files.txt"' \
  "$root/scripts/install-harness.ps1"
grep -Fq \
  '$script:ClaudeSkillsPayloadManifest = "scripts/claude-skill-install-files.txt"' \
  "$root/scripts/install-harness.ps1"
grep -Fq 'Install-ClaudeSkills' "$root/scripts/install-harness.ps1"

echo "engineering-wisdom default exclusion and explicit opt-in passed"
