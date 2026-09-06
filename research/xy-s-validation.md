# XY-S acceptance check — 2026-09-06

**Software/geometry evidence only; no physical print or accuracy improvement
claim.** Accepted artifact DA-XY-S r1 is the approved v10 geometry. Runtime
plugin 0.11.0 uses solver 3.0.0 and result schema 1.3.0. The
[measurement guide](../model/xy-reference.md) defines the contacts and equations.

## Geometry

OpenSCAD 2021.01 on Ubuntu ARM64 rebuilt the three release meshes. The release
verifier passed manifold/winding/degeneracy, component, bounds, volume, working
plane and layout-gap checks:

| Artifact | Bounds, mm | Components | Geometric volume, cm³ |
|---|---|---:|---:|
| DA-XY-S r1 | 145 × 145 × 4.5 | 1 | 22.170 |
| DA-Z-B r1 | 52 × 24 × 120 | 1 | 25.943 |
| DA-XYZ-SB r1 | 145 × 179 × 120 | 2 | 48.113 |

The combined Y gap was 9.999992 mm, within the geometry tolerance. All four
XY outer end planes have 53.438 mm² area. The 3400-triangle XY mesh matched the
approved v10 canonical oriented surface geometry, including relief chamfers.
Its SHA-256 is
`cb5eb1e5b367e4d430d01884f99ef0856b8bfe60ee0c2da52d829a0556489d01`.
The preserved legacy SCAD is byte-identical to the previous tracked source
(Git blob `482b11061d13188c2125dc0080dc5c03d7a0130c`); Z definitions were not edited.

`tools/check_xy_reference.py`, now included in `make test`, checks eight depth
poses with 25 rod-tip contact rays each; outside widths, section lengths,
compound/overall spans, crossing widths, windows and walls; and representative
relief contacts at five Z heights. These are independent STL measurements,
not values read back from the SCAD parameters. They do not measure printed
stiffness or verify fit of a particular physical caliper.

## Calculator and compatibility

The final Ubuntu suite passed **59 Python + 55 calculator Lua + 5 generator Lua
tests**, plus Lua syntax, manifest, artifact projection and Makefile safety
checks. New checks cover separation of depth scale and outside/inside offsets,
correlated optional data not changing scale, inconsistent windows/checks,
missing primary data, hidden-field validation, repeat policy, walls without
window data, and supported boolean visibility dependencies. Existing baseline,
write/readback, failure/rollback, metadata and filament-context tests still pass.

The frozen schema-1.0/solver-1 fixture remains reproducible. The new
`tests/fixtures/result-v2.json` freezes the old solver-2 plan generated from
the pre-XY-S tracked plugin 0.6.0 using the existing synthetic fixture inputs.
It is also reproduced by the current code. This fixture is not printed data.

## Actual Ubuntu dialog

An isolated configuration/display used the existing patched PrusaSlicer build.
No additional host patch or host rebuild was needed. The form showed XY-S r1,
145/30/100 mm fields, native filament name/color, four optional groups and the
retained 580/300 width hints. Five readings, including five six-character
overall readings and decimal-comma depth readings, fit without horizontal
scrolling. Widths and windows expanded; hiding them retained entered data. The wall group
showed all six 7.5/17.5 mm fields after scrolling, with action buttons accessible.

Synthetic primary medians were 144.44 / 29.85 / 99.50 mm on both axes, with
five re-seats per field. Extra X readings were crossing 15.09, window length
44.66 and width 9.83 mm, three repeats each. With both extra groups collapsed,
Run produced:

- XY shrinkage 0.5000%, current 0.0000% → proposed 0.5000%;
- outside additive term +0.1650 mm;
- X chain sum 144.44 mm, closure error 0;
- inside additive term −0.1175 mm; hypothetical boundary expansion +0.059045 mm,
  diagnostic only.

Show details displayed the diagnostics and Back retained the form values.
The process log contained exactly one calculation record, with
`NOT_REQUESTED / NOT_PERFORMED / NOT_VERIFIED` for apply/readback/physical
verification. Export and independent Lua replay of this actual GUI record
passed. No synthetic value was written to a preset.

The seven-file runtime bundle was staged in Ubuntu at
`~/prusaslicer-alpha/dimensional-accuracy/build/dev.omelchenko.dimensional-accuracy`.
All seven staged SHA-256 hashes matched the local payload. Close the calculator
and use **Plugins → Rescan Plugins**, or restart with
`bash ~/prusaslicer-alpha/launch-slicer.sh`, to load it in the development session.
