# Asymmetric stepped cross with corner reliefs — visual prototype v7

[OpenSCAD source](xy_asymmetric_cross_v7.scad).
Review files in `build/model-previews/`:
`xy_asymmetric_cross_v7.stl`,
`xy_asymmetric_cross_v7_top.png`,
`xy_asymmetric_cross_v7_corner.png` and
`xy_asymmetric_cross_v7_tool.png`.

The user supplied `/Users/omelchenko/Downloads/k3d_accuracy_test_v8.stl`
as a corner-clearance reference. It was inspected directly. Its recessed
junctions move the corner transition away from the adjacent working plane.
V7 applies that construction principle to our parametric model; no reference
mesh geometry is copied into the prototype.

V6's nominal dimensions remain: 120 × 120 × 4.5 mm, 18/12/6 mm long-arm widths,
6 mm short arms, depth/outside chain 24 + 6 + 90 = 120 per axis, and one
L-shaped window with 26 × 6 mm internal legs.

Reliefs:
- At the two long-interval target junctions, 2 × 0.8 mm rectangular recesses
  remove the adjacent material and extend the flat target plane into the
  recess. The closed end is displaced from the rod landing.
- At the shared short/short junction, a 0.4 mm radius pocket clears the corner.
  An assertion keeps this recess outside the entire default 1 mm rod contact
  strip, whose centre is 1 mm beyond the straight side.
- Similar 2 × 0.8 mm recesses clear the inside corners at width steps.
- Five 0.65 mm radius reliefs clear the convex corners of the L-shaped void.
  Working inside sizes refer to the preserved straight faces, measured away
  from the reliefs. At the window's outside rims at least 3.35 mm of nominal
  material remains. The internal elbow is preserved to protect the seam web.
- The separate flat-ended 2.5 × 4 mm seam pocket remains in the inside corner.

Reliefs are parameterized and can be disabled with
`corner_reliefs_enabled=false`. These are local geometric clearances,
not scale/contour compensation values written to the slicer. The actual print
may still require adjustment for corner bulges and the real caliper.
Reliefs are cut after the body's chamfers so their nominal plan footprint
does not spread onto the adjacent contact strip during chamfer construction.
The edge chamfer is 0.375 mm. This exactly representable offset avoids
microscopic intersection slivers in OpenSCAD 2021.01's mesh export.

The schematic instrument retains V6's explicit assumptions: 7 mm reach from
rod axis to sole edge on the contact side (user approximation), 7 mm on the
opposite side, 1 mm rod width, 3 mm sole thickness. Full-body clearance for
all four short/long X/Y poses is checked with OpenSCAD intersection after a
0.01 mm retreat from intended contact. A deliberately inserted cube provides
a positive control. STL-based rod rays additionally check that first contact
is still the nominal flat plane rather than a relief bottom.

Geometry review on 2026-09-06, default parameters, OpenSCAD 2021.01:

- Binary STL: 5,484 triangles, one closed component, no open/non-manifold
  edges, winding errors or degenerate triangles at the repository verifier's
  0.001 mm tolerance. Bounds: 120 × 120 × 4.5 mm.
- All four terminal measurement planes remain, each with 19.688 mm² of
  planar surface. Geometric solid volume: 9.073 cm³ (not a slicing estimate).
- Four full schematic instrument poses: no volumetric interference;
  the deliberately injected 1 mm³ collision was detected.
- 25 rays across each of four rod-tip positions: first contact at exactly
  the nominal 24 or 90 mm within the 0.001 mm check tolerance.

This remains a visual/geometry prototype; no physical accuracy or instrument
fit is certified, and the plugin calculator/catalog are unchanged.

Build with OpenSCAD 2021.01 or newer:

```sh
mkdir -p build/model-previews
openscad --export-format binstl \
  -o build/model-previews/xy_asymmetric_cross_v7.stl \
  prototypes/xy_asymmetric_cross_v7.scad
```
