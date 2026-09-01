#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
core_manifest="$root/scripts/harness-install-files.txt"
wisdom_manifest="$root/scripts/engineering-wisdom-install-files.txt"
claude_manifest="$root/scripts/claude-skill-install-files.txt"
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
core="$temp/core"
wisdom="$temp/wisdom"
claude="$temp/claude"

[[ "$(grep -Fc 'PAYLOAD_MANIFEST="scripts/harness-install-files.txt"' "$root/scripts/install-harness.sh")" == 1 ]]
[[ "$(grep -Fc 'ENGINEERING_WISDOM_PAYLOAD_MANIFEST="scripts/engineering-wisdom-install-files.txt"' "$root/scripts/install-harness.sh")" == 1 ]]
[[ "$(grep -Fc '$script:PayloadManifest = "scripts/harness-install-files.txt"' "$root/scripts/install-harness.ps1")" == 1 ]]
[[ "$(grep -Fc '$script:EngineeringWisdomPayloadManifest = "scripts/engineering-wisdom-install-files.txt"' "$root/scripts/install-harness.ps1")" == 1 ]]
[[ "$(grep -Fc 'CLAUDE_SKILLS_PAYLOAD_MANIFEST="scripts/claude-skill-install-files.txt"' "$root/scripts/install-harness.sh")" == 1 ]]
[[ "$(grep -Fc '$script:ClaudeSkillsPayloadManifest = "scripts/claude-skill-install-files.txt"' "$root/scripts/install-harness.ps1")" == 1 ]]
[[ -f "$root/scripts/claude-engineering-wisdom-shim.md" ]]

python3 - "$root" "$core_manifest" "$wisdom_manifest" "$claude_manifest" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
seen = set()
for manifest_name in sys.argv[2:]:
    manifest = pathlib.Path(manifest_name)
    for number, raw in enumerate(manifest.read_text().splitlines(), 1):
        value = raw.strip()
        if not value or value.startswith("#"):
            continue
        if value.startswith("/") or ".." in pathlib.PurePosixPath(value).parts:
            raise SystemExit(f"unsafe manifest path at {manifest.name}:{number}: {value}")
        if value in seen:
            raise SystemExit(f"duplicate payload path: {value}")
        seen.add(value)
        if not (root / value).is_file():
            raise SystemExit(f"missing manifest source: {value}")
PY

HARNESS_CORE_BINARY="$root/target/debug/harness" "$root/scripts/install-harness.sh" --directory "$core" --yes >/dev/null
HARNESS_CORE_BINARY="$root/target/debug/harness" "$root/scripts/install-harness.sh" --directory "$wisdom" --with-engineering-wisdom --yes >/dev/null
HARNESS_CORE_BINARY="$root/target/debug/harness" "$root/scripts/install-harness.sh" --directory "$claude" --claude --yes >/dev/null

python3 - "$core" "$wisdom" "$claude" "$core_manifest" "$wisdom_manifest" "$claude_manifest" <<'PY'
import pathlib
import re
import sys

core, wisdom, claude, core_manifest, wisdom_manifest, claude_manifest = map(pathlib.Path, sys.argv[1:])

def entries(path):
    return {
        line.strip()
        for line in path.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }

core_expected = entries(core_manifest)
runtime = {
    ".gitignore",
    ".harness-core/.gitignore",
    ".harness-core/lock",
    ".harness-core/manifest.json",
    "scripts/bin/harness",
} | {f".harness-core/base/{path}" for path in core_expected}

expected_by_root = {
    core: core_expected | runtime,
    wisdom: core_expected | runtime | entries(wisdom_manifest),
    claude: core_expected | runtime | entries(claude_manifest) | {"CLAUDE.md"},
}
pattern = re.compile(r"!?\[[^]]*\]\(([^)]+)\)")
for install_root, expected in expected_by_root.items():
    actual = {
        str(path.relative_to(install_root))
        for path in install_root.rglob("*")
        if path.is_file()
    }
    if actual != expected:
        raise SystemExit(
            f"payload mismatch: missing={sorted(expected-actual)} "
            f"extra={sorted(actual-expected)}"
        )
    errors = []
    for document in install_root.rglob("*.md"):
        for target in pattern.findall(document.read_text(errors="replace")):
            target = target.strip().split(maxsplit=1)[0].strip("<>")
            if not target or target.startswith(("#", "http://", "https://", "mailto:")):
                continue
            resolved = (document.parent / target.split("#", 1)[0]).resolve()
            try:
                resolved.relative_to(install_root.resolve())
            except ValueError:
                errors.append(f"{document.relative_to(install_root)}: link escapes: {target}")
                continue
            if not resolved.exists():
                errors.append(f"{document.relative_to(install_root)}: missing link: {target}")
    if errors:
        raise SystemExit("\n".join(errors))
PY

echo "core, engineering-wisdom, and Claude manifests, exact payloads, and installed links passed"
