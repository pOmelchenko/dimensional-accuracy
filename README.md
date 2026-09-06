# Dimensional Accuracy Calibration (experimental)

An experimental calibration plugin for the PrusaSlicer Lua Plugin API. The
accepted XY reference is **DA-XY-S revision 1**: a 145 × 145 × 4.5 mm stepped
cross with two 10 × 45 mm windows and chamfered corner reliefs. Plugin **0.11.0**
collects its outside, depth, inside and wall measurements. The Z-B reference is
unchanged. See the [XY-S measurement guide](model/xy-reference.md).

> **Not ready for production presets.** The meshes pass automated geometry
> checks, but no physical validation results have been recorded and there is no
> currently supported public PrusaSlicer build for the complete
> calculate-and-apply workflow.

## Compatibility and requirements

- PrusaSlicer 3.0.0-alpha11 as the API baseline; the complete compact XY-S form
  uses the development dialog patch described below;
- for automatic application, a development PrusaSlicer build containing both
  preset-setting host fixes described below; numeric write verification also
  needs the `fix/lua-percentage-readback` host patch;
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
The current combined development patches pass the recorded
[XY-S apply and reslicing check](research/xy-s-software-validation.md) and
[Z reslicing plus preset/project restart checks](research/z-persistence-validation.md).

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
make release
make stage-plugin

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

The development [calculator dialog patch](research/calculator-ui.md) adds wide,
aligned measurement fields, a shared input example, optional Z/session fields,
and an in-window result with current/proposed values and their difference.
`Show details` expands fit diagnostics and warnings; `Back` preserves the form.
Labels occupy the left column; switches align with the inputs in the right
column, including `Show details` on the result page. Long labels wrap.
Plugin 0.11.0 keeps a compact 580-unit dialog with 300-unit measurement fields.
Plugin 0.8.0 with the updated dialog patch shows the selected filament preset's
name and material slot 1 above the form and on the result page. The name is read
again on each opening, including after changing presets. It is read-only;
optional spool/lot provenance remains entered separately. If the host cannot
provide a name, the context says `name unavailable`.
Plugin 0.9.0 and the latest dialog patch also show a color marker matching the
current slot color in PrusaSlicer's main window, including manual color changes.
Reopening refreshes it; the marker is read-only and remains on the result page.
An unavailable color omits the marker while preserving the name.
Plugin 0.10.0 with the updated dialog patch adds native, wrapped tooltips on
fields and toggles. Hover over a measurement input for re-seating instructions
and an example, or over an Apply switch for its target and requirements.
Optional session fields explain the recorded instrument and spool information.
Older hosts ignore this help metadata; the shared entry instructions remain.
On hosts without that extension, fields remain visible and results use the log.
An unreadable current setting is shown as unavailable, including its difference;
plugin 0.7.0 also rereads the active material settings after applying a change.
The separate Percentage host patch makes these values readable. The result
shows the actual and expected values, their match status, and the change from
the initial setting. Host branch details are in the dialog note linked above.

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
   Select `Generate XY-S stepped cross`, `Generate Z gauge`, or both. The checkbox
   combination loads one of three prepared models: XY, Z, or a combined XY+Z
   layout whose two printable shells already have a 10 mm gap.
4. Confirm that the object is assigned to extruder 1, print the generated
   calibration gauge(s) with the usual profile, and let them cool to room
   temperature.
5. Take the selected measurements:

   - for XY-S, use outside jaws for the overall 145 mm span and the depth rod
     for the short 30 mm and long 100 mm intervals on each axis. The long X
     arm points right and long Y arm down. The [guide](model/xy-reference.md)
     identifies each contact; tooltips repeat these instructions;
   - for Z, approach the thin stepped wall from its open side and measure from
     the common bottom datum to each upper step; from left to right they are
     Z40, Z80, and Z120.

6. Run `2. Calculate and apply`. Select `Calibrate XY`, `Calibrate Z`, or both:

   - for XY, enter 3–5 independent re-seat readings for the six primary fields;
   - optionally expand XY widths/spans, steps, windows or walls. Blank fields
     are skipped. Hiding retains readings; filled fields are checked whenever
     XY is enabled. These checks do not change the primary scale estimate;
   - for Z, enter 3–5 independent re-seat readings for each step Z40, Z80 and Z120;
   - keep every `Apply ...` checkbox cleared for a preview on alpha11.

7. Review the result and `Show details` in the patched dialog, or the process log
   on a host without the dialog extension. Only on a
   validated apply-capable host, enable the relevant `Apply ...` controls and
   explicitly select both `I am using a validated apply-capable PrusaSlicer
   build` and `I printed the gauge with selected compensation settings at zero`.
   Rerun the calculation. After the write calls, the plugin obtains a fresh
   material-settings handle and reads every requested shrinkage setting.
   `Written and checked` / `CONFIRMED` means all values match the calculation
   within 0.000001 percentage point and no setter raised an error. A mismatch
   is an apply error; an unavailable read leaves the write unconfirmed. Both
   outcomes show the individual readouts for manual inspection before retrying.
   PrusaSlicer provides no transactional preset update: rollback after a setter
   exception remains best-effort, and the final readout describes the values
   left afterward. Readback confirms active settings only; print and measure
   calibration objects again to establish whether dimensional accuracy improves.

The XY-S gauge has 30 mm short arms, a 15 mm crossing and 100 mm long arms.
Long-arm sections are 30/30/30 mm after a 10 mm root offset, with outside widths
35/25/15 mm. Both windows are 10 × 45 mm with 7.5 mm nominal end/straight-edge
spacing. Top/bottom chamfers and relieved corners keep the central flat contact
region accessible. Its generated mesh matches the accepted v10 prototype.

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

Solver **3.0.0** uses the two XY depth medians to estimate scale through the
origin, separately on each axis:

```text
s = (30 * short_depth + 100 * long_depth) / (30² + 100²)
b_outer = overall_145 - 145 * s
XY shrinkage [%] = 100 * (1 - mean(s_x, s_y))
```

This assumes that the two same-facing surfaces of a depth interval have the
same contour displacement. The overall outside span then supplies an observed
additive term. The assumption is experimental and needs physical validation.

Optional widths and steps check this estimate without changing its weights.
Window readings estimate a separate observed inside additive term; wall
readings can check the combination of outside and inside terms. A crossing
width also enables the short + crossing + long versus overall closure check.
All results and raw repeats appear in the result details and JSON. Outside and
inside boundary corrections remain diagnostic only; only filament shrinkage
can be applied. Inconsistent additional readings remain reviewable in preview
and block application. Related dimensions are not independent evidence of
accuracy. See [definitions and equations](model/xy-reference.md).

Z continues to use the 40/80/120 mm median OLS fit, with M0/M1 diagnostics and
no applied additive Z correction. Solvers 1.0.0 and 2.0.0 are retained for replay
of old grid-gauge results; their inputs cannot be reused in the XY-S form.
The [previous model derivation](research/models-v2.md) documents that legacy fit.

Before reporting a selected plan or attempting the first preset write, the
calculator applies these provisional software sanity limits to every selected
axis:

- every measurement must be positive and no more than 5.0 mm from its nominal
  value;
- the Z 40/80/120 sequence must be strictly increasing;
- XY depth fits and the Z fit must have maximum absolute residual no greater
  than 0.25 mm and RMS no greater than 0.15 mm; outside additive terms must be
  within ±1.0 mm. Additional XY check residuals must be within ±0.25 mm for
  application; inside additive terms must also remain within ±1.0 mm;
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
adds the solver-2 diagnostics; schema 1.2.0 adds setting readback and its comparison
with the requested values. Schema 1.3.0 adds typed XY-S primary/additional
measurements, window diagnostics and chain closure. Saved schema-1.0/1.1/1.2
results remain replayable using their original solver version.

## Research tooling

For the current XY-S reference, use the [baseline/verification experiment](research/xy-s-experiment.md)
and its [blank measurement table](research/templates/xy-s-first/measurements.csv).
`tools/xy_experiment.py` prepares all 32 dimensions, preserves repeated readings
and compares before/after errors using the production Lua calculation.
The [software validation report](research/xy-s-software-validation.md) records
synthetic analysis cases and actual Ubuntu plugin apply/reslice/G-code checks.

Prepare the versioned geometry-selection experiment with `python3 tools/trial.py`.
The [trial guide](prototypes/README.md) covers deterministic schedules, immutable
protocol/provenance, raw observations and the distinction between pilot and full
v1. The [decision log](research/decisions.md) records changes to research meaning.
No physical validation is implied by generating or validating a trial plan.
The [implementation audit](research/implementation-status.md) records the five
milestones, validation results and remaining physical/host release evidence.

## Model source and prototypes

The release entry point is `model/dimensional_accuracy_gauge.scad`, using
`model/xy_reference.scad` and `model/legacy_gauges.scad`. The latter preserves
Z and the previous research models; the catalog selects each artifact source. Product
and research work have deliberately separate targets. The local quality gate
requires OpenSCAD, Python 3, and a Lua 5.4 interpreter/compiler (`LUA` and
`LUAC` may point to non-default executable names):

```bash
make verify-release     # rebuild and verify the three runtime STL files
make verify-prototypes  # rebuild and verify the research-only challengers
make verify-all         # run both verification groups
make test               # verifier, manifest, generator, and calculator tests
make stage-plugin       # stage the exact seven-file unsigned runtime payload
make stage-plugin-existing # dev-only: verify/stage previously generated STL without OpenSCAD
```

`make all`, `make release`, and `make gauges` build only the three runtime
layouts. `make verify` is an alias for `make verify-release`; it already builds
what it verifies, so do not precede it with `make all`. On a machine without
OpenSCAD, `make verify-existing` checks existing generated runtime meshes without
claiming that they are fresh. Prototype generation remains opt-in.

`prototypes/dimensional_accuracy_xy_7x5.stl` tests the alternative 7 x 5 mm
bar section. `prototypes/dimensional_accuracy_zc40.stl` is a 50 mm fragment
with a 9 x 7 mm through-window whose lower working plane is exactly 40 mm from
the datum. Prototype files are not loaded by the plugin. The old XY-A and XYZ-AB layouts
remain available as `prototypes/dimensional_accuracy_xy_a_legacy.stl` and
`prototypes/dimensional_accuracy_xyz_ab_legacy.stl` for frozen legacy protocols.
Those protocols do not automatically include XY-S.

The verifier checks binary STL structure, finite non-degenerate triangles,
manifold edges, consistent outward winding, connected components, per-component
bounds and volume, layout gaps, and the required measurement planes on the
intended component. Canonical oriented surface comparison tolerates coplanar
retriangulation. These checks do not replace slicing or physical measurements.

## Validation status

The [XY-S acceptance check](research/xy-s-validation.md) records geometry gates,
119 software tests and the Ubuntu dialog/export/replay check for plugin 0.11.0.

The generated meshes satisfy the automated geometry checks. The current patched
Ubuntu host also passes the [XY-S slicing check](research/xy-s-software-validation.md).
The [Z and persistence check](research/z-persistence-validation.md) confirms
changed Z trajectories and restoration of both shrinkage values from manually
saved presets and projects in fresh processes; all 146 software tests pass.
No physical result is claimed. Release approval still requires the
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
- XY uses only its two primary depth intervals to estimate scale; Z uses
  unweighted OLS. Both fit per-feature medians and preserve every raw repeat.
  Additional XY measurements diagnose disagreement without gaining extra fit
  weight. No uncertainty or physical success is inferred from a small residual.
- Plugin API 1.0.0 cannot arrange objects after adding them. The combined STL
  avoids overlap, but its XY and Z shells are one slicer object and cannot be
  moved or deleted independently.
- The Lua API cannot paint the seam automatically. Place it in an XY corner
  relief or the Z rear groove, away from every measured face.

## License

[GNU Affero General Public License v3.0](LICENSE).
