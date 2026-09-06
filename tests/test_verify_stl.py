#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 pOmelchenko
"""Regression tests for the STL invariant checker."""

from __future__ import annotations

import argparse
import contextlib
import importlib.util
import io
import math
import struct
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "verify_stl", ROOT / "tools" / "verify_stl.py"
)
VERIFY_STL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFY_STL)


def tetrahedron(offset_x=0.0):
    a = (offset_x + 0.0, 0.0, 0.0)
    b = (offset_x + 1.0, 0.0, 0.0)
    c = (offset_x + 0.0, 1.0, 0.0)
    d = (offset_x + 0.0, 0.0, 1.0)
    return [
        (a, c, b),
        (a, b, d),
        (a, d, c),
        (b, c, d),
    ]


def triangulated_cube(alternate_top=False, top_height=1.0):
    vertices = [
        (0.0, 0.0, 0.0),
        (1.0, 0.0, 0.0),
        (1.0, 1.0, 0.0),
        (0.0, 1.0, 0.0),
        (0.0, 0.0, top_height),
        (1.0, 0.0, top_height),
        (1.0, 1.0, top_height),
        (0.0, 1.0, top_height),
    ]
    quads = [
        (0, 3, 2, 1),
        (4, 5, 6, 7),
        (0, 1, 5, 4),
        (1, 2, 6, 5),
        (2, 3, 7, 6),
        (3, 0, 4, 7),
    ]

    def split(quad, alternate=False):
        a, b, c, d = (vertices[index] for index in quad)
        if alternate:
            return [(a, b, d), (b, c, d)]
        return [(a, b, c), (a, c, d)]

    triangles = []
    for index, quad in enumerate(quads):
        triangles.extend(split(quad, alternate_top and index == 1))
    return triangles


def write_binary_stl(path, triangles):
    data = bytearray(80)
    data.extend(struct.pack("<I", len(triangles)))
    for triangle in triangles:
        values = (0.0, 0.0, 0.0) + tuple(
            coordinate for vertex in triangle for coordinate in vertex
        )
        data.extend(struct.pack("<12fH", *values, 0))
    path.write_bytes(data)


def run_verifier(triangles, *arguments):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "fixture.stl"
        write_binary_stl(path, triangles)
        stdout = io.StringIO()
        stderr = io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            result = VERIFY_STL.main([str(path), *arguments])
        return result, stdout.getvalue(), stderr.getvalue()


def run_verifier_against_reference(candidate, reference, *arguments):
    with tempfile.TemporaryDirectory() as directory:
        candidate_path = Path(directory) / "candidate.stl"
        reference_path = Path(directory) / "reference.stl"
        write_binary_stl(candidate_path, candidate)
        write_binary_stl(reference_path, reference)
        stdout = io.StringIO()
        stderr = io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            result = VERIFY_STL.main(
                [
                    str(candidate_path),
                    "--compare-geometry",
                    str(reference_path),
                    *arguments,
                ]
            )
        return result, stdout.getvalue(), stderr.getvalue()


class VerifyStlTests(unittest.TestCase):
    def test_closed_consistently_oriented_tetrahedron_passes(self):
        result, stdout, stderr = run_verifier(tetrahedron())

        self.assertEqual(result, 0, stderr)
        self.assertIn("orientation errors: 0", stdout)

    def test_reversed_face_is_rejected_even_when_every_edge_has_two_owners(self):
        triangles = tetrahedron()
        first = triangles[0]
        triangles[0] = (first[1], first[0], first[2])

        stats = VERIFY_STL.mesh_stats(triangles, tolerance=0.001)
        self.assertEqual(stats["bad_edges"], 0)
        self.assertGreater(stats["orientation_errors"], 0)

        result, _stdout, stderr = run_verifier(triangles)
        self.assertEqual(result, 1)
        self.assertIn("traverse the edge in the same direction", stderr)

    def test_fully_inverted_component_is_rejected(self):
        triangles = [
            (triangle[0], triangle[2], triangle[1])
            for triangle in tetrahedron()
        ]

        stats = VERIFY_STL.mesh_stats(triangles, tolerance=0.001)
        self.assertEqual(stats["bad_edges"], 0)
        self.assertEqual(stats["orientation_errors"], 0)
        self.assertLess(stats["component_data"][0]["signed_volume_mm3"], 0)

        result, _stdout, stderr = run_verifier(triangles)
        self.assertEqual(result, 1)
        self.assertIn("inward winding", stderr)

    def test_zero_volume_shell_is_rejected(self):
        a = (0.0, 0.0, 0.0)
        b = (1.0, 0.0, 0.0)
        c = (0.0, 1.0, 0.0)
        d = (1.0, 1.0, 0.0)
        triangles = [(a, c, b), (a, b, d), (a, d, c), (b, c, d)]

        result, _stdout, stderr = run_verifier(triangles)

        self.assertEqual(result, 1)
        self.assertIn("zero or negligible signed volume", stderr)

    def test_degenerate_triangle_is_rejected(self):
        triangles = tetrahedron()
        triangles[0] = (
            triangles[0][0],
            triangles[0][1],
            triangles[0][0],
        )

        result, _stdout, stderr = run_verifier(triangles)

        self.assertEqual(result, 1)
        self.assertIn("degenerate triangles", stderr)

    def test_open_and_nonmanifold_meshes_are_rejected(self):
        open_result, _stdout, open_stderr = run_verifier(tetrahedron()[:-1])
        nonmanifold = tetrahedron() + [tetrahedron()[0]]
        nonmanifold_result, _stdout, nonmanifold_stderr = run_verifier(nonmanifold)

        self.assertEqual(open_result, 1)
        self.assertIn("non-manifold/open edges", open_stderr)
        self.assertEqual(nonmanifold_result, 1)
        self.assertIn("non-manifold/open edges", nonmanifold_stderr)

    def test_vertex_welding_honours_distance_across_spatial_cell_boundaries(self):
        triangles = tetrahedron()
        near_left = (0.00049, 0.0, 0.0)
        near_right = (0.00051, 0.0, 0.0)
        triangles[0] = (near_left, triangles[0][1], triangles[0][2])
        triangles[1] = (near_right, triangles[1][1], triangles[1][2])
        triangles[2] = (near_right, triangles[2][1], triangles[2][2])

        result, stdout, stderr = run_verifier(
            triangles, "--tolerance", "0.001"
        )

        self.assertEqual(result, 0, stderr)
        self.assertIn("non-manifold/open edges: 0", stdout)

    def test_vertex_welding_does_not_join_vertices_outside_tolerance(self):
        triangles = tetrahedron()
        triangles[0] = ((0.0, 0.0, 0.0), triangles[0][1], triangles[0][2])
        triangles[1] = ((0.002, 0.0, 0.0), triangles[1][1], triangles[1][2])
        triangles[2] = ((0.002, 0.0, 0.0), triangles[2][1], triangles[2][2])

        result, _stdout, stderr = run_verifier(
            triangles, "--tolerance", "0.001"
        )

        self.assertEqual(result, 1)
        self.assertIn("non-manifold/open edges", stderr)

    def test_working_plane_area_cannot_be_aggregated_across_components(self):
        triangles = tetrahedron() + tetrahedron(offset_x=3.0)

        result, _stdout, stderr = run_verifier(
            triangles,
            "--expect-components",
            "2",
            "--require-plane",
            "z=0",
            "--min-plane-area",
            "0.75",
        )

        self.assertEqual(result, 1)
        self.assertIn("0.500000 mm^2", stderr)
        self.assertIn("largest component", stderr)

    def test_working_plane_area_on_one_component_passes(self):
        triangles = tetrahedron() + tetrahedron(offset_x=3.0)

        result, stdout, stderr = run_verifier(
            triangles,
            "--expect-components",
            "2",
            "--require-plane",
            "z=0",
            "--min-plane-area",
            "0.5",
        )

        self.assertEqual(result, 0, stderr)
        self.assertIn("0.500 mm^2 on component 1", stdout)

    def test_component_scoped_plane_cannot_move_to_another_component(self):
        triangles = tetrahedron() + tetrahedron(offset_x=3.0)

        result, _stdout, stderr = run_verifier(
            triangles,
            "--expect-components",
            "2",
            "--require-component-plane",
            "2:x=0",
            "--min-plane-area",
            "0.5",
        )

        self.assertEqual(result, 1)
        self.assertIn("component 2 working plane x=0", stderr)

    def test_component_bounds_volume_and_gap_requirements_pass(self):
        triangles = tetrahedron() + tetrahedron(offset_x=3.0)

        result, stdout, stderr = run_verifier(
            triangles,
            "--expect-components",
            "2",
            "--expect-bounds",
            "4",
            "1",
            "1",
            "--expect-volume",
            "0.0003",
            "0.0004",
            "--expect-gap",
            "x=2",
            "--expect-component-bounds",
            "1:1:1:1",
            "--expect-component-bounds",
            "2:1:1:1",
            "--expect-component-volume",
            "1:0.0001:0.0002",
            "--expect-component-volume",
            "2:0.0001:0.0002",
            "--require-component-plane",
            "1:x=0",
            "--require-component-plane",
            "2:x=3",
            "--min-plane-area",
            "0.5",
        )

        self.assertEqual(result, 0, stderr)
        self.assertIn("X component gap: 2.000000 mm", stdout)

    def test_wrong_bounds_volume_and_gap_are_each_reported(self):
        triangles = tetrahedron() + tetrahedron(offset_x=3.0)

        result, _stdout, stderr = run_verifier(
            triangles,
            "--expect-components",
            "2",
            "--expect-bounds",
            "5",
            "1",
            "1",
            "--expect-volume",
            "1",
            "2",
            "--expect-gap",
            "x=1",
            "--expect-component-bounds",
            "2:2:1:1",
            "--expect-component-volume",
            "1:1:2",
        )

        self.assertEqual(result, 1)
        self.assertIn("X bound is", stderr)
        self.assertIn("volume is", stderr)
        self.assertIn("X component gap is", stderr)
        self.assertIn("component 2 X bound is", stderr)
        self.assertIn("component 1 volume is", stderr)

    def test_geometry_comparison_ignores_order_cyclic_start_and_small_noise(self):
        reference = tetrahedron()
        candidate = []
        for triangle in reversed(reference):
            shifted = tuple(
                (vertex[0] + 0.0002, vertex[1], vertex[2])
                for vertex in triangle
            )
            candidate.append((shifted[1], shifted[2], shifted[0]))

        result, stdout, stderr = run_verifier_against_reference(
            candidate, reference, "--tolerance", "0.001"
        )

        self.assertEqual(result, 0, stderr)
        self.assertIn("geometry matches reference", stdout)

    def test_geometry_comparison_ignores_coplanar_retriangulation(self):
        reference = triangulated_cube()
        candidate = triangulated_cube(alternate_top=True)

        for mesh in (reference, candidate):
            stats = VERIFY_STL.mesh_stats(mesh, tolerance=0.001)
            self.assertEqual(stats["bad_edges"], 0)
            self.assertEqual(stats["orientation_errors"], 0)
            self.assertAlmostEqual(stats["volume_cm3"], 0.001)

        result, stdout, stderr = run_verifier_against_reference(
            candidate, reference
        )

        self.assertEqual(result, 0, stderr)
        self.assertIn("geometry matches reference", stdout)

    def test_geometry_comparison_rejects_real_surface_change(self):
        reference = triangulated_cube()
        candidate = triangulated_cube(top_height=1.01)

        result, _stdout, stderr = run_verifier_against_reference(
            candidate, reference
        )

        self.assertEqual(result, 1)
        self.assertIn("geometry differs", stderr)

    def test_geometry_comparison_rejects_changed_winding(self):
        reference = tetrahedron()
        candidate = list(reference)
        candidate[0] = (
            candidate[0][0],
            candidate[0][2],
            candidate[0][1],
        )

        result, _stdout, stderr = run_verifier_against_reference(
            candidate, reference
        )

        self.assertEqual(result, 1)
        self.assertIn("geometry differs", stderr)

    def test_geometry_comparison_reports_missing_surface_patch(self):
        reference = tetrahedron()

        result, _stdout, stderr = run_verifier_against_reference(
            reference[:-1], reference
        )

        self.assertEqual(result, 1)
        self.assertIn("reference surface patches missing", stderr)
        self.assertIn("unexpected surface patches", stderr)

    def test_nonfinite_coordinate_is_reported_without_a_traceback(self):
        triangles = tetrahedron()
        triangles[0] = ((math.inf, 0.0, 0.0), triangles[0][1], triangles[0][2])

        result, _stdout, stderr = run_verifier(triangles)

        self.assertEqual(result, 1)
        self.assertIn("non-finite coordinate", stderr)

    def test_truncated_binary_stl_is_reported_without_a_traceback(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "truncated.stl"
            path.write_bytes(b"not an STL")
            stderr = io.StringIO()
            with contextlib.redirect_stderr(stderr):
                result = VERIFY_STL.main([str(path)])

        self.assertEqual(result, 1)
        self.assertIn("file is too short", stderr.getvalue())

    def test_empty_binary_stl_is_rejected(self):
        result, _stdout, stderr = run_verifier([])

        self.assertEqual(result, 1)
        self.assertIn("mesh contains no triangles", stderr)

    def test_nonfinite_cli_number_is_rejected(self):
        with self.assertRaisesRegex(
            argparse.ArgumentTypeError, "is not finite"
        ):
            VERIFY_STL.finite_float("nan")


if __name__ == "__main__":
    unittest.main()
