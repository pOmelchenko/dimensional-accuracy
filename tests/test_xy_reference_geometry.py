# SPDX-License-Identifier: AGPL-3.0-only
import subprocess
import sys
import unittest
from pathlib import Path


class XYReferenceGeometryTests(unittest.TestCase):
    def test_measurement_contacts_depth_rod_clearance_and_relief_chamfers(self):
        root = Path(__file__).resolve().parents[1]
        completed = subprocess.run([sys.executable, str(root / "tools/check_xy_reference.py")],
                                   cwd=root, capture_output=True, text=True, timeout=45)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("nominal mid-height targets retained", completed.stdout)


if __name__ == "__main__":
    unittest.main()
