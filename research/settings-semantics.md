# Setting semantics checked for this implementation

Checked on 2026-09-04 against the local PrusaSlicer source commit
`5f096a3cd060d5dcf4e814c53cfb06fd6fc7e332`. This names inspected source,
not a tested public apply-capable binary. No host capability claim is inferred.

| Key | Owner / units / range | Zero-baseline meaning / scope | API and failure behavior |
|---|---|---|---|
| filament_shrinkage_compensation_xy | Filament slot 1, percent, config −10…10 | XY scale multiplier 100/(100−p); a zero-baseline measured slope s yields descriptive p=100(1−s); one value for X/Y | Read may be numeric/text/Percentage; unreadable is explicit. Write requires host and original-print zero confirmations and repeats; plugin 0.7.0 confirms only a successful write with matching fresh readback |
| filament_shrinkage_compensation_z | Filament slot 1, percent, config −10…10 | Same scaling formula along Z; no corresponding additive Z setting is used | Same rules; independent XY/Z selection and all selected fits checked before writes |
| xy_size_compensation | Print, mm, positive outward / negative inward; object override possible; definition sets no explicit numeric min/max | Contour offset during slicing; zero baseline is required for the outer-span model; −b/(2s) is hypothetical | Read to check baseline; diagnostic output only; no apply control or write operation |

Source locations (relative to the inspected PrusaSlicer checkout):

- `src/slic3r-domain/src/Slic3r/Domain/ConfigDefsFDM.cpp`: owners, sign,
  units and configured ranges (filament keys at 1525/1540, XY size at 4834).
- `src/libslic3r/src/libslic3r/ShrinkageCompensation.cpp`: axis multipliers;
  its broad internal −99…99 clamp is not the plugin's accepted config range.
- `src/libslic3r/src/libslic3r/PrintObject.cpp`: shrinkage in object transforms.
- `src/libslic3r/src/libslic3r/PrintObjectSlice.cpp`: XY boundary offsets;
  positive and negative offsets have separate slicing paths; material/fuzzy
  painting can change applicability. The plugin's scope remains a single-
  material ordinary gauge, with no painted per-feature process.
- `src/slic3r-shared/src/Slic3r/App/Lua/ProjectApi.cpp`: `ConfigBox:value`
  and `ConfigBox:set`, material slot indexed from zero. Setter returns no
  success status and can return without writing; no transaction is exposed.

Compensation is defined on the sliced/scaled model, while measured dimensions
also contain physical shrinkage and boundary effects. The hypothetical outer
span formula assumes m=sN+b, then m_new=s(N+2c)+b for zero shrinkage baseline;
solving for c gives −b/(2s). It does not prove that real seam/first-layer/jaw
effects will respond to that setting. Nonzero-baseline iteration would require
explicit composition; it remains blocked instead of silently replacing an
existing correction. Current settings never prove an old print's baseline.

No new setting or setter API is introduced here. Shrinkage application remains
experimental; the contour write path is removed. The separate host
`fix/lua-percentage-readback` patch converts `Domain::Percentage` to numeric
percentage points for Lua. Plugin 0.7.0 reacquires the active material settings
after writing and compares all requested shrinkage values with the calculation
using an absolute tolerance of 0.000001 percentage point. Matching values and
successful setters produce `apply_status=CONFIRMED`; a mismatch or setter
exception produces ERROR_UNCONFIRMED; unreadable values leave UNCONFIRMED.

The structured record separates the workflow (`APPLY_ATTEMPTED`), write outcome,
readback and physical verification (`NOT_VERIFIED`). Tests cover silent no-ops,
partial matches, failed reads, numeric tolerance, selected-axis scope and final
readback after best-effort rollback. This checks active settings, not persistence,
fresh slicing or dimensional improvement. See [result schema](results-v1.md) and
the [development host and GUI checks](calculator-ui.md).
