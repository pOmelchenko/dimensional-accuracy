# Dimensional Accuracy Calibration

An MVP plugin for the PrusaSlicer 3.0 Lua Plugin API. It generates a
parametric measurement gauge and estimates dimensional error independently
for the X and Y axes:

```text
measured = scale * nominal + contour_offset
```

## Requirements

- PrusaSlicer 3.0 or newer;
- `project.plugin` API version 1.0.0;
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

1. Set `XY Size Compensation` in the print profile and
   `Shrinkage compensation XY` in the filament profile to zero.
2. Run
   `Plugins -> Calibration -> Dimensional accuracy -> 1. Generate gauge`.
3. Print the gauge with the usual profile and let it cool to room
   temperature.
4. Measure the gauge near the middle of its height to avoid first-layer
   elephant-foot distortion:

   - horizontal bars from bottom to top: X40, X80, X120;
   - vertical bars from left to right: Y40, Y80, Y120.

5. Enter the six measurements in
   `2. Calculate and apply`.
6. Inspect the applied values in the print and filament settings, then print
   another gauge to verify the result.

The plugin writes independent X/Y scale factors, fit RMS error, and
anisotropy to the process log. Launch PrusaSlicer from a terminal to see
these values immediately.

## Calculation

For each axis, the plugin fits a straight line to nominal lengths of 40, 80,
and 120 mm. The slope represents scale error, while the intercept represents
the combined offset of the two outer contours. The fit produces:

- independent X and Y scale corrections;
- a common `filament_shrinkage_compensation_xy` value;
- a common `xy_size_compensation` value.

## MVP limitations

- PrusaSlicer provides one filament shrinkage value for both X and Y. The
  plugin applies their mean correction and writes the independent values to
  the log.
- The Lua API cannot scale an existing object independently along X and Y.
- The plugin changes the active settings of the current project but does not
  create a saved user preset.
- The regression uses equal measurement weights and does not reject outliers.
- The Lua API cannot paint the seam automatically. Place it at an internal
  bar intersection and away from the measured end faces.

## License

[GNU Affero General Public License v3.0](LICENSE).
