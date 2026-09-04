# SPDX-License-Identifier: AGPL-3.0-only
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import artifact_spec as spec


class ArtifactTests(unittest.TestCase):
    def test_checked_projections_and_layout_planes(self):
        data = spec.check()
        layout = spec.by_id(data)["DA-XYZ-AB"]
        args = spec.verifier_args(data, layout)
        self.assertIn("1:x=-60", args)
        self.assertIn("2:z=120", args)
        self.assertIn("y=10", args)
        self.assertIn("1:120:120:4.5", args)
        self.assertIn("2:52:24:120", args)

    def make_copy(self, directory):
        root = Path(directory)
        (root / "model").mkdir()
        for name in ("model/artifacts.json", "model/dimensional_accuracy_gauge.scad",
                     "calculate_compensation.lua", "generate_gauge.lua", "Makefile", "manifest.json"):
            shutil.copyfile(spec.ROOT / name, root / name)
        return root

    def test_changed_nominals_and_stale_lua_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_copy(directory)
            path = root / "calculate_compensation.lua"
            path.write_text(path.read_text().replace("local NOMINAL_LENGTHS = {40, 80, 120}",
                                                     "local NOMINAL_LENGTHS = {30, 80, 120}"))
            with self.assertRaisesRegex(ValueError, "stale"):
                spec.check(root)
            spec.check(root, write=True)
            spec.check(root)
            path = root / "model/dimensional_accuracy_gauge.scad"
            path.write_text(path.read_text().replace("xy_bar_width = 6.5", "xy_bar_width = 7.5"))
            with self.assertRaisesRegex(ValueError, "SCAD xy_bar_width"):
                spec.check(root)

    def test_changed_label_and_make_verifier_fail(self):
        for filename, before, after in (
            ("calculate_compensation.lua", 'label = "Measured X40', 'label = "Measured X30'),
            ("Makefile", "verify DA-XY-A", "verify DA-XY-T"),
        ):
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as directory:
                root = self.make_copy(directory)
                path = root / filename
                path.write_text(path.read_text().replace(before, after))
                with self.assertRaises(ValueError):
                    spec.check(root)

    def test_unique_id_and_layout_revision(self):
        data = spec.load_spec()
        data["artifacts"][-1]["components"][0]["revision"] = 999
        with self.assertRaisesRegex(ValueError, "revision"):
            spec.verifier_args(data, data["artifacts"][-1])

    def test_internal_nominal_mismatch_cannot_be_synced_away(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_copy(directory)
            path = root / "model/artifacts.json"
            data = json.loads(path.read_text())
            data["nominal_lengths_mm"] = [20, 40, 60]
            path.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, "nominal definitions differ"):
                spec.check(root, write=True)


if __name__ == "__main__":
    unittest.main()
