# Asymmetric stepped cross — visual prototype v5

[OpenSCAD source](xy_asymmetric_cross_v5.scad).
Generated review files: `build/model-previews/xy_asymmetric_cross_v5.stl`,
`xy_asymmetric_cross_v5_top.png`, `xy_asymmetric_cross_v5_tool.png`.

V5 revisits the asymmetric-cross measurement principle illustrated in
[K3D/Sorkin's accuracy method](https://k3d.tech/calibrations/accuracy/).
The geometry is constructed here from parameters, without importing the K3D
model. Height remains constant at 4.5 mm. The footprint is 120 × 120 mm.

Each long arm has 14/10/6 mm transverse widths. All width changes are on one
side; the opposite side stays straight. Short arms and long-arm tips are 6 mm
wide. Two local 12 × 6 mm windows remain in the wide sections. A short diagonal
rectangular seam pocket (2.5 mm wide, 4 mm deep, flat closed end) replaces the
deep converging notch. Seam placement still requires slicer seam painting.

For each axis, the nominal chain is now 24 + 6 + 90 = 120 mm:

| Feature | Nominal | Proposed contact method | Ideal contour coefficient |
|---|---:|---|---:|
| Short tip to near face of transverse short arm | 24 mm | Depth measurement | 0 |
| Width of transverse short arm | 6 mm | Outside jaws | +2 |
| Far face of transverse short arm to long tip | 90 mm | Depth measurement | 0 |
| Overall tip-to-tip span | 120 mm | Outside jaws | +2 |

The 24/90 intervals use equally oriented contact faces. Uniform contour growth
cancels ideally in each; it does not cancel in the 6 mm width or complete sum.
The old 40/80/120 feature definitions do not apply to v5. A sum of independent
readings can be compared to the independent overall span, with instrument
method differences retained in the analysis.

The user supplied approximately 7 mm from rod to the sole edge. The schematic
uses that reach on the contact side, 7 mm on the opposite side, a 1 mm rod and
a 3 mm sole thickness in Z. Those additional dimensions are explicit preview
assumptions, not a specification of the user's caliper. At the 6 mm tip, the
rod centre is 1 mm beyond the common straight side. The supported half of the
sole spans the tip; the rod travels beside all width steps to the transverse
short arm. The actual instrument footprint and seating remain to be checked.

`show_depth_gauge=true` renders a blue schematic tool for review; do not use
that mode when exporting the printable STL. The default is the gauge alone.
This is a geometry proposal, not a validated calibration or a plugin update.

Build with OpenSCAD 2021.01 or newer:

```sh
mkdir -p build/model-previews
openscad --export-format binstl \
  -o build/model-previews/xy_asymmetric_cross_v5.stl \
  prototypes/xy_asymmetric_cross_v5.scad
```
