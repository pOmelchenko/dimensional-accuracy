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
host/physical verification. Analysis is version 1.0.1; plugin 0.6.0; solver
2.0.0; calculation-result schema 1.1.0; protocol/raw schema 1.0.0.

## Checks run

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

No physical trial, GUI host test, fresh slicing test, signed release or remote
publication was performed. Source inspection confirms that the new runtime code
uses only the permitted base/table/math/string libraries; the host disallows
`io`/`os`/`dofile`/`loadfile`, so export/replay are deliberately external tools.
The inspected source also permits the table-only metatables used to serialize
empty JSON arrays. Source inspection and mock API tests do not validate a live
host's preset persistence or slicing state. Capability/maturity claims remain
unchanged, and all physical research questions remain UNTESTED.
