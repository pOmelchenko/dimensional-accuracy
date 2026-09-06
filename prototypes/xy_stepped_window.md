# Stepped XY cross with a parametric window — visual prototype v1

[OpenSCAD source](xy_stepped_window.scad). The generated review mesh is
`build/model-previews/xy_stepped_window_v1.stl`.

This is a shape proposal based on the user's sketch: long arms extend left and
down, short arms extend right and up. One side of each long arm is straight;
the opposite side has three steps. A single connected L-shaped through window
has three stepped widths along each long arm. X/Y engravings identify the arm
directions, not the directions of the transverse width measurements.

Default dimensions:

| Parameter | Value |
|---|---|
| Overall bounds | 120 × 120 × 4.5 mm |
| Long / short reach from the crossing datum | 90 / 30 mm |
| Section ends from that datum | 44, 67, 90 mm |
| Outside widths, crossing to tip | 24, 18, 12 mm |
| Window widths, crossing to tip | 18, 12, 6 mm |
| Minimum web / window end margin | 3 / 3 mm |
| Top and bottom edge chamfer | 0.4 mm |

The X and Y arm width arrays can be edited independently. Window widths are
independent of outside widths, subject to the minimum-web assertions. Set
`window_enabled=false` to review the solid variant. Window shoulders are
offset 3 mm from outside shoulders to preserve material at each step. The
straight mid-height surfaces carry the nominal widths; chamfered rims and the
crossing are not width measurement locations.

Example paired outside/inside width stations are 32, 54 and 77 mm along each
long arm from the crossing datum. These fall within constant-width sections
of both outlines and clear the crossing. Jaw access and contact lengths still
need review with the intended caliper. Changing parameters can invalidate
these example stations.

Build with OpenSCAD 2021.01 or newer:

```sh
mkdir -p build/model-previews
openscad --export-format binstl \
  -o build/model-previews/xy_stepped_window_v1.stl \
  prototypes/xy_stepped_window.scad
```

This prototype is not connected to the plugin's artifact catalog or calculator.
It has not passed a physical calibration trial. The current released geometry
and its measurement definitions remain unchanged.
