# SPDX-License-Identifier: AGPL-3.0-only
import csv
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import xy_experiment as experiment

LUA = shutil.which(os.environ.get("LUA", "lua"))


class ExperimentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / "experiment"

    def edit_csv(self, name, columns, edit):
        rows = experiment.read_csv(self.path / name, columns)
        edit(rows)
        with (self.path / name).open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=columns, lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)

    def test_template_is_complete_but_never_fabricates_observations(self):
        protocol = experiment.initialize(self.path, "FIRST", repeats=5)
        _, _, rows, prints = experiment.load(self.path)
        self.assertEqual(len(rows), 320)
        self.assertEqual(sum(f["required"] for f in protocol["features"]), 6)
        self.assertEqual(len({r["feature_id"] for r in rows}), 32)
        self.assertTrue(all(not r["measured_mm"] and not r["status"] for r in rows))
        self.assertEqual(prints[0]["xy_shrinkage_percent"], "0")
        self.assertEqual(prints[1]["xy_shrinkage_percent"], "")
        report = experiment.analyze(self.path)
        self.assertEqual(report["status"], "INCOMPLETE")
        self.assertNotIn("baseline_plan", report)
        self.assertEqual(report["physical_validation"], "NOT_ESTABLISHED")
        with self.assertRaises(FileExistsError):
            experiment.initialize(self.path, "FIRST")

    def test_protocol_and_row_identity_are_frozen(self):
        for field, value in (("phase", "verification"), ("nominal_mm", "140"),
                             ("method", "depth_rod"), ("repetition", "2")):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as tmp:
                self.path = Path(tmp) / "trial"
                experiment.initialize(self.path, "FIXED")
                self.edit_csv("measurements.csv", experiment.COLUMNS, lambda rows: rows[0].update({field: value}))
                with self.assertRaisesRegex(ValueError, "identity"):
                    experiment.load(self.path)
        self.path = Path(self.tmp.name) / "tampered"
        experiment.initialize(self.path, "FIXED")
        with (self.path / "protocol.json").open("a") as stream:
            stream.write(" ")
        with self.assertRaisesRegex(ValueError, "protocol changed"):
            experiment.load(self.path)

    def test_missing_rows_and_nonfinite_readings_are_rejected(self):
        experiment.synthetic(self.path)
        self.edit_csv("measurements.csv", experiment.COLUMNS, lambda rows: rows[0].update(measured_mm="NaN"))
        with self.assertRaises(ValueError):
            experiment.load(self.path)
        self.edit_csv("measurements.csv", experiment.COLUMNS, lambda rows: rows.pop())
        with self.assertRaisesRegex(ValueError, "missing or duplicated"):
            experiment.load(self.path)

    def test_zero_baseline_and_single_changed_setting_are_enforced(self):
        experiment.synthetic(self.path)
        for column, value in (("xy_shrinkage_percent", ".1"), ("xy_size_compensation_mm", ".1"),
                              ("z_shrinkage_percent", "1"), ("material_slot", "2")):
            with self.subTest(column=column):
                self.edit_csv("prints.csv", experiment.PRINT_COLUMNS, lambda rows: rows[0].update({column:value}))
                with self.assertRaises(ValueError):
                    experiment.load(self.path)
                self.edit_csv("prints.csv", experiment.PRINT_COLUMNS,
                              lambda rows: rows[0].update({column:"1" if column == "material_slot" else "0"}))

    def test_partial_optional_readings_cannot_silently_disappear(self):
        experiment.synthetic(self.path)
        self.edit_csv("measurements.csv", experiment.COLUMNS,
                      lambda rows: next(r for r in rows if r["feature_id"] == "x_inner45").update(status="", measured_mm=""))
        p, e, rows, _ = experiment.load(self.path)
        with self.assertRaisesRegex(ValueError, "x_inner45.*PARTIAL"):
            experiment.baseline_inputs(p, e, experiment.collect(p, e, rows))

    def test_zero_drift_and_instrument_resolution(self):
        experiment.synthetic(self.path)
        env = json.loads((self.path / "environment.json").read_text())
        env["resolution_mm"] = ".01"
        (self.path / "environment.json").write_text(json.dumps(env))
        with self.assertRaisesRegex(ValueError, "finer than"):
            experiment.load(self.path)
        env["resolution_mm"] = ".000001"
        (self.path / "environment.json").write_text(json.dumps(env))
        self.edit_csv("measurements.csv", experiment.COLUMNS,
                      lambda rows: rows[0].update(zero_after_mm=".02"))
        p, e, rows, _ = experiment.load(self.path)
        self.assertEqual(experiment.collect(p, e, rows)[("baseline", "x_overall145")]["status"], "ZERO_CHECK_FAILED")

    def test_decimal_comma_is_preserved_and_compensated_data_never_enters_fit(self):
        experiment.synthetic(self.path)
        def edit(rows):
            for row in rows:
                row["measured_mm"] = row["measured_mm"].replace(".", ",") if row["phase"] == "baseline" else "999"
        self.edit_csv("measurements.csv", experiment.COLUMNS, edit)
        p, e, rows, _ = experiment.load(self.path)
        inputs = experiment.baseline_inputs(p, e, experiment.collect(p, e, rows))
        self.assertEqual(inputs["x_overall145"], "144,265000;144,275000;144,285000")
        self.assertFalse(inputs["apply_uniform_scale"])
        self.assertFalse(inputs["confirm_zero_compensation"])

    @unittest.skipUnless(LUA, "Lua required for production solver integration")
    def test_scale_pair_reproduces_production_solver_and_compares_all_features(self):
        experiment.synthetic(self.path)
        report = experiment.analyze(self.path, LUA)
        self.assertEqual(report["status"], "COMPARED")
        self.assertEqual(report["evidence_status"], "SYNTHETIC_ONLY")
        self.assertAlmostEqual(report["proposed_xy_shrinkage_percent"], .5)
        self.assertEqual(len(report["comparisons"]), 32)
        for feature in report["comparisons"]:
            self.assertEqual(feature["comparison"], "CLOSER_TO_NOMINAL")
            self.assertAlmostEqual(feature["verification_error_mm"], 0)
            self.assertAlmostEqual(feature["baseline_error_mm"], -.005*feature["nominal_mm"])
        self.assertIn("SYNTHETIC", experiment.markdown(report))

    @unittest.skipUnless(LUA, "Lua required")
    def test_offsets_remain_visible_after_scaling(self):
        experiment.synthetic(self.path, "offsets")
        report = experiment.analyze(self.path, LUA)
        self.assertEqual(report["status"], "COMPARED")
        self.assertAlmostEqual(report["proposed_xy_shrinkage_percent"], .5)
        features = {f["feature_id"]:f for f in report["comparisons"]}
        self.assertAlmostEqual(features["x_overall145"]["verification_error_mm"], .16)
        self.assertAlmostEqual(features["x_inner45"]["verification_error_mm"], -.12)
        self.assertAlmostEqual(features["x_wall_straight7_5"]["verification_error_mm"], .14)
        self.assertEqual(features["x_width15"]["comparison"], "FARTHER_FROM_NOMINAL")

    @unittest.skipUnless(LUA, "Lua required")
    def test_contradiction_and_wrong_applied_compensation_require_review(self):
        experiment.synthetic(self.path, "contradiction")
        report = experiment.analyze(self.path, LUA)
        self.assertEqual(report["status"], "REVIEW_NEEDED")
        self.assertEqual(report["baseline_quality"], "REVIEW_NEEDED")
        self.edit_csv("prints.csv", experiment.PRINT_COLUMNS, lambda rows: rows[1].update(xy_shrinkage_percent=".3"))
        self.assertEqual(experiment.analyze(self.path, LUA)["compensation_match"], "MISMATCH")

    @unittest.skipUnless(LUA, "Lua required")
    def test_failed_verification_is_not_used_as_a_passing_comparison(self):
        experiment.synthetic(self.path)
        self.edit_csv("measurements.csv", experiment.COLUMNS,
                      lambda rows: next(r for r in rows if r["phase"] == "verification").update(
                          status="FAILED", measured_mm="", notes="damaged face"))
        report = experiment.analyze(self.path, LUA)
        self.assertEqual(report["status"], "INCOMPLETE")
        self.assertEqual(report["comparisons"][0]["comparison"], "NOT_COMPARABLE")
        self.assertEqual(report["comparisons"][0]["verification"]["n"], 2)
        self.assertNotIn("verification_error_mm", report["comparisons"][0])


if __name__ == "__main__":
    unittest.main()
