# Stepped cross from the user's sketch — prototype v8

[OpenSCAD source](xy_sketch_cross_v8.scad). This is a geometry review model,
not a new artifact already supported by the plugin calculator.

The asymmetric outline follows the user's 2026-09-06 sketch, with square
corner recesses and two separate rectangular measurement windows. Long X
points right, long Y down. Dimensions were adjusted to fit a 145 mm outside
span using round values. The user requested that the windows become shorter
while retaining their 10 mm width; this is not a uniform scale operation.

| Feature | Nominal size, mm |
| --- | --- |
| Overall X × Y × Z | 145 × 145 × 4.5 |
| Short / crossing / long chain, each axis | 20 + 15 + 110 = 145 |
| Long-arm start offset | 5 |
| Three longitudinal sections | 35 + 35 + 35 |
| Outside section widths, root to tip | 35 / 25 / 15 |
| Each internal window, length × width | 55 × 10 |
| Window interval along the long arm | 10…65 |
| Straight-edge window wall | 5 |
| Opposite window wall in the wide / middle section | 20 / 10 |
| Outside corner recess footprint | 2 × 2 |

The long-arm dimension chain is 5 + 35 + 35 + 35 = 110. The first 35 mm
section has opposing outside faces; the two subsequent sections provide
35 mm depth intervals. Additional combinations, including 90 mm outside
spans, are possible. These related dimensions should not be treated as
independent repetitions in a future fit: shared faces and sum relationships
need to be represented in the measurement model.

Each window has four square corner reliefs, centred on the nominal corners
and extending 1 mm beyond the straight faces. The 55 × 10 dimensions refer
to those straight faces, measured away from the reliefs and the top/bottom
chamfers. Reliefs at the crossing and width steps retain the intended flat
depth targets; two additional root corners are relieved as well.

Nominal webs adjacent to the window reliefs are at least 4 mm in the vertical
wall region. The 0.375 mm edge chamfer reduces the local width at the top and
bottom faces. Strength under caliper force has not been measured.

Parameters separately control lengths, widths, height, the windows and both
sets of reliefs. The source checks the actual overall span against 145 mm,
including any width protruding beyond a short arm. Changing the geometry
requires regenerating and reviewing the STL; default contact checks do not
certify arbitrary parameter combinations.

Review artifacts are generated into ignored `build/model-previews/`:
`xy_sketch_cross_v8.stl`, `xy_sketch_cross_v8_top.png`,
`xy_sketch_cross_v8_iso.png`, and `xy_sketch_cross_v8_corner.png`.

Build and check, using OpenSCAD 2021.01:

```sh
openscad --export-format binstl \
  -o build/model-previews/xy_sketch_cross_v8.stl \
  prototypes/xy_sketch_cross_v8.scad
python3 tools/verify_stl.py build/model-previews/xy_sketch_cross_v8.stl \
  --expect-bounds 145 145 4.5 --expect-components 1 \
  --require-plane x=-35 --require-plane x=110 \
  --require-plane y=-110 --require-plane y=35 --min-plane-area 50
```

The schematic depth tool assumes 7 mm from the rod axis to each sole edge,
a 1 mm rod and a 3 mm sole thickness. `review_check="clearance"` intersects
the complete tool with the gauge in eight short/long/step X/Y poses after a
0.01 mm retreat from intended contact. `review_inject_collision=true` adds
a 1 mm³ positive control. These checks cover geometric interference, not
the seating of a particular real caliper or the behavior of a printed part.

Internal dimensions can support future checks of inner contour error and
its agreement with external measurements. The model alone does not prove
that one correction will improve all internal features, nor does it enable
writing an internal compensation setting in the current plugin.

Geometry validation on 2026-09-06, final default parameters:

- STL: 3,448 triangles, one closed component; no open/non-manifold edges,
  winding errors or degenerate triangles at the standard 0.001 mm tolerance.
  Bounds are exactly 145 × 145 × 4.5 mm at STL precision.
- Geometric solid volume: 22.630 cm³. This is not printed material usage or
  a print-time estimate.
- All eight schematic tool poses clear the body; the deliberately injected
  1 mm³ collision is detected.
- 25 rays across each rod tip contact the nominal 20, 110 or 35 mm target.
  Opposing contacts confirm the first 35 mm section and widths 15/25/35 mm.
- Window faces give 55 × 10 mm at three positions per dimension. Additional
  contacts verify 5/10/20 mm walls, 90 mm compound spans and 145 mm full spans
  on both axes. These are geometric contact checks, not a complete caliper
  jaw-access or physical measurement validation.
