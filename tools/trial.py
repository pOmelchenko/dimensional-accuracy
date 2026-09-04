#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Prepare, freeze and validate a reproducible geometry-selection trial (stdlib only)."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import random
import re
from pathlib import Path

from artifact_spec import load_spec

ROOT = Path(__file__).resolve().parents[1]
PROTOCOL = json.loads((ROOT / "research/protocol-v1.json").read_text())
FROZEN_FILES = ("protocol.md", "protocol.json", "environment.json", "artifacts.csv",
                "prints.csv", "instruments.csv", "schedule.csv", "artifact-spec.json")
ARTIFACT_COLUMNS = ["artifact_id", "artifact_revision", "role", "family", "stl_file", "stl_sha256"]
PRINT_COLUMNS = ["print_id", "print_batch_id", "blind_model_id", "artifact_id",
                 "gcode_sha256", "project_sha256", "bed_x_mm", "bed_y_mm",
                 "print_time_min", "material_g"]
INSTRUMENT_COLUMNS = ["caliper_id", "resolution_mm", "mpe_mm", "asset_id", "calibration_status"]
DEVIATION_COLUMNS = ["event_id", "scope_id", "reason", "action"]


def read_csv(path):
    with Path(path).open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        rows = list(reader)
        if reader.fieldnames is None or len(set(reader.fieldnames)) != len(reader.fieldnames):
            raise ValueError(f"{path}: missing or duplicate column names")
        if any(None in row or None in row.values() for row in rows):
            raise ValueError(f"{path}: malformed CSV row")
        return rows


def write_csv(path, columns, rows):
    with Path(path).open("x", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_json(path, value):
    with Path(path).open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write("\n")


def finite(value, label, positive=False):
    if isinstance(value, bool):
        raise ValueError(f"{label}: booleans are not numeric measurements")
    try:
        result = float(value)
    except (TypeError, ValueError):
        raise ValueError(f"{label}: expected a finite number") from None
    if not math.isfinite(result) or (positive and result <= 0):
        raise ValueError(f"{label}: expected a {'positive ' if positive else ''}finite number")
    return result


def artifacts_for(families, spec=None):
    spec = load_spec() if spec is None else spec
    return [dict(artifact_id=a["artifact_id"], artifact_revision=a["revision"],
                 role=a["role"], family=a["family"], stl_file=a["file"], stl_sha256="")
            for family in families for a in spec["artifacts"]
            if a["family"] == family and a["role"] in ("control", "challenger")]



def make_schedule(config, artifacts, spec=None):
    """One shuffled model/feature round per reseat; crossed, cyclic instrument order."""
    spec = load_spec() if spec is None else spec
    rng = random.Random(config["seed"])
    rows, prints = [], []
    block_counter = 0
    for family in config["families"]:
        models = [a for a in artifacts if a["family"] == family]
        codes = [family.upper() + "-A", family.upper() + "-B"]
        rng.shuffle(codes)
        specimens = []
        for batch in range(1, config["print_batches"] + 1):
            batch_id = f"{family}-{batch}"
            for model, code in zip(models, codes):
                specimen = dict(print_id=f"{batch_id}-{code}", print_batch_id=batch_id,
                                blind_model_id=code, artifact_id=model["artifact_id"])
                specimens.append((model, specimen))
                prints.append(dict(specimen, gcode_sha256="", project_sha256="",
                                   bed_x_mm="", bed_y_mm="", print_time_min="", material_g=""))
        definitions = {a["artifact_id"]: a for a in spec["artifacts"]}
        control_features = definitions[models[0]["artifact_id"]]["measurements"]
        matched = {f["id"] for f in definitions[models[1]["artifact_id"]]["measurements"]}
        features = [(f["axis"], f["nominal_mm"]) for f in control_features if f["id"] in matched]
        instruments = list(range(1, config["calipers"] + 1))
        rng.shuffle(instruments)
        operators = list(range(1, config["operators"] + 1))
        rng.shuffle(operators)
        pairs = [(operator, instruments[(index + shift) % len(instruments)])
                 for shift in range(len(instruments)) for index, operator in enumerate(operators)]
        for gate in ("A", "B"):
            selected = specimens[:2] if gate == "A" else specimens
            blocks = pairs if gate == "A" else [(1, 1)]
            repeats = config[f"gate_{gate.lower()}_repeats"]
            for operator, caliper in blocks:
                in_block = config["max_block_attempts"]
                for repetition in range(1, repeats + 1):
                    round_rows = [(model, specimen, axis, n)
                                  for model, specimen in selected for axis, n in features]
                    rng.shuffle(round_rows)
                    for model, specimen, axis, nominal in round_rows:
                        if in_block >= config["max_block_attempts"]:
                            block_counter += 1
                            in_block = 0
                        order = len(rows) + 1
                        rows.append(dict(
                            observation_id=f"{config['trial_id']}-{order:05d}",
                            trial_id=config["trial_id"], protocol_version=config["protocol_version"],
                            gate=gate, session_id=f"{family}-{gate}-O{operator}-C{caliper}",
                            block_id=f"block-{block_counter:03d}", scheduled_order=order,
                            **specimen, artifact_revision=model["artifact_revision"],
                            operator_id=f"O{operator}", caliper_id=f"C{caliper}", axis=axis,
                            feature_id=f"{axis}{nominal}", measurement_method="outer_jaws",
                            nominal_mm=nominal, repetition=repetition))
                        in_block += 1
    return rows, prints


def initialize(directory, trial_id, seed, families=("xy", "z"), calipers=3):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", trial_id):
        raise ValueError("trial_id must be 1–64 letters, digits, underscores or hyphens")
    if calipers not in (2, 3) or not families or len(set(families)) != len(families):
        raise ValueError("choose 2/3 calipers and distinct xy/z families")
    config = dict(PROTOCOL, trial_id=trial_id, seed=seed, families=list(families),
                  calipers=calipers, study_kind="confirmatory" if calipers == 3 else "pilot")
    artifacts = artifacts_for(families)
    schedule, prints = make_schedule(config, artifacts)
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=False)
    write_json(directory / "protocol.json", config)
    write_json(directory / "artifact-spec.json", load_spec())
    (directory / "protocol.md").write_text(
        f"# Trial {trial_id}\n\n" + (ROOT / "research/protocol-v1.md").read_text())
    write_json(directory / "environment.json", {
        "date": "", "plugin_commit": "", "model_commit": "", "slicer_version_commit": "",
        "printer_firmware": "", "nozzle_mm": "", "material_brand_polymer_colour_lot": "",
        "material_slot": 1, "preset_identifiers": "", "preset_snapshot_sha256": "",
        "orientation": "", "seam": "", "layer_height_mm": "", "line_width_mm": "",
        "walls": "", "top_bottom_layers": "", "infill": "", "flow_pa": "",
        "temperatures": "", "humidity": "", "minimum_cooling_h": "",
        "xy_shrinkage": 0, "z_shrinkage": 0, "xy_size_compensation": 0,
        "operators": [f"O{i}" for i in range(1, config["operators"] + 1)],
        "cost_acceptance_rule": "", "protocol_deviations": []})
    write_csv(directory / "artifacts.csv", ARTIFACT_COLUMNS, artifacts)
    write_csv(directory / "prints.csv", PRINT_COLUMNS, prints)
    write_csv(directory / "instruments.csv", INSTRUMENT_COLUMNS,
              [dict.fromkeys(INSTRUMENT_COLUMNS, "") | {"caliper_id": f"C{i}"}
               for i in range(1, calipers + 1)])
    write_csv(directory / "schedule.csv", config["schedule_columns"], schedule)
    write_csv(directory / "measurements.csv", config["measurement_columns"], [])
    write_csv(directory / "deviations.csv", DEVIATION_COLUMNS, [])
    (directory / "photos").mkdir()
    return config, schedule


def validate_plan(directory, ready=False):
    directory = Path(directory)
    config = json.loads((directory / "protocol.json").read_text())
    for key, value in PROTOCOL.items():
        if key in ("status", "calipers"):
            continue
        if config.get(key) != value:
            raise ValueError(f"protocol {key} differs from v1; use a new supported version")
    if config["status"] != "DRAFT" or config["calipers"] not in (2, 3):
        raise ValueError("invalid study configuration")
    if config["study_kind"] != ("confirmatory" if config["calipers"] == 3 else "pilot"):
        raise ValueError("two-caliper studies must be pilots")
    artifacts = read_csv(directory / "artifacts.csv")
    spec = json.loads((directory / "artifact-spec.json").read_text())
    expected_artifacts = artifacts_for(config["families"], spec)
    if len(artifacts) != len(expected_artifacts):
        raise ValueError("artifact count mismatch")
    for actual, expected in zip(artifacts, expected_artifacts):
        for key in ARTIFACT_COLUMNS[:-1]:
            if actual[key] != str(expected[key]):
                raise ValueError(f"artifact mismatch: {key}")
    schedule, expected_prints = make_schedule(config, artifacts, spec)
    actual_schedule = read_csv(directory / "schedule.csv")
    if actual_schedule != [{k: str(v) for k, v in row.items()} for row in schedule]:
        raise ValueError("schedule does not match the frozen seed/design")
    prints = read_csv(directory / "prints.csv")
    if len(prints) != len(expected_prints):
        raise ValueError("print count mismatch")
    for actual, expected in zip(prints, expected_prints):
        if any(actual[key] != expected[key] for key in PRINT_COLUMNS[:4]):
            raise ValueError("print identity mismatch")
    instruments = read_csv(directory / "instruments.csv")
    if [row["caliper_id"] for row in instruments] != [f"C{i}" for i in range(1, config["calipers"] + 1)]:
        raise ValueError("instrument roster mismatch")
    if ready:
        environment = json.loads((directory / "environment.json").read_text())
        required = ("date plugin_commit model_commit slicer_version_commit printer_firmware nozzle_mm "
                    "material_brand_polymer_colour_lot material_slot preset_identifiers preset_snapshot_sha256 "
                    "orientation seam layer_height_mm line_width_mm walls top_bottom_layers infill flow_pa "
                    "temperatures humidity minimum_cooling_h operators cost_acceptance_rule").split()
        if any(not environment.get(key) for key in required):
            raise ValueError("complete every environment/process field before freezing")
        if environment["operators"] != [f"O{i}" for i in range(1, config["operators"] + 1)]:
            raise ValueError("operator roster mismatch")
        for key in ("nozzle_mm", "layer_height_mm", "line_width_mm", "minimum_cooling_h"):
            finite(environment[key], key, positive=True)
        if environment["material_slot"] != 1 or any(
            finite(environment[key], key) != 0 for key in
            ("xy_shrinkage", "z_shrinkage", "xy_size_compensation")
        ):
            raise ValueError("v1 requires slot 1 and zero compensation")
        for row in artifacts + prints + [environment]:
            for key, value in row.items():
                if key.endswith("sha256") and not re.fullmatch(r"[0-9a-f]{64}", value):
                    raise ValueError(f"{key}: enter an actual lowercase SHA-256")
        for row in instruments:
            finite(row["resolution_mm"], "resolution", positive=True)
            if finite(row["mpe_mm"], "MPE") < 0 or not row["asset_id"] or not row["calibration_status"]:
                raise ValueError("complete instrument metadata")
        for row in prints:
            for key in ("bed_x_mm", "bed_y_mm", "print_time_min", "material_g"):
                finite(row[key], key, positive=key in ("print_time_min", "material_g"))
    return config, actual_schedule


def freeze(directory):
    directory = Path(directory)
    validate_plan(directory, ready=True)
    if json.loads((directory / "artifact-spec.json").read_text()) != load_spec():
        raise ValueError("freeze with the source catalog used to generate this trial; do not relabel artifact definitions")
    if read_csv(directory / "measurements.csv"):
        raise ValueError("cannot preregister a trial after observations exist")
    with (directory / "checksums.sha256").open("x", encoding="utf-8") as stream:
        for name in FROZEN_FILES:
            stream.write(f"{hashlib.sha256((directory / name).read_bytes()).hexdigest()}  {name}\n")


def verify_frozen(directory):
    directory = Path(directory)
    lines = (directory / "checksums.sha256").read_text().splitlines()
    expected = [f"{hashlib.sha256((directory / name).read_bytes()).hexdigest()}  {name}" for name in FROZEN_FILES]
    if lines != expected:
        raise ValueError("frozen protocol or provenance was changed; create a new trial")
    return validate_plan(directory, ready=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    init = sub.add_parser("init")
    init.add_argument("directory", type=Path)
    init.add_argument("--trial-id", required=True)
    init.add_argument("--seed", required=True, type=int)
    init.add_argument("--families", nargs="+", choices=("xy", "z"), default=["xy", "z"])
    init.add_argument("--calipers", type=int, choices=(2, 3), default=3)
    for name in ("validate", "freeze", "verify-frozen"):
        sub.add_parser(name).add_argument("directory", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "init":
            config, schedule = initialize(args.directory, args.trial_id, args.seed, args.families, args.calipers)
            print(f"DRAFT {config['study_kind']}: {len(schedule)} planned attempts; no physical results")
        elif args.command == "validate":
            validate_plan(args.directory)
            print("Draft plan is internally consistent; not a physical PASS")
        elif args.command == "freeze":
            freeze(args.directory)
            print("PROTOCOL_LOCKED: preserve frozen files; begin only after the documented Gate 0 checks")
        else:
            verify_frozen(args.directory)
            print("Frozen plan and provenance verified")
    except (ValueError, OSError, KeyError) as exc:
        parser.exit(1, f"ERROR: {exc}\n")


if __name__ == "__main__":
    main()
