# SPDX-License-Identifier: AGPL-3.0-only
import copy
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import result
import artifact_spec

LUA = shutil.which(os.environ.get("LUA", "lua"))


def synthetic_inputs():
    inputs = dict(calibrate_xy=True, calibrate_z=True, session_id='SYNTHETIC "fixture"\nпроверка',
                  operator_id="O1", caliper_id="C1", resolution_mm="0.01", mpe_mm="0.02",
                  slicer_version="synthetic host", printer_nozzle="synthetic 0.4", filament="synthetic PLA",
                  preset_ids="synthetic printer / print / filament")
    for axis in "xyz":
        for nominal in (40, 80, 120):
            measured = nominal * (.998 if axis == "z" else .9975) + (.12 if axis == "z" else .3)
            inputs[f"{axis}{nominal}"] = ";".join(f"{measured + offset:.3f}" for offset in (-.01, 0, .01))
    for feature in artifact_spec.by_id(artifact_spec.load_spec())["DA-XY-S"]["measurements"]:
        measured = feature["nominal_mm"] * .9975 + feature["contour_coefficient"] * .15 + feature["inner_coefficient"] * .06
        inputs[feature["id"]] = ";".join(f"{measured + offset:.6f}" for offset in (-.01, 0, .01))
    return inputs


def run_plugin(inputs, lua=LUA, mode="normal"):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "inputs.luatest"
        path.write_text("return " + result.lua_literal(inputs))
        return subprocess.run([lua, str(result.ROOT / "tests/run_result.luatest"),
                               str(result.ROOT / "calculate_compensation.lua"), str(path), mode],
                              capture_output=True, text=True, timeout=30)


class ResultTests(unittest.TestCase):
    @staticmethod
    def apply_inputs():
        inputs = synthetic_inputs()
        inputs.update(apply_uniform_scale=True, apply_z_shrinkage=True,
                      confirm_zero_compensation=True, confirm_apply_capable_host=True)
        return inputs

    def test_data_encoder_never_interpolates_executable_text(self):
        text = '\\"; os.execute("unexpected"); --\x00\nкириллица'
        literal = result.lua_literal(text)
        self.assertNotIn("os.execute", literal)
        self.assertNotIn("\n", literal)
        with self.assertRaises(ValueError):
            result.lua_literal(float("nan"))

    def test_nonfinite_json_and_modified_fields_are_rejected(self):
        with self.assertRaises(ValueError):
            result.strict_json('{"value": NaN}')
        with self.assertRaises(ValueError):
            result.compare({"slope": 1}, {"slope": 2})
        with self.assertRaises(ValueError):
            result.compare({"slope": True}, {"slope": 1})

    @unittest.skipUnless(LUA, "Lua is required for integration; make test also requires Lua")
    def test_roundtrip_replay_and_tamper_detection(self):
        completed = run_plugin(synthetic_inputs())
        self.assertEqual(completed.returncode, 0, completed.stderr)
        records = result.records_from_log(completed.stdout)
        record = records[-1]
        self.assertEqual(record["inputs"]["session_id"], synthetic_inputs()["session_id"])
        self.assertIsInstance(record["warnings"], list)
        self.assertIsInstance(record["metadata"]["missing"], list)
        self.assertEqual(record["verification_status"], "NOT_VERIFIED")
        result.replay(record, LUA)
        changed = copy.deepcopy(record)
        changed["inputs"]["x_overall145"] = "144.91;144.91;144.91"
        with self.assertRaisesRegex(ValueError, "replay mismatch"):
            result.replay(changed, LUA)

    @unittest.skipUnless(LUA, "Lua required")
    def test_invalid_input_is_exportable_without_a_success_claim(self):
        inputs = synthetic_inputs()
        inputs["x_overall145"] = "145;;145"
        completed = run_plugin(inputs)
        self.assertNotEqual(completed.returncode, 0)
        record = result.records_from_log(completed.stdout)[-1]
        self.assertEqual(record["workflow_state"], "INVALID_INPUT")
        self.assertEqual(record["inputs"]["x_overall145"], "145;;145")
        self.assertEqual(record["severity"], "FAIL")
        with self.assertRaisesRegex(ValueError, "no calculated plan"):
            result.replay(record, LUA)

    @unittest.skipUnless(LUA, "Lua required")
    def test_cli_export_and_replay_never_overwrite_results(self):
        completed = run_plugin(synthetic_inputs())
        with tempfile.TemporaryDirectory() as directory:
            log, exported = Path(directory) / "log.txt", Path(directory) / "result.json"
            log.write_text(completed.stdout)
            command = [sys.executable, str(result.ROOT / "tools/result.py"), "export", str(log), "--output", str(exported)]
            first = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            second = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(second.returncode, 0)
            replay = subprocess.run([sys.executable, str(result.ROOT / "tools/result.py"), "replay", str(exported), "--lua", LUA], capture_output=True, text=True)
            self.assertEqual(replay.returncode, 0, replay.stderr)

    @unittest.skipUnless(LUA, "Lua required")
    def test_frozen_solver_v1_fixture_remains_reproducible(self):
        record = result.strict_json((result.ROOT / "tests/fixtures/result-v1.json").read_text())
        result.replay(record, LUA)

    @unittest.skipUnless(LUA, "Lua required")
    def test_confirmed_readback_exports_and_replays_without_claiming_physical_verification(self):
        completed = run_plugin(self.apply_inputs())
        self.assertEqual(completed.returncode, 0, completed.stderr)
        records = result.records_from_log(completed.stdout)
        self.assertEqual(records[0]["apply_status"], "NOT_REQUESTED")
        self.assertEqual(records[0]["readback_status"], "NOT_PERFORMED")
        record = records[-1]
        self.assertEqual(record["schema_version"], "1.3.0")
        self.assertEqual(record["apply_status"], "CONFIRMED")
        self.assertEqual(record["readback_status"], "MATCHED")
        self.assertEqual(record["verification_status"], "NOT_VERIFIED")
        self.assertEqual(len(record["readback"]["settings"]), 2)
        self.assertAlmostEqual(record["readback"]["settings"][0]["actual_percent"], .25)
        result.replay(record, LUA)

    @unittest.skipUnless(LUA, "Lua required")
    def test_failed_and_unreadable_apply_results_remain_exportable(self):
        for mode, apply_status, readback_status in (
            ("noop_xy", "ERROR_UNCONFIRMED", "MISMATCH"),
            ("unreadable_xy", "UNCONFIRMED", "UNREADABLE"),
            ("throw_z", "ERROR_UNCONFIRMED", "MISMATCH"),
        ):
            with self.subTest(mode=mode):
                completed = run_plugin(self.apply_inputs(), mode=mode)
                record = result.records_from_log(completed.stdout)[-1]
                self.assertEqual(record["apply_status"], apply_status)
                self.assertEqual(record["readback_status"], readback_status)
                self.assertEqual(record["verification_status"], "NOT_VERIFIED")
                self.assertEqual(completed.returncode == 0, mode == "unreadable_xy")
                result.replay(record, LUA)

    @unittest.skipUnless(LUA, "Lua required")
    def test_inconsistent_readback_claims_are_rejected(self):
        record = result.records_from_log(run_plugin(self.apply_inputs()).stdout)[-1]
        mutations = (
            lambda r: r["readback"]["settings"][0].update(actual_percent=.75),
            lambda r: r["readback"]["settings"].pop(),
            lambda r: r["readback"]["settings"][0].update(expected_percent=.75),
            lambda r: r.update(readback_status="UNREADABLE"),
            lambda r: r.update(verification_status="VERIFIED"),
            lambda r: r.update(schema_version="1.1.0"),
            lambda r: r.pop("readback"),
        )
        for mutate in mutations:
            changed = copy.deepcopy(record)
            mutate(changed)
            with self.assertRaises(ValueError):
                result.validate_record(changed)

    @unittest.skipUnless(LUA, "Lua required")
    def test_schema_1_1_preview_remains_reproducible(self):
        record = result.strict_json((result.ROOT / "tests/fixtures/result-v2.json").read_text())
        self.assertEqual(record["solver_version"], "2.0.0")
        result.validate_record(record)
        result.replay(record, LUA)


if __name__ == "__main__":
    unittest.main()
