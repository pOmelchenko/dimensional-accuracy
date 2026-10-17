// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 pOmelchenko
// Visual prototype v7. Corner reliefs preserve access to the flat measurement faces.
// Original construction inspired by the measurement principle of K3D/Sorkin.
// No imported model geometry. Units: mm; height is constant.

/* [Body] */
height = 4.5;
short_length = 24;
short_width = 6;
section_ends = [36, 66, 96];
x_arm_widths = [18, 12, 6];
y_arm_widths = [18, 12, 6];

/* [L-shaped window] */
windows_enabled = true;
window_start = 4;
window_length = 26;
window_width = 6;
window_edge_offset = 4;
minimum_web = 4;

/* [Corner reliefs] */
corner_reliefs_enabled = true;
// Recess the adjoining arm while retaining the nominal target plane.
corner_relief_run = 2;
corner_relief_depth = 0.8;
corner_relief_mouth = 0.5;
// Shared short/short corner: keep the complete schematic rod landing outside it.
shared_corner_radius = 0.4;
window_corner_radius = 0.65;
minimum_relief_web = 3;
$fn = 48;

/* [Seam pocket] */
// Short rectangular slot in the inside corner, with a flat blind end.
seam_pocket_enabled = true;
seam_pocket_width = 2.5;
seam_pocket_depth = 4;
seam_pocket_mouth = 2;

/* [Finish] */
// Exactly representable offset avoids microscopic slivers where OpenSCAD
// 2021.01's chamfer construction meets the subsequent relief cuts.
edge_chamfer = 0.375;
labels_enabled = true;
label_depth = 0.25;
label_font = "Liberation Sans:style=Bold";

/* [Schematic depth gauge - preview only] */
show_depth_gauge = false;
preview_short_side = false;
// Development review modes: "none" or "clearance". Leave "none" for STL export.
review_check = "none";
review_inject_collision = false;
review_contact_tolerance = 0.01;
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
        assert(window_start == window_edge_offset,
               "Both window legs must meet to form one L-shaped opening");
        assert(window_start + window_length > cross_width);
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
    if (windows_enabled)
        assert(min(x_arm_widths[0], y_arm_widths[0])
               - (seam_pocket_depth + seam_pocket_width/2)/sqrt(2)
               - (window_edge_offset + window_width) >= minimum_web,
               "Keep a full web between the seam pocket and L-shaped window");
    translate([y_arm_widths[0], x_arm_widths[0]])
        rotate(45)
            translate([-seam_pocket_depth, -seam_pocket_width/2])
                square([seam_pocket_depth + seam_pocket_mouth, seam_pocket_width]);
}

module arm_step_reliefs(widths) {
    for (i = [0 : len(section_ends)-2])
        translate([section_ends[i]-corner_relief_run, widths[i+1]])
            square([corner_relief_run+corner_relief_mouth,corner_relief_depth]);
}

module corner_reliefs() {
    assert(corner_relief_run > 0 && corner_relief_depth > 0);
    assert(corner_relief_mouth > 0);
    assert(shared_corner_radius > 0 && window_corner_radius > 0);
    assert(shared_corner_radius + 0.05
           <= -probe_lane - rod_width/2,
           "Shared relief must stay outside the full rod contact strip");
    assert(short_width - corner_relief_depth >= minimum_relief_web);
    // Long X approach at v<0: extend target u=short_width into the relief.
    translate([short_width,-corner_relief_mouth])
        square([corner_relief_run,corner_relief_depth+corner_relief_mouth]);
    // Long Y approach is transposed.
    transpose_xy()
        translate([short_width,-corner_relief_mouth])
            square([corner_relief_run,corner_relief_depth+corner_relief_mouth]);
    // Both short intervals use this corner. A small symmetric relief avoids
    // cutting either flat rod landing at the default 1 mm outside probe lane.
    circle(r=shared_corner_radius);
    arm_step_reliefs(x_arm_widths);
    transpose_xy() arm_step_reliefs(y_arm_widths);
    if (windows_enabled) {
        assert(window_edge_offset-window_corner_radius >= minimum_relief_web);
        assert(section_ends[0]-(window_start+window_length)
               -window_corner_radius-corner_relief_run >= minimum_relief_web);
        a = window_edge_offset;
        b = a+window_width;
        c = window_start+window_length;
        // Five convex corners of the L-shaped void. Its elbow at (b,b)
        // is intentionally left alone to preserve the seam-pocket web.
        for (p=[[a,a],[c,a],[c,b],[b,c],[a,c]])
            translate(p) circle(r=window_corner_radius);
    }
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
        // Cut reliefs after chamfer construction: retain their exact plan
        // footprint instead of spreading them along adjacent contact faces.
        if (corner_reliefs_enabled)
            translate([0,0,-0.1])
                linear_extrude(height=height+0.2) corner_reliefs();
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

module local_depth_gauge(distance) {
    // Base plane is u=0. The body lies behind it at u>0; the rod extends
    // toward the target at u=-distance. Entire sole and beam are represented.
    z0 = (height-sole_thickness_z)/2;
    translate([0, probe_lane-other_sole_reach, z0])
        cube([2,rod_to_sole_edge+other_sole_reach,sole_thickness_z]);
    translate([2,probe_lane-other_sole_reach+2,z0])
        cube([26,rod_to_sole_edge+other_sole_reach-4,sole_thickness_z]);
    translate([-distance,probe_lane-rod_width/2,(height-rod_width)/2])
        cube([distance,rod_width,rod_width]);
}

module schematic_depth_gauge(short_side=false, retreat=0) {
    if (short_side)
        translate([-short_length-retreat,0,0])
            mirror([1,0,0]) local_depth_gauge(short_length);
    else
        translate([last(section_ends)+retreat,0,0])
            local_depth_gauge(last(section_ends)-short_width);
}

module all_review_tools() {
    for (short_side=[false,true]) {
        schematic_depth_gauge(short_side,review_contact_tolerance);
        transpose_xy() schematic_depth_gauge(short_side,review_contact_tolerance);
    }
    // Positive control for the checker, never enabled in a review model.
    if (review_inject_collision) translate([1,1,1]) cube([1,1,1]);
}

assert(review_check == "none" || review_check == "clearance");
check_arm(x_arm_widths, y_arm_widths[0])
check_arm(y_arm_widths, x_arm_widths[0])
rotate(180) {
    if (review_check == "clearance")
        intersection() {
            gauge();
            all_review_tools();
        }
    else {
        color([0.22,0.47,0.49]) gauge();
        if (show_depth_gauge)
            color([0.18,0.4,0.85]) schematic_depth_gauge(preview_short_side);
    }
}
