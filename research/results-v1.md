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
