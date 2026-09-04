# Geometry-selection analysis 1.0.0

The implemented rules are the frozen [protocol 1.0.0](protocol-v1.md). All
data are descriptive research observations; geometry selection is never a
`VERIFIED` calibration. Synthetic tests are not physical evidence.

For values x_i, mean is sum(x_i)/n, sample variance is
sum((x_i-mean)^2)/(n-1), and MAD is median(abs(x_i-median(x))). Variance is
undefined for n<2; empty summaries contain nulls, not zeros. Pooled within-cell
variance weights each cell by its residual degrees of freedom n_g-1; thus
operator/caliper location shifts do not inflate within-cell variation.

The SD-ratio bootstrap samples each valid operator/caliper cell with replacement
at its original size and recomputes the two pooled SDs. The central 90% interval
uses linear interpolation at positions (B-1)p (percentile/type-7 quantiles).
Each feature has a stable seed given by SHA-256 of
`<protocol seed>:<family>:<feature ID>` interpreted as an unsigned integer.
The protocol fixes 10,000 iterations. Zero SD or any undefined bootstrap ratio
prevents a comparative claim; undefined samples are not silently discarded.
The only epsilon is 1e-10 for floating-point roundoff, not an uncertainty margin.

A Gate B print is summarized by its five-reseat median. Print range/SD uses
those three medians, not all fifteen placements. Per-print X/Y OLS slope is
sum((N-mean(N))*(m-mean(m)))/sum((N-mean(N))^2), and the observed additive term
is mean(m)-s*mean(N). The 40/80/120 curvature hint is
m80-(m40+m120)/2. These are diagnostics, not a model-selection or correction
decision. Preservation of handling advantage in each Gate B batch means
candidate within-copy SD is below control within-copy SD on a qualifying span.

Raw CSV is read-only. Every planned observation contributes to the denominator.
Missing/skipped/transcription-pending attempts are incomplete; physical failures,
zero-invalid blocks, invalidated specimens and insufficient cooling remain
explicit failures. A demonstrated strict breach is FAIL even in a partial
dataset. Incomplete data cannot PASS. All complete cell, print and matching
checks must pass; two-caliper pilots cannot produce `SUPPORTED`.

Comparative support additionally requires the stated SD improvement and interval,
no worsening span or matched operator/caliper shift, consistent independent-print
direction and an explicit cost-acceptance record against the frozen rule. A
wide interval spanning practically relevant improvement and worsening is
inconclusive. A strict failure is `NOT_SUPPORTED`; lack of comparative evidence
is `INCONCLUSIVE`. Neither means the dataset should be removed.

After recording observations:

```bash
python3 tools/analyze_trial.py prototypes/results/my-trial --output build/analysis/my-trial-v1
```

The destination must be new. Outputs are `analysis.json` (all metrics, statuses,
per-print fits, input hashes), `analysis.md` (readable summary) and standalone
`observations.html` (observation-order strip plots and rows). Retain them beside
the raw data when publishing a completed trial. The analysis checks all frozen
provenance hashes before computation. Re-analysis writes a new output directory
and cannot alter the original result or its original version/margins.

`deviations.csv` has `event_id,scope_id,reason,action`. Scope can be a block,
print, print batch or family (`xy`/`z`). Use `INVALIDATE` for an unusable scope,
`NOTE` for a deviation without exclusion, and family-level `CONTINUE_GATE_B`
for an explicitly inconclusive follow-up. Family-level `COST_ACCEPTED` or
`COST_REJECTED` records the documented cost decision. Later cost records
supersede earlier cost decisions; they never delete observations. Keep this
file append-only with the raw data.

The input checks and algorithms are exercised with synthetic crossed data:
known variance/SD ratios, constant/quantized readings, incomplete schedules,
NaN/negative inputs, zero drift, failed installations, correction chains,
and independently shifted per-print observations. Physical data are still needed
to assess whether the provisional margins or the geometry are useful.
