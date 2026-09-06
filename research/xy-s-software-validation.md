# XY-S experiment tools and actual reslicing — 2026-09-06

**Both software tasks passed without printing or physical measurements.**
The experiment tooling is ready for real baseline/verification observations.
The current patched Ubuntu host changes XY-S slicing geometry after an actual
plugin apply in the same GUI process. Physical accuracy remains untested.

## Experiment preparation and analysis

The [protocol and commands](xy-s-experiment.md) use the accepted DA-XY-S r1
catalog and production Lua solver 3.0.0. The [blank table](templates/xy-s-first/measurements.csv)
contains 32 dimensions × 3 full reseats × 2 phases = 192 blank observations.
Nominals, axes, methods and contact instructions are frozen alongside it.

All three complete synthetic pairs were calculated in Ubuntu, each with 192
observations. The [recorded summary](evidence/xy-s-software/xy-s-synthetic-summary.json)
contains these results (comparison margin 0.02 mm):

| Synthetic case | Calculated XY shrinkage | Closer / farther dimensions | Result |
|---|---:|---:|---|
| Pure 0.995 scale, then nominal | 0.5% | 32 / 0 | COMPARED |
| Same scale with persistent outside/inside offsets | 0.5% | 16 / 16 | COMPARED, residual errors remain visible |
| Additional X width-25 contradiction of 0.6 mm | 0.5% | 17 / 15 | REVIEW_NEEDED |

`COMPARED` means the pair was numerically compared; it does not mean the print
improved. In the offsets case, verification outside-span error remains +0.16 mm,
window error −0.12 mm and wall error +0.14 mm. The report never applies an
inside or contour setting. Verification data never enters the baseline fit.

Tests cover incomplete and failed series, missing/duplicated or relabelled rows,
invalid values, decimal comma, declared resolution, zero drift, nonzero baseline,
changed compensation, contradictory optional measurements and no overwrite.
The old geometry-selection protocol is explicitly pinned to its legacy models.

Final Ubuntu `make test`: **78 Python + 55 calculator Lua + 5 generator Lua =
138 tests passed**, plus catalog/projection, Lua syntax, manifest and Makefile
safety checks. The actual GUI apply record also replays from its raw inputs.
The `synthetic → inputs → analyze` CLI sequence passed; analysis of the blank
physical template correctly returns `INCOMPLETE` without inventing a fit.

## Actual GUI apply → reslice → exported G-code

Environment: Ubuntu 26.04.1 LTS, aarch64, UTM; PrusaSlicer 3.0.0-alpha11 with
the existing settings/dialog/Percentage patches. The
[build record](evidence/xy-s-software/xy-s-slicing-provenance.json) includes binary,
source-diff and runtime hashes. Plugin 0.11.0 and the generated XY-S mesh match
the repository bytes at `89964befe776900ca05586d4d487ca05b09cfc5e`.
No slicer source patch or rebuild was needed for this check.

The session used a separate configuration copy and Xvfb display `:95`:

1. Generate one XY-S object through the real plugin. Keep 100% object scale
   and its original orientation. Profile: Prusa MK3S 0.4, 0.15 mm QUALITY,
   Prusament PLA in slot 1, two perimeters, 15% grid infill, no brim.
2. Slice at zero XY shrinkage and export ASCII G-code to Local Drive.
3. Open the actual calculator. For both X and Y, enter three identical
   **synthetic** readings of 144.275, 29.85 and 99.5 mm for overall, short and
   long dimensions respectively. Leave Z and optional dimensions disabled.
4. Enable XY apply and the two confirmations only to exercise this isolated
   software test. No physical gauge was printed; the confirmations are not
   physical evidence. The [unmodified plugin record](evidence/xy-s-software/SYNTHETIC-apply-result.json)
   reports `CONFIRMED` / `MATCHED`, from 0% to 0.5%, and `NOT_VERIFIED` physically.
5. Close the result and slice the same object again in the same process. Export
   the second G-code. The [event excerpt](evidence/xy-s-software/gui-events.log)
   records both slicing passes with the actual apply/readback between them.

`tools/check_slicing.py` parses modal XY/Z/E positions, absolute/relative
extrusion and G92 E resets. Only positive-extrusion straight external-perimeter
segments at least 5 mm long are used as flat contact planes. Travels, wipes,
skirt/infill and curved corner segments do not supply bounds. Arc endpoints
still update the parser position. Unsupported coordinate/units modes fail.

The check uses 16 layers from Z=0.65 through 2.90 mm, away from the bottom/top
chamfers and engraving. It compares the full exported legacy configuration:
**only `filament_shrinkage_compensation_xy` changed**, from `0%` to `0.5%`.
XY size compensation and Z shrinkage remain zero. All 30 layer heights are
unchanged, including the profile's final Z=4.55 mm layer.

Native `ShrinkageCompensation.cpp` uses `100 / (100 − shrinkage_percent)`.
For 0.5%, the scale is 1.005025125628; the 145 mm span should increase by
0.728643216 mm. The actual G-code check found:

| Quantity, on both axes and all 16 layers | Baseline | After apply |
|---|---:|---:|
| Outer-perimeter centreline span | 144.550 mm | 145.278 mm |
| Width on measured end faces | 0.449999 mm | 0.449999 mm |
| Programmed boundary span (centreline plus half-width at each end) | 144.999999 mm | 145.727999 mm |

Observed span increase: **0.728000 mm**. Maximum difference from the expected
increase: **0.000643216 mm**, below the 0.005 mm trajectory-check tolerance.
This is consistent with G-code coordinate rounding. Programmed path/width
geometry is not a measurement of deposited plastic.

The [complete numeric report](evidence/xy-s-software/trajectory-report.json)
preserves all 32 axis/layer checks, source G-code line numbers, bounds, widths,
settings change, layer schedule and SHA-256 values of the complete input files.
The [negative control](evidence/xy-s-software/negative-control.json) changes only
the parsed percentage declaration on the actual baseline paths: the checker
correctly rejects the unchanged trajectories. A settings-only change cannot
pass this test.

The two full exports are retained locally as:

```text
build/utm-ubuntu/SYNTHETIC-xy-s-baseline.gcode
build/utm-ubuntu/SYNTHETIC-xy-s-compensated.gcode
```

Replay the check from the repository root:

```sh
python3 tools/check_slicing.py build/utm-ubuntu/SYNTHETIC-xy-s-baseline.gcode build/utm-ubuntu/SYNTHETIC-xy-s-compensated.gcode --apply-result research/evidence/xy-s-software/SYNTHETIC-apply-result.json --output build/xy-s-trajectory-recheck.json
python3 tools/result.py replay research/evidence/xy-s-software/SYNTHETIC-apply-result.json
```

Generated full G-code remains outside version control; the report and evidence
above are versioned. Reproducing from a fresh checkout requires rerunning the
GUI sequence and providing its two new exports and apply record. The checker
is deliberately scoped to this axis-aligned single-material XY-S case. This
does not establish Z shrinkage, multi-object/multi-material behavior, disk
persistence of presets or printed accuracy.

The subsequent [Z and persistence check](z-persistence-validation.md) separately
verifies Z shrinkage and manually saved preset/project values after restart.

The isolated application and Xvfb session were stopped after export. The next
physical step is still the [baseline/verification experiment](xy-s-experiment.md).
