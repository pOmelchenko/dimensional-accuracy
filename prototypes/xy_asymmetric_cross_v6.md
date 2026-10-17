# Asymmetric stepped cross with one L-shaped window — visual prototype v6

[OpenSCAD source](xy_asymmetric_cross_v6.scad).
Review outputs in `build/model-previews/`:
`xy_asymmetric_cross_v6.stl`,
`xy_asymmetric_cross_v6_top.png` and
`xy_asymmetric_cross_v6_tool.png`.

The user's reference is an asymmetric cross with width steps on the inward
sides and uninterrupted straight sides for depth-gauge approach. V6 keeps
constant 4.5 mm height and 120 × 120 mm bounds. Long-arm widths are 18/12/6 mm.
Short arms and long-arm tips are 6 mm wide.

One continuous L-shaped through window replaces the two separate v5 windows.
Each leg has a 26 mm internal longitudinal span and a 6 mm transverse width;
the void runs from station 4 to 30 on each axis. Measure transverse width
beyond the elbow, e.g. at station 24. Measure the complete longitudinal span
on the corresponding straight leg, e.g. at transverse station 7. These
internal features are distinct from the outside 24/6/90 chain.

The wide sections were increased from 14 to 18 mm to retain at least 4 mm of
material between the L-shaped window and the rectangular seam pocket.
The pocket remains 2.5 mm wide and 4 mm deep, with a flat closed end. Its
placement is a target for manual seam painting, not an automatic host action.
Corner and edge chamfers are 0.4 mm.

The nominal outside/depth chain remains 24 + 6 + 90 = 120 mm per axis:
- 24 mm short interval: depth measurement from short tip to the near face of
  the transverse short arm, ideal contour coefficient 0.
- 6 mm transverse short-arm width: outside jaws, coefficient +2.
- 90 mm long interval: depth measurement from long tip to the far face of
  the transverse short arm, coefficient 0.
- 120 mm full extent: outside jaws, coefficient +2.

The 18/12/6 outside widths are additional jaw measurements. This design does
not claim that every pair of intermediate width steps is directly accessible
to the depth gauge. Tool pose and base support must be checked for each pair.

The schematic caliper uses the user's approximate 7 mm rod-to-sole-edge reach
on the contact side. Opposite reach 7 mm, rod width 1 mm and sole Z thickness
3 mm are explicit assumptions. At a 6 mm tip, the rod centre is 1 mm outside
the straight side, while the supporting side of the sole spans the tip.
The body, entire sole and rod are represented, not just a centreline.

Development mode `review_check="clearance"` intersects the gauge with all
four full schematic tool poses (short/long on X/Y). Each tool retreats 0.01 mm
to exclude intended contact and numerical surface coincidence. A positive
control deliberately inserts a 1 mm cube into the gauge to check that the
intersection test detects interference. This geometric check does not validate
the real caliper, seating stability, printed surface quality or calibration
accuracy. The user must review the actual instrument fit.

The full sum is a consistency check, not a contour-neutral overall length.
An L-window supplies useful inner straight dimensions; physical verification
on independent printed parts is still required. No plugin catalog/calculator
or physical validation status is changed.

Build with OpenSCAD 2021.01 or newer:

```sh
mkdir -p build/model-previews
openscad --export-format binstl \
  -o build/model-previews/xy_asymmetric_cross_v6.stl \
  prototypes/xy_asymmetric_cross_v6.scad
```
