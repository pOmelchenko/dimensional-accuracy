#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Versioned gauge definitions and checked projections for the seven-file plugin."""
from __future__ import annotations

import argparse
import json
import math
import re
import shlex
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_spec(root=ROOT):
    spec = json.loads((root / "model/artifacts.json").read_text())
    if spec["schema_version"] != "2.0.0":
        raise ValueError("unsupported artifact schema")
    nominals = spec["nominal_lengths_mm"]
    if nominals != spec["scad_constants"]["nominal_lengths"]:
        raise ValueError("calculator and SCAD nominal definitions differ")
    if (len(nominals) != 3 or any(isinstance(n, bool) or not isinstance(n, (int, float)) or not math.isfinite(n) or n <= 0 for n in nominals)
            or not nominals[0] < nominals[1] < nominals[2]
            or nominals[1] * 2 != nominals[0] + nominals[2]):
        raise ValueError("this gauge/solver requires three increasing equally spaced nominal lengths")
    ids = set()
    paths = set()
    for artifact in spec["artifacts"]:
        if artifact["artifact_id"] in ids or artifact["file"] in paths:
            raise ValueError("duplicate artifact ID or path")
        ids.add(artifact["artifact_id"])
        paths.add(artifact["file"])
        if artifact["revision"] < 1 or Path(artifact["file"]).is_absolute() or ".." in Path(artifact["file"]).parts:
            raise ValueError("invalid artifact revision/path")
        features = artifact["measurements"]
        if len({f["id"] for f in features}) != len(features):
            raise ValueError("duplicate measurement feature")
        for feature in features:
            n = feature["nominal_mm"]
            if feature["axis"] not in ("x", "y", "z") or type(n) not in (int, float) or not math.isfinite(n) or n <= 0:
                raise ValueError("invalid measurement feature")
            if not re.fullmatch(feature["axis"] + r"[a-z0-9_]+", feature["id"]):
                raise ValueError("feature ID and axis differ")
            if "group" in feature:
                if feature["group"] not in ("primary", "widths", "steps", "windows", "walls"):
                    raise ValueError("unknown measurement group")
                if feature["method"] not in ("outer_jaws", "inner_jaws", "depth_rod"):
                    raise ValueError("unknown measurement method")
                expected = {"outer_jaws": (2, 0), "inner_jaws": (0, -2), "depth_rod": (0, 0)}[feature["method"]]
                if feature["group"] == "walls": expected = (1, 1)
                if (feature["contour_coefficient"], feature["inner_coefficient"]) != expected:
                    raise ValueError("measurement method and contour coefficients differ")
            elif feature["id"] != f"{feature['axis']}{n}" or n not in nominals:
                raise ValueError("legacy feature ID and nominal differ")
        source = Path(artifact["source"])
        if source.is_absolute() or ".." in source.parts or source.suffix != ".scad":
            raise ValueError("invalid SCAD source path")
        if artifact["role"] == "control" and artifact["artifact_id"] != spec["release_artifacts"]["xy"]:
            expected = [(axis, n) for axis in artifact["family"] for n in nominals]
            if [(f["axis"], f["nominal_mm"]) for f in features] != expected:
                raise ValueError("control features differ from the calculator nominal definitions")
    artifacts = by_id(spec)
    for family, aid in spec["release_artifacts"].items():
        if family not in ("xy", "z", "xyz") or aid not in artifacts or artifacts[aid]["family"] != family:
            raise ValueError("invalid release artifact selection")
    xy = artifacts[spec["release_artifacts"]["xy"]]
    for axis in "xy":
        primary = [f for f in xy["measurements"] if f["axis"] == axis and f.get("required")]
        if [(f["nominal_mm"], f["method"]) for f in primary] != [(145, "outer_jaws"), (30, "depth_rod"), (100, "depth_rod")]:
            raise ValueError("XY primary features differ from accepted reference")
    return spec


def by_id(spec):
    return {a["artifact_id"]: a for a in spec["artifacts"]}


def projections(spec, plugin_version):
    artifacts = by_id(spec)
    xy, z, xyz = (artifacts[spec["release_artifacts"][key]] for key in ("xy", "z", "xyz"))
    identity = "local GAUGE_ARTIFACTS = {\n" + "\n".join(
        f'    {family} = {{id = "{a["artifact_id"]}", revision = {a["revision"]}}},'
        for family, a in (("xy", xy), ("z", z), ("xyz", xyz))) + "\n}"
    def lua(value):
        if value is None: return "nil"
        if isinstance(value, bool): return str(value).lower()
        if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
        if isinstance(value, (int, float)): return str(value)
        if isinstance(value, list): return "{" + ", ".join(lua(v) for v in value) + "}"
        return "{" + ", ".join(f"{k} = {lua(v)}" for k, v in value.items()) + "}"
    calculator = f'local PLUGIN_VERSION = "{plugin_version}"\n' + "local NOMINAL_LENGTHS = {" + ", ".join(str(v) for v in spec["nominal_lengths_mm"]) + "}\n" + identity
    calculator += "\nlocal XY_FEATURES = {\n" + "\n".join("    " + lua(f) + "," for f in xy["measurements"]) + "\n}"
    generator = "\n".join(f'local {key}_MODEL_FILE = "{a["file"]}"' for key, a in (("XY", xy), ("Z", z), ("XYZ", xyz))) + "\n" + identity
    make = []
    names = {"DA-XY-S": "XY", "DA-Z-B": "Z", "DA-XYZ-SB": "XYZ",
             "DA-XY-A": "LEGACY_XY", "DA-XYZ-AB": "LEGACY_XYZ",
             "DA-XY-T": "PROTOTYPE_XY", "DA-Z-C40": "PROTOTYPE_Z"}
    for artifact in spec["artifacts"]:
        aid, filename = artifact["artifact_id"], artifact["file"]
        make.extend([
            f"{filename}: $(MODEL_SOURCES) Makefile model/artifacts.json tools/artifact_spec.py",
            f'\t$(PYTHON) tools/artifact_spec.py build {aid} --output $@ --openscad "$(OPENSCAD)"',
            "", f"define VERIFY_{names[aid]}",
            f"\t$(PYTHON) tools/artifact_spec.py verify {aid}", "endef", ""])
    return {"calculate_compensation.lua": calculator, "generate_gauge.lua": generator,
            "Makefile": "\n".join(make).rstrip()}


def marked(text, extension, body):
    comment = "--" if extension == ".lua" else "#"
    start = f"{comment} BEGIN GENERATED ARTIFACT SPEC"
    end = f"{comment} END GENERATED ARTIFACT SPEC"
    pattern = re.escape(start) + r"\n.*?\n" + re.escape(end)
    replacement = start + "\n" + body + "\n" + end
    result, count = re.subn(pattern, lambda _: replacement, text, flags=re.S)
    if count != 1:
        raise ValueError("expected one artifact projection block")
    return result


def check(root=ROOT, write=False):
    spec = load_spec(root)
    sources = {spec["scad_constants_file"]: spec["scad_constants"], **spec["source_constants"]}
    for filename, constants in sources.items():
        scad = (root / filename).read_text()
        for key, expected in constants.items():
            match = re.search(r"^\s*" + re.escape(key) + r"\s*=\s*([^;]+);", scad, re.M)
            if not match or json.loads(match[1]) != expected:
                raise ValueError(f"SCAD {key} differs from the artifact specification")
    for filename, projection in projections(spec, json.loads((root / "manifest.json").read_text())["version"]).items():
        path = root / filename
        original = path.read_text()
        expected = marked(original, path.suffix, projection)
        if write:
            path.write_text(expected)
        elif original != expected:
            raise ValueError(f"stale artifact projection: {filename}; run artifact_spec.py sync")
    calculator = (root / "calculate_compensation.lua").read_text()
    for a in [by_id(spec)[spec["release_artifacts"]["z"]]]:
        for f in a["measurements"]:
            pattern = (r'name = "' + re.escape(f["id"]) + r'", label = "' +
                       re.escape(f["id"].upper() + " [mm]") + '"')
            if not re.search(pattern, calculator):
                raise ValueError(f"missing calculator feature label: {f['id']}")
    return spec


def verifier_args(spec, artifact):
    args = [artifact["file"], "--expect-bounds", *map(str, artifact["bounds_mm"]),
            "--expect-volume", *map(str, artifact["volume_cm3"]),
            "--min-plane-area", str(artifact["min_plane_area_mm2"])]
    for plane in artifact["planes"]:
        args += ["--require-plane", plane]
    if "components" in artifact:
        args += ["--expect-components", str(len(artifact["components"])), "--expect-gap",
                 f"{artifact['gap']['axis']}={artifact['gap']['mm']}"]
        for index, component in enumerate(artifact["components"], 1):
            definition = by_id(spec)[component["artifact_id"]]
            if definition["revision"] != component["revision"]:
                raise ValueError("layout component revision mismatch")
            args += ["--expect-component-bounds", str(index) + ":" + ":".join(map(str, definition["bounds_mm"])),
                     "--expect-component-volume", str(index) + ":" + ":".join(map(str, definition["volume_cm3"]))]
            args += [arg for plane in definition["planes"] for arg in ("--require-component-plane", f"{index}:{plane}")]
    return args


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("check")
    sub.add_parser("sync")
    for command in ("build", "verify"):
        child = sub.add_parser(command)
        child.add_argument("artifact_id")
        if command == "build":
            child.add_argument("--openscad", default="openscad")
            child.add_argument("--output", required=True)
    args = parser.parse_args()
    try:
        spec = check(write=args.command == "sync")
        if args.command in ("check", "sync"):
            print("Artifact specification and projections agree")
            return
        artifact = by_id(spec)[args.artifact_id]
        if args.command == "verify":
            subprocess.run([sys.executable, str(ROOT / "tools/verify_stl.py"),
                            *verifier_args(spec, artifact)], cwd=ROOT, check=True)
        else:
            if args.output != artifact["file"]:
                raise ValueError("output must match the fixed artifact path")
            output = ROOT / artifact["file"]
            output.parent.mkdir(parents=True, exist_ok=True)
            defines = {"gauge_mode": artifact["mode"], **artifact["scad_overrides"]}
            options = [arg for key, value in defines.items() for arg in ("-D", f"{key}={json.dumps(value)}")]
            subprocess.run([*shlex.split(args.openscad), *options, "--export-format", "binstl",
                            "-o", str(output), str(ROOT / artifact["source"])], check=True)
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as exc:
        parser.exit(1, f"ERROR: {exc}\n")


if __name__ == "__main__":
    main()
