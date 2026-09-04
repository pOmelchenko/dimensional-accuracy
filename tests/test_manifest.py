#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Contract tests for the plugin manifest and its runtime payload."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "manifest.json"

REQUIRED_STRING_FIELDS = (
    "id",
    "name",
    "license",
    "min_slicer_version",
    "version",
    "author",
    "description",
    "category",
    "repo",
    "web",
)

RUNTIME_FILES = (
    "LICENSE",
    "generate_gauge.lua",
    "calculate_compensation.lua",
    "dimensional_accuracy_gauge.stl",
    "dimensional_accuracy_z_gauge.stl",
    "dimensional_accuracy_xyz_gauge.stl",
)

SEMVER = re.compile(
    r"^(0|[1-9]\d*)\."
    r"(0|[1-9]\d*)\."
    r"(0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)


class ManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))

    def test_manifest_is_a_json_object_with_required_string_fields(self):
        self.assertIsInstance(self.manifest, dict)
        for field in REQUIRED_STRING_FIELDS:
            with self.subTest(field=field):
                self.assertIn(field, self.manifest)
                self.assertIsInstance(self.manifest[field], str)
                self.assertTrue(self.manifest[field].strip())

    def test_identity_and_versions_match_the_experimental_contract(self):
        self.assertEqual(
            self.manifest["id"], "dev.omelchenko.dimensional-accuracy"
        )
        self.assertEqual(self.manifest["min_slicer_version"], "3.0.0-alpha11")
        self.assertRegex(self.manifest["version"], SEMVER)
        self.assertIn("experimental", self.manifest["name"].lower())
        self.assertIn("experimental", self.manifest["description"].lower())

    def test_api_requirement_and_license_are_explicit(self):
        required_apis = self.manifest.get("required_apis")
        self.assertIsInstance(required_apis, dict)
        self.assertEqual(required_apis, {"project.plugin": "1.0.0"})
        self.assertEqual(self.manifest["license"], "AGPL-3.0-only")

    def test_repository_links_are_https(self):
        self.assertTrue(self.manifest["repo"].startswith("https://"))
        self.assertTrue(self.manifest["web"].startswith("https://"))

    def test_runtime_payload_sources_exist(self):
        for relative_path in RUNTIME_FILES:
            with self.subTest(path=relative_path):
                path = ROOT / relative_path
                self.assertTrue(path.is_file(), f"missing runtime file: {relative_path}")
                self.assertGreater(path.stat().st_size, 0)

    def test_only_runtime_entrypoints_have_the_plugin_lua_suffix(self):
        # PrusaSlicer recursively executes every *.lua file in a bundle while
        # scanning it. Test harnesses therefore use the .luatest suffix.
        lua_files = {
            path.relative_to(ROOT).as_posix()
            for path in ROOT.rglob("*.lua")
            if "build" not in path.relative_to(ROOT).parts
        }
        self.assertEqual(
            lua_files,
            {"calculate_compensation.lua", "generate_gauge.lua"},
        )


if __name__ == "__main__":
    unittest.main()
