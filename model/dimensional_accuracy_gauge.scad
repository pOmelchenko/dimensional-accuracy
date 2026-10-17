// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 pOmelchenko
// Release models: accepted XY-S reference and the existing Z-B plate.
use <xy_reference.scad>
use <legacy_gauges.scad>
gauge_mode = "xy";
xyz_gap = 10;
if (gauge_mode == "xy") {
    xy_reference_gauge();
} else if (gauge_mode == "z") {
    z_b_gauge();
} else if (gauge_mode == "xyz") {
    xy_reference_gauge();
    // XY y=-100..45, Z y=-12..12; nearest faces have a 10 mm gap.
    translate([0,45+xyz_gap+12,0]) z_b_gauge();
} else {
    assert(false,str("Unsupported release mode: ",gauge_mode));
}
