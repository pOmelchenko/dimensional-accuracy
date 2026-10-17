# Repeated inputs and structured calculation results

Plugin 0.5.0 introduces result schema 1.0.0 and named solver 1.0.0. Each field
accepts **3–5** complete caliper removals/reinstallations separated by `;`, e.g.
`39,98;40,00;39,99`. Both decimal point and decimal comma remain supported.
Whitespace and raw input text are retained. An empty token, non-finite number,
nonpositive number or unsupported count rejects the input. A single old-style
reading remains available for preview with an explicit repeatability warning;
it cannot be applied. Measurement defaults are empty to prevent nominal values
from being mistaken for actual observations.

For each span retain all raw tokens and numeric values; compute mean, median,
min/max, range, sample SD (n−1 denominator) and MAD. Fit the medians with the
existing unweighted OLS model. Median aggregation is a declared estimator,
not automatic deletion of outliers: every input remains in the result and
statistics. A range larger than the observed median deviation is warned about,
without inventing an uncertainty distribution or a calibrated threshold.

Solver 1.0.0 names the former scale-plus-observed-offset fit with median input.
OLS slope is cov(N,m)/var(N); b=mean(m)−s mean(N). For a zero baseline, the
existing descriptive shrinkage calculation is 100(1−s), and the hypothetical
outer-contour setting is −b/(2s). The existing sanity limits are unchanged.
Single-reading fixtures therefore retain the old arithmetic. The frozen
`tests/fixtures/result-v1.json` records a **synthetic** full repeated XY/Z
example for version compatibility; it is not a physical trial.

Enter session/print, operator, caliper, resolution/MPE, slicer version,
printer/nozzle, spool/lot and preset identifiers alongside the readings.
Missing provenance is explicitly recorded and warned about. MPE remains an
instrument error bound and is never treated as sample SD or divided by sqrt(n).
Artifact ID/revision is the expected selected gauge identity; match it to the
actual print label. A context field cannot prove that an old print used the
current presets or zero compensation.

The host sandbox provides no `io`/`os` file access (checked in the local
PrusaSlicer `doc/Plugin_API.md`, commit
`5f096a3cd060d5dcf4e814c53cfb06fd6fc7e332`). The plugin writes one-line JSON
records prefixed **`DA_RESULT_JSON `** to the normal process log. Invalid input
also produces a record preserving the entered text and refusal. An apply run
emits a preview before the first write and a final record afterward. Export
defaults to the last record; `--index` selects another zero-based record.

```bash
python3 tools/result.py export slicer-session.log --output measurement-result.json
python3 tools/result.py replay measurement-result.json --lua /path/to/lua
```

Export never overwrites a file. Replay serializes data as escaped Lua literals
and invokes only the pure calculator under a standalone Lua 5.4 interpreter:
there is no PrusaSlicer API, preset read or write. It compares all fit/statistic
fields against the saved plan and fails on mismatches or unsupported versions.
Successful replay verifies reproducibility, not the physical input or outcome.
Refused inputs without a plan remain exportable but cannot be replayed as a
successful calculation. Preserve the original log as well as the JSON file.

Schema 1.0.0 fields:

| Field | Meaning |
|---|---|
| schema_version / plugin_version / solver_version | Exact data/implementation versions |
| inputs | Original declared inputs, including raw repeated measurement text |
| metadata | Operator-entered process and instrument provenance; missing fields explicit |
| artifacts / artifact_identity_source | Expected artifact IDs/revisions and identity qualification |
| baseline | Current selected setting readouts, numeric interpretation and readability |
| plan | All selected fits, repeated values and descriptive statistics |
| proposed_settings | Preset owner/key, before/proposed/delta and requested write flag |
| workflow_state / severity | Separate process state and software diagnostic severity |
| apply_status / readback_status | Write outcome; unverified remains explicitly unconfirmed |
| verification_status | NOT_VERIFIED; this workflow has no independent physical verification |
| warnings / error | Incomplete provenance, repeatability warnings and refusals |

Fields that were not reached on a refused run may be absent. Empty warning and
missing-field collections are JSON arrays. Non-finite JSON numbers are rejected.
Raw values are not rounded; formatted human log summaries do not replace them.
Schema revisions require a compatibility note/migration. No old physical result
format exists in this repository; standalone legacy single-input preview is
preserved rather than silently converted into repeated data.

## Schema 1.1.0 and 1.2.0 compatibility

Schema 1.1.0 adds the solver-2 M0/M1 diagnostics described in
[models-v2.md](models-v2.md). Plugin 0.7.0 emits schema 1.2.0, retaining those
calculations and adding post-write verification. Export/replay accepts all
three schema versions; legacy versions cannot claim confirmed host readback.
The frozen solver-1/schema-1.0 fixture remains unchanged.

After all requested writes (and any best-effort rollback on a setter exception),
the plugin reacquires `current_bed():material_presets(0)` and reads only the
requested XY/Z shrinkage keys. The final record adds:

| Field | Meaning |
|---|---|
| readback.tolerance_percent | Absolute comparison tolerance, 0.000001 percentage point; a software numeric tolerance, not a physical acceptance limit |
| readback.settings[] | One entry for each requested key; no entry for an unselected axis or diagnostic contour proposal |
| key / expected_percent | Setting key and the calculated value requested for it |
| actual_percent / error_percent | Finite readback and actual minus expected; absent if unreadable |
| raw / error | Available raw readout text or the reason it could not be read |
| status | Per-setting MATCHED, MISMATCH, or UNREADABLE |

Aggregate `readback_status` is MISMATCH if any value differs, otherwise UNREADABLE
if any read failed, otherwise MATCHED. A non-throwing write with MATCHED readback
produces `apply_status=CONFIRMED`; unavailable reads leave UNCONFIRMED. A mismatch
or setter exception produces ERROR_UNCONFIRMED. A setter exception remains an
error even if the final values happen to match the proposal. Readback after
rollback compares the remaining values with the calculation; it does not claim
that rollback restored the initial state. A readback mismatch triggers no extra
writes. Preview/refusal before writing retains NOT_PERFORMED and has no
`readback` object.

`workflow_state` remains APPLY_ATTEMPTED for these write outcomes. Physical
`verification_status` remains NOT_VERIFIED even when the settings match.
Validation checks requested-key coverage, numeric differences, tolerance and
status consistency. Offline replay checks the saved calculation without reading
the host; it cannot independently authenticate the recorded setting values,
confirm persistence after restarting, or validate slicing and physical accuracy.

## Schema 1.3.0 / solver 3.0.0 (plugin 0.11.0)

The default XY artifact is DA-XY-S r1. Its inputs have explicit feature IDs
(`x_overall145`, `x_short30`, `x_long100`, etc.); old `x40/x80/x120` grid inputs
cannot substitute for them. [XY-S definitions](../model/xy-reference.md) specify
the depth-scale estimator and separate outside/inside boundary assumptions.

Each XY fit has three primary `measurements` and an `additional_measurements`
array, which is empty when no optional fields are filled. Records retain raw
text/tokens/values, statistics, nominal, method, group and boundary coefficients.
Additional observations include predictions/residuals/status where identifiable;
wall-only data uses `NEEDS_WINDOW_MEASUREMENT` without an invented prediction.
The optional `inner` object records a diagnostic additive term, hypothetical
boundary expansion, observation count and consistency status. One window is
`NOT_TESTABLE`; its observation is `DESCRIPTIVE_ONLY`. The optional `chain`
records the depth + crossing + depth sum, overall, closure error and status.
None of the additional fields changes primary scale weights or authorizes an
inside/contour setting write. Contradictions block application but remain
exportable/replayable. Host readback semantics are unchanged from schema 1.2.0.

Replay dispatches solvers 1.0.0, 2.0.0 and 3.0.0 separately, preserving the legacy
plan shapes and arithmetic. Z keeps the solver-2 fit within solver 3.0.0.
