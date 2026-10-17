# XY-S: baseline and verification experiment

This protocol prepares one DA-XY-S revision 1 print pair: **zero XY shrinkage →
repeated measurements → the production plugin calculation → a separate print
with the calculated XY shrinkage → repeated measurements and comparison**.
The tooling can be checked without printing. Synthetic data tests the software;
it does not establish printed accuracy.

The [blank measurement table](templates/xy-s-first/measurements.csv) has all 32
dimensions of the [accepted reference](../model/xy-reference.md), three readings
per dimension per phase: 192 blank observations. The frozen `protocol.json`
beside it includes the nominal, method, axis and contact instructions for every
dimension. Only the six primary dimensions are required for calculation.
Optional widths, steps, windows and walls diagnose other errors independently.

## Prepare a new experiment

From the repository root, with Python 3 and Lua 5.4 available:

```sh
python3 tools/xy_experiment.py init build/experiments/xy-s-first --id XY-S-FIRST --repeats 3
```

Use 3–5 readings, fully releasing and reseating the caliper each time. A new
directory is required: commands never overwrite an existing experiment or
report. `protocol.json` and its checksum freeze the design and feature list;
changing the model, row identities, nominal values or methods requires a new
experiment. The checksum detects accidental edits; it is not an authenticated
signature or proof of printing.

Fill `environment.json` with the printer, spool/lot, presets, slicer build,
instrument identity, resolution, stated MPE, seam and cooling conditions. Keep
the same model orientation, material, profile, measurement method and cooling
procedure between the two prints. Record the actual STL, saved project and
exported G-code SHA-256 values in `prints.csv`. A prefilled local mesh hash only
identifies the generated file; verify it against the file actually used.

This first protocol changes **only XY filament shrinkage in slot 1**. XY size
compensation and Z shrinkage are recorded as zero in both phases. Confirm the
actual exported baseline setting is zero. Do not change per-object scale,
orientation, XY contour settings or other print parameters between prints.
The protocol does not calibrate Z or automatically apply inside compensation.

## Record and calculate

Each CSV row is one observation. Enter a plain positive decimal (dot or comma),
`status=OK`, and the signed zero readings before and after reseating. Do not
replace the blank cells with nominal values. Use `SKIPPED` plus a reason for
every repeat of an omitted optional feature, or `FAILED` plus a reason and no
measurement for a failed reading. Partial series remain partial; raw values
and exclusions are retained in the report. Row identity and order must remain
unchanged. Readings finer than the declared instrument resolution are rejected.
Zero offset or drift greater than one declared resolution marks that series
`ZERO_CHECK_FAILED`; missing zero checks are explicitly reported.

Once baseline measurements are complete:

```sh
python3 tools/xy_experiment.py inputs build/experiments/xy-s-first --output build/xy-s-baseline-inputs.json
python3 tools/xy_experiment.py analyze build/experiments/xy-s-first --output build/xy-s-baseline-report
```

The input JSON gives the same semicolon-separated strings used by the plugin.
Enter them in the normal calculator, inspect diagnostics and use its normal
apply/readback workflow. The script itself never writes slicer settings.
Analysis calls the **production Lua solver 3.0.0**, not a second Python fit.
The preliminary report remains `INCOMPLETE` until verification observations
exist. A contradictory optional measurement requires review even if the six
primary values produce a plausible estimate.

Record the applied XY shrinkage in the verification row of `prints.csv`; after
the separate verification print, fill the verification observations and run:

```sh
python3 tools/xy_experiment.py analyze build/experiments/xy-s-first --output build/xy-s-comparison
```

`report.md` compares each dimension with its nominal before and after.
`report.json` also preserves input hashes, raw rows, counts, means, medians,
ranges, sample standard deviations, exclusions and the baseline solver plan.
Verification measurements **never enter the zero-baseline fit**. A declared
verification setting differing from the calculated proposal by more than
0.000001 percentage points is reported as a mismatch. This is a comparison
with an operator declaration; use the separate slicing check to inspect actual
G-code settings and trajectories.

For each complete pair the report computes
`abs(before_median - nominal) - abs(after_median - nominal)`.
Positive means closer to nominal; negative means farther away. The default
0.02 mm comparison margin is a declared descriptive threshold, adjustable at
initialization with `--margin-mm`; it is neither a confidence interval nor an
instrument specification. MPE is retained as metadata and never treated as a
standard deviation. A repeat range exceeding the observed deviation is flagged.

Related dimensions share surfaces, and repeated reseats share a specimen.
They are not independent printed samples. One pair gives an initial comparison,
not a general accuracy or causal improvement claim. `physical_validation`
remains `NOT_ESTABLISHED`; no software status certifies physical performance.

## Test the tools without printing

```sh
python3 tools/xy_experiment.py synthetic build/experiments/demo --case scale
python3 tools/xy_experiment.py analyze build/experiments/demo --output build/demo-report
```

Three deterministic cases are available:

| Case | Baseline | Verification | Expected check |
|---|---|---|---|
| `scale` | 0.995 × nominal | nominal | 0.5% XY proposal; all dimensions closer |
| `offsets` | 0.995 × nominal plus boundary offsets | nominal plus the same offsets | residual inside/outside errors persist; some widths become worse |
| `contradiction` | offsets case plus 0.6 mm on X width 25 | offsets case | optional contradiction requires review |

All examples add symmetric repeat noise. Their very fine declared resolution
is a mathematical fixture, not a claim about a real caliper. Every dataset and
report is marked `SYNTHETIC`; no project or G-code provenance is invented.

The old `tools/trial.py` / `tools/analyze_trial.py` and protocol v1 remain the
historical **model comparison** (XY-A versus XY-T, Z-B versus Z-C40). They are
pinned to those artifact IDs so the new release cannot silently change an old
trial. This XY-S compensation experiment is a separate protocol with different
questions and observations.
