# Accepted XY-S reference, 2026-09-06

Current [XY-S geometry, calculator and Ubuntu GUI validation](xy-s-validation.md):
119 tests passed; preview/export/replay checked; no physical print.

The current plugin is 0.11.0 with DA-XY-S r1, solver 3.0.0 and result schema
1.3.0. The [measurement guide](../model/xy-reference.md) is the current XY
protocol. Earlier milestone/trial notes below refer to legacy grid geometry.
The accepted v10 mesh has been promoted unchanged; Z-B remains unchanged.
The form collects six primary measurements plus 26 optional checks through
existing dialog capabilities. No new PrusaSlicer patch is required.

The subsequent [XY-S experiment and slicing check](xy-s-software-validation.md)
prepares the 32-dimension before/after protocol and confirms that a real plugin
apply of 0.5% XY shrinkage changes the exported trajectories after reslicing in
the same Ubuntu GUI process. The evidence is saved in the repository. All
entered readings are synthetic; physical trials remain outstanding.

The [Z reslicing and persistence check](z-persistence-validation.md) additionally
confirms changed Z-B print layers after a 0.5% plugin apply and recovery of both
XY/Z values after manual preset/project saves and independent application
restarts. Native settings and preview-only API reads agree. All 146 tests pass.
No additional runtime or host patch was needed; CI repair remains deferred.

# Implementation and verification — 2026-09-05

The five selected software tasks are implemented. This is an implementation
audit, not a physical trial or release approval. The plugin remains experimental.

| Task | Implementation | Milestone commit | Acceptance evidence |
|---|---|---|---|
| Executable trial v1 | Versioned protocol/raw schema, templates, deterministic crossed schedule, frozen provenance | 89bb349 | Schedule completeness, stable seed, pilot designation, no overwrite, incomplete freeze refusal, tamper detection |
| Artifact specification | IDs/revisions, nominal features, SCAD/Lua checks, generated build/verifier projections and frozen trial catalog | de4ce8d | Nominal/label/SCAD/Makefile drift tests; all five existing meshes pass catalog-based verification |
| Trial analysis | Raw/correction validation, Gate A/B, per-cell/per-print statistics, bootstrap comparison and reports | 9713c5c | Missing/failure/zero/quantization tests; complete 1,050-observation synthetic XY+Z CLI run; all plotted points preserved |
| Repeats and saved results | 3–5 readings, raw text and statistics, JSON logs, CLI export/replay | 2b249a0 | JSON/control-character/Unicode roundtrip, refusal export, no overwrite, altered-input mismatch, offline replay |
| M0/M1 diagnostics | Both fits/residuals/degrees of freedom; no automatic winner; contour apply disabled | e8e3a14 | 100 parameter-recovery cases, nested SSE, middle-span/curvature checks, contour refusal before host access, frozen v1 replay |

The final audit additionally fixes unknown/nil baseline reporting, supplies an
empty deviation template, rejects mismatched nominal definitions and impossible
display precision, and prevents exported records from claiming unsupported
host/physical verification. At that audit, analysis was version 1.0.1; plugin
0.6.0; solver 2.0.0; calculation-result schema 1.1.0; protocol/raw schema 1.0.0.

The subsequent [calculator UI and readback work](calculator-ui.md) advances
the plugin to 0.7.0 and calculation-result schema to 1.2.0. All 104 plugin
tests pass in Ubuntu. The patched development host also passes its five Lua
test cases (77 assertions). An isolated GUI test with synthetic inputs confirms
active-setting readback after applying 0.5% XY shrinkage. The other versions
above are unchanged; no physical trial or release approval is implied.

The later filament-context addition advances the plugin to 0.8.0 while retaining
result schema 1.2.0. Its 107 plugin tests and the combined host's nine Lua cases
(125 assertions) pass in Ubuntu. An isolated GUI check verifies that the form
refreshes the filament name after changing the selected preset and retains it
on the calculation result. Details and branch references are in the same UI note.

Plugin 0.9.0 added the current slot's color marker in the same
context. All 109 plugin tests and 11 host Lua cases (200 assertions) pass in
Ubuntu, including manual project-color overrides, invalid-color fallback and
context layout. Solver and result schema versions are unchanged.

Plugin 0.10.0 added native parameter tooltips through a further
commit on the existing dialog branch. All 110 plugin tests and 13 host Lua cases
(296 assertions) pass in Ubuntu. An isolated GUI check confirms wrapped help
on measurement inputs, calibration/apply toggles and session metadata fields,
including after scrolling. No calculation or setting write was requested in
that check. Solver 2.0.0 and result schema 1.2.0 remain unchanged.

The current plugin is 0.10.1 with a 580-unit dialog and 300-unit measurement
fields. The latest dialog host aligns switches in the control column and wraps
long labels. All 110 plugin tests and 13 host Lua cases (296 assertions) pass.
The Ubuntu GUI check confirms five full 120.00 readings remain visible, Z
visibility preserves XY inputs, and the result's aligned Show details switch
and Back action work. A synthetic preview recorded five readings per XY span
and no setting writes or physical verification.

## Original milestone checks

- **54 Python tests** passed, including CLI export/replay using Lua 5.4.8.
- **32 calculator + 5 generator Lua tests** passed; `luac -p` passed.
- `make test-artifacts` and Makefile override-safety checks passed.
- `make stage-plugin-existing` passed tests and all three runtime mesh checks.
  Its seven files exactly match the verified source bytes; research/test helpers
  are excluded from the runtime payload.
- `make verify-prototypes-existing` passed both prototype mesh checks.
- A full **synthetic** CLI trial with 1,050 observations produced JSON, Markdown
  and standalone HTML plots under analysis 1.0.1; the plots retain all 1,050
  effective observations. The calibration status remains NOT_VERIFIED.
- The saved solver-1.0.0 fixture remains reproducible after solver 2.0.0 changes.

## Scope and remaining release evidence

The worktree already had five deleted STL files before this work. Those deletions
are preserved and excluded from every implementation commit. Full testing and
staging therefore ran in an isolated copy with the existing STL bytes extracted
from Git. No geometry/source shape changed. OpenSCAD regeneration was not run
on this machine; CI retains regeneration and canonical geometry comparison.

At the original milestone audit, no physical trial, GUI host test, fresh slicing
test, signed release or remote publication was performed. Later development
GUI, XY/Z reslicing and preset/project restart checks are recorded above;
physical trials and a signed release remain outstanding. Source inspection confirms that the new runtime code
uses only the permitted base/table/math/string libraries; the host disallows
`io`/`os`/`dofile`/`loadfile`, so export/replay are deliberately external tools.
The inspected source also permits the table-only metatables used to serialize
empty JSON arrays. Source inspection and mock API tests do not validate a live
host's preset persistence or slicing state. Capability/maturity claims remain
unchanged, and all physical research questions remain UNTESTED.
