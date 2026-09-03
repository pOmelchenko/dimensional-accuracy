# Dimensional Accuracy Calibration

A calibration plugin for the PrusaSlicer 3.0 Lua Plugin API. It generates an
XY measurement grid and estimates dimensional error independently for the X,
Y, and optional Z axes:

```text
measured = scale * nominal + fixed_offset
```

## Requirements

- PrusaSlicer 3.0 or newer;
- `project.plugin` API version 1.0.0;
- an FFF printer preset (SLA presets are not supported);
- calipers with a resolution of 0.01–0.02 mm.

Applying the calculated values requires a PrusaSlicer build that includes the
Lua preset-setting fix. Earlier 3.0 alpha builds bypass preset-change
notifications, so the settings UI and slicing state may remain stale after
the calls.

Entering fractional measurements also requires the PrusaSlicer fix tracked in
[prusa3d/PrusaSlicer#15611](https://github.com/prusa3d/PrusaSlicer/issues/15611).
Affected builds swap the `float` and `int` dialog controls, so every fractional
X/Y/Z measurement is rounded to an integer before it reaches `execute(opts)`.

## Installation

Open the configuration directory with `Help -> Show Configuration Folder`,
create a `lua` directory inside it, and clone the plugin bundle:

```bash
git clone git@github.com:pOmelchenko/dimensional-accuracy.git \
  <config-dir>/lua/dev.omelchenko.dimensional-accuracy
```

Select `Plugins -> Rescan` in PrusaSlicer or restart the application.

## Usage

1. Set the compensation values for the axes being calibrated to zero:
   `XY Size Compensation` in the print profile and `Shrinkage compensation
   XY` / `Shrinkage compensation Z` in the filament profile.
2. Run `Plugins -> Calibration -> Dimensional accuracy -> 1. Generate gauge`.
   Select `Generate XY gauge`, `Generate Z gauge`, or both. The checkbox
   combination loads one of three prepared models: XY, Z, or a combined XY+Z
   layout whose two printable shells already have a 10 mm gap.
3. Print the generated calibration gauge(s) with the usual profile and let them
   cool to room temperature.
4. Take the selected measurements:

   - for XY, measure between the flat end faces near the middle of the gauge
     height, avoiding the edge chamfers and first-layer elephant foot;
     horizontal bars from bottom to top are X40, X80, X120, and vertical bars
     from left to right are Y40, Y80, Y120;
   - for Z, approach the thin stepped wall from its open side and measure from
     the common bottom datum to each upper step; from left to right they are
     Z40, Z80, and Z120.

5. Run `2. Calculate and apply`. Select `Calibrate XY`, `Calibrate Z`, or both:

   - for XY, enter the six grid measurements;
   - for Z, enter the three measured step heights Z40, Z80, and Z120.

6. Confirm the applied values in the print and filament settings, then print
   the relevant calibration object again to verify the result.

The XY-A gauge is a single 120 x 120 x 4.5 mm `#`-like body made from 6.5 mm
bars. Its measurement ends retain flat working faces of at least 5 x 3 mm,
while the outside top and bottom edges are chamfered. Recessed labels identify
all six dimensions and a concave pocket provides a sheltered seam location.

The Z-B gauge is a 52 x 24 x 120 mm stepped plate. Three adjacent 14 mm blades
share a 6.5 mm wall thickness and a common datum. Rear gussets stiffen the wall
without entering the open caliper approach side. Its recessed labels and seam
groove do not intersect the working planes. XY and Z are deliberately separate
files, so either standard can be generated and reprinted independently. The
combined layout is one PrusaSlicer object containing both non-touching shells.

The plugin writes independent X/Y scale factors, fit RMS error, anisotropy,
and the optional Z scale factor to the process log. Launch PrusaSlicer from a
terminal to see these values immediately.

## Calculation

For each axis, the plugin uses ordinary least squares to fit a straight line
to nominal lengths of 40, 80, and 120 mm. The slope represents scale error,
while the intercept represents a fixed dimensional offset. For X/Y this is
the combined offset of the two outer contours; for Z it captures effects such
as the first layer and layer-height rounding. The fit produces:

- independent X and Y scale corrections;
- a common `filament_shrinkage_compensation_xy` value;
- a common `xy_size_compensation` value;
- an optional `filament_shrinkage_compensation_z` value fitted from Z40, Z80,
  and Z120;
- the fixed Z offset and fit RMS, reported in the process log but not applied
  because PrusaSlicer has no corresponding Z-offset compensation setting.

The calculation is not tied to this particular mesh. Any gauge that supplies
the same three external nominal spans per axis can be used. The model assumes
that error is the sum of a length-dependent scale term and one constant
offset; it does not model nonlinear or feature-specific error.
Both XY and Z shrinkage estimates are limited to PrusaSlicer's supported
range of -10% to +10%; the process log reports a warning whenever limiting is
applied. XY and Z calculations are independent, so either one or both can be
run without validating or changing the unselected axis.

## Model source and prototypes

All models are generated from `model/dimensional_accuracy_gauge.scad`. Build
the three plugin layouts, the larger XY-A challenger, and the short Z-C/40 window
prototype with:

```bash
make all
make verify
```

`prototypes/dimensional_accuracy_xy_7x5.stl` tests the alternative 7 x 5 mm
bar section. `prototypes/dimensional_accuracy_zc40.stl` is a 50 mm fragment
with a 9 x 7 mm through-window whose lower working plane is exactly 40 mm from
the datum. Prototype files are not loaded by the plugin and must not replace
the bundled gauges without the physical repeatability experiment.

The verifier checks binary STL structure, manifold edges, connectedness,
bounds, geometric-volume targets, and the presence of every nominal
measurement plane. It does not replace slicing or physical measurements.

## Validation status

The generated meshes satisfy the automated geometry checks. Release approval
still requires slicing results and physical trials with multiple prints,
operators, and calipers. In particular, the smaller XY section must pass the
rigidity/repeatability check and Z-C may replace Z-B only if it is no worse in
access, repeatability, and systematic offset.

## MVP limitations

- PrusaSlicer provides one filament shrinkage value for both X and Y. The
  plugin applies their mean correction and writes the independent values to
  the log.
- The compensation settings are FFF-specific. The calculator rejects SLA
  presets before calculating or changing any settings.
- The Lua API cannot scale an existing object independently along X and Y.
- The plugin changes the active settings of the current project but does not
  create a saved user preset.
- The regression uses equal measurement weights and does not reject outliers.
- Plugin API 1.0.0 cannot arrange objects after adding them. The combined STL
  avoids overlap, but its XY and Z shells are one slicer object and cannot be
  moved or deleted independently.
- The Lua API cannot paint the seam automatically. Place it in the XY concave
  pocket or the Z rear groove, away from every measured face.

## License

[GNU Affero General Public License v3.0](LICENSE).
