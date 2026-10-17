#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Prepare and compare one XY-S baseline/verification print pair (stdlib + Lua)."""
from __future__ import annotations

import argparse
import csv
from decimal import Decimal, InvalidOperation
import hashlib
import json
import math
from pathlib import Path
import re
import statistics
import subprocess

from artifact_spec import ROOT, by_id, load_spec
from result import calculate, strict_json

SCHEMA = "1.0.0"
PROTOCOL = "XY-S-COMPENSATION-1"
SOLVER = "3.0.0"
PHASES = ("baseline", "verification")
COLUMNS = ("phase", "print_id", "feature_id", "axis", "nominal_mm", "method",
           "repetition", "measured_mm", "status", "zero_before_mm", "zero_after_mm", "notes")
PRINT_COLUMNS = ("phase", "print_id", "artifact_id", "artifact_revision", "mesh_sha256",
                 "project_sha256", "gcode_sha256", "xy_shrinkage_percent",
                 "xy_size_compensation_mm", "z_shrinkage_percent", "material_slot", "notes")


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save_json(path, value):
    with Path(path).open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, ensure_ascii=False, allow_nan=False)
        stream.write("\n")


def save_csv(path, columns, rows):
    with Path(path).open("x", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path, columns):
    with Path(path).open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != list(columns):
            raise ValueError(f"{path.name}: header differs from the protocol")
        rows = list(reader)
    if any(None in row or None in row.values() for row in rows):
        raise ValueError(f"{path.name}: malformed CSV row")
    return rows


def decimal(text, label, positive=False):
    text = str(text).strip().replace(",", ".")
    if not re.fullmatch(r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)", text):
        raise ValueError(f"{label}: expected a plain decimal number")
    value = Decimal(text)
    if not value.is_finite() or not math.isfinite(float(value)) or (positive and value <= 0):
        raise ValueError(f"{label}: invalid measurement")
    return value


def schedule(protocol):
    return [dict(phase=phase, print_id=f"{protocol['experiment_id']}-{phase}",
                 feature_id=f["id"], axis=f["axis"], nominal_mm=str(f["nominal_mm"]),
                 method=f["method"], repetition=str(repeat))
            for phase in PHASES for f in protocol["features"]
            for repeat in range(1, protocol["repeats"] + 1)]


def initialize(directory, experiment_id, repeats=3, margin_mm=.02, synthetic=False):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", experiment_id):
        raise ValueError("experiment ID must contain 1-64 letters, digits, underscores or hyphens")
    if type(repeats) is not int or repeats not in (3, 4, 5):
        raise ValueError("choose 3-5 full re-seat readings per feature")
    margin = decimal(margin_mm, "decision margin")
    if margin < 0:
        raise ValueError("decision margin must be nonnegative")
    spec = load_spec()
    artifact = by_id(spec)[spec["release_artifacts"]["xy"]]
    if artifact["artifact_id"] != "DA-XY-S" or artifact["revision"] != 1:
        raise ValueError("this protocol requires XY-S revision 1")
    protocol = dict(schema_version=SCHEMA, protocol_id=PROTOCOL,
                    experiment_id=experiment_id, data_kind="SYNTHETIC" if synthetic else "PHYSICAL",
                    artifact_id=artifact["artifact_id"], artifact_revision=artifact["revision"],
                    source_catalog_sha256=digest(ROOT / "model/artifacts.json"),
                    solver_version=SOLVER, repeats=repeats, decision_margin_mm=float(margin),
                    features=artifact["measurements"])
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=False)
    save_json(directory / "protocol.json", protocol)
    (directory / "protocol.sha256").write_text(digest(directory / "protocol.json") + "\n")
    rows = [dict.fromkeys(COLUMNS, "") | row for row in schedule(protocol)]
    save_csv(directory / "measurements.csv", COLUMNS, rows)
    mesh = ROOT / artifact["file"]
    save_csv(directory / "prints.csv", PRINT_COLUMNS, [dict.fromkeys(PRINT_COLUMNS, "") | dict(
        phase=phase, print_id=f"{experiment_id}-{phase}", artifact_id=artifact["artifact_id"],
        artifact_revision=artifact["revision"], mesh_sha256=digest(mesh) if mesh.exists() else "",
        xy_shrinkage_percent=0 if phase == "baseline" else "", xy_size_compensation_mm=0,
        z_shrinkage_percent=0, material_slot=1) for phase in PHASES])
    save_json(directory / "environment.json", dict(
        operator_id="", caliper_id="", resolution_mm="", mpe_mm="", printer="",
        filament_spool_lot="", slicer_version_commit="", preset_identifiers="",
        orientation="Long X right, long Y down", seam="", cooling_hours="", notes=""))
    (directory / "README.md").write_text(
        f"# {experiment_id} — {protocol['data_kind']}\n\n"
        "One baseline print at zero compensation, then a separate verification print.\n"
        "Fill environment.json and prints.csv with actual provenance. The initial mesh hash\n"
        "identifies the generated file, not proof that it was printed.\n\n"
        "In measurements.csv retain one row per full re-seat. Use status OK with measured_mm\n"
        "and zero checks, SKIPPED with a reason for an omitted optional feature, or FAILED\n"
        "with a reason and no value. Blank rows remain missing; never enter nominal values\n"
        "as placeholders. Fill baseline first. All six primary fields are required.\n\n"
        "Export baseline input strings with tools/xy_experiment.py inputs. Apply them using\n"
        "the normal plugin workflow. Record the actual verification-print shrinkage in\n"
        "prints.csv, then fill verification rows and run analyze. Do not feed compensated\n"
        "verification readings back into the zero-baseline calculator.\n\n"
        "Related dimensions are not independent samples. The comparison margin is a\n"
        "declared descriptive threshold, not a confidence interval or certified tolerance.\n"
        "See model/xy-reference.md and research/xy-s-experiment.md in the repository.\n")
    return protocol


def load(directory):
    directory = Path(directory)
    protocol = strict_json((directory / "protocol.json").read_text())
    if (directory / "protocol.sha256").read_text().strip() != digest(directory / "protocol.json"):
        raise ValueError("protocol changed; create a new experiment instead of relabelling observations")
    if protocol["schema_version"] != SCHEMA or protocol["protocol_id"] != PROTOCOL or protocol["solver_version"] != SOLVER:
        raise ValueError("unsupported experiment protocol")
    if protocol["data_kind"] not in ("SYNTHETIC", "PHYSICAL"):
        raise ValueError("invalid evidence kind")
    env = strict_json((directory / "environment.json").read_text())
    resolution = decimal(env["resolution_mm"], "resolution", True) if env["resolution_mm"] else None
    if env["mpe_mm"] and decimal(env["mpe_mm"], "MPE") < 0:
        raise ValueError("MPE must be nonnegative")
    rows = read_csv(directory / "measurements.csv", COLUMNS)
    expected = schedule(protocol)
    if len(rows) != len(expected):
        raise ValueError("measurement rows are missing or duplicated; preserve the complete template")
    for row, planned in zip(rows, expected):
        if any(row[key] != value for key, value in planned.items()):
            raise ValueError("measurement identity/order/nominal/method differs from the protocol")
        status = row["status"]
        if status not in ("", "OK", "SKIPPED", "FAILED"):
            raise ValueError("unsupported measurement status")
        if status == "OK":
            decimal(row["measured_mm"], row["feature_id"], True)
        elif row["measured_mm"] or (status and not row["notes"]):
            raise ValueError("non-OK rows require an empty measurement and an explicit reason")
        for field in ("measured_mm", "zero_before_mm", "zero_after_mm"):
            if row[field]:
                value = decimal(row[field], field, field == "measured_mm")
                if resolution:
                    try:
                        remainder = value % resolution
                    except InvalidOperation as error:
                        raise ValueError("reading exceeds supported decimal precision") from error
                    if remainder:
                        raise ValueError(f"{field}: reading is finer than declared instrument resolution")
    prints = read_csv(directory / "prints.csv", PRINT_COLUMNS)
    if len(prints) != 2:
        raise ValueError("one baseline and one verification print are required")
    for phase, row in zip(PHASES, prints):
        if (row["phase"], row["print_id"], row["artifact_id"], row["artifact_revision"]) != (
            phase, f"{protocol['experiment_id']}-{phase}", protocol["artifact_id"], str(protocol["artifact_revision"])):
            raise ValueError("print identity differs from the protocol")
        for key in ("mesh_sha256", "project_sha256", "gcode_sha256"):
            if row[key] and not re.fullmatch(r"[0-9a-f]{64}", row[key]):
                raise ValueError(f"{key}: expected a SHA-256 or an explicit blank")
        for key in ("xy_size_compensation_mm", "z_shrinkage_percent"):
            if decimal(row[key], key) != 0:
                raise ValueError("this experiment changes only XY shrinkage; keep other compensation zero")
        if row["material_slot"] != "1":
            raise ValueError("this experiment requires material slot 1")
    if decimal(prints[0]["xy_shrinkage_percent"], "baseline shrinkage") != 0:
        raise ValueError("baseline print must have zero shrinkage")
    if prints[1]["xy_shrinkage_percent"]:
        value = decimal(prints[1]["xy_shrinkage_percent"], "verification shrinkage")
        if not -10 <= value <= 10:
            raise ValueError("verification shrinkage is outside the supported range")
    return protocol, env, rows, prints


def collect(protocol, env, rows):
    cells = {}
    for phase in PHASES:
        for feature in protocol["features"]:
            selected = [r for r in rows if r["phase"] == phase and r["feature_id"] == feature["id"]]
            values = [float(decimal(r["measured_mm"], feature["id"], True)) for r in selected if r["status"] == "OK"]
            cell = dict(n=len(values), expected_n=protocol["repeats"], raw=selected, values_mm=values)
            if any(r["status"] == "FAILED" for r in selected):
                status = "FAILED"
            elif all(r["status"] == "SKIPPED" for r in selected):
                status = "SKIPPED"
            elif len(values) == protocol["repeats"]:
                status = "COMPLETE"
            else:
                status = "PARTIAL" if values or any(r["status"] for r in selected) else "MISSING"
            if values:
                cell.update(median_mm=statistics.median(values), mean_mm=statistics.mean(values),
                            range_mm=max(values)-min(values), sample_sd_mm=statistics.stdev(values) if len(values)>1 else None)
            zero_missing = any(r["status"] == "OK" and (not r["zero_before_mm"] or not r["zero_after_mm"]) for r in selected)
            bad_zero = False
            if env["resolution_mm"]:
                limit = decimal(env["resolution_mm"], "resolution", True)
                bad_zero = any(r["status"] == "OK" and r["zero_before_mm"] and r["zero_after_mm"] and
                               max(abs(decimal(r["zero_before_mm"], "zero")), abs(decimal(r["zero_after_mm"], "zero")),
                                   abs(decimal(r["zero_after_mm"], "zero")-decimal(r["zero_before_mm"], "zero"))) > limit
                               for r in selected)
            cell.update(status="ZERO_CHECK_FAILED" if bad_zero else status, zero_checks_missing=zero_missing)
            cells[(phase, feature["id"])] = cell
    return cells


def baseline_inputs(protocol, env, cells):
    inputs = dict(calibrate_xy=True, calibrate_z=False, apply_uniform_scale=False, apply_z_shrinkage=False,
                  confirm_zero_compensation=False, confirm_apply_capable_host=False,
                  session_id=protocol["experiment_id"] + "-baseline", operator_id=env["operator_id"],
                  caliper_id=env["caliper_id"], resolution_mm=env["resolution_mm"], mpe_mm=env["mpe_mm"],
                  slicer_version=env["slicer_version_commit"], filament=env["filament_spool_lot"],
                  preset_ids=env["preset_identifiers"])
    for feature in protocol["features"]:
        cell = cells[("baseline", feature["id"])]
        if cell["status"] == "COMPLETE":
            inputs[feature["id"]] = ";".join(r["measured_mm"] for r in cell["raw"])
        elif feature["required"] or cell["status"] not in ("MISSING", "SKIPPED"):
            raise ValueError(f"{feature['id']}: baseline {cell['status']}; repeat or explicitly skip the whole optional feature")
    return inputs


def analyze(directory, lua="lua"):
    directory = Path(directory)
    protocol, env, rows, prints = load(directory)
    cells = collect(protocol, env, rows)
    report = dict(schema_version=SCHEMA, protocol_id=PROTOCOL, experiment_id=protocol["experiment_id"],
                  data_kind=protocol["data_kind"], physical_validation="NOT_ESTABLISHED",
                  evidence_status="SYNTHETIC_ONLY" if protocol["data_kind"] == "SYNTHETIC" else "REPORTED_MEASUREMENTS",
                  artifact_id=protocol["artifact_id"], artifact_revision=protocol["artifact_revision"], solver_version=SOLVER,
                  environment=env, prints=prints, warnings=[], comparisons=[],
                  decision_margin_mm=protocol["decision_margin_mm"],
                  input_sha256={name:digest(directory / name) for name in
                                ("protocol.json", "protocol.sha256", "environment.json", "prints.csv", "measurements.csv")})
    missing = [key for key,value in env.items() if not value and key != "notes"]
    if missing:
        report["warnings"].append("Incomplete provenance: " + ", ".join(missing))
    if any(not p[k] for p in prints for k in ("mesh_sha256", "project_sha256", "gcode_sha256")):
        report["warnings"].append("Print provenance hashes are incomplete; file identity is not verified")
    try:
        inputs = baseline_inputs(protocol, env, cells)
        plan = calculate(inputs, SOLVER, lua)
        report.update(baseline_inputs=inputs, baseline_plan=plan)
        report["proposed_xy_shrinkage_percent"] = plan["xy"]["shrinkage_percent"]
        if any(plan["xy"][axis]["additional_status"] == "INCONSISTENT" for axis in "xy"):
            report["warnings"].append("Baseline additional measurements contradict the primary fit")
            report["baseline_quality"] = "REVIEW_NEEDED"
        else:
            report["baseline_quality"] = "ACCEPTED_BY_SOFTWARE_GATES"
    except (ValueError, subprocess.CalledProcessError) as error:
        report["baseline_error"] = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        report["baseline_quality"] = "NOT_ACCEPTED"
    recorded = prints[1]["xy_shrinkage_percent"]
    report["compensation_match"] = "NOT_RECORDED"
    if recorded and "proposed_xy_shrinkage_percent" in report:
        report["compensation_match"] = "MATCHED_DECLARATION" if abs(float(decimal(recorded, "shrinkage")) -
            report["proposed_xy_shrinkage_percent"]) <= 1e-6 else "MISMATCH"
    for feature in protocol["features"]:
        before, after = (cells[(p, feature["id"])] for p in PHASES)
        item = dict(feature_id=feature["id"], label=feature["label"], axis=feature["axis"], group=feature["group"],
                    method=feature["method"], nominal_mm=feature["nominal_mm"], required=feature["required"],
                    baseline=before, verification=after, comparison="NOT_COMPARABLE")
        if before["status"] == after["status"] == "COMPLETE":
            b, a = before["median_mm"]-feature["nominal_mm"], after["median_mm"]-feature["nominal_mm"]
            reduction = abs(b)-abs(a)
            margin = protocol["decision_margin_mm"]
            item.update(baseline_error_mm=b, verification_error_mm=a, absolute_error_reduction_mm=reduction,
                        comparison="CLOSER_TO_NOMINAL" if reduction > margin+1e-10 else
                        "FARTHER_FROM_NOMINAL" if reduction < -margin-1e-10 else "WITHIN_COMPARISON_MARGIN")
        if before["zero_checks_missing"] or after["zero_checks_missing"]:
            report["warnings"].append(feature["id"] + ": zero checks are missing")
        for phase, cell in (("baseline", before), ("verification", after)):
            if cell["n"] and cell["range_mm"] > abs(cell["median_mm"]-feature["nominal_mm"]) + 1e-10:
                report["warnings"].append(f"{phase} {feature['id']}: repeat range exceeds the observed deviation")
        report["comparisons"].append(item)
    primary_complete = all(c["comparison"] != "NOT_COMPARABLE" for c in report["comparisons"] if c["required"])
    incomplete_optional = any(c[p]["status"] in ("PARTIAL", "FAILED", "ZERO_CHECK_FAILED")
                              for c in report["comparisons"] for p in PHASES if not c["required"])
    report["status"] = "INCOMPLETE" if not primary_complete else (
        "COMPARED" if report["baseline_quality"] == "ACCEPTED_BY_SOFTWARE_GATES" and
        report["compensation_match"] == "MATCHED_DECLARATION" and not incomplete_optional else "REVIEW_NEEDED")
    report["warnings"].append("Related features and repeated re-seats are not independent prints; no uncertainty or causal improvement claim is inferred")
    return report


def markdown(report):
    lines = [f"# XY-S comparison: {report['experiment_id']}", "",
             f"**{report['data_kind']} — {report['status']}; physical validation NOT_ESTABLISHED.**", "",
             f"Baseline quality: {report['baseline_quality']}. Compensation: {report['compensation_match']}.",
             f"Descriptive comparison margin: {report['decision_margin_mm']:g} mm (not a confidence interval).", ""]
    if "proposed_xy_shrinkage_percent" in report:
        lines += [f"Baseline proposal: {report['proposed_xy_shrinkage_percent']:.6f}% XY shrinkage. Verification data is compared with nominal, never used to estimate a second compensation.", ""]
    if "baseline_error" in report:
        lines += ["Baseline calculation refused: " + report["baseline_error"].replace("\n", " "), ""]
    lines += ["| Feature | Method | Before error, mm | After error, mm | Absolute error reduction, mm | Comparison |", "|---|---|---:|---:|---:|---|"]
    for item in report["comparisons"]:
        values = [f"{item[k]:+.4f}" if k in item else "—" for k in
                  ("baseline_error_mm", "verification_error_mm", "absolute_error_reduction_mm")]
        status = item["comparison"] if item["comparison"] != "NOT_COMPARABLE" else f"{item['baseline']['status']} / {item['verification']['status']}"
        lines.append(f"| {item['label']} | {item['method']} | {' | '.join(values)} | {status} |")
    lines += ["", "Raw rows, repeat statistics, exclusions and input hashes are preserved in the JSON report.", ""]
    lines += ["- " + warning for warning in report["warnings"]]
    return "\n".join(lines)+"\n"


def synthetic(directory, case="scale", repeats=3):
    protocol = initialize(directory, "SYNTHETIC-XY-S-"+case, repeats, synthetic=True)
    directory = Path(directory)
    env = strict_json((directory / "environment.json").read_text())
    for key in env:
        env[key] = "SYNTHETIC — no physical observation"
    env.update(resolution_mm="0.000001", mpe_mm="0.02", cooling_hours="0")
    (directory / "environment.json").write_text(json.dumps(env,indent=2)+"\n")
    rows = read_csv(directory / "measurements.csv", COLUMNS)
    features = {f["id"]:f for f in protocol["features"]}
    outer, inner = (0,0) if case == "scale" else (.08,.06)
    for row in rows:
        f = features[row["feature_id"]]
        scale = .995 if row["phase"] == "baseline" else 1
        value = scale*f["nominal_mm"]+outer*f["contour_coefficient"]+inner*f["inner_coefficient"]
        value += (int(row["repetition"])-(repeats+1)/2)*.01
        if case == "contradiction" and row["phase"] == "baseline" and f["id"] == "x_width25":
            value += .6
        row.update(measured_mm=f"{value:.6f}", status="OK", zero_before_mm="0", zero_after_mm="0", notes="SYNTHETIC")
    with (directory / "measurements.csv").open("w",newline="") as stream:
        writer = csv.DictWriter(stream,fieldnames=COLUMNS,lineterminator="\n"); writer.writeheader();writer.writerows(rows)
    prints = read_csv(directory / "prints.csv", PRINT_COLUMNS)
    prints[1]["xy_shrinkage_percent"] = "0.5"
    for p in prints:
        p["notes"] = "SYNTHETIC; no project or G-code claims"
    with (directory / "prints.csv").open("w",newline="") as stream:
        writer = csv.DictWriter(stream,fieldnames=PRINT_COLUMNS,lineterminator="\n");writer.writeheader();writer.writerows(prints)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command",required=True)
    init = sub.add_parser("init"); init.add_argument("directory",type=Path);init.add_argument("--id",required=True)
    init.add_argument("--repeats",type=int,default=3);init.add_argument("--margin-mm",type=float,default=.02)
    demo = sub.add_parser("synthetic");demo.add_argument("directory",type=Path)
    demo.add_argument("--case",choices=("scale","offsets","contradiction"),default="scale")
    demo.add_argument("--repeats",type=int,default=3)
    inputs = sub.add_parser("inputs");inputs.add_argument("directory",type=Path);inputs.add_argument("--output",type=Path,required=True)
    analyze_cmd = sub.add_parser("analyze");analyze_cmd.add_argument("directory",type=Path)
    analyze_cmd.add_argument("--output",type=Path,required=True);analyze_cmd.add_argument("--lua",default="lua")
    args = parser.parse_args()
    try:
        if args.command == "init":
            initialize(args.directory,args.id,args.repeats,args.margin_mm)
        elif args.command == "synthetic":
            synthetic(args.directory,args.case,args.repeats)
        elif args.command == "inputs":
            protocol,env,rows,_ = load(args.directory)
            save_json(args.output,baseline_inputs(protocol,env,collect(protocol,env,rows)))
        else:
            report = analyze(args.directory,args.lua)
            args.output.mkdir(parents=True,exist_ok=False)
            save_json(args.output / "report.json",report)
            (args.output / "report.md").write_text(markdown(report))
            print(f"{report['data_kind']}: {report['status']}; physical validation NOT_ESTABLISHED")
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1,f"ERROR: {error}\n")


if __name__ == "__main__":
    main()
