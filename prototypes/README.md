# Gauge prototype trial

These meshes are experimental and are not loaded by the plugin:

- `dimensional_accuracy_xy_7x5.stl` is the 7.0 x 5.0 mm XY-A challenger. Its
  control is the bundled 6.5 x 4.5 mm XY-A gauge.
- `dimensional_accuracy_zc40.stl` is the 50 mm Z-C fragment. Its 9 x 7 mm
  window provides a 40 mm working plane for comparison with Z-B.

## Trial protocol

Keep the comparison single-material on physical extruder/material slot 1. Use
the same printer, nozzle, material spool and lot, slicer build, profile values,
orientation, seam placement, and ambient conditioning for control and
candidate. Record every deviation from that setup. Do not combine these trials
with a profile-tuning run.

Run the trial in two gates so print-to-print coverage does not require a wasteful
full factorial experiment:

1. **Handling and measurement repeatability.** Print one control and one
   candidate in the same batch. Two operators use three ordinary 150 mm
   calipers and take ten readings for every operator/caliper/model/span
   combination. Fully remove and reinstall the caliper for every reading.
2. **Print-to-print repeatability.** If the first gate passes, print at least two
   additional copies of each model. Reuse the same G-code for copies of one
   model and record its SHA-256. One designated operator and caliper take five
   independently reinstalled readings per copy and span. Randomize measurement
   order across models and copies.

Before each session, clean and zero every caliper and record its resolution and
zero-check result. Record a failed or ambiguous jaw installation as a failed
installation; do not silently retry it.

- For the XY comparison, measure X40, X80, X120, Y40, Y80, and Y120 on the
  bundled 6.5 x 4.5 mm control and the 7 x 5 mm challenger. Use the same
  mid-height jaw position and avoid chamfers and elephant foot.
- For the Z comparison, measure Z40 on Z-B and Z-C/40 from the common bottom
  datum. Approach both models from their open side. Z80 and Z120 on Z-B may be
  recorded as supporting data, but they are not a matched Z-C/40 comparison.

A candidate passes the handling gate only if every operator/caliper/model/span
group has no failed installation and a range no greater than 0.03 mm. It passes
the print-to-print gate only if every copy is measurable without failure and
the range of per-copy means is no greater than 0.03 mm for every span. Report
per-group, per-copy, and pooled results so variation is not hidden. A challenger
must also show no systematic mean shift greater than 0.03 mm from its control
on a matched span. Z-C must meet these gates against Z-B at Z40 before a full
40/80/120 window model is produced.

These are prototype-selection gates, not proof that the resulting calibration
is accurate. The calculator's provisional software sanity limits are likewise
not physical acceptance criteria. A release trial must additionally produce at
least three independent prints of each selected XY and Z gauge with zero
compensation and at least three independent verification prints after
calculation, then compare all selected 40/80/120 spans using the same raw-data
procedure. Define the acceptable post-correction bias and RMS before that trial
starts.

## Recording results

Commit raw results under `prototypes/results/<trial-id>/` only after the trial
has been run. Use this structure:

- `environment.md`: date, printer and firmware, exact PrusaSlicer version and
  commit, plugin commit, nozzle, material brand/type/lot, material slot, full
  preset identifiers, layer height, orientation, seam placement, temperature,
  humidity, and any protocol deviations;
- `measurements.csv`: one raw observation per row with columns
  `trial_id,gate,session_id,model,role,stl_sha256,gcode_sha256,print_id,operator_id,caliper_id,caliper_zero_mm,axis,nominal_mm,repetition,measured_mm,install_failed,notes`;
- `summary.md`: valid and failed counts, mean, standard deviation, range, bias
  from nominal, matched candidate-control shift, pass/fail for every gate, and
  the release decision with rationale.

Do not enter a replacement value for a failed installation. Keep immutable raw
rows and derive summaries from them. This repository currently records no
physical result and therefore makes no pass claim.

Do not replace either bundled STL based on appearance or material use alone.
