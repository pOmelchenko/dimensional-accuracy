# Chamfered corner reliefs — prototype v10

[OpenSCAD source](xy_sketch_cross_v10.scad).

V10 adds 0.375 mm × 45° top and bottom chamfers to all enabled reliefs:
the crossing, the width steps, the two root corners and the eight window
corners. The nominal dimensions and placement from [V9](xy_sketch_cross_v9.md)
remain: 145 × 145 × 4.5 mm overall, 10 × 45 mm windows, 7.5 mm nominal
window offsets, 30 mm sections and 15/25/35 mm outside widths.

The relief cutters use explicit tapered end sections. Their middle
rectangular footprint remains nominal from z = 0.375 to 4.125 mm; only the
surface opening expands. This avoids spreading a relief through the full
measurement height. `relief_chamfer` controls this bevel independently of
the body's `edge_chamfer`; both default to 0.375 mm. The reliefs still pass
through the part and their blind edges remain flat between the chamfers.

At a window relief the nominal middle web is 6.5 mm. Where both its outside
edge and relief opening are chamfered, the top/bottom surface web can be
5.75 mm. Measurements refer to the vertical faces, away from the chamfers.

Generated files in ignored `build/model-previews/`:
`xy_sketch_cross_v10.stl`, `xy_sketch_cross_v10_top.png`,
`xy_sketch_cross_v10_iso.png`, `xy_sketch_cross_v10_corner.png`.

Validation on 2026-09-06 with OpenSCAD 2021.01:

- STL: 3,400 triangles, one closed component, exact 145 × 145 × 4.5 mm
  bounds at STL precision. No open/non-manifold edges, winding errors or
  degenerate triangles at the standard 0.001 mm verifier tolerance.
- All four terminal contact planes retain 53.438 mm² of flat surface.
- The eight complete schematic depth-tool poses remain clear; the injected
  1 mm³ collision is detected. Tool assumptions are unchanged from V9.
- Nominal rod contacts, outside dimensions, 45 × 10 mm windows, 7.5/17.5 mm
  walls and 85/145 mm compound/full spans pass the STL contact checks.
- At representative step, long/short crossing and window reliefs, rays
  at five heights verify the 45° taper at both surfaces and the unchanged
  middle wall. At z = 0.1 and 4.4 mm the cut extends 0.275 mm beyond its
  nominal footprint; at mid-height the extension is zero.
- Solid geometric volume: 22.170 cm³, not a filament usage estimate.

Build and verify:

```sh
openscad --export-format binstl \
  -o build/model-previews/xy_sketch_cross_v10.stl \
  prototypes/xy_sketch_cross_v10.scad
python3 tools/verify_stl.py build/model-previews/xy_sketch_cross_v10.stl \
  --expect-bounds 145 145 4.5 --expect-components 1 \
  --require-plane x=-45 --require-plane x=100 \
  --require-plane y=-100 --require-plane y=45 --min-plane-area 50
```

This is a geometry prototype. Real caliper seating, printed accuracy and
stiffness are not established, and the plugin calculator is not changed.
