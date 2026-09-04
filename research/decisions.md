# Research decisions

## D001 — Version the executable geometry-selection protocol

- Date: 2026-09-04. Status: ACCEPTED. Protocol/schema: 1.0.0.
- Context: the research note and prototype instructions disagreed about Gate B
  mean versus median, G-code reuse versus balanced bed positions, and whether
  inconclusive Gate A results could continue.
- Decision: use per-print medians; preserve per-batch G-code provenance while
  balancing positions; allow explicitly inconclusive follow-up, not a clearly
  worse challenger. The executable template is `research/protocol-v1.md`.
- Alternatives: retain the shorter unversioned instructions, or run a complete
  factorial print study. The staged trial answers the current geometry question
  with fewer independent prints and retains the full crossed handling study.
- Evidence: local research note sections 9.4–9.13 and existing prototype design;
  these are preregistered choices, not physical findings.
- Consequence: old schemas cannot be silently pooled. Missing observations and
  failed installations remain visible. No physical PASS is claimed.
- Revisit after the first pilot; any changed margin/design gets a new version
  and trial ID, preserving this execution's analysis.

## D002 — Catalog the existing geometry without silently revising it

- Date: 2026-09-04. Status: ACCEPTED. Artifact schema 1.0.0; all five
  existing meshes receive geometry revision 1.
- Decision: use `model/artifacts.json` for build/verifier expectations, checked
  Lua projections and trial features. Retain the exact existing geometry.
  Physical print labels and the frozen mesh-hash mapping provide identity on
  these legacy unengraved parts; do not invent an engraved revision.
- Alternatives: new runtime JSON parsing, or a new engraving on every mesh.
  Checked projections preserve the seven-file payload, and external labels
  avoid changing the physical control during a repeatability study.
- Evidence: the existing SCAD, verifier expectations, and plugin discovery
  contract (every `.lua` file is a runtime entry point).
- Consequence: a shape change must receive a new artifact revision; external
  physical labels remain a required step for these existing revision-1 meshes.
- Revisit when an independently validated replacement geometry is introduced.

## D003 — Make incomplete and failed trials reproducibly analyzable

- Date: 2026-09-04. Status: ACCEPTED. Analysis version 1.0.0, protocol 1.0.0.
- Decision: implement the preregistered Gate A/B statistics without dropping raw
  rows, with separate strict and comparative outcomes and a permanent
  NOT_VERIFIED calibration status. Freeze artifact definitions with each trial
  so future catalog edits do not reinterpret its features.
- Alternatives: pooled summaries alone, automatic outlier removal, or manually
  transcribed spreadsheets. These would hide the scheduled denominator or make
  exact re-analysis harder.
- Evidence: `analysis-v1.md` derivations and synthetic tests in
  `tests/test_analyze_trial.py`; no physical evidence is claimed.
- Consequence: missing values, quantized ratios and unknown cost acceptance can
  return INCONCLUSIVE. Synthetic superiority exercises the complete support path.
- Revisit after a recorded pilot; change formulas/margins only with new versions.
