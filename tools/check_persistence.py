#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Compare manually saved 3MF values and post-restart plugin baseline readings.

This checks numeric evidence. Fresh processes, preset selection and independent
configuration directories must also be observed in the GUI and documented.
The saved YAML is fingerprinted; its values are tested by the host loading it.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import zipfile

from check_slicing import XY_KEY, Z_KEY, applied_percent as applied_xy, sha256
from check_z_slicing import applied_percent as applied_z
from result import READBACK_TOLERANCE_PERCENT, strict_json, validate_record

RECORDS = ("SYNTHETIC-xy-apply.json", "SYNTHETIC-z-apply.json",
           "SYNTHETIC-preset-reopened.json", "SYNTHETIC-project-reopened.json")
PROJECT_MEMBER = "Metadata/PrusaSlicer3_project.json"


def matching_number(actual, expected, label):
    if (type(actual) not in (int, float) or not math.isfinite(actual) or
            abs(actual - expected) > READBACK_TOLERANCE_PERCENT):
        raise ValueError(f"{label}: saved/reopened value {actual!r} differs from {expected!r}")
    return actual


def compare(xy_apply, z_apply, preset_reopened, project_reopened, project):
    expected = {XY_KEY: applied_xy(xy_apply), Z_KEY: applied_z(z_apply)}
    versions = ("schema_version", "solver_version", "plugin_version")
    for record in (z_apply, preset_reopened, project_reopened):
        validate_record(record)
        if any(record[key] != xy_apply[key] for key in versions):
            raise ValueError("mixed plugin/solver/result versions")
    containers = project["config_containers"]
    if len(containers) != 1 or len(containers[0]["preset"]["materials"]) != 1:
        raise ValueError("requires one configuration container and filament slot")
    settings = containers[0]["configuration"]["filament_settings"]
    saved = {}
    for key, value in expected.items():
        entries = settings[key]
        if len(entries) != 1 or entries[0].get("is_percent") is not True:
            raise ValueError(f"{key}: missing typed Percentage in saved 3MF")
        saved[key] = matching_number(entries[0]["value"], value, "3MF " + key)
    reopened = {}
    for label, record in (("preset", preset_reopened), ("project", project_reopened)):
        if (record["workflow_state"] != "ESTIMATED" or record["apply_status"] != "NOT_REQUESTED" or
                record["readback_status"] != "NOT_PERFORMED" or
                record["inputs"].get("apply_uniform_scale") is not False or
                record["inputs"].get("apply_z_shrinkage") is not False or
                any(p.get("write_requested") for p in record["proposed_settings"])):
            raise ValueError("post-restart evidence must be a preview without setting writes")
        values = {}
        for key, baseline_key in ((XY_KEY, "xy_shrinkage"), (Z_KEY, "z_shrinkage")):
            baseline = record["baseline"][baseline_key]
            if baseline.get("known") is not True:
                raise ValueError(label + ": unreadable baseline " + key)
            values[key] = matching_number(baseline["numeric"], expected[key], label + " " + key)
        reopened[label] = values
    return dict(status="SAVED_VALUES_MATCH_REOPENED_API", physical_validation="NOT_ESTABLISHED",
                tolerance_percent=READBACK_TOLERANCE_PERCENT, expected_percent=expected,
                saved_project_percent=saved, reopened_percent=reopened,
                saved_project_material_name=containers[0]["preset"]["materials"][0]["name"],
                process_isolation_evidence="See GUI procedure, screenshots and z-persistence-provenance.json")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        paths = [args.evidence / name for name in RECORDS]
        with zipfile.ZipFile(args.project) as archive:
            project = strict_json(archive.read(PROJECT_MEMBER).decode("utf-8"))
        report = compare(*(strict_json(p.read_text()) for p in paths), project)
        paths += [args.evidence / "SYNTHETIC-saved-filament.yaml", args.project]
        report["sha256"] = {p.name: sha256(p) for p in paths}
        with args.output.open("x") as stream:
            json.dump(report, stream, indent=2, allow_nan=False)
            stream.write("\n")
        print(report["status"] + "; physical validation NOT_ESTABLISHED")
    except (ValueError, OSError, KeyError, TypeError, zipfile.BadZipFile) as error:
        parser.exit(1, f"ERROR: {error}\n")


if __name__ == "__main__":
    main()
