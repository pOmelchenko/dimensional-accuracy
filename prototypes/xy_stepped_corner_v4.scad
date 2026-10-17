// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 pOmelchenko
// Visual prototype v4: local bearing pads for direct inter-shoulder measurements.
// Units: mm. The two straight datum faces are x=0 and y=0 after rotation.
// Outside shoulders/end faces are at -40, -80 and -120 by default.

/* [Body] */
height = 4.5;
section_ends = [40, 80, 120];
// From the corner toward each tip. X-arm widths are measured along Y,
// and Y-arm widths are measured along X.
x_arm_widths = [24, 18, 12];
y_arm_widths = [24, 18, 12];

/* [Bearing pads] */
// Widen only the working faces at 40/80, keeping the intervening arms narrow.
bearing_pads_enabled = true;
bearing_face_width = 12;
bearing_pad_length = 8;
bearing_pad_ramp = 8;

/* [Windows] */
window_enabled = true;
// A compact L-shaped window entirely within the first section of each arm.
// Start/end positions are measured from the straight outside datum faces.
window_edge_offset = 6;
window_section_ends = [24, 34];
x_window_widths = [12, 6];
y_window_widths = [12, 6];
// All outside rims and the distance to the first shoulder retain this web.
minimum_window_web = 6;

// Separate windows in the 40..80 mm sections; solid material surrounds 40/80.
// The default interval is 46..74 mm, leaving a 12 mm bridge at the 40 mm step
// between the corner window (ending at 34 mm) and each middle window.
middle_windows_enabled = true;
middle_window_edge_offset = 6;
middle_window_end_margin = 6;
x_middle_window_width = 6;
y_middle_window_width = 6;

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

module validate_arm(widths, window_widths, middle_width) {
    assert(len(widths) == len(section_ends));
    for (i = [0 : len(section_ends) - 1]) {
        assert(section_ends[i] > section_start(i));
        assert(widths[i] > 2 * edge_chamfer);
        if (i > 0)
            assert(widths[i - 1] - widths[i] > 2 * edge_chamfer,
                   "Each shoulder needs a flat measurement face");
        if (bearing_pads_enabled && i < len(section_ends) - 1) {
            assert(bearing_face_width > 2 * edge_chamfer);
            assert(bearing_pad_length > 0 && bearing_pad_ramp > 0);
            assert(section_ends[i] - section_start(i)
                   > bearing_pad_length + bearing_pad_ramp,
                   "Bearing pad must stay within its section");
        }
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
    if (window_enabled && middle_windows_enabled) {
        assert(len(section_ends) >= 2);
        assert(middle_window_edge_offset >= minimum_window_web);
        assert(middle_window_end_margin >= minimum_window_web);
        assert(section_ends[1] - section_ends[0]
               > 2 * middle_window_end_margin,
               "Middle section is too short for its end webs");
        assert(middle_width > 2 * edge_chamfer);
        assert(middle_window_edge_offset + middle_width
               + minimum_window_web <= widths[1],
               "Middle window leaves an undersized outside rim");
    }
    children();
}

module transpose_xy() {
    mirror([1, -1, 0]) children();
}

module bearing_pad(widths, i) {
    end = section_ends[i];
    // Keep the working face in the same plane. Added width lies outside
    // the original arm, with a solid backing and a tapered return.
    pad_width = widths[i + 1] + bearing_face_width;
    if (pad_width > widths[i])
        polygon([
            [end - bearing_pad_length - bearing_pad_ramp, widths[i]],
            [end - bearing_pad_length, pad_width],
            [end, pad_width],
            [end, widths[i]]
        ]);
}

module arm_outline(widths) {
    union() {
        for (i = [0 : len(section_ends) - 1])
            translate([section_start(i), 0])
                square([section_ends[i] - section_start(i), widths[i]]);
        if (bearing_pads_enabled)
            for (i = [0 : len(section_ends) - 2])
                bearing_pad(widths, i);
    }
}

module arm_window(widths) {
    union()
        for (i = [0 : len(window_section_ends) - 1])
            translate([window_start(i), window_edge_offset])
                square([window_section_ends[i] - window_start(i), widths[i]]);
}

module middle_window(width) {
    start = section_ends[0] + middle_window_end_margin;
    finish = section_ends[1] - middle_window_end_margin;
    translate([start, middle_window_edge_offset])
        square([finish - start, width]);
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
                if (middle_windows_enabled) {
                    middle_window(x_middle_window_width);
                    transpose_xy() middle_window(y_middle_window_width);
                }
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
    // faces at default settings. Solid bridges and bearing pads back each shoulder.
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

validate_arm(x_arm_widths, x_window_widths, x_middle_window_width)
validate_arm(y_arm_widths, y_window_widths, y_middle_window_width)
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
