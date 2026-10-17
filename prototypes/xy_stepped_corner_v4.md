# Stepped XY corner with bearing pads — visual prototype v4

Review outcome: the user rejected the deep converging notch and the proposed
depth-gauge seating. The rod-only clearance check omitted the complete sole
and is not evidence of usable instrument access. V4 is retained as a rejected
approach proposal; [v5](xy_asymmetric_cross_v5.md) explores a different layout.

[OpenSCAD source](xy_stepped_corner_v4.scad).
Review files in `build/model-previews/`:
`xy_stepped_corner_v4.stl`,
`xy_stepped_corner_v4_top.png` and
`xy_stepped_corner_v4_measurements.png`.

V4 preserves v3's 120 × 120 × 4.5 mm bounds, three windows, 40/80/120
measurement planes and straight datum faces. Four local bearing pads widen
the 40/80 shoulder faces from 6 to 12 mm in nominal plan width (at least
11.2 mm of flat width remains clear of the 0.4 mm corner chamfers). Each pad has 8 mm
of solid backing and an 8 mm tapered return. The 120 end faces already have
12 mm nominal width. Disable `bearing_pads_enabled` to recover v3.
Pads add material locally; actual stiffness and print cost are not established.

Suggested measurement chain along each axis:
- Outside datum to 40 shoulder: 40 mm, outside jaws.
- 40 to 80 shoulders: 40 mm, a separate depth/step measurement.
- 80 to 120 end: 40 mm, a separate depth/step measurement.
- Outside datum to 120 end: 120 mm, outside jaws, checked against the sum.

For the X 40..80 interval, a schematic depth-gauge base bears against the
80 mm face while its probe reaches the 40 mm face through free space beside
the arm. The diagram places that probe at transverse station 27 mm. For
80..120 the base is at 120 and the probe reaches 80 at transverse station
20 mm. The Y setup is transposed. These are geometric approach proposals:
the actual caliper's base footprint, rod position, contact force and stability
must be checked. A nominal 12 × 4.5 mm face does not guarantee compatibility
with every caliper. Measurements use the flat mid-height band, not the rims.

The direct shoulder intervals have equally oriented contact normals, so a
uniform contour displacement cancels ideally. The first outside 0..40 span
and the full outside 0..120 span retain the idealized +2 contour coefficient.
Adding the three intervals therefore does NOT eliminate contour displacement
from the complete length. Sum closure is a consistency check; algebraically
derived differences must not be counted as independent readings.
The diagram is a measurement concept, not a validated instrument fixture.

This prototype does not change the plugin catalog, calculator, or physical
validation status. V1/V2/V3 remain available for comparison.

Generate with OpenSCAD 2021.01 or newer:

```sh
mkdir -p build/model-previews
openscad --export-format binstl \
  -o build/model-previews/xy_stepped_corner_v4.stl \
  prototypes/xy_stepped_corner_v4.scad
```
