# SPDX-License-Identifier: AGPL-3.0-only
import collections
import csv
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import trial


class TrialTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / "test"

    def init(self, **kwargs):
        return trial.initialize(self.path, "synthetic", 7321, **kwargs)

    def test_complete_crossed_design_and_rounds(self):
        config, rows = self.init()
        self.assertEqual(collections.Counter(r["gate"] for r in rows), {"A": 840, "B": 210})
        self.assertEqual(len({r["observation_id"] for r in rows}), 1050)
        cells = collections.Counter((r["gate"], r["print_id"], r["feature_id"],
                                     r["operator_id"], r["caliper_id"]) for r in rows)
        self.assertTrue(all(n == (10 if key[0] == "A" else 5) for key, n in cells.items()))
        blocks = collections.Counter(r["block_id"] for r in rows)
        self.assertLessEqual(max(blocks.values()), 60)
        rounds = collections.Counter((r["gate"], r["session_id"], r["repetition"],
                                      r["print_id"], r["feature_id"]) for r in rows)
        self.assertEqual(set(rounds.values()), {1})
        self.assertEqual(trial.read_csv(self.path / "measurements.csv"), [])
        trial.validate_plan(self.path)

    def test_same_seed_same_schedule_and_different_seed_changes_order(self):
        config, rows = self.init()
        artifacts = trial.artifacts_for(config["families"])
        self.assertEqual(rows, trial.make_schedule(config, artifacts)[0])
        self.assertNotEqual(rows, trial.make_schedule(dict(config, seed=98), artifacts)[0])

    def test_new_release_cannot_change_the_legacy_model_comparison(self):
        config, _ = self.init(families=["xy"])
        artifacts = trial.artifacts_for(["xy"])
        self.assertEqual([a["artifact_id"] for a in artifacts], ["DA-XY-A", "DA-XY-T"])
        with self.assertRaisesRegex(ValueError, "exactly one"):
            trial.make_schedule(config, artifacts + [dict(artifacts[0], artifact_id="DA-XY-S")])

    def test_pilot_and_single_family(self):
        config, rows = self.init(families=["z"], calipers=2)
        self.assertEqual(config["study_kind"], "pilot")
        self.assertEqual(collections.Counter(r["gate"] for r in rows), {"A": 80, "B": 30})

    def test_no_overwrite_or_freeze_of_incomplete_plan(self):
        self.init()
        with self.assertRaises(FileExistsError):
            self.init()
        with self.assertRaisesRegex(ValueError, "environment"):
            trial.freeze(self.path)
        self.assertFalse((self.path / "checksums.sha256").exists())

    def fill_metadata(self):
        envpath = self.path / "environment.json"
        env = json.loads(envpath.read_text())
        for key, value in env.items():
            if value == "":
                env[key] = "a" * 64 if key.endswith("sha256") else "synthetic"
        env.update(nozzle_mm=0.4, layer_height_mm=0.2, line_width_mm=0.45, minimum_cooling_h=1)
        envpath.write_text(json.dumps(env))
        for name in ("artifacts.csv", "prints.csv", "instruments.csv"):
            path = self.path / name
            rows = trial.read_csv(path)
            for row in rows:
                for key, value in row.items():
                    if value == "":
                        row[key] = "a" * 64 if key.endswith("sha256") else (
                            "0.001" if key == "resolution_mm" else
                            "0.01" if key.endswith("_mm") or key in ("print_time_min", "material_g") else "synthetic")
            with path.open("w", newline="") as stream:
                writer = csv.DictWriter(stream, fieldnames=rows[0])
                writer.writeheader()
                writer.writerows(rows)

    def test_frozen_provenance_detects_tampering(self):
        self.init()
        self.fill_metadata()
        trial.freeze(self.path)
        trial.verify_frozen(self.path)
        with self.assertRaises(FileExistsError):
            trial.freeze(self.path)
        with (self.path / "protocol.md").open("a") as stream:
            stream.write("Changed margin")
        with self.assertRaisesRegex(ValueError, "changed"):
            trial.verify_frozen(self.path)

    def test_missing_or_modified_schedule_is_rejected(self):
        self.init()
        path = self.path / "schedule.csv"
        path.write_text("\n".join(path.read_text().splitlines()[:-1]) + "\n")
        with self.assertRaisesRegex(ValueError, "schedule"):
            trial.validate_plan(self.path)


if __name__ == "__main__":
    unittest.main()
