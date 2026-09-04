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
