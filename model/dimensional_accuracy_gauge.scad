// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 pOmelchenko

$fn = 24;

gauge_height = 5;
bar_width = 8;
bar_pitch = 12;
corner_chamfer = 1;
edge_chamfer = 0.4;
relief_radius = 1.25;
nominal_lengths = [40, 80, 120];
render_3d = true;

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

module grid_outline() {
    difference() {
        union() {
            for (index = [0 : 2]) {
                offset = (index - 1) * bar_pitch;
                translate([0, offset])
                    chamfered_rectangle(
                        [nominal_lengths[index], bar_width],
                        corner_chamfer
                    );
                translate([offset, 0])
                    chamfered_rectangle(
                        [bar_width, nominal_lengths[index]],
                        corner_chamfer
                    );
            }
        }

        // Open circular reliefs at every concave grid corner give the seam a
        // sheltered location and keep it away from the measured end faces.
        for (x_index = [-1 : 1])
            for (y_index = [-1 : 1])
                for (x_side = [-1, 1])
                    for (y_side = [-1, 1])
                        translate([
                            x_index * bar_pitch + x_side * bar_width / 2,
                            y_index * bar_pitch + y_side * bar_width / 2
                        ])
                            circle(r = relief_radius);
    }
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

if (render_3d) {
    // The inset extrusion plus octahedral Minkowski sum produces a true
    // chamfer on the top, bottom, and outline edges while preserving nominal
    // dimensions through the middle of the gauge height.
    minkowski() {
        translate([0, 0, edge_chamfer])
            linear_extrude(height = gauge_height - 2 * edge_chamfer)
                offset(delta = -edge_chamfer)
                    grid_outline();
        octahedron(edge_chamfer);
    }
} else {
    grid_outline();
}
