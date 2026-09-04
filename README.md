# Dimensional Accuracy Calibration (experimental)

An experimental calibration plugin for the PrusaSlicer Lua Plugin API. It
generates an XY measurement grid and estimates dimensional error independently
for the X, Y, and optional Z axes:

```text
measured = scale * nominal + observed_additive_term
```

> **Not ready for production presets.** The meshes pass automated geometry
> checks, but no physical validation results have been recorded and there is no
> currently supported public PrusaSlicer build for the complete
> calculate-and-apply workflow.

## Compatibility and requirements

- PrusaSlicer 3.0.0-alpha11 for gauge generation and calculation-only preview;
- for automatic application, a development PrusaSlicer build containing both
  preset-setting host fixes described below;
- `project.plugin` API version 1.0.0;
- an FFF, single-material print using physical extruder/material slot 1 (SLA
  and multi-material calibration are not supported);
- calipers with a resolution of 0.01–0.02 mm.

As of 2026-09-04, the public PrusaSlicer source baseline is 3.0.0-alpha11. Gauge
generation and a calculation-only preview are supported for experimental use.
Automatic application is not supported on that build: Lua preset setters bypass
preset-change notifications, so the settings UI and slicing state may remain
stale after the calls. An apply-capable host must include both the preset-update
fix and the material-override activation fix before this workflow is tested.

The PrusaSlicer float-control defect is tracked in
[prusa3d/PrusaSlicer#15611](https://github.com/prusa3d/PrusaSlicer/issues/15611).
The plugin deliberately accepts measurements as text to avoid the swapped
`float` and `int` controls in alpha11. Enter 3–5 positive decimal readings separated by `;`, for example
`39,98;40,00;39,99`. Each reading accepts `.` or `,` as the decimal separator;
surrounding spaces are accepted and preserved in the structured result. Invalid text,
non-finite values, and non-positive measurements are rejected.

The manifest's `3.0.0-alpha11` minimum names the earliest public build supported
for generation and preview. It is not a promise that automatic application
works on alpha11 or on every later 3.0 build. An exact public apply-capable
PrusaSlicer version will be named only after the host and physical validation
gates pass.

## Development installation

There is no signed release yet. For development and review, clone the source
outside PrusaSlicer's configuration directory, run the test-backed staging
target, then link only that seven-file payload. Do not place the source checkout
itself under `lua`: PrusaSlicer recursively treats every `*.lua` file in a
bundle as a runtime plugin. Development staging needs Python 3 plus Lua 5.4;
the release target additionally needs OpenSCAD.

```bash
git clone --branch fix/lua-plugin-settings \
  https://github.com/pOmelchenko/dimensional-accuracy.git
cd dimensional-accuracy
make stage-plugin-existing

PRUSASLICER_CONFIG_DIR="/path/shown/by/Help/Show Configuration Folder"
mkdir -p "$PRUSASLICER_CONFIG_DIR/lua"
ln -s "$PWD/build/dev.omelchenko.dimensional-accuracy" \
  "$PRUSASLICER_CONFIG_DIR/lua/dev.omelchenko.dimensional-accuracy"
```

Select `Plugins -> Rescan` in PrusaSlicer or restart the application.

A public release requires all of the following: a named known-good PrusaSlicer
version, recorded XY and Z physical trials, a successful slicing smoke test,
and a signed plugin archive. The staged payload contains exactly seven files:
`LICENSE`, `manifest.json`, the two Lua entry points, and the three runtime STL
files—no research prototypes or build tooling. A Git checkout is not a release
artifact.

## Usage

On the current public PrusaSlicer baseline, use the calculator only as a preview:
leave all `Apply ...` checkboxes cleared and read the result in the process log.
They are cleared by default. Automatic application is restricted to a
development host containing both preset-setting fixes. Every apply run requires
two separate explicit confirmations: the running PrusaSlicer build is a
validated apply-capable host, and the exact gauge being measured was printed
with every selected compensation setting at zero. The current preset values do
not prove how that gauge was printed.

1. Select an FFF profile and put the calibration filament in material slot 1.
   Use a single-material print: no multi-material painting, supports from
   another extruder, or wipe-tower routing. The generator explicitly assigns
   the gauge object to physical extruder 1, and the calculator targets only the
   material settings for slot 1.
2. Set the compensation values for the axes being calibrated to zero:
   `XY Size Compensation` in the print profile and `Shrinkage compensation
   XY` / `Shrinkage compensation Z` in the filament profile. This is a
   measurement-model precondition, not an optional cleanup step. Preview mode
   warns when it can read a non-zero baseline; apply mode refuses all writes.
3. Run `Plugins -> Calibration -> Dimensional accuracy -> 1. Generate gauge`.
   Select `Generate XY gauge`, `Generate Z gauge`, or both. The checkbox
   combination loads one of three prepared models: XY, Z, or a combined XY+Z
   layout whose two printable shells already have a 10 mm gap.
4. Confirm that the object is assigned to extruder 1, print the generated
   calibration gauge(s) with the usual profile, and let them cool to room
   temperature.
5. Take the selected measurements:

   - for XY, measure between the flat end faces near the middle of the gauge
     height, avoiding the edge chamfers and first-layer elephant foot;
     horizontal bars from bottom to top are X40, X80, X120, and vertical bars
     from left to right are Y40, Y80, Y120;
   - for Z, approach the thin stepped wall from its open side and measure from
     the common bottom datum to each upper step; from left to right they are
     Z40, Z80, and Z120.

6. Run `2. Calculate and apply`. Select `Calibrate XY`, `Calibrate Z`, or both:

   - for XY, enter 3–5 independent re-seat readings for each of the six dimensions;
   - for Z, enter 3–5 independent re-seat readings for each step Z40, Z80 and Z120;
   - keep every `Apply ...` checkbox cleared for a preview on alpha11.

7. Review the fit, warnings, and proposed values in the process log. Only on a
   validated apply-capable host, enable the relevant `Apply ...` controls and
   explicitly select both `I am using a validated apply-capable PrusaSlicer
   build` and `I printed the gauge with selected compensation settings at zero`.
   Rerun the calculation. `ConfigBox:set()` provides no success status, so a
   non-throwing setter call proves only that the write was attempted, not that
   the active value changed. Preset readback or slicing state may also be stale.
   PrusaSlicer provides no transactional preset update, and rollback calls after
   an exception are best-effort and unverified. After every apply attempt,
   manually inspect every selected value in the active print and filament
   settings before slicing or retrying. Print multiple calibration objects again
   to verify the result.

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

The plugin preserves raw repeats, reports median/mean/range/sample SD/MAD, and
writes independent X/Y scale factors, fit RMS error, anisotropy,
and the optional Z scale factor to the process log. For experimental runs,
launch PrusaSlicer from a terminal and review the complete output before
accepting any changed setting.

## Calculation

For each axis, the plugin uses ordinary least squares to fit a straight line
to the per-span medians at nominal lengths of 40, 80, and 120 mm. The slope represents scale error,
while the intercept is an **observed additive term**. External dimensions alone
do not identify its cause: contour construction, seam, jaw placement and other
effects can produce similar values. For Z, first-layer/datum and layer-height
effects are additional possibilities. The fit produces:

- independent X and Y scale corrections;
- a common `filament_shrinkage_compensation_xy` value;
- a hypothetical `xy_size_compensation` value, explicitly diagnostic only;
- an optional `filament_shrinkage_compensation_z` value fitted from Z40, Z80,
  and Z120;
- the observed additive Z term and fit RMS, reported in the process log but not applied
  because PrusaSlicer has no corresponding Z-offset compensation setting.

The calculation is not tied to this particular mesh. Any gauge that supplies
the same three external nominal spans per axis can be used. The model assumes
that error is the sum of a length-dependent scale term and one constant
offset; it does not model nonlinear or feature-specific error.

Solver 2.0.0 also reports M0 (scale only) beside M1 (scale plus additive term),
including residuals, SSE/RMS and residual degrees of freedom. It does not choose
a physical winner from lower RMS. Existing scale proposals are explicitly
labelled legacy M1 diagnostics; M0 values are shown alongside them. XY size
compensation has no apply control, and stale contour-apply requests are rejected
before any settings access. See the [model derivation and error budget](research/models-v2.md)
and [setting semantics](research/settings-semantics.md).

Before reporting a selected plan or attempting the first preset write, the
calculator applies these provisional software sanity limits to every selected
axis:

- every measurement must be positive and no more than 5.0 mm from its nominal
  value;
- the measured 40/80/120 sequence must be strictly increasing;
- each axis fit must have a maximum absolute point residual no greater than
  0.25 mm, RMS no greater than 0.15 mm, and an absolute intercept no greater
  than 1.0 mm;
- the absolute X/Y anisotropy must be no greater than 0.10 percentage point;
- every calculated shrinkage value must remain within PrusaSlicer's supported
  -10% to +10% range.

Failure of any applicable limit rejects the complete selected plan and writes
no setting; an out-of-range value is not substituted with a boundary value.
These limits are defensive input checks, not physical acceptance criteria for
the gauge, printer, or corrected profile. They remain provisional until the
recorded physical trials establish suitable thresholds. XY and Z calculations
are independent, so either one or both can be run without validating or
changing the unselected axis.

## Saving and reproducing a calculation

The calculator emits `DA_RESULT_JSON` records to the process log, including raw
inputs, expected artifact revisions, metadata, current baseline, setting diff and
separate apply/verification statuses. Fill the session, instrument and process
fields to record provenance. Missing metadata is explicit. The Lua sandbox has
no file-writing API; save the terminal log and export locally:

```bash
python3 tools/result.py export slicer-session.log --output measurement-result.json
python3 tools/result.py replay measurement-result.json --lua /path/to/lua
```

Replay performs no host reads or writes. Successful reproduction is not physical
verification. Single-value input remains preview-only; applying requires 3–5
re-seats at every selected dimension. Measurement defaults are intentionally empty.
See the [result schema and analytical note](research/results-v1.md). Schema 1.1.0
adds the solver-2 diagnostics; saved solver-1/schema-1.0 results remain replayable.

## Research tooling

Prepare the versioned geometry-selection experiment with `python3 tools/trial.py`.
The [trial guide](prototypes/README.md) covers deterministic schedules, immutable
protocol/provenance, raw observations and the distinction between pilot and full
v1. The [decision log](research/decisions.md) records changes to research meaning.
No physical validation is implied by generating or validating a trial plan.
The [implementation audit](research/implementation-status.md) records the five
milestones, validation results and remaining physical/host release evidence.

## Model source and prototypes

All models are generated from `model/dimensional_accuracy_gauge.scad`. Product
and research work have deliberately separate targets. The local quality gate
requires OpenSCAD, Python 3, and a Lua 5.4 interpreter/compiler (`LUA` and
`LUAC` may point to non-default executable names):

```bash
make verify-release     # rebuild and verify the three runtime STL files
make verify-prototypes  # rebuild and verify the research-only challengers
make verify-all         # run both verification groups
make test               # verifier, manifest, generator, and calculator tests
make stage-plugin       # stage the exact seven-file unsigned runtime payload
make stage-plugin-existing # dev-only: verify/stage committed STL without OpenSCAD
```

`make all`, `make release`, and `make gauges` build only the three runtime
layouts. `make verify` is an alias for `make verify-release`; it already builds
what it verifies, so do not precede it with `make all`. On a machine without
OpenSCAD, `make verify-existing` checks the committed runtime meshes without
claiming that they are fresh. Prototype generation remains opt-in.

`prototypes/dimensional_accuracy_xy_7x5.stl` tests the alternative 7 x 5 mm
bar section. `prototypes/dimensional_accuracy_zc40.stl` is a 50 mm fragment
with a 9 x 7 mm through-window whose lower working plane is exactly 40 mm from
the datum. Prototype files are not loaded by the plugin and must not replace
the bundled gauges without the physical repeatability experiment.

The verifier checks binary STL structure, finite non-degenerate triangles,
manifold edges, consistent outward winding, connected components, per-component
bounds and volume, layout gaps, and the required measurement planes on the
intended component. CI regenerates both runtime and prototype meshes and
compares their canonical oriented surface patches with the committed artifacts;
coplanar retriangulation alone does not fail that comparison. These checks do
not replace slicing or physical measurements.

## Validation status

The generated meshes satisfy the automated geometry checks. No physical result
is claimed. Release approval still requires recorded slicing results and the
physical trials defined in `prototypes/README.md`, using multiple prints,
operators, and calipers. In particular, the smaller XY section must pass the
rigidity/repeatability check and Z-C may replace Z-B only if it is no worse in
access, repeatability, and systematic offset.

## MVP limitations

- PrusaSlicer provides one filament shrinkage value for both X and Y. The
  plugin uses their mean correction for the corresponding preset-write attempt
  and reports the independent values in the log.
- The MVP supports only a single-material print on physical extruder/material
  slot 1. The generator pins the object to extruder 1 and the calculator targets
  only slot 1 for material-setting write attempts; it does not calibrate or
  synchronize other material slots.
- The compensation settings are FFF-specific. The calculator rejects SLA
  presets before any preset-write attempt.
- The Lua API cannot scale an existing object independently along X and Y.
- The plugin's write attempts target the active settings of the current project;
  it does not create a saved user preset.
- The regression uses equal measurement weights and does not automatically
  delete a raw observation. It fits per-span medians; all readings remain in
  the saved raw input and descriptive statistics. If an aggregated span breaches
  a residual, RMS or other provisional sanity limit, the selected plan is rejected.
- Plugin API 1.0.0 cannot arrange objects after adding them. The combined STL
  avoids overlap, but its XY and Z shells are one slicer object and cannot be
  moved or deleted independently.
- The Lua API cannot paint the seam automatically. Place it in the XY concave
  pocket or the Z rear groove, away from every measured face.

## License

[GNU Affero General Public License v3.0](LICENSE).
