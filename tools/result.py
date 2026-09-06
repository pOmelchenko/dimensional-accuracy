#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Export a structured plugin log record and reproduce its pure calculation locally."""
from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MARKER = "DA_RESULT_JSON "
READBACK_TOLERANCE_PERCENT = 1e-6


def strict_json(text):
    def invalid(value):
        raise ValueError(f"non-finite JSON number: {value}")
    value = json.loads(text, parse_constant=invalid)
    def finite_tree(item):
        if isinstance(item, float) and not math.isfinite(item):
            raise ValueError("non-finite JSON number")
        if isinstance(item, dict):
            for child in item.values():
                finite_tree(child)
        elif isinstance(item, list):
            for child in item:
                finite_tree(child)
    finite_tree(value)
    return value


def validate_readback(record):
    status = record["readback_status"]
    if status == "NOT_PERFORMED":
        if "readback" in record or record["apply_status"] == "CONFIRMED":
            raise ValueError("inconsistent missing readback")
        return
    if status not in ("MATCHED", "MISMATCH", "UNREADABLE") or record["workflow_state"] != "APPLY_ATTEMPTED":
        raise ValueError("invalid readback outcome")
    readback = record.get("readback")
    if not isinstance(readback, dict) or readback.get("tolerance_percent") != READBACK_TOLERANCE_PERCENT:
        raise ValueError("invalid readback tolerance")
    entries = readback.get("settings")
    if not isinstance(entries, list) or not entries:
        raise ValueError("missing setting readbacks")
    proposals = {p["key"]: p["proposed"] for p in record.get("proposed_settings", []) if p.get("write_requested") is True}
    expected_keys = {"filament_shrinkage_compensation_xy", "filament_shrinkage_compensation_z"}
    if not proposals or not proposals.keys() <= expected_keys:
        raise ValueError("invalid readback proposals")

    def finite_number(value):
        return type(value) in (int, float) and math.isfinite(value)

    seen, statuses = set(), set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("invalid setting readback")
        key, expected = entry.get("key"), entry.get("expected_percent")
        if key not in proposals or key in seen or not finite_number(expected) or expected != proposals[key]:
            raise ValueError("readback does not match requested settings")
        seen.add(key)
        entry_status = entry.get("status")
        if entry_status == "UNREADABLE":
            if "actual_percent" in entry or "error_percent" in entry or not isinstance(entry.get("error"), str):
                raise ValueError("invalid unreadable setting")
        elif entry_status in ("MATCHED", "MISMATCH"):
            actual, difference = entry.get("actual_percent"), entry.get("error_percent")
            if not finite_number(actual) or not finite_number(difference):
                raise ValueError("non-numeric setting readback")
            if not math.isclose(difference, actual - expected, rel_tol=1e-12, abs_tol=1e-12):
                raise ValueError("incorrect readback difference")
            calculated_status = "MATCHED" if abs(actual - expected) <= READBACK_TOLERANCE_PERCENT else "MISMATCH"
            if entry_status != calculated_status:
                raise ValueError("incorrect setting readback status")
        else:
            raise ValueError("invalid setting readback status")
        statuses.add(entry_status)
    if seen != proposals.keys():
        raise ValueError("missing requested setting readback")
    aggregate = "MISMATCH" if "MISMATCH" in statuses else ("UNREADABLE" if "UNREADABLE" in statuses else "MATCHED")
    if status != aggregate:
        raise ValueError("incorrect aggregate readback status")
    allowed_apply = {"MATCHED": {"CONFIRMED", "ERROR_UNCONFIRMED"},
                     "MISMATCH": {"ERROR_UNCONFIRMED"},
                     "UNREADABLE": {"UNCONFIRMED", "ERROR_UNCONFIRMED"}}
    if record["apply_status"] not in allowed_apply[status]:
        raise ValueError("apply outcome disagrees with readback")
    if record["apply_status"] == "CONFIRMED" and "error" in record:
        raise ValueError("failed apply cannot be confirmed")


def validate_record(record):
    if not isinstance(record, dict) or record.get("schema_version") not in ("1.0.0", "1.1.0", "1.2.0", "1.3.0"):
        raise ValueError("unsupported structured result schema")
    for key in ("solver_version", "plugin_version", "workflow_state", "apply_status", "readback_status", "verification_status"):
        if not isinstance(record.get(key), str):
            raise ValueError(f"missing result field: {key}")
    if not isinstance(record.get("inputs"), dict):
        raise ValueError("missing raw inputs")
    if record["workflow_state"] not in ("INVALID_INPUT", "ESTIMATED", "APPLY_ATTEMPTED"):
        raise ValueError("unsupported workflow state for this result schema")
    new_schema = record["schema_version"] in ("1.2.0", "1.3.0")
    apply_statuses = {"NOT_REQUESTED", "UNCONFIRMED", "ERROR_UNCONFIRMED"}
    if new_schema:
        apply_statuses.add("CONFIRMED")
    if record["apply_status"] not in apply_statuses:
        raise ValueError("unsupported apply outcome")
    if record["verification_status"] != "NOT_VERIFIED":
        raise ValueError("these result versions cannot claim physical verification")
    if new_schema:
        validate_readback(record)
    elif record["readback_status"] != "NOT_PERFORMED":
        raise ValueError("legacy result versions cannot claim host verification")
    return record


def records_from_log(text):
    records = []
    for line in text.splitlines():
        if MARKER in line:
            record = strict_json(line.split(MARKER, 1)[1])
            records.append(validate_record(record))
    if not records:
        raise ValueError("no structured plugin records found in this log")
    return records


def lua_literal(value):
    """Encode data as literals only; never interpolate untrusted executable Lua."""
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        if not math.isfinite(value):
            raise ValueError("non-finite input")
        return repr(value)
    if isinstance(value, str):
        return '"' + "".join(f"\\{byte:03d}" for byte in value.encode("utf-8")) + '"'
    if isinstance(value, dict):
        if not all(isinstance(key, str) for key in value):
            raise ValueError("input keys must be strings")
        return "{" + ",".join(f"[{lua_literal(key)}]={lua_literal(item)}" for key, item in sorted(value.items())) + "}"
    raise ValueError("inputs must contain scalar measurement/metadata values")


def compare(actual, expected, path="plan"):
    if isinstance(expected, bool) or expected is None:
        if actual is not expected:
            raise ValueError(f"replay mismatch: {path}")
    elif isinstance(expected, (int, float)):
        if isinstance(actual, bool) or not isinstance(actual, (int, float)) or not math.isfinite(actual) or not math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-12):
            raise ValueError(f"replay mismatch: {path}")
    elif isinstance(expected, dict):
        if not isinstance(actual, dict) or set(actual) != set(expected):
            raise ValueError(f"replay fields differ: {path}")
        for key in expected:
            compare(actual[key], expected[key], f"{path}.{key}")
    elif isinstance(expected, list):
        if not isinstance(actual, list) or len(actual) != len(expected):
            raise ValueError(f"replay array differs: {path}")
        for index, (left, right) in enumerate(zip(actual, expected)):
            compare(left, right, f"{path}[{index}]")
    elif actual != expected:
        raise ValueError(f"replay mismatch: {path}")


def calculate(inputs, solver_version, lua="lua"):
    """Run the production pure solver, with no host API or setting writes."""
    with tempfile.TemporaryDirectory(prefix="da-replay-") as directory:
        input_file = Path(directory) / "inputs.luatest"
        input_file.write_text("return " + lua_literal(inputs) + "\n", encoding="utf-8")
        completed = subprocess.run([lua, str(ROOT / "tools/replay_result.luatest"),
                                    str(ROOT / "calculate_compensation.lua"), str(input_file), solver_version],
                                   capture_output=True, text=True, check=True, timeout=30)
    return strict_json(completed.stdout)


def replay(record, lua="lua"):
    validate_record(record)
    if "plan" not in record:
        raise ValueError("this record has no calculated plan; raw inputs and refusal are preserved")
    actual = calculate(record["inputs"], record["solver_version"], lua)
    compare(actual, record["plan"])
    return actual


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    export = sub.add_parser("export")
    export.add_argument("log", type=Path)
    export.add_argument("--output", type=Path, required=True)
    export.add_argument("--index", type=int, default=-1, help="zero-based record index; default is the last/final record")
    rerun = sub.add_parser("replay")
    rerun.add_argument("result", type=Path)
    rerun.add_argument("--lua", default=os.environ.get("LUA", "lua"))
    args = parser.parse_args()
    try:
        if args.command == "export":
            records = records_from_log(args.log.read_text(encoding="utf-8"))
            record = records[args.index]
            with args.output.open("x", encoding="utf-8") as stream:
                json.dump(record, stream, ensure_ascii=False, indent=2, allow_nan=False)
                stream.write("\n")
            print(f"Exported {record['workflow_state']}; apply={record['apply_status']}; verification={record['verification_status']}")
        else:
            record = strict_json(args.result.read_text(encoding="utf-8"))
            replay(record, args.lua)
            print("Calculation reproduced from raw input; no host settings read or written. Physical verification unchanged.")
    except (ValueError, OSError, KeyError, IndexError, subprocess.SubprocessError) as exc:
        detail = exc.stderr if isinstance(exc, subprocess.CalledProcessError) else str(exc)
        parser.exit(1, f"ERROR: {detail}\n")


if __name__ == "__main__":
    main()
