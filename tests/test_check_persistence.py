# SPDX-License-Identifier: AGPL-3.0-only
import copy
import json
from pathlib import Path
import sys
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import check_persistence as check


def evidence():
    directory = ROOT / "research/evidence/z-persistence"
    records = [json.loads((directory / name).read_text()) for name in check.RECORDS]
    with zipfile.ZipFile(directory / "SYNTHETIC-XY-Z-0p5.3mf") as archive:
        project = json.loads(archive.read(check.PROJECT_MEMBER))
    return [*records, project]


class PersistenceTests(unittest.TestCase):
    def test_both_gui_previews_match_original_writes(self):
        result = check.compare(*evidence())
        self.assertEqual(result["status"], "SAVED_VALUES_MATCH_REOPENED_API")
        self.assertEqual(result["physical_validation"], "NOT_ESTABLISHED")
        for values in result["reopened_percent"].values():
            for value in values.values():
                self.assertAlmostEqual(value, .5)

    def test_reset_unreadable_and_nonfinite_baselines_fail(self):
        for phase in (2, 3):
            for axis in ("xy_shrinkage", "z_shrinkage"):
                for field, value in (("known", False), ("numeric", 0), ("numeric", float("nan")), ("numeric", True)):
                    args = evidence()
                    args[phase]["baseline"][axis][field] = value
                    with self.subTest(phase=phase, axis=axis, value=value), self.assertRaises(ValueError):
                        check.compare(*args)

    def test_apply_record_cannot_stand_in_for_restart_preview(self):
        args = evidence()
        args[2] = copy.deepcopy(args[0])
        with self.assertRaisesRegex(ValueError, "preview"):
            check.compare(*args)
        args = evidence()
        args[3]["inputs"]["apply_z_shrinkage"] = True
        with self.assertRaisesRegex(ValueError, "preview"):
            check.compare(*args)

    def test_saved_project_must_retain_both_percentages_and_single_slot(self):
        for key in (check.XY_KEY, check.Z_KEY):
            for field, value in (("value", 0), ("is_percent", False)):
                args = evidence()
                args[4]["config_containers"][0]["configuration"]["filament_settings"][key][0][field] = value
                with self.subTest(key=key, field=field), self.assertRaises(ValueError):
                    check.compare(*args)
        args = evidence()
        args[4]["config_containers"] *= 2
        with self.assertRaisesRegex(ValueError, "one configuration"):
            check.compare(*args)


if __name__ == "__main__":
    unittest.main()
