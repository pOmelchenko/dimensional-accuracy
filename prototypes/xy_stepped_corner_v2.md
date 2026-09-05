# Stepped XY corner — visual prototype v2

[Parametric OpenSCAD source](xy_stepped_corner_v2.scad).
Review STL: `build/model-previews/xy_stepped_corner_v2.stl`.
Top view: `build/model-previews/xy_stepped_corner_v2_top.png`.

This revision removes both short extensions. The two long straight outside
faces form the X/Y datums. Shoulders at 40 and 80 mm, plus the 120 mm end face,
provide three outside spans per axis. Labels X40/X80/X120 and Y40/Y80/Y120
identify these spans, not the transverse arm widths.

Default outside widths remain 24/18/12 mm from the corner toward each tip.
Overall bounds are 120 × 120 × 4.5 mm. The stepped measurement areas are solid;
the previous full-length window has been replaced by one compact L-shaped
window at the corner, with 12 and 6 mm local widths. It starts 6 mm from each
datum, ends at 34 mm, and retains at least 6 mm to the first outside shoulder.
Top/bottom chamfers are 0.4 mm. Change `window_enabled` to remove the window.

The 6 mm inner widths have clear measuring lands at station 29 mm along each
arm. The 12 mm widths have short lands beyond the window intersection; access
with the intended inside jaws must be reviewed. Neither the corner intersection
nor a chamfer is a nominal-width contact location.

Outside shoulder spans respond to uniform contour growth as outside dimensions
(idealized coefficient +2). Removing the short extensions does not turn these
into contour-neutral measurements. Any future calculator integration must use
their actual contact geometry and separately describe the inside measurements.

This is a visual proposal, not an approved replacement for the plugin's current
artifact. Arm stiffness, jaw access, print time/material and physical correction
performance have not been validated. The existing catalog/calculator is not
changed by this prototype. V1 remains available for comparison.

Generate with OpenSCAD 2021.01 or newer:

```sh
mkdir -p build/model-previews
openscad --export-format binstl \
  -o build/model-previews/xy_stepped_corner_v2.stl \
  prototypes/xy_stepped_corner_v2.scad
```
