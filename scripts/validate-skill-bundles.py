#!/usr/bin/env python3
"""Validate the repository's portable Agent Skills bundles.

This validator intentionally uses only the Python standard library. It checks
the normative metadata needed for skills-compatible clients and the local
manifest/compatibility contract that keeps canonical skills and client wrappers
from drifting.
"""

from __future__ import annotations

import argparse
import ast
import os
import re
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import urlsplit


MANIFESTS = (
    Path("scripts/harness-install-files.txt"),
    Path("scripts/engineering-wisdom-install-files.txt"),
    Path("scripts/claude-skill-install-files.txt"),
)
CANONICAL_ROOT = Path(".agents/skills")
CLAUDE_ROOT = Path(".claude/skills")
FRONTMATTER_FIELD = re.compile(r"^([A-Za-z][A-Za-z0-9_-]*):(?:[ \t]*(.*))?$")
SKILL_NAME = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$|^[a-z0-9]$")
MARKDOWN_LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


class ValidationError(Exception):
    """An actionable skill bundle contract failure."""


def error(message: str) -> None:
    raise ValidationError(message)


def safe_relative_path(value: str, label: str) -> PurePosixPath:
    if not value or value.startswith(("/", "\\")) or "\\" in value:
        error(f"{label} is not a safe repository-relative POSIX path: {value!r}")
    path = PurePosixPath(value)
    if path == PurePosixPath(".") or ".." in path.parts:
        error(f"{label} escapes its repository root: {value!r}")
    return path


def regular_file(root: Path, relative: str, label: str) -> Path:
    path = safe_relative_path(relative, label)
    current = root
    for component in path.parts:
        if current.is_symlink():
            error(f"{label} traverses a symlink: {current}")
        current = current / component
        if current.is_symlink():
            error(f"{label} traverses a symlink: {current}")
    if not current.is_file():
        error(f"{label} is missing or not a regular file: {root / path}")
    return current


def scalar_value(raw: str) -> str:
    value = raw.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        try:
            parsed = ast.literal_eval(value)
        except (SyntaxError, ValueError):
            return value[1:-1]
        return parsed if isinstance(parsed, str) else value
    return value


def parse_frontmatter(path: Path) -> tuple[dict[str, str], list[str]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as exc:
        error(f"{path}: cannot read UTF-8 skill file: {exc}")
    if not lines or lines[0] != "---":
        error(f"{path}: frontmatter must start with --- on the first line")

    try:
        closing = lines.index("---", 1)
    except ValueError:
        error(f"{path}: frontmatter closing --- is missing")

    fields: dict[str, str] = {}
    index = 1
    while index < closing:
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            index += 1
            continue
        match = FRONTMATTER_FIELD.match(line)
        if not match:
            error(f"{path}:{index + 1}: unsupported frontmatter syntax")
        key, raw = match.groups()
        raw = raw or ""
        if key in fields:
            error(f"{path}:{index + 1}: duplicate frontmatter field: {key}")
        if raw.strip().startswith(("|", ">")):
            folded = raw.strip().startswith(">")
            values: list[str] = []
            index += 1
            while index < closing and (
                not lines[index].strip() or lines[index].startswith((" ", "\t"))
            ):
                values.append(lines[index].strip())
                index += 1
            fields[key] = (" " if folded else "\n").join(values).strip()
            continue
        if not raw.strip():
            index += 1
            while index < closing and (
                not lines[index].strip() or lines[index].startswith((" ", "\t"))
            ):
                index += 1
            fields[key] = ""
            continue
        fields[key] = scalar_value(raw)
        index += 1

    for required in ("name", "description"):
        if required not in fields or not fields[required].strip():
            error(f"{path}: required frontmatter field is missing or empty: {required}")
    return fields, lines[closing + 1 :]


def validate_metadata(path: Path, expected_name: str) -> dict[str, str]:
    fields, _ = parse_frontmatter(path)
    name = fields["name"]
    description = fields["description"]
    if name != expected_name:
        error(f"{path}: name {name!r} must match directory {expected_name!r}")
    if len(name) > 64 or not SKILL_NAME.fullmatch(name) or "--" in name:
        error(
            f"{path}: name must use 1-64 lowercase letters, numbers, and single hyphens"
        )
    if len(description) > 1024:
        error(f"{path}: description exceeds the 1024-character Agent Skills limit")
    return fields


def validate_internal_links(path: Path, root: Path) -> None:
    text = path.read_text(encoding="utf-8")
    for raw_target in MARKDOWN_LINK.findall(text):
        target = raw_target.strip().split(maxsplit=1)[0].strip("<>")
        if not target or target.startswith("#"):
            continue
        if target.startswith("//"):
            continue
        if target.startswith("/"):
            error(f"{path}: absolute skill link is not portable: {target}")
            continue
        parsed = urlsplit(target)
        if parsed.scheme or parsed.netloc:
            continue
        target_path = target.split("#", 1)[0]
        if not target_path:
            continue
        candidate = Path(os.path.normpath(str(path.parent / target_path)))
        try:
            relative = candidate.relative_to(root).as_posix()
        except ValueError:
            error(f"{path}: internal link escapes the repository: {target}")
        regular_file(root, relative, f"{path} link {target}")


def read_manifests(root: Path) -> dict[str, str]:
    seen: dict[str, str] = {}
    for manifest in MANIFESTS:
        manifest_path = regular_file(root, manifest.as_posix(), "payload manifest")
        for line_number, raw in enumerate(
            manifest_path.read_text(encoding="utf-8").splitlines(), 1
        ):
            value = raw.strip()
            if not value or value.startswith("#"):
                continue
            safe_relative_path(value, f"{manifest.as_posix()}:{line_number}")
            if value in seen:
                error(
                    f"duplicate payload path {value!r} in {manifest} and {seen[value]}"
                )
            seen[value] = manifest.as_posix()
            regular_file(root, value, f"{manifest.as_posix()}:{line_number}")
    return seen


def discover_skill_files(root: Path, skill_root: Path) -> dict[str, Path]:
    absolute_root = root / skill_root
    if not absolute_root.is_dir():
        error(f"skill root is missing: {absolute_root}")
    discovered: dict[str, Path] = {}
    for child in sorted(absolute_root.iterdir()):
        if child.is_symlink():
            error(f"skill root contains a symlink: {child}")
        if not child.is_dir():
            continue
        skill_file = child / "SKILL.md"
        if skill_file.is_symlink():
            error(f"skill root contains a symlink: {skill_file}")
        if not skill_file.is_file():
            continue
        name = child.name
        if name in discovered:
            error(f"duplicate skill directory: {name}")
        discovered[name] = skill_file
    if not discovered:
        error(f"no SKILL.md files discovered under {absolute_root}")
    return discovered


def validate_root(root: Path) -> None:
    root = root.resolve()
    manifests = read_manifests(root)
    canonical = discover_skill_files(root, CANONICAL_ROOT)
    wrappers = discover_skill_files(root, CLAUDE_ROOT)

    canonical_files = {
        (CANONICAL_ROOT / name / "SKILL.md").as_posix() for name in canonical
    }
    all_skill_files: set[str] = set()
    for path in (root / CANONICAL_ROOT).rglob("*"):
        if path.is_symlink():
            error(f"canonical skill bundle contains a symlink: {path}")
        if path.is_file():
            all_skill_files.add(path.relative_to(root).as_posix())
    missing_manifest = sorted(all_skill_files - set(manifests))
    if missing_manifest:
        error(f"canonical skill files are not installable: {', '.join(missing_manifest)}")

    for name, path in canonical.items():
        fields = validate_metadata(path, name)
        validate_internal_links(path, root)
        if name in wrappers:
            wrapper_fields = validate_metadata(wrappers[name], name)
            if wrapper_fields["description"] != fields["description"]:
                error(f"{wrappers[name]}: metadata drifted from {path}")
            validate_internal_links(wrappers[name], root)

    expected_wrappers = {
        value.removeprefix(f"{CLAUDE_ROOT.as_posix()}/").split("/", 1)[0]
        for value in manifests
        if value.startswith(f"{CLAUDE_ROOT.as_posix()}/")
        and value.endswith("/SKILL.md")
    }
    if set(wrappers) != expected_wrappers:
        error(
            "Claude wrapper manifest mismatch: "
            f"expected={sorted(expected_wrappers)} actual={sorted(wrappers)}"
        )
    if set(wrappers) != set(canonical) - {"engineering-wisdom"}:
        error(
            "Claude wrappers must cover only the four core skills: "
            f"actual={sorted(wrappers)}"
        )
    if not canonical_files.issubset(set(manifests)):
        error("every canonical SKILL.md must appear in a payload manifest")

    engineering_wrapper = root / "scripts/claude-engineering-wisdom-shim.md"
    engineering = canonical.get("engineering-wisdom")
    if engineering is None or not engineering_wrapper.is_file():
        error("engineering-wisdom canonical skill or Claude wrapper source is missing")
    engineering_fields = validate_metadata(engineering, "engineering-wisdom")
    wrapper_fields = validate_metadata(engineering_wrapper, "engineering-wisdom")
    if wrapper_fields["description"] != engineering_fields["description"]:
        error(f"{engineering_wrapper}: metadata drifted from {engineering}")
    validate_internal_links(engineering_wrapper, root)

    marker = chr(96)
    for name, wrapper in wrappers.items():
        expected_reference = f".agents/skills/{name}/SKILL.md"
        expected_text = f"canonical skill is\n{marker}{expected_reference}{marker}"
        if expected_text not in wrapper.read_text(encoding="utf-8"):
            error(f"{wrapper}: missing canonical reference {expected_reference}")
    expected_engineering_reference = ".agents/skills/engineering-wisdom/SKILL.md"
    expected_text = (
        f"canonical skill is\n{marker}{expected_engineering_reference}{marker}"
    )
    if expected_text not in engineering_wrapper.read_text(encoding="utf-8"):
        error(
            f"{engineering_wrapper}: missing canonical reference "
            f"{expected_engineering_reference}"
        )

    print(
        "Agent Skills portability contract passed: "
        f"{len(canonical)} canonical skills, {len(wrappers)} Claude wrappers, "
        f"{len(manifests)} manifest entries"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--skill-file",
        action="append",
        type=Path,
        help="validate one isolated SKILL.md (used by focused negative tests)",
    )
    args = parser.parse_args()
    try:
        if args.skill_file:
            for path in args.skill_file:
                path = path.resolve()
                validate_metadata(path, path.parent.name)
            print(
                f"Agent Skills metadata contract passed: {len(args.skill_file)} file(s)"
            )
        else:
            validate_root(args.root)
    except ValidationError as exc:
        print(f"skill bundle validation failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
