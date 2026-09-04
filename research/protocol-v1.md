Protocol version **1.0.0**, raw schema **1.0.0**. This is a geometry-selection
experiment, not calibration accuracy or a release approval. The accompanying
`protocol.json` fixes all counts, margins, seeds and formulas for this execution.
An empty generated directory is DRAFT. `checksums.sha256` locks the execution
copy; the repository template remains DRAFT. No recorded physical PASS exists.

## Questions and specimens

XY-H1/XY-H3/U-1: compare the 6.5 × 4.5 mm XY control with the 7 × 5 mm
challenger at X40/X80/X120/Y40/Y80/Y120. Z-H1: compare stepped Z-B with
Z-C40 at Z40 only. Z80/Z120 are not matched Z-C observations. Artifact
identity, role and revision are in `artifacts.csv`; blind codes and the three
independent matched print batches are in `prints.csv`. Keep that mapping out
of the operator's view. The shapes prevent full blinding.

## Before printing and measurement

Fill every environment/process field, instrument entry, planned print position,
STL/G-code/project SHA-256 and preset snapshot hash. Record the plugin/model
commits, exact slicer build, nozzle, spool/lot, orientation, seam, layer and
extrusion settings, temperatures, humidity and minimum cooling time. Select
physical material slot 1 and zero XY/Z shrinkage and XY size compensation.
Freeze `protocol.md`, `protocol.json`, environment, artifacts, prints,
instruments and schedule before the first print. The checksum file itself
must be preserved in version control or another immutable archive.

Run `make verify-all` in the source revision used for the meshes and preserve
its output. Slice and inspect all models. Approve the printed positions,
orientation, seam and cost tradeoff before revealing the blind mapping. Balance
control/challenger bed positions across the three batches. G-code hashes may
therefore differ between batches; within an unchanged layout reuse the same
G-code. Retain every G-code and project, not just the hash. Do not tune the
profile during the trial or post-process measurement faces.

Photograph the measurement approach and label each physical print using the
planned blind code and print ID. Clean/zero instruments and record resolution,
manufacturer MPE, asset ID and calibration status. Record deviations in a
separate append-only `deviations.csv` (`event_id,scope_id,reason,action`), not
by rewriting the frozen plan. A invalid batch or zero-invalid block remains
in the data; a replacement needs a new trial/execution schedule and cannot
silently turn the original strict gate into PASS.

## Gate A: handling

Use two operators, three calipers and ten complete removals/reinstallations for
every model × feature × operator × caliper cell, on one fresh matched pair.
There are 720 XY and 120 Z attempts. A two-caliper exploratory pilot has
480/80 attempts and cannot receive full v1 PASS.

The generator creates ten shuffled rounds for each operator/caliper pair.
Every model/feature occurs once per round; rotate instrument order between
operators. XY blocks contain five rounds (60 attempts). Follow the schedule,
take a break and check zero before and after every block. Do not show previous
readings to the operator. Fully remove the caliper before every attempt;
do not move it to search for the expected number. Measure XY mid-height flat
end faces, avoiding chamfers/first layers. Measure Z from the common bottom
datum from its open side.

Record one row per scheduled observation using the display's full precision.
An ambiguous, slipped or failed installation has an explicit status and an
empty `measured_mm`; do not replace it with a hidden extra attempt. A missing
observation still counts in the planned denominator. A correction is a new
unique observation ID with `supersedes_observation_id` pointing to the prior
row; preserve all original rows. Only transcription errors may be corrected
this way, with a reason. Corrections may not change specimen, operator,
instrument, feature or the outcome of an actual failed installation.

The entire block is zero-invalid if zero drift exceeds one display resolution.
Record both zero values consistently on each row in that block. A damaged
working face, wrong preset or wrong baseline invalidates the batch: keep its
observations and record the deviation. Cosmetic defects elsewhere are recorded
but do not alone invalidate a print.

## Gate B: independent prints

Proceed after strict Gate A PASS, or an explicit INCONCLUSIVE decision useful
for confirmation. Do not continue a clearly worse challenger. Print three
independent matched batches in total, including the Gate A batch; completely
finish and cool one before starting the next. One designated operator O1 and
caliper C1 take five re-seats per feature per copy, in the shuffled schedule.
Gate A readings do not replace the new Gate B readings. Total: 180 XY/30 Z.
For batch/feature summaries use the **median**, not the mean. The print is the
experimental unit; do not pool placements to inflate the print count.

## Analysis fixed before measurement

For every Gate A cell report scheduled/valid/failed counts, failure rate,
median, mean, min/max, range, sample SD, MAD and 1.4826 × MAD. Preserve the
observation-order raw plot. Pooled within-cell SD is
`sqrt(sum((n_g-1)*s_g^2) / sum(n_g-1))`. Report operator and caliper median
shifts within matched factors, matched candidate/control median shift and
candidate/control pooled SD ratio for every span, including the worst span.

For each span use a stratified bootstrap within each operator/caliper cell:
10,000 iterations, resample its original valid count with replacement,
recompute pooled SD and the ratio. Use the protocol seed and central 90%
percentile interval. Failed observations never become numeric values. A zero
denominator or quantization-limited variation is INCONCLUSIVE, never evidence
of superiority. This interval does not replace independent prints.

Strict A requires no failed installation, no zero-invalid block, every cell
range ≤0.03 mm and every matched candidate/control shift ≤0.03 mm. Strict B
requires all copies measurable, range of three per-print medians ≤0.03 mm
and every within-batch matched shift ≤0.03 mm. Missing data are INCONCLUSIVE;
a demonstrated strict breach remains visible regardless of completeness.

For comparative XY superiority, pooled SD ratio ≤0.8 and the upper 90%
bootstrap bound <1 on at least four spans; no span ratio >1.2, failures and
matched operator/caliper shifts no worse than control. Advantage must persist
in all three matched Gate B batches; cost must satisfy the frozen acceptance
rule. For Z the single matched span must meet ratio ≤0.8, upper bound <1 and
the same direction in all three batches. Inconclusive intervals produce
INCONCLUSIVE. Show all per-print medians, range/SD, descriptive bias and
matched shifts; do not bootstrap three prints. Report per-print XY scale,
observed additive term and curvature hints descriptively.

If equivalent at instrument resolution, retain the smaller control. A better
challenger still needs a correction trial before release replacement; passing
Z-C40 permits developing a full window prototype, not claiming Z80/Z120 PASS.
Thresholds 0.03 mm and 20% are provisional engineering margins. Change them
only in a new protocol/trial, with rationale. No retroactive PASS.

## Data contract and compatibility

The CSV header is defined in `protocol.json`. Semicolon-delimited decimal
lists are not CSV measurements: every raw trial row is one observation.
Numeric CSV values use a decimal point. Preserve raw text and row order.
Scheduled fields are copied exactly from the schedule; `actual_order` records
the real positive order, including deviations. Non-OK statuses require a
reason and an empty numeric measurement. `SKIPPED` covers an unperformed
attempt, so its zero checks and elapsed time can be empty.

This replaces the former unversioned `environment.md`/short CSV/`summary.md`
proposal in `prototypes/README.md`. No old physical dataset exists in the
repository. Do not silently reinterpret external legacy files: preserve them,
document a field mapping and label the imported result as a separate analysis.
Schema/protocol changes require new versions. A schema-valid record is not a
physical PASS, and Gate A/B never imply VERIFIED calibration.
