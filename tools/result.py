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


def validate_record(record):
    if not isinstance(record, dict) or record.get("schema_version") != "1.0.0":
        raise ValueError("unsupported structured result schema")
    for key in ("solver_version", "plugin_version", "workflow_state", "apply_status", "readback_status", "verification_status"):
        if not isinstance(record.get(key), str):
            raise ValueError(f"missing result field: {key}")
    if not isinstance(record.get("inputs"), dict):
        raise ValueError("missing raw inputs")
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


def replay(record, lua="lua"):
    validate_record(record)
    if "plan" not in record:
        raise ValueError("this record has no calculated plan; raw inputs and refusal are preserved")
    with tempfile.TemporaryDirectory(prefix="da-replay-") as directory:
        inputs = Path(directory) / "inputs.luatest"
        inputs.write_text("return " + lua_literal(record["inputs"]) + "\n", encoding="utf-8")
        completed = subprocess.run([lua, str(ROOT / "tools/replay_result.luatest"),
                                    str(ROOT / "calculate_compensation.lua"), str(inputs), record["solver_version"]],
                                   capture_output=True, text=True, check=True, timeout=30)
    actual = strict_json(completed.stdout)
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
