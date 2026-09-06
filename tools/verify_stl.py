#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 pOmelchenko
"""Check the geometric invariants of generated binary STL gauges."""

from __future__ import annotations

import argparse
import math
import struct
import sys
from collections import Counter, defaultdict
from itertools import product
from pathlib import Path


NEIGHBOR_OFFSETS = tuple(product((-1, 0, 1), repeat=3))


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


def weld_triangle_vertices(triangles, tolerance):
    """Assign one stable ID to vertices connected within Euclidean tolerance."""
    if not math.isfinite(tolerance) or tolerance <= 0:
        raise ValueError("tolerance must be a finite number greater than zero")

    unique_vertices = []
    vertex_indices = {}
    triangle_unique_indices = []
    for triangle_index, triangle in enumerate(triangles):
        if len(triangle) != 3:
            raise ValueError(f"triangle {triangle_index} does not have three vertices")
        indices = []
        for vertex_index, raw_vertex in enumerate(triangle):
            if len(raw_vertex) != 3:
                raise ValueError(
                    f"triangle {triangle_index} vertex {vertex_index} "
                    "does not have three coordinates"
                )
            vertex = tuple(raw_vertex)
            if not all(math.isfinite(value) for value in vertex):
                raise ValueError(
                    f"triangle {triangle_index} vertex {vertex_index} "
                    "contains a non-finite coordinate"
                )
            unique_index = vertex_indices.get(vertex)
            if unique_index is None:
                unique_index = len(unique_vertices)
                vertex_indices[vertex] = unique_index
                unique_vertices.append(vertex)
            indices.append(unique_index)
        triangle_unique_indices.append(tuple(indices))

    vertex_sets = DisjointSet(len(unique_vertices))
    spatial_bins = defaultdict(list)
    tolerance_squared = tolerance * tolerance
    comparison_slack = tolerance_squared * 1e-12
    for vertex_index, vertex in enumerate(unique_vertices):
        cell = tuple(math.floor(value / tolerance) for value in vertex)
        for offset in NEIGHBOR_OFFSETS:
            neighbour = tuple(cell[axis] + offset[axis] for axis in range(3))
            for candidate_index in spatial_bins.get(neighbour, ()):
                candidate = unique_vertices[candidate_index]
                distance_squared = sum(
                    (vertex[axis] - candidate[axis]) ** 2 for axis in range(3)
                )
                if distance_squared <= tolerance_squared + comparison_slack:
                    vertex_sets.union(vertex_index, candidate_index)
        spatial_bins[cell].append(vertex_index)

    groups = defaultdict(list)
    for vertex_index, vertex in enumerate(unique_vertices):
        groups[vertex_sets.find(vertex_index)].append(vertex)
    ordered_groups = sorted(
        (min(vertices), root) for root, vertices in groups.items()
    )
    root_ids = {root: group_id for group_id, (_vertex, root) in enumerate(ordered_groups)}
    unique_ids = [root_ids[vertex_sets.find(index)] for index in range(len(unique_vertices))]
    triangle_vertex_ids = [
        tuple(unique_ids[index] for index in triangle)
        for triangle in triangle_unique_indices
    ]
    representatives = [vertex for vertex, _root in ordered_groups]
    return triangle_vertex_ids, representatives


def triangle_unit_normal(triangle):
    a, b, c = triangle
    ab = tuple(b[axis] - a[axis] for axis in range(3))
    ac = tuple(c[axis] - a[axis] for axis in range(3))
    cross = (
        ab[1] * ac[2] - ab[2] * ac[1],
        ab[2] * ac[0] - ab[0] * ac[2],
        ab[0] * ac[1] - ab[1] * ac[0],
    )
    length = math.sqrt(sum(value * value for value in cross))
    if length == 0:
        raise ValueError("cannot canonicalize a degenerate triangle")
    return tuple(value / length for value in cross)


def triangles_are_coplanar(left, right, left_normal, right_normal, tolerance):
    if sum(
        left_normal[axis] * right_normal[axis] for axis in range(3)
    ) <= 0:
        return False

    def distance_from_plane(vertex, origin, normal):
        return abs(
            sum(
                (vertex[axis] - origin[axis]) * normal[axis]
                for axis in range(3)
            )
        )

    return all(
        distance_from_plane(vertex, left[0], left_normal) <= tolerance
        for vertex in right
    ) and all(
        distance_from_plane(vertex, right[0], right_normal) <= tolerance
        for vertex in left
    )


def simplify_boundary_loop(vertex_ids, representatives, tolerance):
    """Remove collinear boundary subdivisions without reversing the loop."""
    simplified = list(vertex_ids)
    changed = True
    while changed and len(simplified) > 3:
        changed = False
        for index, current_id in enumerate(simplified):
            previous_id = simplified[index - 1]
            next_id = simplified[(index + 1) % len(simplified)]
            previous = representatives[previous_id]
            current = representatives[current_id]
            following = representatives[next_id]
            incoming = tuple(
                current[axis] - previous[axis] for axis in range(3)
            )
            outgoing = tuple(
                following[axis] - current[axis] for axis in range(3)
            )
            if sum(
                incoming[axis] * outgoing[axis] for axis in range(3)
            ) <= 0:
                continue
            span = tuple(following[axis] - previous[axis] for axis in range(3))
            span_length = math.sqrt(sum(value * value for value in span))
            if span_length == 0:
                continue
            cross = (
                incoming[1] * span[2] - incoming[2] * span[1],
                incoming[2] * span[0] - incoming[0] * span[2],
                incoming[0] * span[1] - incoming[1] * span[0],
            )
            distance = math.sqrt(sum(value * value for value in cross)) / span_length
            if distance <= tolerance:
                del simplified[index]
                changed = True
                break

    rotations = [
        tuple(simplified[index:] + simplified[:index])
        for index in range(len(simplified))
    ]
    return min(rotations)


def directed_boundary_loops(edges, representatives, tolerance):
    remaining = Counter(edges)
    outgoing = defaultdict(Counter)
    for start, end in edges:
        outgoing[start][end] += 1

    def remove_edge(start, end):
        remaining[(start, end)] -= 1
        outgoing[start][end] -= 1

    loops = []
    edges_left = len(edges)
    while edges_left:
        start, following = min(
            edge for edge, count in remaining.items() if count > 0
        )
        loop = [start]
        current = start
        while True:
            remove_edge(current, following)
            edges_left -= 1
            loop.append(following)
            if following == start:
                break
            current = following
            candidates = sorted(
                end for end, count in outgoing[current].items() if count > 0
            )
            if len(candidates) != 1:
                raise ValueError(
                    "coplanar patch boundary is not a set of directed loops"
                )
            following = candidates[0]
            if len(loop) > len(edges) + 1:
                raise ValueError("coplanar patch boundary loop does not close")
        if len(loop) < 4:
            raise ValueError("coplanar patch boundary has fewer than three edges")
        loops.append(
            simplify_boundary_loop(loop[:-1], representatives, tolerance)
        )
    return tuple(sorted(loops))


def canonical_surface_patches(triangles, triangle_vertex_ids, representatives, tolerance):
    """Canonicalize oriented coplanar patches by their boundary loops."""
    normals = [triangle_unit_normal(triangle) for triangle in triangles]
    edge_owners = defaultdict(list)
    for triangle_index, vertex_ids in enumerate(triangle_vertex_ids):
        for start, end in ((0, 1), (1, 2), (2, 0)):
            edge = tuple(sorted((vertex_ids[start], vertex_ids[end])))
            edge_owners[edge].append(triangle_index)

    patch_sets = DisjointSet(len(triangles))
    for owners in edge_owners.values():
        if len(owners) != 2:
            continue
        left_index, right_index = owners
        if triangles_are_coplanar(
            triangles[left_index],
            triangles[right_index],
            normals[left_index],
            normals[right_index],
            tolerance,
        ):
            patch_sets.union(left_index, right_index)

    patch_triangles = defaultdict(list)
    for triangle_index in range(len(triangles)):
        patch_triangles[patch_sets.find(triangle_index)].append(triangle_index)

    patches = Counter()
    for triangle_indices in patch_triangles.values():
        directed_edges = Counter()
        for triangle_index in triangle_indices:
            vertex_ids = triangle_vertex_ids[triangle_index]
            for start, end in ((0, 1), (1, 2), (2, 0)):
                directed_edges[(vertex_ids[start], vertex_ids[end])] += 1

        boundary_edges = []
        visited = set()
        for (start, end), count in directed_edges.items():
            edge = tuple(sorted((start, end)))
            if edge in visited:
                continue
            visited.add(edge)
            reverse_count = directed_edges.get((end, start), 0)
            difference = count - reverse_count
            if difference > 0:
                boundary_edges.extend([(start, end)] * difference)
            elif difference < 0:
                boundary_edges.extend([(end, start)] * -difference)

        if not boundary_edges:
            raise ValueError("coplanar patch has no boundary")
        loops = directed_boundary_loops(
            boundary_edges, representatives, tolerance
        )
        patches[loops] += 1
    return patches


def compare_mesh_geometry(reference, candidate, tolerance):
    """Compare oriented surfaces independent of coplanar retriangulation."""
    combined = list(reference) + list(candidate)
    combined_ids, representatives = weld_triangle_vertices(combined, tolerance)
    reference_ids = combined_ids[: len(reference)]
    candidate_ids = combined_ids[len(reference) :]
    reference_patches = canonical_surface_patches(
        reference, reference_ids, representatives, tolerance
    )
    candidate_patches = canonical_surface_patches(
        candidate, candidate_ids, representatives, tolerance
    )
    missing = sum((reference_patches - candidate_patches).values())
    unexpected = sum((candidate_patches - reference_patches).values())
    return missing == 0 and unexpected == 0, missing, unexpected


def mesh_stats(triangles, tolerance):
    if not triangles:
        raise ValueError("mesh contains no triangles")

    triangle_vertex_ids, welded_vertices = weld_triangle_vertices(
        triangles, tolerance
    )
    vertices = [vertex for triangle in triangles for vertex in triangle]
    minimum = tuple(min(vertex[index] for vertex in vertices) for index in range(3))
    maximum = tuple(max(vertex[index] for vertex in vertices) for index in range(3))
    bounds = tuple(maximum[index] - minimum[index] for index in range(3))

    degenerate_triangles = sum(
        1
        for triangle, vertex_ids in zip(triangles, triangle_vertex_ids)
        if len(set(vertex_ids)) != 3
        or triangle_area(triangle) <= tolerance * tolerance
    )

    edge_owners = {}
    for triangle_index, vertex_ids in enumerate(triangle_vertex_ids):
        for start, end in ((0, 1), (1, 2), (2, 0)):
            start_id = vertex_ids[start]
            end_id = vertex_ids[end]
            edge = tuple(sorted((start_id, end_id)))
            direction = 1 if (start_id, end_id) == edge else -1
            edge_owners.setdefault(edge, []).append((triangle_index, direction))

    triangle_sets = DisjointSet(len(triangles))
    for owners in edge_owners.values():
        for owner, _direction in owners[1:]:
            triangle_sets.union(owners[0][0], owner)

    incidences = Counter(len(owners) for owners in edge_owners.values())
    bad_edges = sum(count for incidence, count in incidences.items() if incidence != 2)
    orientation_errors = sum(
        1
        for owners in edge_owners.values()
        if len(owners) == 2 and owners[0][1] == owners[1][1]
    )

    component_triangles = defaultdict(list)
    for triangle_index in range(len(triangles)):
        component_triangles[triangle_sets.find(triangle_index)].append(triangle_index)

    component_data = []
    for triangle_indices in component_triangles.values():
        members = [
            vertex
            for triangle_index in triangle_indices
            for vertex in triangles[triangle_index]
        ]
        signed_volume = sum(
            signed_tetrahedron_volume(triangles[index])
            for index in triangle_indices
        )
        component_data.append(
            {
                "minimum": tuple(
                    min(vertex[index] for vertex in members) for index in range(3)
                ),
                "maximum": tuple(
                    max(vertex[index] for vertex in members) for index in range(3)
                ),
                "triangle_indices": triangle_indices,
                "signed_volume_mm3": signed_volume,
                "volume_cm3": signed_volume / 1000,
            }
        )
    component_data.sort(
        key=lambda component: (component["minimum"], component["maximum"])
    )

    return {
        "minimum": minimum,
        "maximum": maximum,
        "bounds": bounds,
        "components": len(component_data),
        "bad_edges": bad_edges,
        "orientation_errors": orientation_errors,
        "degenerate_triangles": degenerate_triangles,
        "edge_incidences": incidences,
        "component_data": component_data,
        "welded_vertices": len(welded_vertices),
        "volume_cm3": sum(
            component["volume_cm3"] for component in component_data
        ),
    }


def plane_area_for_component(
    triangles, component, axis, coordinate, tolerance
):
    return sum(
        triangle_area(triangles[index])
        for index in component["triangle_indices"]
        if all(
            abs(vertex[axis] - coordinate) <= tolerance
            for vertex in triangles[index]
        )
    )


def plane_areas_by_component(
    triangles, component_data, axis, coordinate, tolerance
):
    return [
        plane_area_for_component(
            triangles, component, axis, coordinate, tolerance
        )
        for component in component_data
    ]


def finite_float(value):
    try:
        parsed = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError(f"'{value}' is not a number") from error
    if not math.isfinite(parsed):
        raise argparse.ArgumentTypeError(f"'{value}' is not finite")
    return parsed


def positive_component(value):
    try:
        component = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("component must be a positive integer") from error
    if component < 1:
        raise argparse.ArgumentTypeError("component must be a positive integer")
    return component - 1


def parse_plane(value):
    try:
        axis_name, coordinate_text = value.split("=", 1)
        axis_name = axis_name.lower()
        axis = {"x": 0, "y": 1, "z": 2}[axis_name]
    except (KeyError, ValueError) as error:
        raise argparse.ArgumentTypeError(
            "plane must have the form x=12.3, y=-4, or z=40"
        ) from error
    coordinate = finite_float(coordinate_text)
    return axis_name, axis, coordinate


def parse_component_plane(value):
    try:
        component_text, plane_text = value.split(":", 1)
    except ValueError as error:
        raise argparse.ArgumentTypeError(
            "component plane must have the form 1:x=12.3"
        ) from error
    return positive_component(component_text), *parse_plane(plane_text)


def parse_component_bounds(value):
    parts = value.split(":")
    if len(parts) != 4:
        raise argparse.ArgumentTypeError(
            "component bounds must have the form 1:120:120:4.5"
        )
    return positive_component(parts[0]), tuple(finite_float(part) for part in parts[1:])


def parse_component_volume(value):
    parts = value.split(":")
    if len(parts) != 3:
        raise argparse.ArgumentTypeError(
            "component volume must have the form 1:10:14"
        )
    return positive_component(parts[0]), finite_float(parts[1]), finite_float(parts[2])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stl", type=Path)
    parser.add_argument(
        "--expect-bounds", nargs=3, type=finite_float, metavar=("X", "Y", "Z")
    )
    parser.add_argument(
        "--expect-volume", nargs=2, type=finite_float, metavar=("MIN", "MAX")
    )
    parser.add_argument("--expect-components", type=int, default=1)
    parser.add_argument("--expect-gap", type=parse_plane)
    parser.add_argument("--require-plane", action="append", type=parse_plane, default=[])
    parser.add_argument(
        "--require-component-plane",
        action="append",
        type=parse_component_plane,
        default=[],
        metavar="COMPONENT:AXIS=COORDINATE",
    )
    parser.add_argument(
        "--expect-component-bounds",
        action="append",
        type=parse_component_bounds,
        default=[],
        metavar="COMPONENT:X:Y:Z",
    )
    parser.add_argument(
        "--expect-component-volume",
        action="append",
        type=parse_component_volume,
        default=[],
        metavar="COMPONENT:MIN:MAX",
    )
    parser.add_argument("--compare-geometry", type=Path, metavar="REFERENCE_STL")
    parser.add_argument("--min-plane-area", type=finite_float, default=0.1)
    parser.add_argument("--tolerance", type=finite_float, default=0.001)
    args = parser.parse_args(argv)

    if args.tolerance <= 0:
        parser.error("--tolerance must be greater than zero")
    if args.min_plane_area < 0:
        parser.error("--min-plane-area must not be negative")
    if args.expect_components < 1:
        parser.error("--expect-components must be at least one")
    if args.expect_bounds and any(value < 0 for value in args.expect_bounds):
        parser.error("--expect-bounds values must not be negative")
    if args.expect_volume and (
        args.expect_volume[0] < 0
        or args.expect_volume[0] > args.expect_volume[1]
    ):
        parser.error("--expect-volume requires 0 <= MIN <= MAX")
    if args.expect_gap and args.expect_gap[2] < 0:
        parser.error("--expect-gap must not be negative")
    for _component, bounds in args.expect_component_bounds:
        if any(value < 0 for value in bounds):
            parser.error("--expect-component-bounds values must not be negative")
    for _component, minimum_volume, maximum_volume in args.expect_component_volume:
        if minimum_volume < 0 or minimum_volume > maximum_volume:
            parser.error("--expect-component-volume requires 0 <= MIN <= MAX")

    try:
        triangles = read_binary_stl(args.stl)
        stats = mesh_stats(triangles, args.tolerance)
    except (OSError, OverflowError, ValueError) as error:
        print(f"ERROR: cannot read {args.stl}: {error}", file=sys.stderr)
        return 1
    failures = []

    if stats["components"] != args.expect_components:
        failures.append(
            f"mesh has {stats['components']} connected surface components, "
            f"expected {args.expect_components}"
        )
    if stats["degenerate_triangles"]:
        failures.append(
            f"mesh has {stats['degenerate_triangles']} degenerate triangles"
        )
    if stats["bad_edges"]:
        failures.append(
            f"mesh has {stats['bad_edges']} non-manifold/open edges "
            f"({dict(stats['edge_incidences'])})"
        )
    if stats["orientation_errors"]:
        failures.append(
            f"mesh has {stats['orientation_errors']} shared edges whose two "
            "triangles traverse the edge in the same direction"
        )

    volume_epsilon = args.tolerance ** 3
    for component_index, component in enumerate(stats["component_data"], start=1):
        signed_volume = component["signed_volume_mm3"]
        if signed_volume < -volume_epsilon:
            failures.append(
                f"component {component_index} has inward winding "
                f"(signed volume {signed_volume / 1000:.6f} cm^3)"
            )
        elif signed_volume <= volume_epsilon:
            failures.append(
                f"component {component_index} has zero or negligible signed volume"
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
        if len(stats["component_data"]) != 2:
            failures.append("component gap can be checked only for two components")
        else:
            intervals = sorted(
                (component["minimum"][axis], component["maximum"][axis])
                for component in stats["component_data"]
            )
            measured_gap = intervals[1][0] - intervals[0][1]
            if abs(measured_gap - expected_gap) > args.tolerance:
                failures.append(
                    f"{axis_name.upper()} component gap is {measured_gap:.6f} mm, "
                    f"expected {expected_gap:.6f} mm"
                )

    for component_index, expected_bounds in args.expect_component_bounds:
        if component_index >= len(stats["component_data"]):
            failures.append(
                f"component {component_index + 1} bounds requested, but the mesh "
                f"has only {len(stats['component_data'])} components"
            )
            continue
        component = stats["component_data"][component_index]
        actual_bounds = tuple(
            component["maximum"][axis] - component["minimum"][axis]
            for axis in range(3)
        )
        for axis_name, actual, expected in zip("XYZ", actual_bounds, expected_bounds):
            if abs(actual - expected) > args.tolerance:
                failures.append(
                    f"component {component_index + 1} {axis_name} bound is "
                    f"{actual:.6f} mm, expected {expected:.6f} mm"
                )

    for component_index, minimum_volume, maximum_volume in args.expect_component_volume:
        if component_index >= len(stats["component_data"]):
            failures.append(
                f"component {component_index + 1} volume requested, but the mesh "
                f"has only {len(stats['component_data'])} components"
            )
            continue
        volume = stats["component_data"][component_index]["volume_cm3"]
        if not minimum_volume <= volume <= maximum_volume:
            failures.append(
                f"component {component_index + 1} volume is {volume:.3f} cm^3, "
                f"expected {minimum_volume:g}-{maximum_volume:g} cm^3"
            )

    plane_areas = []
    for axis_name, axis, coordinate in args.require_plane:
        component_areas = plane_areas_by_component(
            triangles,
            stats["component_data"],
            axis,
            coordinate,
            args.tolerance,
        )
        area = max(component_areas, default=0.0)
        component_index = component_areas.index(area) if component_areas else None
        display_component = component_index + 1 if component_index is not None else None
        plane_areas.append((axis_name, coordinate, area, display_component))
        if area < args.min_plane_area:
            failures.append(
                f"working plane {axis_name}={coordinate:g} has only "
                f"{area:.6f} mm^2 of flat triangles in its largest component"
            )

    for component_index, axis_name, axis, coordinate in args.require_component_plane:
        if component_index >= len(stats["component_data"]):
            failures.append(
                f"component {component_index + 1} plane {axis_name}={coordinate:g} "
                f"requested, but the mesh has only {len(stats['component_data'])} components"
            )
            continue
        area = plane_area_for_component(
            triangles,
            stats["component_data"][component_index],
            axis,
            coordinate,
            args.tolerance,
        )
        plane_areas.append((axis_name, coordinate, area, component_index + 1))
        if area < args.min_plane_area:
            failures.append(
                f"component {component_index + 1} working plane "
                f"{axis_name}={coordinate:g} has only {area:.6f} mm^2 "
                "of flat triangles"
            )

    geometry_comparison = None
    if args.compare_geometry:
        try:
            reference = read_binary_stl(args.compare_geometry)
            geometry_comparison = compare_mesh_geometry(
                reference, triangles, args.tolerance
            )
        except (OSError, OverflowError, ValueError) as error:
            failures.append(
                f"cannot compare geometry with {args.compare_geometry}: {error}"
            )
        else:
            matches, missing, unexpected = geometry_comparison
            if not matches:
                failures.append(
                    f"geometry differs from {args.compare_geometry}: "
                    f"{missing} reference surface patches missing and "
                    f"{unexpected} unexpected surface patches"
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
        f"non-manifold/open edges: {stats['bad_edges']}; "
        f"orientation errors: {stats['orientation_errors']}; "
        f"degenerate triangles: {stats['degenerate_triangles']}"
    )
    for component_index, component in enumerate(stats["component_data"], start=1):
        component_bounds = tuple(
            component["maximum"][axis] - component["minimum"][axis]
            for axis in range(3)
        )
        print(
            f"  component {component_index}: bounds "
            + " x ".join(f"{value:.6f}" for value in component_bounds)
            + f" mm; signed volume {component['volume_cm3']:.3f} cm^3"
        )
    for axis_name, coordinate, area, component_index in plane_areas:
        print(
            f"  plane {axis_name}={coordinate:g}: {area:.3f} mm^2 "
            f"on component {component_index}"
        )
    if geometry_comparison and geometry_comparison[0]:
        print(f"  geometry matches reference: {args.compare_geometry}")

    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
