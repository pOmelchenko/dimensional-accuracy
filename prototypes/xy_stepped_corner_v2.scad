// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 pOmelchenko
// Visual prototype v2: solid stepped arms, no short extensions, local window.
// Units: mm. The two straight datum faces are x=0 and y=0 after rotation.
// Outside shoulders/end faces are at -40, -80 and -120 by default.

/* [Body] */
height = 4.5;
section_ends = [40, 80, 120];
// From the corner toward each tip. X-arm widths are measured along Y,
// and Y-arm widths are measured along X.
x_arm_widths = [24, 18, 12];
y_arm_widths = [24, 18, 12];

/* [Local through window] */
window_enabled = true;
// A compact L-shaped window entirely within the first section of each arm.
// Start/end positions are measured from the straight outside datum faces.
window_edge_offset = 6;
window_section_ends = [24, 34];
x_window_widths = [12, 6];
y_window_widths = [12, 6];
// All outside rims and the distance to the first shoulder retain this web.
minimum_window_web = 6;

/* [Finish] */
edge_chamfer = 0.4;
dimension_labels = true;
label_depth = 0.25;
label_font = "Liberation Sans:style=Bold";

function last(values) = values[len(values) - 1];
function section_start(i) = i == 0 ? 0 : section_ends[i - 1];
function window_start(i) = i == 0 ? window_edge_offset
                                 : window_section_ends[i - 1];

assert(edge_chamfer > 0 && height > 2 * edge_chamfer);
assert(len(section_ends) > 0);
assert(label_depth > 0 && label_depth < height - 2 * edge_chamfer);

module validate_arm(widths, window_widths) {
    assert(len(widths) == len(section_ends));
    for (i = [0 : len(section_ends) - 1]) {
        assert(section_ends[i] > section_start(i));
        assert(widths[i] > 2 * edge_chamfer);
        if (i > 0)
            assert(widths[i - 1] - widths[i] > 2 * edge_chamfer,
                   "Each shoulder needs a flat measurement face");
    }
    if (window_enabled) {
        assert(minimum_window_web > 2 * edge_chamfer);
        assert(window_edge_offset >= minimum_window_web);
        assert(len(window_section_ends) > 0);
        assert(len(window_widths) == len(window_section_ends));
        assert(last(window_section_ends) <= section_ends[0]
               - minimum_window_web,
               "Keep the local window clear of the first shoulder");
        for (i = [0 : len(window_section_ends) - 1]) {
            assert(window_section_ends[i] > window_start(i));
            assert(window_widths[i] > 2 * edge_chamfer);
            assert(window_edge_offset + window_widths[i]
                   + minimum_window_web <= widths[0],
                   "Window leaves an undersized outside rim");
            if (i > 0)
                assert(window_widths[i] <= window_widths[i - 1]);
        }
    }
    children();
}

module transpose_xy() {
    mirror([1, -1, 0]) children();
}

module arm_outline(widths) {
    union()
        for (i = [0 : len(section_ends) - 1])
            translate([section_start(i), 0])
                square([section_ends[i] - section_start(i), widths[i]]);
}

module arm_window(widths) {
    union()
        for (i = [0 : len(window_section_ends) - 1])
            translate([window_start(i), window_edge_offset])
                square([window_section_ends[i] - window_start(i), widths[i]]);
}

module outline() {
    difference() {
        union() {
            arm_outline(x_arm_widths);
            transpose_xy() arm_outline(y_arm_widths);
        }
        if (window_enabled)
            union() {
                arm_window(x_window_widths);
                transpose_xy() arm_window(y_window_widths);
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
    // Both rims are chamfered; the middle 3.7 mm height preserves nominal
    // faces at default settings. The stepped arms remain solid in section.
    minkowski() {
        translate([0, 0, edge_chamfer])
            linear_extrude(height = height - 2 * edge_chamfer)
                offset(delta = -edge_chamfer) outline();
        octahedron(edge_chamfer);
    }
}

module engraving(value, position, angle) {
    translate([position[0], position[1], height - label_depth])
        linear_extrude(height = label_depth + 0.05)
            rotate(angle)
                text(value, size = 2.8, font = label_font,
                     halign = "center", valign = "center");
}

validate_arm(x_arm_widths, x_window_widths)
validate_arm(y_arm_widths, y_window_widths)
rotate(180)
    difference() {
        body();
        if (dimension_labels)
            for (i = [0 : len(section_ends) - 1]) {
                engraving(str("X", section_ends[i]),
                          [section_ends[i] - 7, x_arm_widths[i] - 3], 180);
                engraving(str("Y", section_ends[i]),
                          [y_arm_widths[i] - 3, section_ends[i] - 7], 270);
            }
    }
