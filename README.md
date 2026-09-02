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
   Select `Generate XY gauge`, `Generate Z coupon`, or both. With both selected,
   the plugin places the Z column through the center of the XY grid, producing
   one physically connected calibration object.
3. Print the generated calibration object with the usual profile and let it
   cool to room temperature.
4. Take the selected measurements:

   - for XY, measure between the flat end faces near the middle of the gauge
     height, avoiding the edge chamfers and first-layer elephant foot;
     horizontal bars from bottom to top are X40, X80, X120, and vertical bars
     from left to right are Y40, Y80, Y120;
   - for Z, measure the three step heights from the common bottom surface;
     from left to right they are Z40, Z80, and Z120.

5. Run `2. Calculate and apply`. Select `Calibrate XY`, `Calibrate Z`, or both:

   - for XY, enter the six grid measurements;
   - for Z, enter the three measured step heights Z40, Z80, and Z120.

6. Inspect the applied values in the print and filament settings, then print
   the relevant calibration object again to verify the result.

The XY gauge is a single 120 x 120 x 5 mm `#`-like body. Its outside corners
and top/bottom edges are chamfered. Circular reliefs at the concave grid
corners provide sheltered seam locations away from all measured end faces.
The Z gauge consists of three overlapping 20 x 20 mm columns with nominal
heights of 40, 80, and 120 mm. Together they form one stepped part. When both
standards are generated, the steps intersect the center of the XY grid from
the build plate upward. The result remains a single connected
120 x 120 x 120 mm part, while all X/Y measuring end faces remain unobstructed.

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

## Model source

The bundled XY STL is generated from `model/dimensional_accuracy_gauge.scad`.
To regenerate it:

```bash
openscad --export-format binstl \
  -o dimensional_accuracy_gauge.stl \
  model/dimensional_accuracy_gauge.scad
```

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
- The Z step gauge is intentionally code-generated; unlike the XY gauge, it
  has no separate STL or OpenSCAD source.
- The Lua API cannot paint the seam automatically. Place it in one of the
  circular internal reliefs and away from the measured end faces.

## License

[GNU Affero General Public License v3.0](LICENSE).
