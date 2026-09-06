# XY-S form, 2026-09-06

Current [XY-S geometry, calculator and Ubuntu GUI validation](xy-s-validation.md):
119 tests passed; preview/export/replay checked; no physical print.

Plugin 0.11.0 adopts the [XY-S r1 reference](../model/xy-reference.md). Six
primary fields collect overall 145 mm outside spans and 30/100 mm depth
intervals. Four optional groups collect widths/spans, steps, windows and walls,
for 32 XY fields total. Z remains 40/80/120. Each feature has specific contact
instructions, method and repeat example. The 580/300 layout, filament name/color,
readback and result page use the existing host patches; no new host patch is
needed. Result details include every supplied check and chain/window diagnostics.

`visible_if` accepts exactly one boolean reference, with no conjunction or
nested group semantics. Optional XY group switches therefore remain accessible
independently of Calibrate XY. Hiding retains data and does not exclude it from
calculation; disabling XY ignores all XY data. Blank optional fields are skipped.
On an unpatched public host all rows remain visible; the dialog patch is needed
for a practical compact form with collapsible groups and scrolling.

The following sections retain the history of the earlier grid form and host
patches; they are not the measurement protocol for XY-S.

# Calculator dialog, 2026-09-05

The calculator now uses short span labels (`X40 [mm]`, etc.) and one shared
instruction with a repeat-entry example. The development dialog shows all five
readings without horizontal scrolling, hides unselected XY/Z measurement rows,
and initially collapses the optional session metadata. Hiding fields preserves
their values. Calibration and apply selections still undergo the same Lua
validation; visibility never authorizes a write.

The latest host dialog aligns all parameter labels in a left column and places
boolean switches in the right control column alongside text/numeric inputs,
matching the native settings layout. Long labels wrap, including the two apply
confirmations. The result's `Show details` switch uses the same alignment.
The control column adapts to the space left by a scrollbar. Plugin 0.10.1
requests a compact 580-unit dialog and a 300-unit input column, retaining room
for five readings per feature. The label column keeps its previous width.

Plugin 0.8.0 adds the selected filament preset name and material slot 1 above the
form and on the result page. It is read automatically on each menu opening and
cannot be edited as an input. `Back` retains the context together with the form;
reopening refreshes it. This identifies the active target preset, while the
optional filament/spool/lot field retains the operator's physical provenance.
An unavailable name is explicit. Opening/cancelling the form writes no settings.

Plugin 0.9.0 adds a bordered color marker beside this context on both pages.
The host reads the current slot color from `ProjectSettingsInteractor::get_colors`,
the same source as the main material selector. A manual project color therefore
takes precedence over the preset's `filament_colour`. Reopening refreshes the
marker without changing the preset. Missing or malformed colors retain the
name without a marker; the border keeps black and white colors visible.

Plugin 0.10.0 adds plain-text tooltips to every calculator parameter. Measurement
help explains full re-seating, 3–5 semicolon-separated readings, decimal comma,
median aggregation and the one-reading preview limit. Apply help identifies
slot 1 and distinguishes active-setting readback from saved presets and physical
verification. Metadata help distinguishes resolution/accuracy from calculation
thresholds and slot color from physical spool identity.

After Run, the same dialog shows the calculation outcome and shrinkage proposals
as current → proposed, plus the difference in percentage points. Errors appear
there too. After applying, plugin 0.7.0 shows the reread and expected values,
their match status, and the change from the initial setting. `Show details`
expands model estimates, fit RMS, repeat statistics,
anisotropy, diagnostic XY size compensation, and warnings. Tall content scrolls;
the action buttons stay accessible. `Back` returns to the existing inputs without
another calculation or preset write. Complete JSON and statistics remain in the
process log, including on older hosts without the result-display extension.

## Required PrusaSlicer extension

The inspected host baseline is `5f096a3cd060d5dcf4e814c53cfb06fd6fc7e332`,
containing the two earlier preset-setting fixes. Its original `PluginDialog`
only supports a flat list of fields and closes after Run. Lua cannot control
field width or visibility, and cannot display a result dialog through that API.

The host changes are now organized as three branches in the PrusaSlicer fork:

| Branch | Tip | Contents |
| --- | --- | --- |
| [fix/lua-plugin-settings](https://github.com/pOmelchenko/PrusaSlicer/tree/fix/lua-plugin-settings) | `5f096a3cd0` | Existing float/int control, preset notification and material override fixes |
| [feat/lua-plugin-dialog](https://github.com/pOmelchenko/PrusaSlicer/tree/feat/lua-plugin-dialog) | `3f31ae4c5b` | Dialog layout, aligned switches, conditional visibility, result presentation, fresh filament name/color context and native parameter tooltips |
| [fix/lua-percentage-readback](https://github.com/pOmelchenko/PrusaSlicer/tree/fix/lua-percentage-readback) | `5e3c9df080` | Numeric reads of percentage-only settings |

Both new branches start at `fix/lua-plugin-settings`. The dialog branch also
contains the subsequent filament-context extension. Their diffs should be reviewed against that base while its fixes remain
unmerged upstream. The existing settings branch was not rewritten.

The independent [dialog patch](../patches/prusaslicer-plugin-dialog.patch) adds:

- optional `info.description`, `info.dialog_width`, and `info.input_width` hints;
- optional `visible_if` references to boolean parameters;
- optional per-parameter `tooltip` strings on string/float/int fields and boolean
  toggles, using the native settings tooltip with line breaks and a wrapped
  width of 350 layout units; empty/missing/non-string help is ignored;
- `api.show_result(summary, details)` with retained inputs and collapsible details;
- scrolling for long forms and result details.
- an optional `describe()` callback for fresh, read-only form/result context
  with an optional `#RRGGBB` marker color as its second return value;
- `BedInstRef:material_preset_info(slot_idx)` returning copied preset ID/name
  and the current project slot color when available.

The host calls `describe()` in a fresh project-enabled Lua state when opening the
form. It does not call `execute()`, and older plugins without the callback keep
their original loading behavior. Callback errors are logged and shown as
unavailable context. The plugin's callback only reads the name in slot 1; it
does not calculate, write settings, or emit a result record. It tolerates an
older host without the preset identity accessor.

The calculator checks for the result function before calling it. Public alpha11
ignores the extra layout hints and continues using the log. The patch leaves
plugins that do not call `api.show_result()` with close-on-Run behavior. The
host patch includes API documentation and dialog regression tests.

Apply to the above host baseline and incrementally rebuild in Ubuntu:

```sh
git -C /path/to/PrusaSlicer apply --check /path/to/dimensional-accuracy/patches/prusaslicer-plugin-dialog.patch
git -C /path/to/PrusaSlicer apply /path/to/dimensional-accuracy/patches/prusaslicer-plugin-dialog.patch
cmake --build /path/to/build/slicer --target slic3r-app-launcher slic3r-shared-tests --parallel 2
xvfb-run -a /path/to/build/slicer/src/slic3r-shared/slic3r-shared-tests '[Lua]' --reporter compact
```

## Percentage reads and plugin write verification

On the baseline without the percentage branch, `ConfigBox:value()` returns `Domain::Percentage` as opaque Lua
userdata. The `value` getter visits the config variant without converting that
type to a Lua number, and no numeric member is registered for it. The plugin
therefore cannot read shrinkage or calculate its change from the current value.
It displays `unavailable`, rather than assuming the value is zero.

The separate `fix/lua-percentage-readback` branch now exposes percentage points
as a readable number (for example, `0.5` for `0.5%`). It does not change the
distinct `FloatOrPercentage` type. This lets the existing calculator read the
baseline and display a numeric proposed difference. Reacquiring the active
material settings after `set()` and comparing them with the proposals is now
implemented in plugin 0.7.0. It confirms a successful write only when every
requested value matches within 0.000001 percentage point. A mismatch is an
apply error; unavailable reads leave the write unconfirmed. Each setting's
readout is retained in schema 1.2.0 JSON and shown in the result dialog.
Matching readback verifies active settings, while physical dimensional
improvement still requires a print experiment. Neither percentage reads nor
plugin verification are part of the dialog branch.

## Validation

On Ubuntu 26.04.1 ARM64 in UTM, the host rebuilt incrementally and its Lua tests
passed: 4 cases, 49 assertions. The plugin's full test suite passed: 54 Python,
35 calculator Lua and 5 generator Lua tests, plus syntax/manifest checks. The
runtime bundle was staged using the existing generated meshes.

An isolated GUI instance checked five readings per XY field (decimal commas
and decimal points), a synthetic `0.5000%` preview, in-window diagnostics,
return to the retained inputs, Z visibility, optional metadata and scrolling.
All apply controls were clear; this check made no compensation-setting writes.
The synthetic result remained `NOT_REQUESTED` / `NOT_PERFORMED` / `NOT_VERIFIED`
for apply, readback and physical verification respectively.

The updated binary and staged plugin are under
`/home/omelchenko/prusaslicer-alpha` in the VM. Restart PrusaSlicer using
`bash ~/prusaslicer-alpha/launch-slicer.sh` to load the rebuilt host.

The subsequent percentage regression failed against the original getter, then
passed after the conversion fix. With both topic patches present, the Ubuntu
host rebuilt successfully and all 5 Lua test cases passed (77 assertions).
The new test covers numeric reads before writes, zero/positive/negative values,
both supported shrinkage boundaries, retained and freshly obtained preset
handles, and independent checks of the native percentage units.

Plugin 0.7.0 subsequently passed **58 Python, 41 calculator Lua and 5 generator
Lua tests** (104 total), plus syntax, manifest and artifact checks, through
`stage-plugin-existing`. Readback tests cover fresh handles, silent no-ops,
partial matches, unreadable values, accessor failures, numeric tolerance,
independent XY/Z application, setter exceptions and best-effort rollback.
Export/replay validates the added record fields and retains legacy compatibility.

A second isolated GUI instance used a separate configuration copy and synthetic
session `SYNTHETIC-READBACK-NO-PHYSICAL-PRINT`. Three identical readings per XY
span (39.80, 79.60, 119.40 mm for both X and Y) first produced a preview from
a readable zero baseline. Applying XY then read back 0.49999999999998934%, equal
to the proposal. The dialog displayed `Written and checked`, current/expected
0.500000% and change +0.500000 percentage points. The final schema-1.2 record
passed export validation with apply CONFIRMED, readback MATCHED and physical
verification NOT_VERIFIED. No print was performed; the synthetic write was
confined to that separate configuration. That check used plugin 0.7.0.

The filament-context extension is commit `484491019905f9698a84cf159b4fcc9eacada234`
on the existing dialog branch, which combines with the Percentage branch without
conflicts. Ubuntu was rebuilt with all three host topics. All **9 Lua host test
cases passed (125 assertions)**, covering fresh material identities, copied
metadata, slot selection, read-only context, callback failures, legacy loading
and retained form values. Plugin **0.8.0** passed **58 Python, 44 calculator Lua
and 5 generator Lua tests** (107 total), plus the existing staging checks.

In a separate Ubuntu GUI configuration, opening the calculator showed
`Prusament PLA @MK2.5_MK3 0.4 · slot 1`. After cancelling, selecting
`ROSA3D PETG Standard`, and reopening, it showed the corresponding PETG preset
name. A synthetic XY preview kept this name visible on the result page. The
log contained exactly one calculation record, from Run; opening/cancelling
performed no calculation or plugin setting writes. Apply remained NOT_REQUESTED,
readback NOT_PERFORMED and physical verification NOT_VERIFIED. The main staged
bundle is now 0.8.0; restart the launcher above to load the updated host.

The color extension is commit `0fb56004de735df9333b121cdf611055b0aaf63f` on the
same dialog branch. It combines with the independent Percentage branch without
conflicts. With both topics, the Ubuntu host rebuilt and passed **11 Lua test
cases (200 assertions)**. The tests cover project color overrides without preset
changes, copied color metadata, single-text callback compatibility, invalid
colors, black/white border visibility and sufficient width for the context text.
Plugin **0.9.0** passed **58 Python, 46 calculator Lua and 5 generator Lua tests**
(109 total), plus syntax, manifest, artifact and staging checks. Result schema
and solver versions remain 1.2.0 and 2.0.0 respectively.

In the isolated Ubuntu GUI, the calculator first displayed the orange slot
marker. After cancelling and entering `#1234AB` in the main material color
picker, reopening showed the same blue color beside the unchanged Prusament PLA
preset name. A synthetic XY preview retained the blue marker on the result page.
The log contained one calculation record, from Run, with apply NOT_REQUESTED
and physical verification NOT_VERIFIED. The plugin made no setting writes.
The main development configuration was not used for the color change. That
check used the staged 0.9.0 bundle.

The tooltip extension is commit `ab5989ee772c05fe7d9fe6d39bc8ca11e9b7e01f` on
the existing dialog branch, published to the fork. It combines with the
Percentage branch without conflicts. The combined Ubuntu host rebuilt and
passed **13 Lua cases (296 assertions)**. Added checks cover optional/invalid
help metadata, all four parameter types, literal text and newlines, wrapped
width, native input hover and close behavior, and unchanged values passed to
`execute`. Plugin **0.10.0** passed **58 Python, 47 calculator Lua and 5 generator
Lua tests** (110 total), plus syntax, manifest, artifact and staging checks.
The actual measurement parser accepts every tooltip's generated example.

In a separate Ubuntu configuration/display, native tooltips were visually
checked on an empty measurement field, an edited field, calibration and Apply
toggles, and the filament/spool field after scrolling the metadata section.
Long help stays on screen, wraps, and preserves paragraph breaks. Moving to
another control replaces the help; Cancel removes the dialog and its help.
Run was never clicked and the log contains no calculation records. No plugin
setting writes or physical prints were performed. The isolated instance was
stopped after the check. That check used the **0.10.0** bundle.

The control-column alignment is commit
`3f31ae4c5bec13ee46b0336ec6e97a46f2ee099c` on the same published dialog branch.
The combined host rebuilt and passed the existing **13 Lua cases (296
assertions)**, including tooltip metadata and retained hidden/result values.
Plugin **0.10.1** passed **58 Python, 47 calculator Lua and 5 generator Lua
tests** (110 total) and the staging checks. Its only runtime changes are the
dialog/input width hints and version; solver 2.0.0 and result schema 1.2.0 are
unchanged.

The Ubuntu GUI check confirmed the switches share the input column, long
confirmation labels wrap, and enabling/disabling Z retains the XY entries.
At the final 580/300 widths, all five `120.00` readings and separators are
visible without horizontal scrolling. A synthetic all-nominal XY preview
showed five readings per span; Show details opened from its right-column switch,
and Back retained the complete inputs. The log contains one preview record,
with no apply request, readback or physical verification. The isolated instance
was stopped. The development bundle is **0.10.1**. With the updated host already
running, close the calculator, choose Plugins → Rescan Plugins and reopen it
to reload the new width hints; restarting the launcher also reloads them.
