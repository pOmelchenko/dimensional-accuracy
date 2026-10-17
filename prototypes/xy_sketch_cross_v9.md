# User-dimensioned stepped cross — prototype v9

[OpenSCAD source](xy_sketch_cross_v9.scad).

V9 follows the user's revised 2026-09-06 sketch and explicit confirmation
of 10 × 45 mm windows with 7.5 mm offsets. It replaces the proposed V8
length distribution for the next visual review.

| Feature | Nominal size, mm |
| --- | --- |
| Overall X × Y × Z | 145 × 145 × 4.5 |
| Short / crossing / long chain, each axis | 30 + 15 + 100 = 145 |
| Start offset before the wide section | 10 |
| Three longitudinal sections | 30 / 30 / 30 |
| Outside widths, root to tip | 35 / 25 / 15 |
| Each window, width × length | 10 × 45 |
| Window interval along each long arm | 17.5…62.5 |
| Window offset from the straight outside edge | 7.5 |
| Window end offsets from the section planes at 10 and 70 | 7.5 / 7.5 |
| Window wall on the stepped side, wide / middle section | 17.5 / 7.5 |

The 7.5 mm dimensions refer to the nominal straight faces. The previously
requested square reliefs remain: 2 × 2 mm recesses at outside concave
corners, and squares extending 1 mm beyond each nominal window corner.
Thus at a window relief the nominal local web is 6.5 mm; the 0.375 mm
top/bottom chamfer reduces it further at the surface. Window measurements
must use the preserved straight faces away from those reliefs and chamfers.

The source permits switching windows and either relief family off, and
checks the actual overall span against 145 mm. The first 30 mm section
provides opposing outside contacts; the subsequent sections provide 30 mm
depth intervals. Related widths, wall thicknesses and compound lengths
share faces and should not be treated as independent repetitions in a fit.

Generated review files are in ignored `build/model-previews/`:
`xy_sketch_cross_v9.stl`, `xy_sketch_cross_v9_top.png`,
`xy_sketch_cross_v9_iso.png`.

Geometry validation on 2026-09-06, OpenSCAD 2021.01, default parameters:

- Binary STL: 3,328 triangles, one closed component, exact 145 × 145 × 4.5
  mm bounds at STL precision. No open/non-manifold edges, winding errors or
  degenerate triangles at the standard 0.001 mm verifier tolerance.
- All four terminal contact planes retain 53.438 mm² of flat surface.
- The eight complete schematic depth-tool poses have no volumetric
  interference after a 0.01 mm contact retreat. A 1 mm³ injected collision
  is detected. Tool assumptions: 7 mm from rod axis to each sole edge,
  1 mm rod width, 3 mm sole thickness.
- 25 rays across each rod tip reach the nominal 100 or 30 mm target.
  Opposing contacts confirm the external widths and first 30 mm section.
- Internal contacts confirm 45 × 10 mm at three positions per dimension,
  7.5/17.5 mm walls, 85 mm compound spans and 145 mm overall spans on both axes.
- Solid geometric volume: 22.185 cm³; not a print-time or filament estimate.

Build and verify:

```sh
openscad --export-format binstl \
  -o build/model-previews/xy_sketch_cross_v9.stl \
  prototypes/xy_sketch_cross_v9.scad
python3 tools/verify_stl.py build/model-previews/xy_sketch_cross_v9.stl \
  --expect-bounds 145 145 4.5 --expect-components 1 \
  --require-plane x=-45 --require-plane x=100 \
  --require-plane y=-100 --require-plane y=45 --min-plane-area 50
```

These checks establish nominal geometry, not printed accuracy, stiffness
under caliper force or complete real-jaw access. This prototype is not yet
integrated into the plugin's artifact catalog or compensation calculator.
