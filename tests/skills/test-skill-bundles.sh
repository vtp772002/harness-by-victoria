#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
validator="$root/scripts/validate-skill-bundles.py"
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

python3 "$validator" --root "$root"
python3 "$validator" --skill-file \
  "$root/.agents/skills/encode-invariant/SKILL.md"

# Negative proof: an invalid Agent Skills name must fail with the portable
# metadata diagnostic, without mutating the repository source.
bad="$temp/invalid-name/SKILL.md"
mkdir -p "$(dirname "$bad")"
cp "$root/.agents/skills/encode-invariant/SKILL.md" "$bad"
sed -i.bak 's/^name: encode-invariant$/name: Invalid Name/' "$bad"
rm -f "$bad.bak"
if python3 "$validator" --skill-file "$bad" >"$temp/invalid.out" 2>&1; then
  echo "validator unexpectedly accepted an invalid skill name" >&2
  exit 1
fi
grep -Fq 'name' "$temp/invalid.out"
grep -Fq 'must match directory' "$temp/invalid.out"

echo "Agent Skills metadata, bundle closure, wrapper parity, and negative proof passed"
