#!/usr/bin/env python3
"""Validate metadata-only external Harness trajectory evidence."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


INPUT_SCHEMA = "repository-harness-trajectory/v1"
OUTPUT_SCHEMA = "repository-harness-trajectory-validation/v1"
MAX_INPUT_BYTES = 2_000_000
MAX_EVENTS = 10_000
MAX_PROOF_REFS = 64
SAFE_REF = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/@+\-]{0,255}$")
TOKEN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/@+\-]{0,127}$")
LABEL = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 .:/_@+\-]{0,127}$")
REVISION = re.compile(r"^[0-9a-f]{40}$")

TOP_LEVEL_FIELDS = {"schema", "privacy", "run", "events", "outcome"}
PRIVACY_FIELDS = {"mode", "payloads_redacted"}
RUN_FIELDS = {"run_id", "repository_revision", "client", "model", "runner", "started_at"}
EVENT_FIELDS = {"seq", "type", "ref", "authority", "reason", "result"}
OUTCOME_FIELDS = {"status", "changed", "proof_refs"}

EVENT_TYPES = {
    "request",
    "authority_read",
    "behavior_read",
    "decision_stop",
    "mutation",
    "validation",
    "completion",
}
STOP_REASONS = {
    "authority_missing",
    "product_ambiguity",
    "unsafe_recovery",
    "missing_prerequisite",
}
OUTCOME_STATUSES = {"completed", "stopped_for_authority", "failed_validation"}
VALIDATION_RESULTS = {"passed", "failed"}
FORBIDDEN_FIELDS = {
    "prompt",
    "prompts",
    "transcript",
    "conversation",
    "content",
    "stdout",
    "stderr",
    "tool_input",
    "tool_inputs",
    "tool_output",
    "tool_outputs",
    "secret",
    "secrets",
    "token",
    "tokens",
    "credential",
    "credentials",
}


def add_error(errors: list[dict[str, str]], code: str, path: str, message: str) -> None:
    item = {"code": code, "path": path, "message": message}
    if item not in errors:
        errors.append(item)


def path_for(path: str, key: str) -> str:
    return f"{path}.{key}" if path else key


def scan_forbidden_fields(value: Any, path: str, errors: list[dict[str, str]]) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            child_path = path_for(path, str(key))
            if str(key).lower() in FORBIDDEN_FIELDS:
                add_error(
                    errors,
                    "forbidden_field",
                    child_path,
                    "metadata-only evidence cannot contain transcript, payload, or secret fields",
                )
            scan_forbidden_fields(child, child_path, errors)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            scan_forbidden_fields(child, f"{path}[{index}]", errors)


def check_fields(
    value: dict[str, Any],
    allowed: set[str],
    path: str,
    errors: list[dict[str, str]],
) -> None:
    for key in value:
        if key not in allowed and str(key).lower() not in FORBIDDEN_FIELDS:
            add_error(errors, "unknown_field", path_for(path, str(key)), "field is not allowed by the v1 metadata schema")


def required_string(
    value: dict[str, Any],
    key: str,
    path: str,
    errors: list[dict[str, str]],
    *,
    pattern: re.Pattern[str] | None = None,
    pattern_error_code: str = "invalid_reference",
    pattern_error_message: str = "field must be a relative metadata reference",
    max_length: int = 256,
) -> str | None:
    field_path = path_for(path, key)
    if key not in value:
        add_error(errors, "missing_field", field_path, "required field is missing")
        return None
    candidate = value[key]
    if not isinstance(candidate, str):
        add_error(errors, "invalid_type", field_path, "field must be a string")
        return None
    if (
        not candidate
        or len(candidate) > max_length
        or any(ord(character) < 0x20 for character in candidate)
    ):
        add_error(errors, "invalid_string", field_path, "field must be a bounded single-line string")
        return None
    if pattern is not None and pattern.fullmatch(candidate) is None:
        add_error(errors, pattern_error_code, field_path, pattern_error_message)
        return None
    return candidate


def optional_string(
    value: dict[str, Any],
    key: str,
    path: str,
    errors: list[dict[str, str]],
    *,
    pattern: re.Pattern[str] | None = None,
    pattern_error_code: str = "invalid_reference",
    pattern_error_message: str = "field must be a relative metadata reference",
    max_length: int = 256,
) -> str | None:
    if key not in value:
        return None
    return required_string(
        value,
        key,
        path,
        errors,
        pattern=pattern,
        pattern_error_code=pattern_error_code,
        pattern_error_message=pattern_error_message,
        max_length=max_length,
    )


def validate_privacy(value: Any, errors: list[dict[str, str]]) -> None:
    path = "privacy"
    if not isinstance(value, dict):
        add_error(errors, "invalid_type", path, "privacy must be an object")
        return
    check_fields(value, PRIVACY_FIELDS, path, errors)
    mode = required_string(value, "mode", path, errors, pattern=TOKEN, max_length=64)
    if mode is not None and mode != "metadata_only":
        add_error(errors, "privacy_mode_must_be_metadata_only", path_for(path, "mode"), "v1 accepts only metadata_only evidence")
    if value.get("payloads_redacted") is not True:
        add_error(errors, "payloads_must_be_redacted", path_for(path, "payloads_redacted"), "v1 requires payloads_redacted=true")


def validate_run(value: Any, errors: list[dict[str, str]]) -> None:
    path = "run"
    if not isinstance(value, dict):
        add_error(errors, "invalid_type", path, "run must be an object")
        return
    check_fields(value, RUN_FIELDS, path, errors)
    required_string(value, "run_id", path, errors, pattern=TOKEN, max_length=128)
    revision = required_string(value, "repository_revision", path, errors, pattern=REVISION, max_length=40)
    if revision is not None and REVISION.fullmatch(revision) is None:
        add_error(errors, "invalid_revision", path_for(path, "repository_revision"), "repository_revision must be a 40-character lowercase Git revision")
    # Keep producer labels portable across runtimes while preventing a label
    # from becoming a free-form payload field.
    label_kwargs = {
        "pattern": LABEL,
        "pattern_error_code": "invalid_metadata_label",
        "pattern_error_message": "field must be a bounded metadata label",
        "max_length": 128,
    }
    required_string(value, "client", path, errors, **label_kwargs)
    optional_string(value, "model", path, errors, **label_kwargs)
    optional_string(value, "runner", path, errors, **label_kwargs)
    optional_string(value, "started_at", path, errors, max_length=64)


def validate_event(value: Any, index: int, errors: list[dict[str, str]]) -> dict[str, Any]:
    path = f"events[{index}]"
    if not isinstance(value, dict):
        add_error(errors, "invalid_type", path, "event must be an object")
        return {}
    check_fields(value, EVENT_FIELDS, path, errors)
    sequence_path = path_for(path, "seq")
    sequence = value.get("seq")
    if not isinstance(sequence, int) or isinstance(sequence, bool) or sequence < 1:
        add_error(errors, "invalid_sequence", sequence_path, "seq must be a positive integer")

    event_type = required_string(value, "type", path, errors, pattern=TOKEN, max_length=64)
    if event_type is not None and event_type not in EVENT_TYPES:
        add_error(errors, "unknown_event_type", path_for(path, "type"), "event type is not part of trajectory v1")

    ref = optional_string(value, "ref", path, errors, pattern=SAFE_REF, max_length=256)
    authority = optional_string(value, "authority", path, errors, pattern=SAFE_REF, max_length=256)
    reason = optional_string(value, "reason", path, errors, pattern=TOKEN, max_length=64)
    result = optional_string(value, "result", path, errors, pattern=TOKEN, max_length=64)

    if event_type == "request" and ref != "request":
        add_error(errors, "request_reference_required", path_for(path, "ref"), "the request event must use ref=request")
    elif event_type in {"authority_read", "behavior_read"} and ref is None:
        add_error(errors, "reference_required", path_for(path, "ref"), "read events require a relative reference")
    elif event_type == "decision_stop":
        if reason not in STOP_REASONS:
            add_error(errors, "invalid_stop_reason", path_for(path, "reason"), "decision_stop requires a declared authority-boundary reason")
    elif event_type == "mutation":
        if ref is None:
            add_error(errors, "reference_required", path_for(path, "ref"), "mutation events require a relative operation reference")
        if authority is None:
            add_error(errors, "authority_reference_required", path_for(path, "authority"), "mutation events require the governing authority reference")
    elif event_type == "validation":
        if ref is None:
            add_error(errors, "reference_required", path_for(path, "ref"), "validation events require a command reference")
        if result not in VALIDATION_RESULTS:
            add_error(errors, "invalid_validation_result", path_for(path, "result"), "validation result must be passed or failed")
    elif event_type == "completion" and result not in OUTCOME_STATUSES:
        add_error(errors, "invalid_completion_result", path_for(path, "result"), "completion result must match an outcome status")

    return {"seq": sequence, "type": event_type, "ref": ref, "authority": authority, "reason": reason, "result": result}


def validate_outcome(value: Any, errors: list[dict[str, str]]) -> tuple[str | None, bool | None, list[str]]:
    path = "outcome"
    if not isinstance(value, dict):
        add_error(errors, "invalid_type", path, "outcome must be an object")
        return None, None, []
    check_fields(value, OUTCOME_FIELDS, path, errors)
    status = required_string(value, "status", path, errors, pattern=TOKEN, max_length=64)
    if status not in OUTCOME_STATUSES and status is not None:
        add_error(errors, "unknown_outcome_status", path_for(path, "status"), "outcome status is not part of trajectory v1")
    changed = value.get("changed")
    if not isinstance(changed, bool):
        add_error(errors, "invalid_type", path_for(path, "changed"), "changed must be a boolean")
        changed = None
    proof_refs_value = value.get("proof_refs")
    proof_refs: list[str] = []
    if not isinstance(proof_refs_value, list):
        add_error(errors, "invalid_type", path_for(path, "proof_refs"), "proof_refs must be an array")
    elif len(proof_refs_value) > MAX_PROOF_REFS:
        add_error(errors, "too_many_proof_refs", path_for(path, "proof_refs"), "proof_refs exceeds the v1 bound")
    else:
        for index, proof_ref in enumerate(proof_refs_value):
            field_path = f"{path}.proof_refs[{index}]"
            if not isinstance(proof_ref, str) or SAFE_REF.fullmatch(proof_ref) is None:
                add_error(errors, "invalid_reference", field_path, "proof references must be bounded relative metadata references")
            else:
                proof_refs.append(proof_ref)
    return status, changed, proof_refs


def validate_document(document: Any) -> tuple[list[dict[str, str]], dict[str, int]]:
    errors: list[dict[str, str]] = []
    scan_forbidden_fields(document, "$", errors)
    if not isinstance(document, dict):
        add_error(errors, "invalid_root", "$", "trajectory evidence must be a JSON object")
        return errors, {"events": 0, "mutations": 0, "validations": 0}

    check_fields(document, TOP_LEVEL_FIELDS, "", errors)
    schema = document.get("schema")
    if schema != INPUT_SCHEMA:
        add_error(errors, "unsupported_schema", "schema", "trajectory evidence must declare repository-harness-trajectory/v1")
    validate_privacy(document.get("privacy"), errors)
    validate_run(document.get("run"), errors)

    raw_events = document.get("events")
    parsed_events: list[dict[str, Any]] = []
    if not isinstance(raw_events, list):
        add_error(errors, "invalid_type", "events", "events must be an array")
    elif not raw_events:
        add_error(errors, "events_required", "events", "at least one trajectory event is required")
    elif len(raw_events) > MAX_EVENTS:
        add_error(errors, "too_many_events", "events", "events exceeds the v1 bound")
    else:
        parsed_events = [validate_event(event, index, errors) for index, event in enumerate(raw_events)]

    status, changed, proof_refs = validate_outcome(document.get("outcome"), errors)

    event_types = [event.get("type") for event in parsed_events]
    mutations = [index for index, event_type in enumerate(event_types) if event_type == "mutation"]
    validations = [index for index, event_type in enumerate(event_types) if event_type == "validation"]
    stop_events = [index for index, event_type in enumerate(event_types) if event_type == "decision_stop"]

    if parsed_events:
        if event_types[0] != "request":
            add_error(errors, "request_must_be_first", "events[0]", "trajectory must begin with a request event")
        if event_types.count("request") != 1:
            add_error(errors, "exactly_one_request_required", "events", "trajectory must contain exactly one request event")
        if event_types.count("completion") != 1:
            add_error(errors, "exactly_one_completion_required", "events", "trajectory must contain exactly one completion event")
        elif event_types[-1] != "completion":
            add_error(errors, "completion_must_be_last", "events", "completion must be the final event")

        for index, event in enumerate(parsed_events):
            if event.get("seq") != index + 1:
                add_error(errors, "sequence_must_be_contiguous", f"events[{index}].seq", "seq must start at 1 and increase by one")

        for mutation_index in mutations:
            if not any(event_types[index] == "authority_read" for index in range(mutation_index)):
                add_error(
                    errors,
                    "missing_authority_before_mutation",
                    f"events[{mutation_index}]",
                    "a mutation requires an earlier authority_read event",
                )

        if stop_events:
            first_stop = stop_events[0]
            if any(index > first_stop for index in mutations):
                add_error(errors, "mutation_after_authority_stop", f"events[{first_stop}]", "no mutation may follow decision_stop")

        if status == "stopped_for_authority":
            if not stop_events:
                add_error(errors, "authority_stop_required", "outcome.status", "stopped_for_authority requires decision_stop")
            if mutations:
                add_error(errors, "stopped_run_mutated", "outcome.status", "stopped_for_authority trajectories cannot contain mutations")
        if status == "completed" and stop_events:
            add_error(errors, "completed_after_authority_stop", "outcome.status", "a completed trajectory cannot stop at an authority boundary")
        if status == "failed_validation" and not any(
            parsed_events[index].get("type") == "validation" and parsed_events[index].get("result") == "failed"
            for index in validations
        ):
            add_error(errors, "failed_validation_event_required", "outcome.status", "failed_validation requires a failed validation event")

        completion_events = [event for event in parsed_events if event.get("type") == "completion"]
        if completion_events and status is not None and completion_events[0].get("result") != status:
            add_error(errors, "completion_outcome_mismatch", "events", "completion result must match outcome.status")

        if changed is True and not mutations:
            add_error(errors, "changed_without_mutation", "outcome.changed", "changed=true requires a mutation event")
        if status == "completed" and changed is True:
            last_mutation = mutations[-1] if mutations else -1
            if not any(
                index > last_mutation
                and parsed_events[index].get("type") == "validation"
                and parsed_events[index].get("result") == "passed"
                for index in validations
            ):
                add_error(
                    errors,
                    "missing_post_mutation_validation",
                    "events",
                    "a completed mutation requires a later passed validation event",
                )
        if status == "completed" and not proof_refs:
            add_error(errors, "missing_proof_reference", "outcome.proof_refs", "a completed trajectory requires at least one proof reference")

    return errors, {
        "events": len(parsed_events),
        "mutations": len(mutations),
        "validations": len(validations),
    }


def load_document(input_path: str) -> tuple[Any | None, list[dict[str, str]]]:
    errors: list[dict[str, str]] = []
    try:
        raw = sys.stdin.buffer.read() if input_path == "-" else Path(input_path).read_bytes()
    except OSError:
        add_error(errors, "input_unreadable", "input", "trajectory evidence input could not be read")
        return None, errors
    if len(raw) > MAX_INPUT_BYTES:
        add_error(errors, "input_too_large", "input", "trajectory evidence exceeds the v1 size bound")
        return None, errors
    try:
        return json.loads(raw.decode("utf-8")), errors
    except (UnicodeDecodeError, json.JSONDecodeError):
        add_error(errors, "invalid_json", "input", "trajectory evidence must be valid UTF-8 JSON")
        return None, errors


def make_report(errors: list[dict[str, str]], counts: dict[str, int]) -> dict[str, Any]:
    errors = sorted(errors, key=lambda item: (item["path"], item["code"], item["message"]))
    return {
        "schema": OUTPUT_SCHEMA,
        "valid": not errors,
        "errors": errors,
        "summary": {
            "events": counts["events"],
            "mutations": counts["mutations"],
            "validations": counts["validations"],
            "error_count": len(errors),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="trajectory JSON file, or - for stdin")
    args = parser.parse_args()

    document, load_errors = load_document(args.input)
    if load_errors:
        report = make_report(load_errors, {"events": 0, "mutations": 0, "validations": 0})
    else:
        errors, counts = validate_document(document)
        report = make_report(errors, counts)
    json.dump(report, sys.stdout, ensure_ascii=True, sort_keys=True)
    sys.stdout.write("\n")
    return 0 if report["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
