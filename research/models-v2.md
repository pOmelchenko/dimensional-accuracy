# Diagnostic model comparison — solver 2.0.0

Plugin 0.6.0/result schema 1.1.0 adds explicit M0/M1 diagnostics. These are
additive result fields; schema 1.0.0 and solver 1.0.0 results remain replayable.
The v1 calculation path and frozen synthetic result are retained. New results
name solver 2.0.0; no old result is silently relabelled or reclassified.

## Models and derivation

Let N_i be the nominal length and m_i the median of the recorded re-seats.
Assume additive residuals and equal weights across the three spans. Neither
model includes a validated measurement-uncertainty or print-variation model.

M0 minimizes sum((m_i − s0 N_i)²). Differentiating with respect to s0 gives
`s0 = sum(N_i*m_i)/sum(N_i²)` and b0=0. It has n−1=2 residual degrees of
freedom for 40/80/120.

M1 minimizes sum((m_i − s1 N_i − b1)²). Its normal equations give
`s1 = sum((N_i−mean(N))*(m_i−mean(m)))/sum((N_i−mean(N))²)` and
`b1 = mean(m) − s1*mean(N)`. It has n−2=1 residual degree of freedom. At
40/80/120, s1=(m120−m40)/80; m80 affects the intercept/residuals but not slope.

Each candidate reports slope, **observed additive term**, three residuals,
SSE in mm², RMS=sqrt(SSE/n), maximum absolute residual, parameter count,
residual degrees of freedom and descriptive zero-baseline shrinkage percentage.
Also report RMS reduction, slope difference, the curvature hint
`m80−(m40+m120)/2` and maximum observed re-seat range. Range is not labelled
standard uncertainty or substituted into a significance test.

M0 is nested in M1 (b=0), so M1's training SSE cannot exceed M0's apart from
floating-point roundoff. Lower training RMS alone is therefore not evidence
that an offset exists physically or that the correction will generalize.
With ideal m=sN+b, M0 estimates s+b*sum(N)/sum(N²), which demonstrates why
choosing a model is materially different from adding a plotting option.

## Decision and compatibility

The result always states `selection_status=NOT_ESTABLISHED` and
`uncertainty_status=NOT_ESTIMATED` for this single-print input. There is no
automatic preference for M1, p-value, weighted fit, discarded outlier or hidden
uncertainty threshold. The old M1 numbers remain explicitly labelled
`M1_LEGACY` descriptive proposals so users and frozen v1 fixtures can compare
arithmetic. The scale-only M0 proposal is displayed alongside them. Manual
experimental shrinkage application retains the existing host/zero-baseline
confirmations and full-plan validation; it does not establish model superiority.

XY size compensation is **diagnostic only**. Its apply control is removed, and
an old/stale `apply_contour_offset=true` request is rejected before any host
read/write, even with all confirmations. The hypothetical −b/(2s) number is
retained with its qualification; no setter operation is constructed for it.
The JSON retains legacy request text on refusal. Z's observed additive term
also remains a diagnostic and is never written as an offset setting.

Model selection needs independent prints demonstrating stable parameters,
an explicit error budget, alternate contour sensitivities, and a preregistered
correction/verification trial. Geometry Gate A/B cannot supply that evidence
by itself. The proposed future precision model is outside this diagnostic task.

## Error budget before causal interpretation

| Possible contribution | Observable ambiguity / required evidence |
|---|---|
| Instrument resolution/MPE/zero | Repeats may quantize; MPE is a bound, not SD; record checks and calibration |
| Jaw installation/operator/contact force | Re-seat study and matched operator/instrument cells; flexibility may mimic an offset |
| First layer/datum/top surface/seam | Local external size changes can enter b without a contour cause |
| Flow/pressure advance/line width | Process-dependent boundaries; keep the process signature fixed |
| Cooling/material shrinkage | Independent prints and conditioning; a span fit alone cannot isolate material |
| Machine scale/skew | Separate machine study with identifiable features |
| Geometry and model mismatch | Neutral/inner/outer features, residual diagnostics and independent holdout |

No combined uncertainty number is claimed. The purpose of this budget is to
prevent assigning the observed coefficient to one cause without evidence.

Tests cover pure-scale agreement, exact parameter recovery over 100 synthetic
scale/offset combinations, nested SSE, analytical M0 offset contamination,
curvature/middle-point behavior, diagnostic/refusal states, absence of contour
writes, and exact versioned replay of the frozen v1 result. These mathematical
checks do not validate physical accuracy or a host's slicing state.
