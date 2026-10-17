# XY-S software evidence — 2026-09-06

**All entered dimensions are synthetic. No specimen was printed or measured.**

`SYNTHETIC-apply-result.json` is the unmodified structured record exported from
the real patched PrusaSlicer GUI in an isolated Ubuntu configuration. Its apply
confirmations were enabled only to exercise the software path with synthetic
inputs. They are not attestations that a physical gauge exists. The record
confirms the setting write/readback; it retains `verification_status=NOT_VERIFIED`.

`xy-s-synthetic-summary.json` records the three deterministic experiment-tool
fixtures, each run through production solver 3.0.0. The mixed better/worse
results in the offsets case are intentional and must not be reduced to an
overall improvement claim.

`xy-s-slicing-provenance.json` records the actual Ubuntu build, source HEAD plus
the installed worktree-patch digest, runtime bytes and PIDs of the isolated
session. HEAD alone does not identify this patched development binary.

The associated slicing report records the measured straight-face G-code
coordinates and line numbers, extrusion widths, unchanged layer schedule and
hashes of both complete G-code files. Generated full G-code stays under `build/`;
these reviewable evidence records remain in the repository. Repeating the GUI
procedure produces new G-code and timestamps, hence new file hashes.

See [the software validation report](../../xy-s-software-validation.md) and
[the future physical experiment guide](../../xy-s-experiment.md).
