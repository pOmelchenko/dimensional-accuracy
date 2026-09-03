#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 pOmelchenko
"""Check the geometric invariants of generated binary STL gauges."""

from __future__ import annotations

import argparse
import math
import struct
import sys
from collections import Counter
from pathlib import Path


def read_binary_stl(path: Path):
    data = path.read_bytes()
    if len(data) < 84:
        raise ValueError("file is too short to be a binary STL")

    triangle_count = struct.unpack_from("<I", data, 80)[0]
    expected_size = 84 + 50 * triangle_count
    if len(data) != expected_size:
        raise ValueError(
            f"expected {expected_size} bytes for {triangle_count} triangles, "
            f"found {len(data)}"
        )

    triangles = []
    offset = 84
    for _ in range(triangle_count):
        values = struct.unpack_from("<12fH", data, offset)
        triangles.append((values[3:6], values[6:9], values[9:12]))
        offset += 50
    return triangles


def quantize(vertex, tolerance):
    return tuple(round(value / tolerance) for value in vertex)


class DisjointSet:
    def __init__(self, size):
        self.parent = list(range(size))

    def find(self, value):
        while self.parent[value] != value:
            self.parent[value] = self.parent[self.parent[value]]
            value = self.parent[value]
        return value

    def union(self, left, right):
        left_root = self.find(left)
        right_root = self.find(right)
        if left_root != right_root:
            self.parent[right_root] = left_root


def triangle_area(triangle):
    a, b, c = triangle
    ab = tuple(b[index] - a[index] for index in range(3))
    ac = tuple(c[index] - a[index] for index in range(3))
    cross = (
        ab[1] * ac[2] - ab[2] * ac[1],
        ab[2] * ac[0] - ab[0] * ac[2],
        ab[0] * ac[1] - ab[1] * ac[0],
    )
    return math.sqrt(sum(value * value for value in cross)) / 2


def signed_tetrahedron_volume(triangle):
    a, b, c = triangle
    return (
        a[0] * (b[1] * c[2] - b[2] * c[1])
        - a[1] * (b[0] * c[2] - b[2] * c[0])
        + a[2] * (b[0] * c[1] - b[1] * c[0])
    ) / 6


def mesh_stats(triangles, tolerance):
    vertices = [vertex for triangle in triangles for vertex in triangle]
    minimum = tuple(min(vertex[index] for vertex in vertices) for index in range(3))
    maximum = tuple(max(vertex[index] for vertex in vertices) for index in range(3))
    bounds = tuple(maximum[index] - minimum[index] for index in range(3))

    edge_owners = {}
    for triangle_index, triangle in enumerate(triangles):
        keys = [quantize(vertex, tolerance) for vertex in triangle]
        for start, end in ((0, 1), (1, 2), (2, 0)):
            edge = tuple(sorted((keys[start], keys[end])))
            edge_owners.setdefault(edge, []).append(triangle_index)

    sets = DisjointSet(len(triangles))
    for owners in edge_owners.values():
        for owner in owners[1:]:
            sets.union(owners[0], owner)

    components = len({sets.find(index) for index in range(len(triangles))})
    incidences = Counter(len(owners) for owners in edge_owners.values())
    bad_edges = sum(count for incidence, count in incidences.items() if incidence != 2)

    component_vertices = {}
    for triangle_index, triangle in enumerate(triangles):
        root = sets.find(triangle_index)
        component_vertices.setdefault(root, []).extend(triangle)
    component_bounds = []
    for members in component_vertices.values():
        component_bounds.append((
            tuple(min(vertex[index] for vertex in members) for index in range(3)),
            tuple(max(vertex[index] for vertex in members) for index in range(3)),
        ))

    return {
        "minimum": minimum,
        "maximum": maximum,
        "bounds": bounds,
        "components": components,
        "bad_edges": bad_edges,
        "edge_incidences": incidences,
        "component_bounds": component_bounds,
        "volume_cm3": abs(
            sum(signed_tetrahedron_volume(triangle) for triangle in triangles)
        ) / 1000,
    }


def parse_plane(value):
    try:
        axis_name, coordinate = value.split("=", 1)
        axis = {"x": 0, "y": 1, "z": 2}[axis_name.lower()]
        return axis_name.lower(), axis, float(coordinate)
    except (KeyError, ValueError) as error:
        raise argparse.ArgumentTypeError(
            "plane must have the form x=12.3, y=-4, or z=40"
        ) from error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stl", type=Path)
    parser.add_argument(
        "--expect-bounds", nargs=3, type=float, metavar=("X", "Y", "Z")
    )
    parser.add_argument("--expect-volume", nargs=2, type=float, metavar=("MIN", "MAX"))
    parser.add_argument("--expect-components", type=int, default=1)
    parser.add_argument("--expect-gap", type=parse_plane)
    parser.add_argument("--require-plane", action="append", type=parse_plane, default=[])
    parser.add_argument("--min-plane-area", type=float, default=0.1)
    parser.add_argument("--tolerance", type=float, default=0.001)
    args = parser.parse_args()

    triangles = read_binary_stl(args.stl)
    stats = mesh_stats(triangles, args.tolerance)
    failures = []

    if stats["components"] != args.expect_components:
        failures.append(
            f"mesh has {stats['components']} connected surface components, "
            f"expected {args.expect_components}"
        )
    if stats["bad_edges"]:
        failures.append(
            f"mesh has {stats['bad_edges']} non-manifold/open edges "
            f"({dict(stats['edge_incidences'])})"
        )

    if args.expect_bounds:
        for axis_name, actual, expected in zip("XYZ", stats["bounds"], args.expect_bounds):
            if abs(actual - expected) > args.tolerance:
                failures.append(
                    f"{axis_name} bound is {actual:.6f} mm, expected {expected:.6f} mm"
                )

    if args.expect_volume:
        minimum_volume, maximum_volume = args.expect_volume
        if not minimum_volume <= stats["volume_cm3"] <= maximum_volume:
            failures.append(
                f"volume is {stats['volume_cm3']:.3f} cm^3, expected "
                f"{minimum_volume:g}-{maximum_volume:g} cm^3"
            )

    measured_gap = None
    if args.expect_gap:
        axis_name, axis, expected_gap = args.expect_gap
        if len(stats["component_bounds"]) != 2:
            failures.append("component gap can be checked only for two components")
        else:
            intervals = sorted(
                (minimum[axis], maximum[axis])
                for minimum, maximum in stats["component_bounds"]
            )
            measured_gap = intervals[1][0] - intervals[0][1]
            if abs(measured_gap - expected_gap) > args.tolerance:
                failures.append(
                    f"{axis_name.upper()} component gap is {measured_gap:.6f} mm, "
                    f"expected {expected_gap:.6f} mm"
                )

    plane_areas = []
    for axis_name, axis, coordinate in args.require_plane:
        area = sum(
            triangle_area(triangle)
            for triangle in triangles
            if all(
                abs(vertex[axis] - coordinate) <= args.tolerance
                for vertex in triangle
            )
        )
        plane_areas.append((axis_name, coordinate, area))
        if area < args.min_plane_area:
            failures.append(
                f"working plane {axis_name}={coordinate:g} has only "
                f"{area:.6f} mm^2 of flat triangles"
            )

    print(f"{args.stl}: {len(triangles)} triangles")
    print(
        "  bounds: "
        + " x ".join(f"{value:.6f}" for value in stats["bounds"])
        + " mm"
    )
    print(f"  geometric volume: {stats['volume_cm3']:.3f} cm^3")
    if args.expect_gap and measured_gap is not None:
        print(f"  {args.expect_gap[0].upper()} component gap: {measured_gap:.6f} mm")
    print(
        f"  components: {stats['components']}; "
        f"non-manifold/open edges: {stats['bad_edges']}"
    )
    for axis_name, coordinate, area in plane_areas:
        print(f"  plane {axis_name}={coordinate:g}: {area:.3f} mm^2")

    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
