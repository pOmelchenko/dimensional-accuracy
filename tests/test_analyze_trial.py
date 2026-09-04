# SPDX-License-Identifier: AGPL-3.0-only
import copy
import csv
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import analyze_trial as analysis
import trial
import test_trial


class AnalysisTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / "trial"
        trial.initialize(self.path, "synthetic", 123, families=["z"])
        test_trial.TrialTests.fill_metadata(self)
        trial.freeze(self.path)
        self.config, self.schedule = trial.verify_frozen(self.path)

    def rows(self, noise=False):
        result = []
        for planned in self.schedule:
            row = dict.fromkeys(self.config["measurement_columns"], "") | planned
            amplitude = 0.002 if row["artifact_id"] == "DA-Z-C40" else 0.006
            offset = (int(row["repetition"]) % 5 - 2) * amplitude if noise else 0
            row.update(actual_order=row["scheduled_order"], zero_before_mm="0.00", zero_after_mm="0.00",
                       measured_mm=f"{float(row['nominal_mm']) + offset:.3f}", installation_status="OK",
                       elapsed_since_print_h="2")
            result.append(row)
        return result

    def save(self, rows):
        with (self.path / "measurements.csv").open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=self.config["measurement_columns"])
            writer.writeheader()
            writer.writerows(rows)

    def validate(self):
        return analysis.validate_observations(self.path, self.config, self.schedule)

    def test_empty_and_partial_trials_cannot_pass(self):
        result, observations = analysis.analyze(self.path)
        self.assertEqual(result["families"]["z"]["verdict"], "INCONCLUSIVE")
        self.assertEqual(result["families"]["z"]["gate_a"]["counts"]["missing"], 120)
        self.save(self.rows()[:1])
        result, _ = analysis.analyze(self.path)
        counts = result["families"]["z"]["gate_a"]["counts"]
        self.assertEqual(counts["scheduled"], 120)
        self.assertEqual(counts["valid"], 1)
        self.assertEqual(counts["failure_rate"], 119 / 120)

    def test_constant_readings_are_not_evidence_of_superiority(self):
        self.save(self.rows())
        result, _ = analysis.analyze(self.path)
        report = result["families"]["z"]
        self.assertEqual(report["gate_a"]["status"], "PASS")
        self.assertEqual(report["gate_b"]["status"], "PASS")
        self.assertEqual(report["verdict"], "INCONCLUSIVE")
        self.assertIsNone(report["spans"]["z40"]["comparison"]["ratio"])

    def test_synthetic_superiority_requires_all_gates_and_cost_record(self):
        self.save(self.rows(noise=True))
        trial.write_csv(self.path / "deviations.csv", ["event_id", "scope_id", "reason", "action"],
                        [dict(event_id="cost-1", scope_id="z", reason="synthetic preregistered cost met", action="COST_ACCEPTED")])
        before = (self.path / "measurements.csv").read_bytes()
        result, observations = analysis.analyze(self.path)
        self.assertEqual(result["families"]["z"]["verdict"], "SUPPORTED")
        self.assertEqual(result["calibration_status"], "NOT_VERIFIED")
        self.assertAlmostEqual(result["families"]["z"]["spans"]["z40"]["comparison"]["ratio"], 1/3)
        self.assertEqual(before, (self.path / "measurements.csv").read_bytes())
        self.assertEqual(len(observations), 150)
        self.assertIn("NOT_VERIFIED", analysis.report_markdown(result))
        rendered = analysis.observations_html(observations)
        self.assertEqual(rendered.count("<circle "), 150)

    def test_failed_installation_and_zero_drift_are_visible(self):
        rows = self.rows()
        rows[0].update(installation_status="SLIPPED", measured_mm="", failure_reason="lost contact")
        self.save(rows)
        result, _ = analysis.analyze(self.path)
        self.assertEqual(result["families"]["z"]["gate_a"]["status"], "FAIL")
        self.assertEqual(result["families"]["z"]["verdict"], "NOT_SUPPORTED")
        for row in rows:
            if row["block_id"] == rows[0]["block_id"]:
                row["zero_after_mm"] = "0.02"
        self.save(rows)
        result, observations = analysis.analyze(self.path)
        self.assertEqual(result["audit"]["invalid_zero_blocks"], [rows[0]["block_id"]])
        self.assertTrue(all(row["value"] is None for row in observations if row["block_id"] == rows[0]["block_id"]))

    def test_corrections_preserve_history_and_cannot_hide_failed_installations(self):
        rows = self.rows()
        corrected = dict(rows[0], observation_id="correction-1", supersedes_observation_id=rows[0]["observation_id"],
                         measured_mm="39.999", notes="transcription: display had 39.999")
        self.save(rows + [corrected])
        effective, audit = self.validate()
        self.assertEqual(audit["raw_rows"], 151)
        self.assertEqual(audit["corrections"], 1)
        self.assertEqual(effective[0]["value"], 39.999)
        rows[0].update(installation_status="INSTALL_FAILED", measured_mm="", failure_reason="no contact")
        self.save(rows + [corrected])
        with self.assertRaisesRegex(ValueError, "failed physical"):
            self.validate()

    def test_schema_invalid_numbers_identity_and_branching_are_rejected(self):
        for mutation in ({"measured_mm": "nan"}, {"measured_mm": "-1"},
                         {"feature_id": "z80"}, {"installation_status": "UNKNOWN"}):
            with self.subTest(mutation=mutation):
                rows = self.rows()
                rows[0].update(mutation)
                self.save(rows)
                with self.assertRaises(ValueError):
                    self.validate()
        rows = self.rows()
        corrected = dict(rows[0], observation_id="fix1", supersedes_observation_id=rows[0]["observation_id"], notes="typo")
        self.save(rows + [corrected, dict(corrected, observation_id="fix2")])
        with self.assertRaisesRegex(ValueError, "branching"):
            self.validate()

    def test_gate_b_uses_print_medians_not_pooled_placements(self):
        rows = self.rows()
        # One 0.1 mm placement error per print changes its mean, but not median.
        for row in rows:
            if row["gate"] == "B" and row["repetition"] == "1":
                row["measured_mm"] = "40.1"
        self.save(rows)
        result, _ = analysis.analyze(self.path)
        model = result["families"]["z"]["spans"]["z40"]["models"]["control"]
        self.assertEqual(model["print_summary"]["n"], 3)
        self.assertEqual(model["print_summary"]["range"], 0)
        self.assertEqual(model["print_summary"]["median"], 40)
        self.assertNotEqual(model["copies"]["z-1"]["mean"], 40)

    def test_statistics_and_bootstrap_are_reproducible(self):
        self.assertAlmostEqual(analysis.pooled_sd([[1, 3], [5, 7]]), math.sqrt(2))
        self.assertEqual(analysis.summary([1, 2, 3])["mad"], 1)
        self.assertEqual(analysis.quantile([0, 10], .05), .5)
        args = ([[1, 2, 3, 4, 5]], [[1, 1.5, 2, 2.5, 3]], 500, .9, 7)
        self.assertEqual(analysis.bootstrap_ratio(*args), analysis.bootstrap_ratio(*args))
        fit = analysis.axis_fit([40, 80, 120], [40.2, 80.1, 120])
        self.assertAlmostEqual(fit["scale"], .9975)
        self.assertAlmostEqual(fit["observed_additive_term_mm"], .3)


if __name__ == "__main__":
    unittest.main()
