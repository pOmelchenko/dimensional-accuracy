#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Versioned gauge definitions and checked projections for the seven-file plugin."""
from __future__ import annotations

import argparse
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_spec(root=ROOT):
    spec = json.loads((root / "model/artifacts.json").read_text())
    if spec["schema_version"] != "1.0.0":
        raise ValueError("unsupported artifact schema")
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
            if feature["axis"] not in "xyz" or feature["nominal_mm"] <= 0:
                raise ValueError("invalid measurement feature")
            if feature["id"] != f"{feature['axis']}{feature['nominal_mm']}":
                raise ValueError("feature ID and nominal differ")
    return spec


def by_id(spec):
    return {a["artifact_id"]: a for a in spec["artifacts"]}


def projections(spec, plugin_version):
    artifacts = by_id(spec)
    xy, z, xyz = (artifacts[key] for key in ("DA-XY-A", "DA-Z-B", "DA-XYZ-AB"))
    identity = "local GAUGE_ARTIFACTS = {\n" + "\n".join(
        f'    {family} = {{id = "{a["artifact_id"]}", revision = {a["revision"]}}},'
        for family, a in (("xy", xy), ("z", z), ("xyz", xyz))) + "\n}"
    calculator = f'local PLUGIN_VERSION = "{plugin_version}"\n' + "local NOMINAL_LENGTHS = {" + ", ".join(str(v) for v in spec["nominal_lengths_mm"]) + "}\n" + identity
    generator = "\n".join(f'local {key}_MODEL_FILE = "{a["file"]}"' for key, a in (("XY", xy), ("Z", z), ("XYZ", xyz))) + "\n" + identity
    make = []
    names = {"DA-XY-A": "XY", "DA-Z-B": "Z", "DA-XYZ-AB": "XYZ",
             "DA-XY-T": "PROTOTYPE_XY", "DA-Z-C40": "PROTOTYPE_Z"}
    for artifact in spec["artifacts"]:
        aid, filename = artifact["artifact_id"], artifact["file"]
        make.extend([
            f"{filename}: $(MODEL) Makefile model/artifacts.json tools/artifact_spec.py",
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
    scad = (root / "model/dimensional_accuracy_gauge.scad").read_text()
    for key, expected in spec["scad_constants"].items():
        match = re.search(r"^" + re.escape(key) + r"\s*=\s*([^;]+);", scad, re.M)
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
    for a in spec["artifacts"]:
        if a["role"] != "control":
            continue
        for f in a["measurements"]:
            pattern = r'name = "' + re.escape(f["id"]) + r'", label = "Measured ' + re.escape(f["id"].upper())
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
                            "-o", str(output), str(ROOT / "model/dimensional_accuracy_gauge.scad")], check=True)
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as exc:
        parser.exit(1, f"ERROR: {exc}\n")


if __name__ == "__main__":
    main()
