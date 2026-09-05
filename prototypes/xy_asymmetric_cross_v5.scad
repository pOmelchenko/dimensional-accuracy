// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 pOmelchenko
// Visual prototype v5. Asymmetric cross with a common straight probe side.
// Original construction inspired by the measurement principle of K3D/Sorkin.
// No imported model geometry. Units: mm; height is constant.

/* [Body] */
height = 4.5;
short_length = 24;
short_width = 6;
section_ends = [36, 66, 96];
x_arm_widths = [14, 10, 6];
y_arm_widths = [14, 10, 6];

/* [Local windows] */
windows_enabled = true;
window_start = 18;
window_length = 12;
window_width = 6;
window_edge_offset = 4;
minimum_web = 4;

/* [Seam pocket] */
// Short rectangular slot in the inside corner, with a flat blind end.
seam_pocket_enabled = true;
seam_pocket_width = 2.5;
seam_pocket_depth = 4;
seam_pocket_mouth = 2;

/* [Finish] */
edge_chamfer = 0.4;
labels_enabled = true;
label_depth = 0.25;
label_font = "Liberation Sans:style=Bold";

/* [Schematic depth gauge - preview only] */
show_depth_gauge = false;
// User-provided approximate distance, on the side bearing on the tip.
rod_to_sole_edge = 7;
other_sole_reach = 7;
rod_width = 1;
sole_thickness_z = 3;
probe_clearance = 0.5;

function last(a) = a[len(a)-1];
function begin(i) = i == 0 ? 0 : section_ends[i-1];
probe_lane = short_width - rod_to_sole_edge;

assert(len(section_ends) >= 1);
assert(height > 2 * edge_chamfer && edge_chamfer > 0);
assert(label_depth > 0 && label_depth < height - 2 * edge_chamfer);
assert(short_length > 0 && short_width > 2 * edge_chamfer);
assert(probe_lane + rod_width/2 <= -probe_clearance,
       "Terminal width must leave a clear lane for the rod beside the straight edge");
assert(sole_thickness_z <= height - 2 * edge_chamfer);
assert(rod_width > 0 && rod_width <= sole_thickness_z);
assert(other_sole_reach > rod_width/2);

module check_arm(widths, cross_width) {
    assert(len(widths) == len(section_ends));
    assert(last(widths) == short_width,
           "This preview uses the same 6 mm seating width on all four tips");
    for (i = [0 : len(section_ends)-1]) {
        assert(section_ends[i] > begin(i));
        assert(widths[i] > 2 * edge_chamfer);
        if (i > 0) assert(widths[i] <= widths[i-1]);
    }
    if (windows_enabled) {
        assert(window_edge_offset >= minimum_web);
        assert(window_width > 2 * edge_chamfer);
        assert(window_start >= cross_width + minimum_web);
        assert(window_start + window_length <= section_ends[0] - minimum_web);
        assert(window_edge_offset + window_width + minimum_web <= widths[0]);
    }
    children();
}

module transpose_xy() { mirror([1, -1, 0]) children(); }

module arm(widths) {
    union() {
        translate([-short_length, 0]) square([short_length, short_width]);
        for (i = [0 : len(section_ends)-1])
            translate([begin(i), 0]) square([section_ends[i]-begin(i), widths[i]]);
    }
}

module local_window() {
    translate([window_start, window_edge_offset]) square([window_length, window_width]);
}

module seam_pocket() {
    assert(seam_pocket_width > 2 * edge_chamfer);
    assert(seam_pocket_depth > 0 && seam_pocket_mouth > 0);
    assert(seam_pocket_depth + seam_pocket_width < min(x_arm_widths[0], y_arm_widths[0]));
    translate([y_arm_widths[0], x_arm_widths[0]])
        rotate(45)
            translate([-seam_pocket_depth, -seam_pocket_width/2])
                square([seam_pocket_depth + seam_pocket_mouth, seam_pocket_width]);
}

module outline() {
    difference() {
        union() {
            arm(x_arm_widths);
            transpose_xy() arm(y_arm_widths);
        }
        if (windows_enabled) {
            local_window();
            transpose_xy() local_window();
        }
        if (seam_pocket_enabled) seam_pocket();
    }
}

module octahedron(r) {
    polyhedron(
        points = [[r,0,0],[-r,0,0],[0,r,0],[0,-r,0],[0,0,r],[0,0,-r]],
        faces = [[0,2,4],[2,1,4],[1,3,4],[3,0,4],
                 [2,0,5],[1,2,5],[3,1,5],[0,3,5]], convexity = 2);
}

module body() {
    minkowski() {
        translate([0,0,edge_chamfer])
            linear_extrude(height = height - 2*edge_chamfer)
                offset(delta = -edge_chamfer) outline();
        octahedron(edge_chamfer);
    }
}

module engraving(value, p, angle=180, size=2) {
    translate([p[0],p[1],height-label_depth])
        linear_extrude(height=label_depth+0.05)
            rotate(angle)
                text(value,size=size,font=label_font,halign="center",valign="center");
}

module gauge() {
    difference() {
        body();
        if (labels_enabled) {
            engraving("X",[-short_length/2,short_width/2],180,3);
            engraving("Y",[short_width/2,-short_length/2],180,3);
            for (i = [0 : len(section_ends)-1]) {
                engraving(str(x_arm_widths[i]),[section_ends[i]-4,x_arm_widths[i]-2]);
                engraving(str(y_arm_widths[i]),[y_arm_widths[i]-2,section_ends[i]-4],270);
            }
        }
    }
}

module schematic_depth_gauge() {
    // Long X measurement: base at u=96, rod reaches transverse short arm u=6.
    // The full schematic sole extends from v=-8 to +6; its supported part
    // spans the whole terminal face v=0..6. Rod centre is v=-1.
    tip = last(section_ends);
    z0 = (height-sole_thickness_z)/2;
    color([0.18,0.4,0.85]) {
        translate([tip, probe_lane-other_sole_reach, z0])
            cube([2, rod_to_sole_edge+other_sole_reach, sole_thickness_z]);
        translate([tip+2, probe_lane-other_sole_reach+2, z0])
            cube([26, rod_to_sole_edge+other_sole_reach-4, sole_thickness_z]);
        translate([short_width, probe_lane-rod_width/2, (height-rod_width)/2])
            cube([tip-short_width,rod_width,rod_width]);
    }
}

check_arm(x_arm_widths, y_arm_widths[0])
check_arm(y_arm_widths, x_arm_widths[0])
rotate(180) {
    color([0.22,0.47,0.49]) gauge();
    if (show_depth_gauge) schematic_depth_gauge();
}
