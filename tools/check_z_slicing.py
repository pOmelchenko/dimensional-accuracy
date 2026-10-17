#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Check actual Z-B step-height trajectories before/after a Z-only plugin apply."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from check_slicing import XY_KEY, Z_KEY, envelope, numeric_setting, parse, sha256
from result import strict_json, validate_record


def applied_percent(record):
    validate_record(record)
    if record.get("artifacts", {}).get("z") != {"id": "DA-Z-B", "revision": 1}:
        raise ValueError("requires a Z-B revision 1 plugin result")
    if record["apply_status"] != "CONFIRMED" or record["readback_status"] != "MATCHED":
        raise ValueError("requires confirmed apply and numeric readback")
    writes = [p for p in record["proposed_settings"] if p.get("write_requested")]
    if len(writes) != 1 or writes[0]["key"] != Z_KEY or writes[0]["owner"] != "filament_slot_1":
        raise ValueError("requires a Z-only apply in slot 1")
    if not writes[0]["before"].get("known") or writes[0]["before"].get("numeric") != 0:
        raise ValueError("plugin must have observed a zero baseline")
    value = record["plan"]["z"]["shrinkage_percent"]
    if abs(value-writes[0]["proposed"]) > 1e-6:
        raise ValueError("proposal disagrees with the calculated plan")
    return value


def step_tops(parsed):
    # Recover translation from the symmetric base, not from a manually supplied
    # bed position. Base dimensions are checked separately in compare().
    base_z = next((z for z in parsed["layer_z_mm"] if .6 <= z <= 1), None)
    if base_z is None:
        raise ValueError("missing base layers")
    base = envelope(parsed, base_z, "X")
    center_x = (base["low"]["coordinate_mm"]+base["high"]["coordinate_mm"])/2
    tops = []
    for nominal, offset in ((40, -14), (80, 0), (120, 14)):
        probe = center_x+offset
        # At each blade's centre, the last horizontal external-perimeter
        # segment crossing a 1 mm probe band identifies its last printed layer.
        # Chamfered upper corners still leave a wide flat horizontal segment.
        hits = [s for s in parsed["external_segments"]
                if abs(s["start"][1]-s["end"][1]) < 1e-8 and
                min(s["start"][0], s["end"][0]) <= probe-.5 and
                max(s["start"][0], s["end"][0]) >= probe+.5]
        if not hits:
            raise ValueError(f"missing external trajectory over the {nominal} mm blade")
        top = max(hits, key=lambda s: s["z_mm"])
        tops.append(dict(nominal_mm=nominal, probe_x_mm=probe, top_print_z_mm=top["z_mm"],
                         line=top["line"], segment_start=top["start"], segment_end=top["end"]))
    return tops


def compare(before, after, percent):
    if not math.isfinite(percent) or not .5-1e-6 <= percent <= 2+1e-6:
        raise ValueError("this quantized-layer smoke test requires 0.5-2% positive Z shrinkage")
    differences = sorted(k for k in before["config"].keys() | after["config"].keys()
                         if before["config"].get(k) != after["config"].get(k))
    if differences != [Z_KEY]:
        raise ValueError("expected only Z shrinkage to change in the exported configuration")
    for parsed, expected in ((before, 0), (after, percent)):
        if abs(numeric_setting(parsed["config"], Z_KEY, True)-expected) > 1e-6:
            raise ValueError("wrong exported Z shrinkage")
        if numeric_setting(parsed["config"], XY_KEY, True) != 0 or numeric_setting(parsed["config"], "xy_size_compensation") != 0:
            raise ValueError("XY compensation must remain zero")
        layers = parsed["layer_z_mm"]
        if len(layers) < 3 or any(b <= a for a, b in zip(layers, layers[1:])):
            raise ValueError("requires one object with increasing print layers")
    layer_height = numeric_setting(before["config"], "layer_height")
    if not 0 < layer_height <= .2:
        raise ValueError("use fixed layers no thicker than 0.2 mm")
    # Z compensation changes slice geometry, not the selected layer-height
    # setting. Every actual layer increment must retain that fixed height.
    for parsed in (before, after):
        if any(abs(b-a-layer_height) > 1e-5 for a,b in zip(parsed["layer_z_mm"], parsed["layer_z_mm"][1:])):
            raise ValueError("variable/adaptive layer schedule is outside this check")
    if before["layer_z_mm"][0] != after["layer_z_mm"][0]:
        raise ValueError("first-layer height changed")
    for axis, nominal in (("X",52), ("Y",24)):
        for parsed in (before,after):
            base_z = next(z for z in parsed["layer_z_mm"] if .6 <= z <= 1)
            if abs(envelope(parsed,base_z,axis)["nominal_boundary_span_mm"]-nominal) > .005:
                raise ValueError("Z-only apply changed the unscaled XY base footprint")
    factor = 100/(100-percent)
    rows = []
    for b,a in zip(step_tops(before),step_tops(after)):
        n = b["nominal_mm"]
        expected_delta = n*(factor-1)
        actual_delta = a["top_print_z_mm"]-b["top_print_z_mm"]
        # Print Z is quantized by the profile. Each top may deviate from the
        # continuous nominal by at most one layer; the paired delta by one layer
        # for this shared fixed schedule. Require a real positive movement too.
        tolerance = layer_height+1e-5
        if (abs(b["top_print_z_mm"]-n) > tolerance or
                abs(a["top_print_z_mm"]-n*factor) > tolerance or actual_delta <= 0 or
                abs(actual_delta-expected_delta) > tolerance):
            raise ValueError(f"Z trajectory mismatch at {n} mm: delta {actual_delta:g}, expected {expected_delta:g}")
        rows.append(dict(nominal_mm=n, baseline=b, compensated=a, expected_continuous_z_mm=n*factor,
                         expected_delta_mm=expected_delta, observed_delta_mm=actual_delta,
                         delta_error_mm=actual_delta-expected_delta))
    return dict(status="Z_TRAJECTORY_SCALE_CONFIRMED", physical_validation="NOT_ESTABLISHED",
                artifact_id="DA-Z-B", artifact_revision=1, z_shrinkage_percent=percent,
                scale_factor=factor, unchanged_layer_height_mm=layer_height,
                quantization_tolerance_mm=layer_height+1e-5,
                baseline_layer_count=len(before["layer_z_mm"]), compensated_layer_count=len(after["layer_z_mm"]),
                baseline_last_print_z_mm=before["layer_z_mm"][-1],
                compensated_last_print_z_mm=after["layer_z_mm"][-1],
                unchanged_xy_base_mm=[52,24], changed_config_keys=differences, steps=rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline",type=Path)
    parser.add_argument("compensated",type=Path)
    parser.add_argument("--apply-result",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args = parser.parse_args()
    try:
        record = strict_json(args.apply_result.read_text())
        report = compare(parse(args.baseline.read_text(),True),parse(args.compensated.read_text(),True),applied_percent(record))
        report["sha256"] = {key:sha256(path) for key,path in (("baseline_gcode",args.baseline),
            ("compensated_gcode",args.compensated),("apply_result",args.apply_result))}
        with args.output.open("x") as stream:
            json.dump(report,stream,indent=2,allow_nan=False)
            stream.write("\n")
        print(report["status"] + "; physical validation NOT_ESTABLISHED")
    except (ValueError,OSError,KeyError) as error:
        parser.exit(1,f"ERROR: {error}\n")


if __name__ == "__main__":
    main()
