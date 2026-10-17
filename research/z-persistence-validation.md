# Z reslicing and preset/project persistence — 2026-09-06

**Both software checks passed in the patched Ubuntu GUI.** A real plugin apply
changes the Z-B slicing trajectories. Manually saved XY and Z shrinkage values
survive application restart, independently through a filament preset and a 3MF
project. No production plugin or PrusaSlicer source changes were needed.

All input readings below are **synthetic**. No gauge was printed or measured.
These results establish software behavior for this development build; they do
not establish improved dimensional accuracy of printed parts.

## Tested build

- Plugin **0.11.0**, solver **3.0.0**, result schema **1.3.0**.
- Runtime files are unchanged from plugin commit `89964be`; repository base for
  this verification work is `4373f06`.
- PrusaSlicer **3.0.0-alpha11**, source base
  `5f096a3cd060d5dcf4e814c53cfb06fd6fc7e332` with the existing combined host
  patches described in [calculator-ui.md](calculator-ui.md).
- Ubuntu 26.04.1, aarch64, software OpenGL on an isolated Xvfb display.
- Prusa MK3S 0.4, Prusament PLA, 0.15 mm QUALITY, one filament slot.

The [provenance record](evidence/z-persistence/z-persistence-provenance.json)
contains the binary/runtime hashes, host source diff hash, original export/log
hashes, separate process IDs and configuration directories. The host executable
and source diff hashes match the earlier [XY-S slicing check](xy-s-software-validation.md).
The user's main slicer configuration was not used for writes.

## Z-only apply and real reslicing

In process **97123**, generate Z-B r1 through the production generator with
Calibrate/Generate XY off and Z on. Keep object scale at 100%, dimensions
52 × 24 × 120 mm. With XY and Z shrinkage both at zero, slice and export ASCII
G-code through the GUI.

Open the production calculator with Z only, and enter three identical synthetic
readings per height: `39.8;39.8;39.8`, `79.6;79.6;79.6`,
`119.4;119.4;119.4`. Enable Apply Z and the two confirmations solely to exercise
the software write path. Those confirmations are **not physical evidence**.
The [unmodified result](evidence/z-persistence/SYNTHETIC-z-apply.json) records
`CONFIRMED` apply and `MATCHED` numeric readback of approximately **0.5%**.
Close the result, reslice the same object in the same process and export again.

[check_z_slicing.py](../tools/check_z_slicing.py) examines actual positive-extrusion
external-perimeter moves across the three blade centres. It uses the last such
move over each blade, rather than trusting the final travel Z or a setting in
the footer. It also checks the fixed layer schedule, unchanged first-layer
height, unchanged XY base footprint and the complete exported configuration.
Only `filament_shrinkage_compensation_z` changes in that configuration.

| Blade nominal, mm | Baseline last print Z, mm | Compensated last print Z, mm | Observed change, mm |
|---|---:|---:|---:|
| 40 | 39.95 | 40.25 | +0.30 |
| 80 | 80.00 | 80.45 | +0.45 |
| 120 | 120.05 | 120.65 | +0.60 |

Layer count increases from **800 to 804**. The selected layer height remains
**0.15 mm** and the base footprint remains **52 × 24 mm**. PrusaSlicer's scale
factor is `100 / (100 - 0.5) = 1.0050251256`. Continuous target heights are
40.201005 / 80.402010 / 120.603015 mm; actual top print levels lie on the fixed
layer grid. Both individual heights and paired changes agree within one layer.
These are extrusion-plane heights, not predictions of deposited bead surfaces.

The [numeric report](evidence/z-persistence/z-trajectory-report.json) includes
G-code line numbers and exact segment coordinates. A
[negative control](evidence/z-persistence/z-negative-control.json), using the
actual baseline trajectories with only the footer changed to 0.5%, is rejected.
The checker is deliberately limited to axis-aligned Z-B r1, one material,
fixed layers no thicker than 0.2 mm and 0.5–2% positive Z shrinkage. It is not a
general slicer simulator or an adaptive-layer verification tool.

## Manual save and independent restarts

After exporting the Z-only compensated G-code, apply **XY only** in the same
initial process. Use synthetic readings `144.275`, `29.85`, `99.5` on each axis,
each repeated three times. The [XY apply record](evidence/z-persistence/SYNTHETIC-xy-apply.json)
confirms approximately 0.5% XY; the already applied Z value is retained.
This step tests persistence of settings, without claiming that XY readings
were obtained from the Z-B object on the bed.

1. Use **File → Save Project** to save
   [SYNTHETIC-XY-Z-0p5.3mf](evidence/z-persistence/SYNTHETIC-XY-Z-0p5.3mf).
   Save this before creating a custom filament preset, so it contains the
   original Prusament descriptor and project overrides.
2. In the ordinary filament settings, use **Save preset**, accepting the name
   **Prusament PLA - Copy**. The
   [unaltered saved YAML](evidence/z-persistence/SYNTHETIC-saved-filament.yaml)
   contains both Percentage values. Exit the application through its UI.
3. Start process **125143** in a fresh stock configuration with only that saved
   YAML copied into its user-preset directory. Do not open a project. Select
   **(User) Prusament PLA - Copy** in the empty project. The
   [native settings screenshot](evidence/z-persistence/preset-after-restart.png)
   shows both values at 0.5%.
4. Open the calculator, enable XY and Z, enter the same synthetic values once
   per field and run **preview only**, with both Apply switches off. The
   [unmodified preview record](evidence/z-persistence/SYNTHETIC-preset-reopened.json)
   reads both baseline values through the production API. Exit, discarding
   changes to this unsaved empty project.
5. Start process **127986** with another fresh stock configuration and **no user
   preset YAML**. Open the manually saved 3MF through **File → Open Project**.
   The native UI identifies the material as **(From 3mf) Prusament PLA** and
   [shows both values at 0.5%](evidence/z-persistence/project-after-restart.png).
   A second [preview-only API record](evidence/z-persistence/SYNTHETIC-project-reopened.json)
   confirms them independently. Exit through the UI.

Fresh directories exclude backup projects and lock files; neither restart uses
the previous application's remembered selection or autosaved project. The two
preset copies have identical SHA-256 hashes; the project-only configuration has
no user preset file. All three application processes and the isolated Xvfb
server were stopped after the checks. [Log excerpts](evidence/z-persistence/gui-events.log)
record the separate sessions and slicing events.

The [persistence report](evidence/z-persistence/persistence-report.json) compares
the two original confirmed writes, typed Percentage entries in the actual 3MF
ZIP and baseline API values from both new processes. Each value matches within
**0.000001 percentage points**. `NOT_PERFORMED` readback in a preview means no
post-write check was requested; its `baseline` contains the fresh API reads.
The checker verifies numeric consistency; the GUI procedure and provenance
above supply the process-isolation evidence. YAML is fingerprinted and loaded
by the actual host, rather than interpreted by a substitute YAML parser.

## Repeat the checks

Full original G-codes remain in `build/utm-ubuntu/` locally and in
`/home/omelchenko/prusaslicer-alpha/` in Ubuntu. They are ignored generated
artifacts. Repeating Z validation from a fresh checkout requires rerunning the
GUI sequence and supplying the two exports. The 3MF persistence fixture, saved
YAML, API records, screenshots and numeric reports are versioned here.

```sh
python3 tools/check_z_slicing.py build/utm-ubuntu/SYNTHETIC-z-baseline.gcode build/utm-ubuntu/SYNTHETIC-z-compensated.gcode --apply-result research/evidence/z-persistence/SYNTHETIC-z-apply.json --output build/z-trajectory-recheck.json
python3 tools/check_persistence.py --evidence research/evidence/z-persistence --project research/evidence/z-persistence/SYNTHETIC-XY-Z-0p5.3mf --output build/persistence-recheck.json
make test
```

The [Ubuntu test run](evidence/z-persistence/test-run.log) passes **86 Python + 55 calculator Lua + 5 generator Lua =
146 tests**, plus artifact/projection consistency, Lua syntax, manifest and
Makefile override-safety checks. New regression cases reject unchanged/wrong Z
trajectories, variable layers, missing blades, XY changes, reset/unreadable
persistent values, loss of Percentage typing and write records substituted for
post-restart previews.

All four GUI calculation records also replay successfully through the
production pure Lua solver. The original XY-S G-code pair still passes its
16-layer X/Y check after extending the shared parser for Z segments.

These close the two outstanding software checks for the tested development
build. Physical before/after trials remain outstanding. CI repair remains
deferred as requested; signed/public release validation is a separate gate.
