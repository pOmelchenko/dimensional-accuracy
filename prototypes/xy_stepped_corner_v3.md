# Stepped XY corner with middle windows — visual prototype v3

[Parametric OpenSCAD source](xy_stepped_corner_v3.scad).
Review STL: `build/model-previews/xy_stepped_corner_v3.stl`.
Top view: `build/model-previews/xy_stepped_corner_v3_top.png`.

V3 adds one rectangular window to each 40..80 mm arm section. Each new opening
is 28 × 6 mm, extending from station 46 to 74 mm and leaving 6 mm side rims.
The corner window still ends at 34 mm. Thus a 12 mm solid bridge spans the
40 mm shoulder, from 34 to 46 mm; another 6 mm solid end web precedes the
80 mm shoulder. The 80..120 mm sections remain solid.

Overall dimensions, outside measuring faces, labels and the corner window are
unchanged from [v2](xy_stepped_corner_v2.md): 120 × 120 × 4.5 mm, outside widths
24/18/12 mm and outside spans 40/80/120 mm per axis. The three windows are
separate through openings in one connected body. Dimensions refer to the flat
mid-height faces; the 0.4 mm top/bottom chamfers enlarge window rims.

Set `middle_windows_enabled=false` to recover the v2 geometry, or set
`window_enabled=false` to close all windows. Middle window widths, side offsets
and end margins are parameters with minimum-web checks. Stiffness under caliper
force and print cost still require measurement; this is a visual proposal only.
No plugin catalog or calculator integration is part of this revision.

Build with OpenSCAD 2021.01 or newer:

```sh
mkdir -p build/model-previews
openscad --export-format binstl \
  -o build/model-previews/xy_stepped_corner_v3.stl \
  prototypes/xy_stepped_corner_v3.scad
```
