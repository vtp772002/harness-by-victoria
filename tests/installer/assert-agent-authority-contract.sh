#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
agent_block="$root/scripts/agent-harness-block.md"
claude_block="$root/scripts/claude-harness-block.md"
copilot_block="$root/scripts/copilot-harness-block.md"
gemini_block="$root/scripts/gemini-harness-block.md"
workflow="$root/docs/WORKFLOW.md"

extract_block() {
  awk '
    /<!-- HARNESS:BEGIN -->/ { in_block = 1 }
    in_block { print }
    /<!-- HARNESS:END -->/ { exit }
  ' "$1"
}

cmp -s <(extract_block "$root/AGENTS.md") "$agent_block"
cmp -s <(extract_block "$root/CLAUDE.md") "$claude_block"
extract_copilot_block() {
  awk '
    /<!-- HARNESS:COPILOT-INSTRUCTIONS:BEGIN:v1 -->/ { in_block = 1 }
    in_block { print }
    /<!-- HARNESS:COPILOT-INSTRUCTIONS:END:v1 -->/ { exit }
  ' "$1"
}
cmp -s <(extract_copilot_block "$root/.github/copilot-instructions.md") "$copilot_block"
extract_gemini_block() {
  awk '
    /<!-- HARNESS:GEMINI-CONTEXT:BEGIN:v1 -->/ { in_block = 1 }
    in_block { print }
    /<!-- HARNESS:GEMINI-CONTEXT:END:v1 -->/ { exit }
  ' "$1"
}
cmp -s <(extract_gemini_block "$root/GEMINI.md") "$gemini_block"

required_agent_text=(
  'Start with the requested outcome'
  'Answers, explanations, reviews, diagnoses, plans, and status reports are'
  'No control-plane operation is required.'
  'docs/plans/active/'
  'identify repository authority for each new externally'
  'configurable defaults are not authority'
  'docs/patterns/encoding-invariants.md'
  'explicitly asked to use `$improve-harness`'
  'product intent remains ambiguous'
  'Harness has no task database or orchestration lifecycle.'
)
for text in "${required_agent_text[@]}"; do
  grep -Fq "$text" "$agent_block"
done

claude_skill_payloads=(
  .claude/skills/audit-onboarding-proposal/SKILL.md
  .claude/skills/encode-invariant/SKILL.md
  .claude/skills/improve-harness/SKILL.md
  .claude/skills/onboard-repository/SKILL.md
)
for payload in "${claude_skill_payloads[@]}"; do
  grep -Fxq "$payload" "$root/scripts/claude-skill-install-files.txt"
  grep -Fq 'canonical skill is' "$root/$payload"
  grep -Fq '<!-- HARNESS:CLAUDE-SKILL-WRAPPER:v1 -->' "$root/$payload"
done
! grep -Fq '.claude/skills/' "$root/scripts/harness-install-files.txt"
python3 - "$root" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
skills = [
    "audit-onboarding-proposal",
    "encode-invariant",
    "improve-harness",
    "onboard-repository",
]

def frontmatter(path):
    text = path.read_text()
    match = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
    if not match:
        raise SystemExit(f"missing skill frontmatter: {path}")
    return match.group(1)

for skill in skills:
    canonical = frontmatter(root / ".agents/skills" / skill / "SKILL.md")
    wrapper = frontmatter(root / ".claude/skills" / skill / "SKILL.md")
    if canonical != wrapper:
        raise SystemExit(f"Claude wrapper metadata drifted from canonical skill: {skill}")

canonical = frontmatter(root / ".agents/skills/engineering-wisdom/SKILL.md")
wrapper = frontmatter(root / "scripts/claude-engineering-wisdom-shim.md")
if canonical != wrapper:
    raise SystemExit("Claude engineering-wisdom wrapper metadata drifted from canonical skill")
if "<!-- HARNESS:CLAUDE-SKILL-WRAPPER:v1 -->" not in (root / "scripts/claude-engineering-wisdom-shim.md").read_text():
    raise SystemExit("Claude engineering-wisdom wrapper marker is missing")
PY

[[ "$(wc -c <"$agent_block" | tr -d ' ')" -le 1600 ]]
entry_words=$(awk '{ words += NF } END { print words }' "$agent_block" "$workflow")
[[ "$entry_words" -le 1000 ]]

required_workflow_text=(
  'Does The Work Need Durable Memory?'
  'Does The Work Need Human Judgment?'
  'Add rate limiting'
  'must stop'
  'What Proves The Behavior?'
  'Does The Work Encode An Invariant?'
  'positive proof'
  'negative proof'
  'branch protection is externally configured or unverified'
  'Operate The Application'
  'Improve The Harness'
  'No parallel lifecycle record is required.'
)
for text in "${required_workflow_text[@]}"; do
  grep -Fq "$text" "$workflow"
done

[[ "$(grep -Fc '@AGENTS.md' "$claude_block")" == 1 ]]
! grep -Fq 'query matrix' "$claude_block"
[[ "$(grep -Fc '@./AGENTS.md' "$gemini_block")" == 1 ]]

payloads=(
  .agents/skills/audit-onboarding-proposal/SKILL.md
  .agents/skills/audit-onboarding-proposal/agents/openai.yaml
  .agents/skills/audit-onboarding-proposal/scripts/validate_evidence_capsule.py
  .agents/skills/encode-invariant/SKILL.md
  .agents/skills/encode-invariant/agents/openai.yaml
  .agents/skills/improve-harness/SKILL.md
  .agents/skills/improve-harness/agents/openai.yaml
  .agents/skills/onboard-repository/SKILL.md
  .agents/skills/onboard-repository/agents/openai.yaml
  .agents/skills/onboard-repository/references/evidence-capsule-v1.md
  .agents/skills/onboard-repository/references/evidence-capsule-v2.md
  .agents/skills/onboard-repository/scripts/emit_evidence_bundle.py
  .agents/skills/onboard-repository/scripts/render_patch.py
  docs/WORKFLOW.md
  docs/README.md
  docs/patterns/encoding-invariants.md
  docs/product/README.md
  docs/plans/README.md
  docs/plans/active/README.md
  docs/plans/completed/README.md
  docs/decisions/README.md
  docs/templates/application-runbook.md
  docs/templates/decision.md
  docs/templates/exec-plan.md
  docs/templates/harness-improvement.md
)
for payload in "${payloads[@]}"; do
  grep -Fxq "$payload" "$root/scripts/harness-install-files.txt"
done

skill_metadata=(
  .agents/skills/onboard-repository/agents/openai.yaml
  .agents/skills/audit-onboarding-proposal/agents/openai.yaml
  .agents/skills/improve-harness/agents/openai.yaml
)
for metadata in "${skill_metadata[@]}"; do
  grep -Fq 'allow_implicit_invocation: false' "$root/$metadata"
done
grep -Fq 'allow_implicit_invocation: true' \
  "$root/.agents/skills/encode-invariant/agents/openai.yaml"

invariant_skill="$root/.agents/skills/encode-invariant/SKILL.md"
for trigger in \
  'enforce architecture, reliability, security, or quality boundaries' \
  'prevent a documented violation from recurring' \
  'add structural guards' \
  'turn accepted rules into validation'; do
  grep -Fq "$trigger" "$invariant_skill"
done
grep -Fq 'Do not use to infer or invent policy from conventions, code patterns, tests, defaults, or undocumented preferences.' \
  "$invariant_skill"
required_invariant_method=(
  "Reuse the repository's existing test, build, task, lint, scan, or validation"
  'Choose the lowest deterministic layer that sees the complete accepted'
  'name the violating item, the broken rule, the'
  'authority source, and a concrete compliant next action'
  'local validation command and observed result'
  'optional hook availability, if any'
  'CI invocation discovered or absent'
  'branch-protection enforcement verified or unverified'
)
for text in "${required_invariant_method[@]}"; do
  grep -Fq "$text" "$invariant_skill"
done

onboarding_skill="$root/.agents/skills/onboard-repository/SKILL.md"
grep -Fq 'Compare documented invariants with executable checks' "$onboarding_skill"
grep -Fq '**Unenforced rule:**' "$onboarding_skill"
grep -Fq '**Check lacking authority:**' "$onboarding_skill"
grep -Fq 'Do not add, edit, delete, enable, or execute a guard during onboarding.' \
  "$onboarding_skill"

grep -Fq 'read_source_text "scripts/agent-harness-block.md"' "$root/scripts/install-harness.sh"
grep -Fq 'read_source_text "scripts/claude-harness-block.md"' "$root/scripts/install-harness.sh"
grep -Fq 'read_source_text "scripts/copilot-harness-block.md"' "$root/scripts/install-harness.sh"
grep -Fq 'read_source_text "scripts/gemini-harness-block.md"' "$root/scripts/install-harness.sh"
grep -Fq 'REFRESH_AGENT_SHIM=1' "$root/scripts/install-harness.sh"
grep -Fq 'ENGINEERING_WISDOM_PAYLOAD_MANIFEST="scripts/engineering-wisdom-install-files.txt"' "$root/scripts/install-harness.sh"
grep -Fq 'CLAUDE_SKILLS_PAYLOAD_MANIFEST="scripts/claude-skill-install-files.txt"' "$root/scripts/install-harness.sh"
grep -Fq 'install_claude_skills' "$root/scripts/install-harness.sh"
grep -Fq 'scripts/claude-engineering-wisdom-shim.md' "$root/scripts/install-harness.sh"
grep -Fq 'write_copilot_instructions' "$root/scripts/install-harness.sh"
grep -Fq 'write_gemini_context' "$root/scripts/install-harness.sh"
! grep -Fq 'CLI_PAYLOAD_MANIFEST' "$root/scripts/install-harness.sh"

grep -Fq 'Read-SourceText "scripts/agent-harness-block.md"' "$root/scripts/install-harness.ps1"
grep -Fq 'Read-SourceText "scripts/claude-harness-block.md"' "$root/scripts/install-harness.ps1"
grep -Fq 'Read-SourceText "scripts/copilot-harness-block.md"' "$root/scripts/install-harness.ps1"
grep -Fq 'Read-SourceText "scripts/gemini-harness-block.md"' "$root/scripts/install-harness.ps1"
grep -Fq '[switch]$RefreshAgentShim' "$root/scripts/install-harness.ps1"
grep -Fq '[switch]$Claude' "$root/scripts/install-harness.ps1"
grep -Fq '[switch]$Copilot' "$root/scripts/install-harness.ps1"
grep -Fq '[switch]$Gemini' "$root/scripts/install-harness.ps1"
grep -Fq '$script:EngineeringWisdomPayloadManifest = "scripts/engineering-wisdom-install-files.txt"' "$root/scripts/install-harness.ps1"
grep -Fq '$script:ClaudeSkillsPayloadManifest = "scripts/claude-skill-install-files.txt"' "$root/scripts/install-harness.ps1"
grep -Fq 'Install-ClaudeSkills' "$root/scripts/install-harness.ps1"
grep -Fq 'scripts/claude-engineering-wisdom-shim.md' "$root/scripts/install-harness.ps1"
grep -Fq 'Write-CopilotInstructions' "$root/scripts/install-harness.ps1"
grep -Fq 'Assert-CopilotMarkers' "$root/scripts/install-harness.ps1"
grep -Fq 'Write-GeminiContext' "$root/scripts/install-harness.ps1"
grep -Fq 'Assert-GeminiMarkers' "$root/scripts/install-harness.ps1"
! grep -Fq 'CliPayloadManifest' "$root/scripts/install-harness.ps1"

echo "repository authority, bounded context, canonical shims, and core-only installer parity passed"
