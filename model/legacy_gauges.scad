// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 pOmelchenko

// Export modes:
//   xy   - the release XY-A gauge (override the two xy_* values for trials)
//   z    - the release-candidate Z-B stepped plate
//   xyz  - XY and Z pre-arranged as two printable shells in one mesh
//   zc40 - the short Z-C window prototype used only for the physical trial
gauge_mode = "xy";

$fn = 32;

nominal_lengths = [40, 80, 120];
edge_chamfer = 0.4;
corner_chamfer = 0.75;
label_depth = 0.3;
label_font = "Liberation Sans:style=Bold";

// The smaller XY-A section is the default release candidate. The documented
// challenger is exported by overriding these values with 7.0 and 5.0.
xy_bar_width = 6.5;
xy_gauge_height = 4.5;
xy_bar_pitch = 14;
xy_seam_relief_radius = 1.1;

z_step_width = 14;
z_wall_thickness = 6.5;
z_base_size = [52, 24];
z_base_height = 4.5;
z_wall_front = 3.5;
z_wall_back = z_wall_front + z_wall_thickness;
z_gusset_depth = z_base_size[1] / 2 - z_wall_back;
z_gusset_width = 2.4;
z_gusset_height = 19;
xyz_gap = 10;

zc_height = 50;
zc_post_width = z_step_width;
zc_window_width = 9;
zc_window_height = 7;

assert(edge_chamfer > 0);
assert(xy_bar_width - 2 * corner_chamfer >= 5,
       "XY end face must retain at least 5 mm of flat width");
assert(xy_gauge_height - 2 * edge_chamfer >= 3,
       "XY end face must retain at least 3 mm of flat height");
assert(xy_bar_pitch > xy_bar_width,
       "XY bars need a free gap for the caliper jaws");
assert(z_wall_thickness >= 6 && z_wall_thickness <= 8);
assert(zc_window_width >= 8 && zc_window_width <= 10);
assert(zc_window_height >= 6 && zc_window_height <= 9);

module chamfered_rectangle(size, chamfer) {
    x = size[0] / 2;
    y = size[1] / 2;

    polygon([
        [-x + chamfer, -y], [x - chamfer, -y],
        [x, -y + chamfer], [x, y - chamfer],
        [x - chamfer, y], [-x + chamfer, y],
        [-x, y - chamfer], [-x, -y + chamfer]
    ]);
}

module octahedron(radius) {
    polyhedron(
        points = [
            [ radius, 0, 0], [-radius, 0, 0],
            [0,  radius, 0], [0, -radius, 0],
            [0, 0,  radius], [0, 0, -radius]
        ],
        faces = [
            [0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4],
            [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]
        ],
        convexity = 2
    );
}

// The inset extrusion plus the octahedron preserves the requested outer
// dimensions in the middle of every working face while chamfering both the
// first-layer and top-layer edges.
module chamfered_prism(size, height, corner = corner_chamfer) {
    assert(height > 2 * edge_chamfer);
    assert(min(size) > 2 * edge_chamfer);

    minkowski() {
        translate([0, 0, edge_chamfer])
            linear_extrude(height = height - 2 * edge_chamfer)
                offset(delta = -edge_chamfer)
                    chamfered_rectangle(size, corner);
        octahedron(edge_chamfer);
    }
}

module top_engraving(value, position, rotation = 0, size = 3) {
    translate([
        position[0],
        position[1],
        xy_gauge_height - label_depth
    ])
        linear_extrude(height = label_depth + 0.05)
            rotate(rotation)
                text(
                    value,
                    size = size,
                    font = label_font,
                    halign = "center",
                    valign = "center"
                );
}

module xy_outline() {
    difference() {
        union() {
            for (index = [0 : 2]) {
                axis_offset = (index - 1) * xy_bar_pitch;
                translate([0, axis_offset])
                    chamfered_rectangle(
                        [nominal_lengths[index], xy_bar_width],
                        corner_chamfer
                    );
                translate([axis_offset, 0])
                    chamfered_rectangle(
                        [xy_bar_width, nominal_lengths[index]],
                        corner_chamfer
                    );
            }
        }

        // One concave pocket is an explicit, sheltered seam target. It is
        // remote from all six measurement ends.
        translate([xy_bar_width / 2, xy_bar_width / 2])
            circle(r = xy_seam_relief_radius);
    }
}

module xy_body() {
    minkowski() {
        translate([0, 0, edge_chamfer])
            linear_extrude(height = xy_gauge_height - 2 * edge_chamfer)
                offset(delta = -edge_chamfer)
                    xy_outline();
        octahedron(edge_chamfer);
    }
}

module xy_labels() {
    for (index = [0 : 2]) {
        axis_offset = (index - 1) * xy_bar_pitch;
        top_engraving(
            str("X", nominal_lengths[index]),
            [0, axis_offset]
        );
        // Moving the Y labels away from y=0 prevents X80/Y80 overlap while
        // retaining at least 12 mm to the nearest measured end.
        top_engraving(
            str("Y", nominal_lengths[index]),
            [axis_offset, 7],
            90
        );
    }
}

module xy_gauge() {
    difference() {
        xy_body();
        xy_labels();
    }
}

module front_engraving(value, x, z, size = 4) {
    // Rotation maps text Y to model Z. Extrusion starts inside the wall and
    // travels toward its open side, leaving a shallow recessed label.
    translate([x, z_wall_front + label_depth, z])
        rotate([90, 0, 0])
            linear_extrude(height = label_depth + 0.05)
                text(
                    value,
                    size = size,
                    font = label_font,
                    halign = "center",
                    valign = "center"
                );
}

module rear_gusset(x) {
    // The ribs stay entirely behind the measuring side of the wall. The hull
    // creates a self-supporting triangular profile without a horizontal roof.
    hull() {
        translate([
            x - z_gusset_width / 2,
            z_wall_back - 0.5,
            z_base_height - 0.05
        ])
            cube([
                z_gusset_width,
                0.55,
                z_gusset_height - z_base_height
            ]);
        translate([
            x - z_gusset_width / 2,
            z_wall_back - 0.5,
            z_base_height - 0.05
        ])
            cube([
                z_gusset_width,
                z_gusset_depth + 0.5,
                0.55
            ]);
    }
}

module z_base() {
    chamfered_prism(z_base_size, z_base_height, 1);
}

module z_b_solid() {
    union() {
        z_base();

        for (index = [0 : 2]) {
            x = (index - 1) * z_step_width;
            translate([
                x,
                (z_wall_front + z_wall_back) / 2,
                0
            ])
                chamfered_prism(
                    // A small overlap makes the adjacent blades a robust
                    // Boolean union instead of three merely coincident faces.
                    [z_step_width + 0.2, z_wall_thickness],
                    nominal_lengths[index]
                );
            rear_gusset(x);
        }
    }
}

module z_b_cutouts() {
    for (index = [0 : 2]) {
        x = (index - 1) * z_step_width;
        front_engraving(
            str("Z", nominal_lengths[index]),
            x,
            nominal_lengths[index] - 8
        );
    }

    // A vertical groove on the rear of the 120 mm blade shelters the seam and
    // stops short of both the datum and the upper measuring face.
    translate([
        z_step_width + z_step_width / 3,
        z_wall_back - 0.2,
        z_base_height + 2
    ])
        cylinder(
            h = nominal_lengths[2] - z_base_height - 7,
            r = 0.8
        );
}

module z_b_gauge() {
    difference() {
        z_b_solid();
        z_b_cutouts();
    }
}

module zc40_solid() {
    union() {
        z_base();
        translate([0, (z_wall_front + z_wall_back) / 2, 0])
            chamfered_prism(
                [zc_post_width, z_wall_thickness],
                zc_height
            );
        rear_gusset(0);
    }
}

module zc40_cutouts() {
    // The lower face of this through-window is the exact 40 mm working plane.
    // Its 9 mm bridge is within the documented unsupported-span limit.
    translate([
        -zc_window_width / 2,
        z_wall_front - 0.1,
        nominal_lengths[0]
    ])
        cube([
            zc_window_width,
            z_wall_thickness + 0.2,
            zc_window_height
        ]);

    front_engraving("Z40", 0, 28);

    translate([zc_post_width / 2, z_wall_back, z_base_height + 2])
        cylinder(h = 31, r = 0.8);
}

module zc40_gauge() {
    difference() {
        zc40_solid();
        zc40_cutouts();
    }
}

module xyz_gauge() {
    // XY spans y=-60..60. Position the near edge of Z at y=70 so the two
    // printable shells have an exact 10 mm gap and fit within 120 x 154 mm.
    xy_gauge();
    translate([0, nominal_lengths[2] / 2 + xyz_gap + z_base_size[1] / 2, 0])
        z_b_gauge();
}

if (gauge_mode == "xy") {
    xy_gauge();
} else if (gauge_mode == "z") {
    z_b_gauge();
} else if (gauge_mode == "xyz") {
    xyz_gauge();
} else if (gauge_mode == "zc40") {
    zc40_gauge();
} else {
    assert(false, str("Unsupported gauge_mode: ", gauge_mode));
}
