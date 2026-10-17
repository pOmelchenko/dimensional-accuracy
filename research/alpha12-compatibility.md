# PrusaSlicer alpha12 update — 2026-10-17

Plugin **0.12.0** targets the public **3.0.0-alpha12** API baseline. The solver
remains 3.0.0, result schema remains 1.3.0 and gauge geometry is unchanged.

## Public build and development build

The upstream tag `version_3.0.0-alpha12` resolves to
`30ef59195e0f3ee6f270b185bb5f9fb5f349f81f`.

| Function | Official alpha12 | Alpha12 with the combined patch |
| --- | --- | --- |
| Load XY-S and Z gauge meshes | Existing project API | Same API |
| Calculate compensation | Preview with results in the process log | Preview in the result dialog and log |
| Compact form, conditional fields, tooltips, material name/color | Extension metadata is ignored | Included |
| Numeric percentage reads | Opaque `Percentage` userdata | Numbers in percentage points |
| Preset notifications and material override activation | Required fixes absent | Included |
| Apply compensation | Unsupported; unreadable baselines block writes | Requires numeric zero baselines and both existing confirmations |

This matrix describes the inspected source contracts. An alpha12 GUI/apply/
reslicing integration run has not been recorded. Matching numeric readback
alone cannot establish that an arbitrary host emits preset/slicing notifications.
The separate validated-build confirmation remains required.

Alpha12 already fixes the swapped float/int controls (upstream
`e4aeed4f81`). Text inputs remain intentional: each measurement field accepts
3–5 repeats and either decimal separator. The numeric-control fix is preserved
without reintroducing its old change. Alpha12's `emboss_text` and font fixes are
also preserved; this plugin loads prepared STL files and does not call that API.

## Plugin changes

- An unreadable selected baseline now stops every apply operation before its
  first setter call, even with both confirmation boxes checked. A bad Z baseline
  also prevents an otherwise valid XY write in the same run.
- Hosts without `api.show_result` receive the readable summary and diagnostics
  in the process log as well as the replayable JSON record. No settings change
  during preview.
- The manifest and generated runtime version are 0.12.0; the minimum public
  version is alpha12.
- `make test` generates required runtime meshes on a fresh checkout. CI no
  longer expects STL files that were removed from version control; it builds,
  verifies and stages the seven-file runtime payload from the SCAD sources.

## Combined PrusaSlicer patch

[`patches/prusaslicer-alpha12.patch`](../patches/prusaslicer-alpha12.patch)
contains the settings/override fixes from `5f096a3cd0`, the dialog/material
context/tooltip changes through `3f31ae4c5b`, and percentage readback from
`5e3c9df080`, rebased together onto alpha12. It includes the existing host Lua
regression tests. The old `prusaslicer-plugin-dialog.patch` is retained only
for reproducing the historical alpha11 work.

Starting from a clean alpha12 checkout:

```sh
git -C /path/to/PrusaSlicer rev-parse HEAD
# Expected: 30ef59195e0f3ee6f270b185bb5f9fb5f349f81f
git -C /path/to/PrusaSlicer apply --check /path/to/dimensional-accuracy/patches/prusaslicer-alpha12.patch
git -C /path/to/PrusaSlicer apply /path/to/dimensional-accuracy/patches/prusaslicer-alpha12.patch
cmake --build /path/to/build/slicer --target slic3r-app-launcher slic3r-shared-tests --parallel 2
xvfb-run -a /path/to/build/slicer/src/slic3r-shared/slic3r-shared-tests '[Lua]' --reporter compact
```

Use the resulting development build for a new isolated GUI check before
confirming it as apply-capable. Repeat the existing XY/Z apply, reslice and
preset/project reload procedures against that exact binary. The September 6
alpha11 reports do not validate a new alpha12 executable.

## Verification

The local `make -j2 stage-plugin` run passes **148 tests: 86 Python, 57
calculator Lua and 5 generator Lua**. It uses Lua 5.4.8 and OpenSCAD 2021.01
on macOS. Coverage includes public-host preview without dialog extensions,
unreadable percentage rejection before writes, and the valid apply/readback
workflow. Lua syntax, generated artifact projections, manifest checks and
Makefile override checks also pass.

All three runtime STL files were rebuilt from the SCAD sources and passed
geometry validation: nominal dimensions, closed consistently oriented meshes,
working planes, component counts and the combined layout gap. The staged
development bundle contains exactly the seven runtime files.
The separate `make -j2 verify-prototypes` run also rebuilds and validates all
four research/legacy artifacts used by CI.

The combined patch is checked against the exact upstream alpha12 source. CI
now checks its applicability independently on every run. This is a source
compatibility check, not a C++ build or a GUI integration test.
