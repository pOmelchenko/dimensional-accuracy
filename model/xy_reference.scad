// SPDX-License-Identifier: AGPL-3.0-only
// Accepted XY-S revision 1, derived unchanged from approved prototype v10.
module xy_reference_gauge() {
    // SPDX-License-Identifier: AGPL-3.0-only
    // Copyright (C) 2026 pOmelchenko
    // V10: user's dimensioned sketch, 2026-09-06. Units: mm.
    // Long X points right; long Y points down. Constant height.

    /* [Dimensions] */
    height = 4.5;
    arm_width = 15;
    short_length = 30;
    step_start = 10;
    step_lengths = [30,30,30];
    step_increment = 10;
    maximum_span = 145;

    /* [Internal measurement windows] */
    windows_enabled = true;
    window_length = 45;
    window_width = 10;
    window_start = 17.5;
    // Distance from the straight outside edge to the nominal window face.
    window_edge_offset = 7.5;
    window_reliefs_enabled = true;
    // A 2 x 2 mm square centred on each nominal corner extends 1 mm past each face.
    window_corner_reach = 1;
    minimum_window_web = 6.5;

    /* [Corner reliefs] */
    reliefs_enabled = true;
    relief_width = 2;
    relief_depth = 2;
    // Also clear the two inside corners at the beginning of the widest sections.
    root_reliefs_enabled = true;

    /* [Finish] */
    // Exactly representable for clean OpenSCAD 2021.01 boolean intersections.
    edge_chamfer = 0.375;
    // Top and bottom relief edges; the vertical measurement region stays nominal.
    relief_chamfer = 0.375;
    labels_enabled = true;
    label_depth = 0.25;
    label_font = "Liberation Sans:style=Bold";

    /* [Instrument review - leave off for model export] */
    show_depth_gauge = false;
    // 0..3: long X, short X, long Y, short Y. 4..7: outer/middle X/Y steps.
    preview_pose = 0;
    review_check = "none"; // [none,clearance]
    review_inject_collision = false;
    contact_retreat = 0.01;
    rod_side_offset = 1;
    rod_width = 1;
    rod_to_sole_edge = 7;
    other_sole_reach = 7;
    sole_thickness_z = 3;

    /* [Hidden] */
    long_length = step_start + step_lengths[0] + step_lengths[1] + step_lengths[2];
    full_length = max(short_length,2*step_increment) + arm_width + long_length;
    step_a = step_start + step_lengths[0];
    step_b = step_a + step_lengths[1];
    eps = 0.01;

    assert(height > 2*edge_chamfer && edge_chamfer > 0);
    assert(relief_chamfer >= 0 && 2*relief_chamfer < height);
    assert(full_length <= maximum_span, "Overall X/Y length exceeds the caliper span limit");
    assert(arm_width > 2*edge_chamfer && short_length > 0);
    assert(step_start > 0 && step_increment > 0);
    assert(len(step_lengths) == 3 && min(step_lengths) > 0);
    assert(label_depth > 0 && label_depth < height-2*edge_chamfer);
    assert(relief_width > 0 && relief_depth > 0);
    assert(max(relief_width,relief_depth) < min(arm_width/2,step_start,step_increment));
    assert(review_check == "none" || review_check == "clearance");
    assert(preview_pose >= 0 && preview_pose < 8);
    if (windows_enabled) {
        r=window_reliefs_enabled ? window_corner_reach : 0;
        assert(window_length > 2*r && window_width > 2*r);
        assert(window_corner_reach > 0);
        assert(window_start-r >= step_start+minimum_window_web);
        assert(window_start+window_length+r <= step_b-minimum_window_web);
        assert(window_edge_offset-r >= minimum_window_web);
        assert(arm_width+step_increment-window_edge_offset-window_width-r
               >= minimum_window_web);
    }

    module perimeter() {
        polygon([
            [-arm_width-short_length,0], [-arm_width-short_length,arm_width],
            [-arm_width,arm_width], [-arm_width,arm_width+short_length],
            [0,arm_width+short_length], [0,arm_width],
            [long_length,arm_width], [long_length,0],
            [step_b,0], [step_b,-step_increment],
            [step_a,-step_increment], [step_a,-2*step_increment],
            [step_start,-2*step_increment], [step_start,0],
            [0,0], [0,-long_length],
            [-arm_width,-long_length], [-arm_width,-step_b],
            [-arm_width-step_increment,-step_b], [-arm_width-step_increment,-step_a],
            [-arm_width-2*step_increment,-step_a], [-arm_width-2*step_increment,-step_start],
            [-arm_width,-step_start], [-arm_width,0]
        ]);
    }

    module x_window() {
        translate([window_start,arm_width-window_edge_offset-window_width])
            square([window_length,window_width]);
    }

    module to_y_arm() { translate([-arm_width,0]) rotate(-90) children(); }

    module windows() {
        x_window();
        to_y_arm() x_window();
    }

    module x_window_reliefs() {
        y0=arm_width-window_edge_offset-window_width;
        for (x=[window_start,window_start+window_length])
            for (y=[y0,y0+window_width])
                translate([x-window_corner_reach,y-window_corner_reach])
                    relief_cutter([2*window_corner_reach,2*window_corner_reach]);
    }

    module window_reliefs() {
        x_window_reliefs();
        to_y_arm() x_window_reliefs();
    }

    module outline() {
        difference() {
            perimeter();
            if (windows_enabled) windows();
        }
    }

    // Through-cut with a 45-degree expansion at each end. Explicit rings keep
    // the middle footprint exact; including a relief in the body's Minkowski
    // construction would also change its vertical corner geometry.
    module relief_cutter(size) {
        c=relief_chamfer;
        overrun=0.125;
        if (c == 0)
            translate([0,0,-overrun]) cube([size[0],size[1],height+2*overrun]);
        else {
            levels=[-overrun,c,height-c,height+overrun];
            expansion=[c+overrun,0,0,c+overrun];
            points=[for (j=[0:3],i=[0:3])
                let(e=expansion[j])
                [i==0 || i==3 ? -e : size[0]+e,
                 i<2 ? -e : size[1]+e,
                 levels[j]]];
            sides=[for (j=[0:2],i=[0:3])
                [4*j+i,4*j+(i+1)%4,4*(j+1)+(i+1)%4,4*(j+1)+i]];
            polyhedron(points=points,
                       faces=concat([[3,2,1,0]],sides,[[12,13,14,15]]),convexity=4);
        }
    }

    // Recess one adjacent face, retaining the nominal flat target between bevels.
    module recess(p, angle=0) {
        translate(p) rotate(angle)
            relief_cutter([relief_width,relief_depth]);
    }

    module corner_reliefs() {
        recess([-arm_width,arm_width]);
        recess([0,arm_width],-90);
        recess([-arm_width,0],90);
        recess([0,0],180);
        recess([step_b,0]);
        recess([step_a,-step_increment]);
        recess([-arm_width,-step_b],-90);
        recess([-arm_width-step_increment,-step_a],-90);
        if (root_reliefs_enabled) {
            recess([step_start,0],90);
            recess([-arm_width,-step_start]);
        }
    }

    module octahedron(r) {
        polyhedron(
            points=[[r,0,0],[-r,0,0],[0,r,0],[0,-r,0],[0,0,r],[0,0,-r]],
            faces=[[0,2,4],[2,1,4],[1,3,4],[3,0,4],
                   [2,0,5],[1,2,5],[3,1,5],[0,3,5]],convexity=2);
    }

    module body() {
        minkowski() {
            translate([0,0,edge_chamfer])
                linear_extrude(height=height-2*edge_chamfer)
                    offset(delta=-edge_chamfer) outline();
            octahedron(edge_chamfer);
        }
    }

    module engraving(value,p,angle=0,size=3) {
        translate([p[0],p[1],height-label_depth])
            linear_extrude(height=label_depth+0.05)
                rotate(angle) text(value,size=size,font=label_font,
                                   halign="center",valign="center");
    }

    module gauge() {
        difference() {
            body();
            if (reliefs_enabled) corner_reliefs();
            if (windows_enabled && window_reliefs_enabled)
                window_reliefs();
            if (labels_enabled) {
                engraving("X",[-arm_width-short_length/2,arm_width/2],0,4);
                engraving("Y",[-arm_width/2,arm_width+short_length/2],0,4);
                for (i=[0:2]) {
                    w=arm_width+(2-i)*step_increment;
                    p=[step_start,step_a,step_b][i]+step_lengths[i]/2;
                    label_y=windows_enabled && i<2 ? -(2-i)*step_increment/2 : arm_width-w/2;
                    engraving(str(w),[p,label_y]);
                    engraving(str(w),[label_y-arm_width,-p],90);
                }
                if (windows_enabled) {
                    end_label=(window_start+window_length+step_b)/2;
                    window_centre=arm_width-window_edge_offset-window_width/2;
                    engraving(str(window_length),
                              [window_start+window_length/2,arm_width-window_edge_offset/2],0,2.5);
                    engraving(str(window_width),[end_label,window_centre],90,2.5);
                    engraving(str(window_length),
                              [-window_edge_offset/2,-window_start-window_length/2],0,2.5);
                    engraving(str(window_width),[window_centre-arm_width,-end_label],0,2.5);
                }
            }
        }
    }

    // Every row: sole origin, rotation, depth, signed offset of rod from origin.
    function pose(i) = [
        [[long_length,arm_width],0,long_length,rod_side_offset],
        [[-arm_width-short_length,0],180,short_length,rod_side_offset],
        [[0,-long_length],-90,long_length,rod_side_offset],
        [[-arm_width,arm_width+short_length],90,short_length,rod_side_offset],
        [[long_length,0],0,step_lengths[2],-rod_side_offset],
        [[step_b,-step_increment],0,step_lengths[1],-rod_side_offset],
        [[-arm_width,-long_length],-90,step_lengths[2],-rod_side_offset],
        [[-arm_width-step_increment,-step_b],-90,step_lengths[1],-rod_side_offset]
    ][i];

    module depth_gauge(i,retreat=0) {
        p=pose(i);
        assert(rod_side_offset > rod_width/2);
        assert(sole_thickness_z <= height-2*edge_chamfer);
        assert(rod_to_sole_edge > rod_side_offset);
        assert(step_increment > rod_to_sole_edge+rod_side_offset);
        translate(p[0]) rotate(p[1]) translate([retreat,0,0]) {
            z0=(height-sole_thickness_z)/2;
            translate([0,p[3]-rod_to_sole_edge,z0])
                cube([2,rod_to_sole_edge+other_sole_reach,sole_thickness_z]);
            translate([2,p[3]-rod_to_sole_edge+2,z0])
                cube([26,rod_to_sole_edge+other_sole_reach-4,sole_thickness_z]);
            translate([-p[2],p[3]-rod_width/2,(height-rod_width)/2])
                cube([p[2],rod_width,rod_width]);
        }
    }

    if (review_check == "clearance") {
        intersection() {
            gauge();
            union() {
                for (i=[0:7]) depth_gauge(i,contact_retreat);
                if (review_inject_collision) translate([1,5,1]) cube([1,1,1]);
            }
        }
    } else {
        color([0.22,0.47,0.49]) gauge();
        if (show_depth_gauge) color([0.18,0.4,0.85]) depth_gauge(preview_pose);
    }
}
