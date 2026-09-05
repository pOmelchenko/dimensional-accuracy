// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 pOmelchenko
// Visual design prototype v1, not a released calibration artifact.
// Dimensions are in mm. Flat mid-height faces retain the nominal dimensions.
// Long arms point left and down, as in the reference sketch.

/* [Body] */
height = 4.5;
short_arm_length = 30;
// End positions of the three sections, measured from the crossing datum.
// Total X/Y extent = short_arm_length + the last end position.
section_ends = [44, 67, 90];
// Widths run from the crossing toward the long-arm tip.
// X-arm widths are measured along Y; Y-arm widths are measured along X.
x_arm_outer_widths = [24, 18, 12];
y_arm_outer_widths = [24, 18, 12];

/* [Through window] */
window_enabled = true;
x_arm_window_widths = [18, 12, 6];
y_arm_window_widths = [18, 12, 6];
// Distance from each straight outside edge to the straight window edge.
window_edge_offset = 3;
// Window shoulders precede outside shoulders by this distance.
// This also closes the far end of each window.
window_end_margin = 3;
minimum_web = 3;

/* [Finish] */
edge_chamfer = 0.4;
axis_labels = true;
label_depth = 0.25;
label_font = "Liberation Sans:style=Bold";

function previous_end(i) = i == 0 ? 0 : section_ends[i - 1];
function last(values) = values[len(values) - 1];

assert(height > 2 * edge_chamfer);
assert(edge_chamfer > 0);
assert(minimum_web > 2 * edge_chamfer);
assert(short_arm_length > 2 * edge_chamfer);
assert(len(section_ends) > 0);
assert(label_depth > 0 && label_depth < height - 2 * edge_chamfer);

module validate_arm(outer_widths, window_widths) {
    assert(len(outer_widths) == len(section_ends));
    assert(len(window_widths) == len(section_ends));
    for (i = [0 : len(section_ends) - 1]) {
        assert(section_ends[i] > previous_end(i));
        assert(outer_widths[i] > 2 * edge_chamfer);
        if (i > 0)
            assert(outer_widths[i] <= outer_widths[i - 1],
                   "Outer widths must not increase toward the tip");
        if (window_enabled) {
            assert(window_edge_offset >= minimum_web);
            assert(window_end_margin >= minimum_web);
            assert(window_widths[i] > 2 * edge_chamfer);
            assert(outer_widths[i] - window_edge_offset
                   - window_widths[i] >= minimum_web,
                   "Window leaves an undersized outside web");
            assert(section_ends[i] - previous_end(i)
                   > window_end_margin + window_edge_offset,
                   "Section is too short for the selected window margins");
            if (i > 0)
                assert(window_widths[i] <= window_widths[i - 1],
                       "Window widths must not increase toward the tip");
        }
    }
    children();
}

module arm_outline(widths) {
    union() {
        translate([-short_arm_length, 0])
            square([short_arm_length, last(widths)]);
        for (i = [0 : len(section_ends) - 1])
            translate([previous_end(i), 0])
                square([section_ends[i] - previous_end(i), widths[i]]);
    }
}

module arm_window(widths) {
    union() {
        for (i = [0 : len(section_ends) - 1]) {
            start = i == 0 ? window_edge_offset
                           : section_ends[i - 1] - window_end_margin;
            finish = section_ends[i] - window_end_margin;
            translate([start, window_edge_offset])
                square([finish - start, widths[i]]);
        }
    }
}

module transpose_xy() {
    mirror([1, -1, 0]) children();
}

module outline() {
    difference() {
        union() {
            arm_outline(x_arm_outer_widths);
            transpose_xy() arm_outline(y_arm_outer_widths);
        }
        if (window_enabled)
            union() {
                arm_window(x_arm_window_widths);
                transpose_xy() arm_window(y_arm_window_widths);
            }
    }
}

module octahedron(radius) {
    polyhedron(
        points = [[radius, 0, 0], [-radius, 0, 0],
                  [0, radius, 0], [0, -radius, 0],
                  [0, 0, radius], [0, 0, -radius]],
        faces = [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4],
                 [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]],
        convexity = 2
    );
}

module body() {
    // Chamfer top/bottom edges, including window rims. The measurement band
    // from z=edge_chamfer to z=height-edge_chamfer keeps the nominal outline.
    minkowski() {
        translate([0, 0, edge_chamfer])
            linear_extrude(height = height - 2 * edge_chamfer)
                offset(delta = -edge_chamfer) outline();
        octahedron(edge_chamfer);
    }
}

module engraving(value, position) {
    translate([position[0], position[1], height - label_depth])
        linear_extrude(height = label_depth + 0.05)
            rotate(180)
                text(value, size = 5, font = label_font,
                     halign = "center", valign = "center");
}

validate_arm(x_arm_outer_widths, x_arm_window_widths)
validate_arm(y_arm_outer_widths, y_arm_window_widths)
rotate(180)
    difference() {
        body();
        if (axis_labels) {
            engraving("X", [-short_arm_length / 2,
                            last(x_arm_outer_widths) / 2]);
            engraving("Y", [last(y_arm_outer_widths) / 2,
                            -short_arm_length / 2]);
        }
    }
