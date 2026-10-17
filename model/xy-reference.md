# XY-S revision 1: accepted reference and measurements

Accepted 2026-09-06 from `prototypes/xy_sketch_cross_v10.scad`. Runtime source:
`xy_reference.scad`, invoked by `dimensional_accuracy_gauge.scad`. Artifact ID
**DA-XY-S r1**, plugin **0.11.0**, solver **3.0.0**. This replaces the grid in the
generator and calculator. Old XY-A/T artifacts and solver versions remain for
legacy research/replay. Acceptance of the design is not physical validation.

## Geometry and orientation

Place the long X arm to the right and long Y arm downward, with lettering up.
The overall span is **145 mm on both axes**, height **4.5 mm**. Each axis has
30 mm short depth + 15 mm crossing width + 100 mm long depth. Along each long
arm, a 10 mm root interval precedes three 30 mm sections. Outside widths are
35 / 25 / 15 mm, from the wide section toward the tip.

Both windows have nominal flat-face dimensions **10 × 45 mm**, with 7.5 mm
nominal spacing from their ends to the section boundary and from the straight
outside edge to the nearby window face. The opposite wall is 17.5 mm in the
wide section and 7.5 mm in the middle section. Reliefs extend beyond these
nominal window faces; do not measure to the relief extremities.

Outside corner reliefs are 2 × 2 mm. Window reliefs reach 1 mm beyond each
nominal face. Body and relief top/bottom edges have 0.375 mm chamfers at 45°;
the flat working region lies between Z = 0.375 and 4.125 mm. Place jaws/rod
against those vertical flat faces, away from the chamfers, seams and first
layer. Reliefs provide tool clearance; they are not measurement datums.

## Primary fields: required on both axes

All lengths below describe measurement direction, not the name of the arm
being crossed. X measures horizontally and Y vertically in the orientation
above. Remove and re-seat the caliper for each of 3–5 readings, entered with
`;` separators. Decimal comma is accepted. A single reading permits preview
only. Check zero and avoid bending the arms with clamping force.

| Field | Nominal | Contacts and method |
|---|---:|---|
| X overall | 145 mm | Outside jaws between left and right end faces. |
| X short depth | 30 mm | Sole on left short-arm end; rod toward the left face of the vertical arm, guided beside the lower edge of the short arm. |
| X long depth | 100 mm | Sole on right tip; rod toward the right face of the upper arm, guided beside the straight upper edge. |
| Y overall | 145 mm | Outside jaws between upper and lower end faces. |
| Y short depth | 30 mm | Sole on upper short-arm end; rod toward the upper face of the horizontal arm, guided beside the left edge of the short arm. |
| Y long depth | 100 mm | Sole on lower tip; rod toward the lower face of the right arm, guided beside the straight right edge. |

The depth-tool access was checked geometrically with a 14 mm sole and a 1 mm
rod, its axis 7 mm from either sole edge. Confirm that the actual caliper seats
flat and its rod reaches the intended face. A different tool shape or a print
defect can invalidate a reading despite nominal geometric clearance.

## Optional groups

Blank fields are skipped individually. Group switches only show/hide fields;
filled values remain checked while XY calibration is enabled. Disabling XY
ignores every XY field. Z has its own unchanged 40 / 80 / 120 mm fields.

| Group | Fields per axis | How to measure |
|---|---|---|
| Widths and spans | Crossing 15; tip 15; middle 25; wide 35; compound 85 mm | Outside jaws. X widths cross the vertical arm; Y widths cross the horizontal arm. Crossing width uses the short arm; the other widths use long-arm sections. X compound span goes from the vertical arm's left face to the X 70 mm step face; Y from the left arm's upper face to the Y −70 mm step face. |
| Steps | Root section 30; middle step 30; tip step 30 mm | Root section uses outside jaws between its opposite end faces. Middle and tip intervals use the depth rod, sole on the farther-out step/end plane. |
| Windows | Length 45; width 10 mm | Inside jaws against flat faces. X length is the horizontal window; X width is across the vertical window. Y is the converse. Avoid all corner reliefs. |
| Walls | Straight 7.5; wide 17.5; middle 7.5 mm | Outside jaws with one jaw entering the window. X crosses the vertical arm; Y crosses the horizontal arm. Stay within the indicated constant-width section. |

The crossing measurement enables a closure check:
`short depth + crossing width + long depth − overall`.
This is a consistency check using actual readings, not an independent fourth
estimate of scale. All supplied fields retain raw repeats and descriptive
statistics in the result and exported JSON.

## Solver assumptions and signs

For each axis, let `s` be scale, `c_outer` outward displacement of an outside
boundary and `c_inner` material encroachment into a window. The idealized model
is:

```text
depth interval: m = s*N
outside span:   m = s*N + 2*c_outer
window span:    m = s*N - 2*c_inner
wall thickness:m = s*N + c_outer + c_inner
```

Depth intervals cancel equal displacement of two same-facing boundaries.
This assumes equal local contour behavior and negligible depth-tool bias; it
does not establish their physical equality from two measurements alone.

The primary scale is the least-squares fit through the origin of the 30 and
100 mm depth medians:

```text
s = (30*m_short + 100*m_long) / (30² + 100²)
b_outer = m_overall - 145*s = 2*c_outer
shrinkage_XY_percent = 100 * (1 - (s_X + s_Y)/2)
```

The outside additive term is calculated from the overall span after estimating
scale. Its hypothetical contour correction is `-b_outer/(2*s)`, diagnostic
only. RMS and maximum residual describe the two depth intervals, without
diluting them with the fitted overall span's zero residual.

Additional features never change this fit. Windows supply errors `m-s*N`;
their mean is a descriptive inside additive term `b_inner = -2*c_inner`.
The hypothetical boundary expansion is `-b_inner/(2*s)`, positive for an
undersized window. Each window retains its own error and residual. One window
cannot test consistency of an inside offset. Walls can be compared with
`s*N + b_outer/2 - b_inner/2` only when a window on that measurement axis was
supplied. Otherwise their readings are retained without an invented prediction.

Only filament shrinkage has an apply control. Outside and inside corrections
are never written. Check residuals above 0.25 mm or inside additive terms above
±1 mm flag disagreement and block applying; primary depth RMS is limited to
0.15 mm, maximum residual to 0.25 mm, outside additive term to ±1 mm. The existing
nominal-deviation, XY anisotropy and supported-shrinkage gates remain in force.
These are provisional software checks, not calibrated physical tolerances.

Windows and walls share surfaces with other dimensions. More entries therefore
do not automatically mean greater precision. The result does not estimate
uncertainty or claim improved printed accuracy. The next physical experiment
remains: zero-compensation print → repeated measurements → estimate → separate
verification print and measurements.

## Geometry verification

The generated XY-S mesh matches the canonical oriented surface geometry of the
approved v10 STL: 3400 triangles, one closed component, 145 × 145 × 4.5 mm,
22.170 cm³ geometric volume; four outer end planes each 53.438 mm². Z-B remains
52 × 24 × 120 mm. Combined DA-XYZ-SB has two components with a 10 mm Y gap and
145 × 179 × 120 mm overall bounds. Mesh volume is not a slicer material estimate.
