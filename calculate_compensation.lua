-- SPDX-License-Identifier: AGPL-3.0-only
-- Copyright (C) 2026 pOmelchenko

-- BEGIN GENERATED ARTIFACT SPEC
local PLUGIN_VERSION = "0.11.0"
local NOMINAL_LENGTHS = {40, 80, 120}
local GAUGE_ARTIFACTS = {
    xy = {id = "DA-XY-S", revision = 1},
    z = {id = "DA-Z-B", revision = 1},
    xyz = {id = "DA-XYZ-SB", revision = 1},
}
local XY_FEATURES = {
    {id = "x_overall145", axis = "x", label = "X overall [145 mm]", nominal_mm = 145, method = "outer_jaws", group = "primary", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = true, help = "Outside jaws: between the left short-arm end and the right long-arm end. Full horizontal span. This is the new 145 mm stepped cross, not the old grid gauge."},
    {id = "x_short30", axis = "x", label = "X short depth [30 mm]", nominal_mm = 30, method = "depth_rod", group = "primary", contour_coefficient = 0, inner_coefficient = 0, repeat_protocol = "full_reseat", required = true, help = "Depth rod from the left short-arm end to the left side of the vertical arm; guide along the lower edge of the short arm. Seat the sole on the end face and the rod on the flat target beside the relief. This is a depth measurement, not an outside width."},
    {id = "x_long100", axis = "x", label = "X long depth [100 mm]", nominal_mm = 100, method = "depth_rod", group = "primary", contour_coefficient = 0, inner_coefficient = 0, repeat_protocol = "full_reseat", required = true, help = "Depth rod from the right tip to the right side of the upper arm, along the straight upper edge. Seat the sole on the tip and the rod on the flat target beside the corner relief."},
    {id = "x_cross15", axis = "x", label = "X crossing width [15 mm]", nominal_mm = 15, method = "outer_jaws", group = "widths", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the vertical short arm, in the X direction. This 15 mm width closes the short-depth + crossing-width + long-depth = overall chain."},
    {id = "x_width15", axis = "x", label = "X width at tip [15 mm]", nominal_mm = 15, method = "outer_jaws", group = "widths", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the tip of the vertical long arm. Measure in X, perpendicular to that arm. The engraved 15 identifies the section."},
    {id = "x_width25", axis = "x", label = "X width middle [25 mm]", nominal_mm = 25, method = "outer_jaws", group = "widths", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the middle section of the vertical long arm. Measure in X, perpendicular to that arm. The engraved 25 identifies the section."},
    {id = "x_width35", axis = "x", label = "X width wide [35 mm]", nominal_mm = 35, method = "outer_jaws", group = "widths", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the wide root section of the vertical long arm. Measure in X, perpendicular to that arm. The engraved 35 identifies the section."},
    {id = "x_span85", axis = "x", label = "X compound span [85 mm]", nominal_mm = 85, method = "outer_jaws", group = "widths", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws from the left face of the vertical arm to the outer/middle junction of the horizontal long arm, below its straight bottom edge."},
    {id = "x_root30", axis = "x", label = "X root section [30 mm]", nominal_mm = 30, method = "outer_jaws", group = "steps", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws along the horizontal long arm: measure the two opposite ends of its widest section. This interval uses outside jaws; it is not one of the depth steps."},
    {id = "x_step_middle30", axis = "x", label = "X middle step [30 mm]", nominal_mm = 30, method = "depth_rod", group = "steps", contour_coefficient = 0, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Depth rod along the horizontal long arm, between the two successive step/end planes bounding the middle section. Guide beside the stepped edge, with the sole on the farther-out plane."},
    {id = "x_step_tip30", axis = "x", label = "X tip step [30 mm]", nominal_mm = 30, method = "depth_rod", group = "steps", contour_coefficient = 0, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Depth rod along the horizontal long arm, between the two successive step/end planes bounding the tip section. Guide beside the stepped edge, with the sole on the farther-out plane."},
    {id = "x_inner45", axis = "x", label = "X window length [45 mm]", nominal_mm = 45, method = "inner_jaws", group = "windows", contour_coefficient = 0, inner_coefficient = -2, repeat_protocol = "full_reseat", required = false, help = "Inside jaws along the horizontal window, between its flat end faces. Avoid the corner reliefs and top/bottom chamfers. This is the X internal length."},
    {id = "x_inner10", axis = "x", label = "X window width [10 mm]", nominal_mm = 10, method = "inner_jaws", group = "windows", contour_coefficient = 0, inner_coefficient = -2, repeat_protocol = "full_reseat", required = false, help = "Inside jaws across the vertical window, in X. Avoid the corner reliefs and chamfers. The window in the other arm supplies this 10 mm measurement along the selected axis."},
    {id = "x_wall_straight7_5", axis = "x", label = "X straight wall [7.5 mm]", nominal_mm = 7.5, method = "outer_jaws", group = "walls", contour_coefficient = 1, inner_coefficient = 1, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the material between the straight outside edge of the vertical long arm and the adjacent window face. One jaw enters the window. Measure in X, away from corner reliefs."},
    {id = "x_wall_wide17_5", axis = "x", label = "X wide wall [17.5 mm]", nominal_mm = 17.5, method = "outer_jaws", group = "walls", contour_coefficient = 1, inner_coefficient = 1, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the material between the widest stepped outside edge of the vertical long arm and the adjacent window face. One jaw enters the window. Measure in X, away from corner reliefs."},
    {id = "x_wall_middle7_5", axis = "x", label = "X middle wall [7.5 mm]", nominal_mm = 7.5, method = "outer_jaws", group = "walls", contour_coefficient = 1, inner_coefficient = 1, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the material between the middle stepped outside edge of the vertical long arm and the adjacent window face. One jaw enters the window. Measure in X, away from corner reliefs."},
    {id = "y_overall145", axis = "y", label = "Y overall [145 mm]", nominal_mm = 145, method = "outer_jaws", group = "primary", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = true, help = "Outside jaws: between the upper short-arm end and the lower long-arm end. Full vertical span. This is the new 145 mm stepped cross, not the old grid gauge."},
    {id = "y_short30", axis = "y", label = "Y short depth [30 mm]", nominal_mm = 30, method = "depth_rod", group = "primary", contour_coefficient = 0, inner_coefficient = 0, repeat_protocol = "full_reseat", required = true, help = "Depth rod from the upper short-arm end to the top side of the horizontal arm; guide along the left edge of the short arm. Seat the sole on the end face and the rod on the flat target beside the relief. This is a depth measurement, not an outside width."},
    {id = "y_long100", axis = "y", label = "Y long depth [100 mm]", nominal_mm = 100, method = "depth_rod", group = "primary", contour_coefficient = 0, inner_coefficient = 0, repeat_protocol = "full_reseat", required = true, help = "Depth rod from the lower tip to the bottom side of the right arm, along the straight right edge. Seat the sole on the tip and the rod on the flat target beside the corner relief."},
    {id = "y_cross15", axis = "y", label = "Y crossing width [15 mm]", nominal_mm = 15, method = "outer_jaws", group = "widths", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the horizontal short arm, in the Y direction. This 15 mm width closes the short-depth + crossing-width + long-depth = overall chain."},
    {id = "y_width15", axis = "y", label = "Y width at tip [15 mm]", nominal_mm = 15, method = "outer_jaws", group = "widths", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the tip of the horizontal long arm. Measure in Y, perpendicular to that arm. The engraved 15 identifies the section."},
    {id = "y_width25", axis = "y", label = "Y width middle [25 mm]", nominal_mm = 25, method = "outer_jaws", group = "widths", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the middle section of the horizontal long arm. Measure in Y, perpendicular to that arm. The engraved 25 identifies the section."},
    {id = "y_width35", axis = "y", label = "Y width wide [35 mm]", nominal_mm = 35, method = "outer_jaws", group = "widths", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the wide root section of the horizontal long arm. Measure in Y, perpendicular to that arm. The engraved 35 identifies the section."},
    {id = "y_span85", axis = "y", label = "Y compound span [85 mm]", nominal_mm = 85, method = "outer_jaws", group = "widths", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws from the top face of the left short arm to the middle/tip junction of the vertical long arm."},
    {id = "y_root30", axis = "y", label = "Y root section [30 mm]", nominal_mm = 30, method = "outer_jaws", group = "steps", contour_coefficient = 2, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Outside jaws along the vertical long arm: measure the two opposite ends of its widest section. This interval uses outside jaws; it is not one of the depth steps."},
    {id = "y_step_middle30", axis = "y", label = "Y middle step [30 mm]", nominal_mm = 30, method = "depth_rod", group = "steps", contour_coefficient = 0, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Depth rod along the vertical long arm, between the two successive step/end planes bounding the middle section. Guide beside the stepped edge, with the sole on the farther-out plane."},
    {id = "y_step_tip30", axis = "y", label = "Y tip step [30 mm]", nominal_mm = 30, method = "depth_rod", group = "steps", contour_coefficient = 0, inner_coefficient = 0, repeat_protocol = "full_reseat", required = false, help = "Depth rod along the vertical long arm, between the two successive step/end planes bounding the tip section. Guide beside the stepped edge, with the sole on the farther-out plane."},
    {id = "y_inner45", axis = "y", label = "Y window length [45 mm]", nominal_mm = 45, method = "inner_jaws", group = "windows", contour_coefficient = 0, inner_coefficient = -2, repeat_protocol = "full_reseat", required = false, help = "Inside jaws along the vertical window, between its flat end faces. Avoid the corner reliefs and top/bottom chamfers. This is the Y internal length."},
    {id = "y_inner10", axis = "y", label = "Y window width [10 mm]", nominal_mm = 10, method = "inner_jaws", group = "windows", contour_coefficient = 0, inner_coefficient = -2, repeat_protocol = "full_reseat", required = false, help = "Inside jaws across the horizontal window, in Y. Avoid the corner reliefs and chamfers. The window in the other arm supplies this 10 mm measurement along the selected axis."},
    {id = "y_wall_straight7_5", axis = "y", label = "Y straight wall [7.5 mm]", nominal_mm = 7.5, method = "outer_jaws", group = "walls", contour_coefficient = 1, inner_coefficient = 1, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the material between the straight outside edge of the horizontal long arm and the adjacent window face. One jaw enters the window. Measure in Y, away from corner reliefs."},
    {id = "y_wall_wide17_5", axis = "y", label = "Y wide wall [17.5 mm]", nominal_mm = 17.5, method = "outer_jaws", group = "walls", contour_coefficient = 1, inner_coefficient = 1, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the material between the widest stepped outside edge of the horizontal long arm and the adjacent window face. One jaw enters the window. Measure in Y, away from corner reliefs."},
    {id = "y_wall_middle7_5", axis = "y", label = "Y middle wall [7.5 mm]", nominal_mm = 7.5, method = "outer_jaws", group = "walls", contour_coefficient = 1, inner_coefficient = 1, repeat_protocol = "full_reseat", required = false, help = "Outside jaws across the material between the middle stepped outside edge of the horizontal long arm and the adjacent window face. One jaw enters the window. Measure in Y, away from corner reliefs."},
}
-- END GENERATED ARTIFACT SPEC

local function measurement_help(axis, nominal)
    return string.format(
        "Repeated measurements of %s%g, in mm. Remove and re-seat the caliper between readings.\n\n" ..
        "Enter 3-5 readings separated by ;\nExample: %.2f;%.2f;%.2f\n" ..
        "Decimal point or comma is accepted. The calculation uses the median. " ..
        "One reading permits preview only.", axis, nominal, nominal - 0.02, nominal, nominal - 0.01)
end

info = {
    id = "dev.omelchenko.dimensional-accuracy.calculate",
    type = "project.plugin",
    title = "Calculate dimensional compensation (experimental)",
    menu = "Calibration/Dimensional accuracy/2. Calculate and apply",
    description = "XY-S r1: stepped cross, 145 mm; windows 10 x 45 mm.\n" ..
        "3-5 re-seat readings per field, separated by ; (decimal comma accepted).",
    dialog_width = 580,
    input_width = 300,
    params = {
        {
            name = "calibrate_xy",
            label = "Calibrate XY",
            type = "bool",
            default = true,
            tooltip = "Use the X and Y measurements to estimate one shared XY shrinkage value. " ..
                "The 145 mm outside span and 30/100 mm depth readings are required on both axes. Incompatible X/Y scale estimates block the calculation.\n\n" ..
                "This switch selects the calculation; it does not apply settings."
        },
        {
            name = "calibrate_z",
            label = "Calibrate Z",
            type = "bool",
            default = false,
            tooltip = "Show the Z40, Z80 and Z120 measurements and calculate Z shrinkage separately. " ..
                "When disabled, Z readings are retained but ignored.\n\n" ..
                "This switch does not apply settings."
        },
        {name = "z40", label = "Z40 [mm]", type = "string", default = "", visible_if = "calibrate_z",
            tooltip = measurement_help("Z", 40)},
        {name = "z80", label = "Z80 [mm]", type = "string", default = "", visible_if = "calibrate_z",
            tooltip = measurement_help("Z", 80)},
        {name = "z120", label = "Z120 [mm]", type = "string", default = "", visible_if = "calibrate_z",
            tooltip = measurement_help("Z", 120)},
        {name = "show_metadata", label = "Session details (optional)", type = "bool", default = false,
            tooltip = "Show optional information recorded with this calculation for later comparison. " ..
                "Hiding these fields retains their values. These details do not change the calculated compensation."},
        {name = "session_id", label = "Session / print ID", type = "string", default = "", visible_if = "show_metadata",
            tooltip = "Identifier for this measurement session or printed gauge. Use it to connect the result " ..
                "to the baseline print and later verification print."},
        {name = "operator_id", label = "Operator", type = "string", default = "", visible_if = "show_metadata",
            tooltip = "Name or identifier of the person taking the measurements. Optional recordkeeping."},
        {name = "caliper_id", label = "Caliper", type = "string", default = "", visible_if = "show_metadata",
            tooltip = "Model or identifier of the caliper used for this session. Optional recordkeeping."},
        {name = "resolution_mm", label = "Resolution [mm]", type = "string", default = "", visible_if = "show_metadata",
            tooltip = "Smallest displayed or readable increment of the caliper, in mm; for example 0.01.\n\n" ..
                "Recorded for traceability only; it does not set the part tolerance or change the calculation. " ..
                "Leave blank if unknown."},
        {name = "mpe_mm", label = "Accuracy bound [mm]", type = "string", default = "", visible_if = "show_metadata",
            tooltip = "Maximum permissible error specified for the caliper, entered as a positive magnitude " ..
                "in mm; for example 0.02 for +/-0.02 mm.\n\n" ..
                "Recorded only; it is not used as a calculation threshold. Leave blank if unknown."},
        {name = "slicer_version", label = "PrusaSlicer version / commit", type = "string", default = "", visible_if = "show_metadata",
            tooltip = "Version and, for a patched build, commit used to prepare the measured gauge. " ..
                "This is manually recorded information, not an automatic host capability check."},
        {name = "printer_nozzle", label = "Printer / nozzle", type = "string", default = "", visible_if = "show_metadata",
            tooltip = "Printer and nozzle used for the measured gauge; for example MK3S / 0.4 mm. " ..
                "Recorded only; this field does not select a printer profile."},
        {name = "filament", label = "Filament / spool / lot", type = "string", default = "", visible_if = "show_metadata",
            tooltip = "Record the material, physical spool and lot used for the gauge.\n\n" ..
                "The preset name and color above identify the current slicer slot. Its color may be manually " ..
                "overridden and does not identify a physical spool. This field does not select a preset."},
        {name = "preset_ids", label = "Preset IDs", type = "string", default = "", visible_if = "show_metadata",
            tooltip = "Record the print, filament and printer presets used for the measured gauge. " ..
                "This is a session note; it does not change the target preset shown above."},
        {
            name = "apply_uniform_scale",
            label = "Apply XY shrinkage",
            type = "bool",
            default = false,
            tooltip = "On Run, write the calculated XY shrinkage to the filament in slot 1 shown above. " ..
                "Requires Calibrate XY, repeated readings and both confirmations below.\n\n" ..
                "The setting is read back and compared with the calculation. This does not save the preset " ..
                "to disk or verify printed dimensions. Leave both Apply switches off for preview only."
        },
        {
            name = "apply_z_shrinkage",
            label = "Apply Z shrinkage",
            type = "bool",
            default = false,
            tooltip = "On Run, write the calculated Z shrinkage to the filament in slot 1 shown above. " ..
                "Requires Calibrate Z, repeated readings and both confirmations below.\n\n" ..
                "The setting is read back and compared with the calculation. A verification print and new " ..
                "measurements are still needed to assess physical accuracy."
        },
        {
            name = "confirm_zero_compensation",
            label = "This gauge was printed with selected compensation at zero",
            type = "bool",
            default = false,
            tooltip = "Confirm how this exact gauge was printed: the shrinkage compensation for every axis " ..
                "selected for calibration was zero; for XY, XY size compensation was also zero.\n\n" ..
                "Changing settings to zero after printing does not satisfy this requirement. " ..
                "The calculator does not combine its estimate with an earlier compensation."
        },
        {
            name = "confirm_apply_capable_host",
            label = "This PrusaSlicer build is validated for applying settings",
            type = "bool",
            default = false,
            tooltip = "Confirm that this PrusaSlicer build has been tested to apply plugin changes to the active " ..
                "filament settings. Checking this box does not install patches or test the build.\n\n" ..
                "After an apply attempt, inspect the readback status in the result. " ..
                "Readback confirms the setting value, not the accuracy of a printed part."
        }
    }
}


-- The host accepts one boolean visibility dependency per row. Group switches
-- stay accessible independently; visibility never changes the calculation.
local xy_params = {}
local function append_features(group, visible_if)
    for _, feature in ipairs(XY_FEATURES) do
        if feature.group == group then
            xy_params[#xy_params + 1] = {
                name = feature.id, label = feature.label, type = "string", default = "",
                visible_if = visible_if,
                tooltip = feature.help .. "\n\n" .. measurement_help("", feature.nominal_mm) ..
                    (feature.required and " Required for XY." or
                     " Optional check; leave blank to skip. It does not change the primary scale estimate.")
            }
        end
    end
end
append_features("primary", "calibrate_xy")
for _, group in ipairs({
    {"widths", "XY widths and spans (optional)"},
    {"steps", "XY steps (optional)"},
    {"windows", "XY windows (optional)"},
    {"walls", "XY walls (optional)"}
}) do
    local toggle = "show_xy_" .. group[1]
    xy_params[#xy_params + 1] = {
        name = toggle, label = group[2], type = "bool", default = false,
        tooltip = "Show additional measurements of XY-S r1. Blank fields are skipped. " ..
            "Hiding retains entered readings; they are checked whenever Calibrate XY is enabled. " ..
            "All XY readings are ignored when Calibrate XY is disabled."
    }
    append_features(group[1], toggle)
end
-- Place XY measurements before Z and session metadata, after the axis switches.
for i = #xy_params, 1, -1 do table.insert(info.params, 3, xy_params[i]) end

local SOLVER_VERSION = "3.0.0"
local RESULT_SCHEMA_VERSION = "1.3.0"

-- Called by the dialog extension on each opening, separately from execute().
-- It only describes the active target; spool/lot provenance stays user-entered.
function describe()
    local ok, preset = pcall(function()
        return api.project:current_bed():material_preset_info(0)
    end)
    local name, color = "name unavailable", nil
    if ok and type(preset) == "table" then
        if type(preset.name) == "string" and not preset.name:match("^%s*$") then
            name = preset.name:gsub("[%c]", " ")
        end
        if type(preset.color) == "string" and preset.color:match("^#%x%x%x%x%x%x$") then
            color = preset.color:upper()
        end
    end
    local text = "Filament preset: " .. name .. " · slot 1"
    -- Earlier context hosts expose no color and expect exactly one return value.
    if color then return text, color end
    return text
end

local MIN_SHRINKAGE_PERCENT = -10.0
local MAX_SHRINKAGE_PERCENT = 10.0

-- Conservative data-quality limits. They are intentionally tighter than the
-- slicer's setting range: this tool should reject a doubtful measurement set,
-- not turn it into a plausible-looking profile change.
local MAX_NOMINAL_DEVIATION_MM = 5.0
local MAX_POINT_RESIDUAL_MM = 0.25
local MAX_FIT_RMS_MM = 0.15
local MAX_ABS_INTERCEPT_MM = 1.0
local MAX_XY_ANISOTROPY_PERCENT = 0.10
local ZERO_TOLERANCE = 0.000001
-- Compare stored percentage points, not rounded UI text or fractional ratios.
local READBACK_TOLERANCE_PERCENT = 0.000001

local function is_finite(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_decimal_text(text, allow_percent)
    local normalized = trim(text)

    if allow_percent and normalized:sub(-1) == "%" then
        normalized = trim(normalized:sub(1, -2))
    end

    normalized = normalized:gsub(",", ".")

    local unsigned = normalized
    local first = unsigned:sub(1, 1)
    if first == "+" or first == "-" then
        unsigned = unsigned:sub(2)
    end

    if unsigned == "" then
        return nil
    end
    if not unsigned:match("^%d+$") and
       not unsigned:match("^%d+%.%d+$") then
        return nil
    end

    local parsed = tonumber(normalized)
    if parsed == nil or not is_finite(parsed) then
        return nil
    end
    return parsed
end

local function parse_measurement(label, raw_value)
    local parsed
    if type(raw_value) == "number" then
        parsed = raw_value
    elseif type(raw_value) == "string" then
        parsed = parse_decimal_text(raw_value, false)
    end

    if parsed == nil or not is_finite(parsed) then
        error(string.format(
            "%s must be a plain decimal number in millimetres " ..
            "(for example 39.98); got '%s'",
            label,
            tostring(raw_value)
        ))
    end
    if parsed <= 0.0 then
        error(string.format("%s must be greater than zero; got %.6f", label, parsed))
    end
    return parsed
end

local function median(values)
    local ordered = {}
    for i, value in ipairs(values) do ordered[i] = value end
    table.sort(ordered)
    local middle = math.floor(#ordered / 2)
    if #ordered % 2 == 1 then return ordered[middle + 1] end
    return (ordered[middle] + ordered[middle + 1]) / 2
end

local function parse_repeated_measurement(label, raw)
    local text = type(raw) == "number" and tostring(raw) or raw
    if type(text) ~= "string" then error(label .. " requires decimal measurement text") end
    local values, tokens = {}, {}
    -- Appending the delimiter retains an empty final token so a trailing
    -- separator cannot silently discard a missing observation.
    for token in (text .. ";"):gmatch("(.-);") do
        tokens[#tokens + 1] = token
        values[#values + 1] = parse_measurement(label, token)
    end
    if #values ~= 1 and (#values < 3 or #values > 5) then
        error(label .. " requires 3-5 full re-seat readings separated by ';'; one reading is preview-only")
    end
    local center = median(values)
    local total, minimum, maximum = 0, values[1], values[1]
    for _, value in ipairs(values) do
        total = total + value
        minimum, maximum = math.min(minimum, value), math.max(maximum, value)
    end
    local mean, squares, deviations = total / #values, 0, {}
    for i, value in ipairs(values) do
        squares = squares + (value - mean) ^ 2
        deviations[i] = math.abs(value - center)
    end
    return {
        raw_input = raw, raw_tokens = tokens, values_mm = values,
        n = #values, median_mm = center, mean_mm = mean,
        min_mm = minimum, max_mm = maximum, range_mm = maximum - minimum,
        sample_sd_mm = #values > 1 and math.sqrt(squares / (#values - 1)) or nil,
        mad_mm = median(deviations), aggregation = "median"
    }
end

local function measurements_for_axis(opts, axis_key, axis_label)
    local measured, repeated = {}, {}
    for i, nominal in ipairs(NOMINAL_LENGTHS) do
        local key = axis_key .. tostring(nominal)
        repeated[i] = parse_repeated_measurement(axis_label .. tostring(nominal), opts[key])
        repeated[i].feature_id = key
        repeated[i].nominal_mm = nominal
        measured[i] = repeated[i].median_mm
    end
    return measured, repeated
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function shrinkage_for_scale(measured_scale)
    local calculated = 100.0 * (1.0 - measured_scale)
    return clamp(
        calculated,
        MIN_SHRINKAGE_PERCENT,
        MAX_SHRINKAGE_PERCENT
    ), calculated
end

local function checked_shrinkage_for_scale(axis, measured_scale)
    local limited, calculated = shrinkage_for_scale(measured_scale)
    if math.abs(limited - calculated) > ZERO_TOLERANCE then
        error(string.format(
            "%s calculated shrinkage %.4f%% is outside PrusaSlicer's " ..
            "supported %.0f%% to %.0f%% range. Applying a clamped value " ..
            "would not represent the measurements; check the entered values.",
            axis,
            calculated,
            MIN_SHRINKAGE_PERCENT,
            MAX_SHRINKAGE_PERCENT
        ))
    end
    return calculated
end

local function validate_measurements(axis, measured)
    for i = 1, #NOMINAL_LENGTHS do
        local value = measured[i]
        if type(value) ~= "number" or not is_finite(value) or value <= 0.0 then
            error(string.format("%s measurements must be finite numbers greater than zero", axis))
        end
    end

    for i = 2, #NOMINAL_LENGTHS do
        if measured[i] <= measured[i - 1] then
            error(string.format(
                "%s measurements must increase with nominal length: " ..
                "%s%.0f=%.4f mm must be less than %s%.0f=%.4f mm; " ..
                "check the field order.",
                axis,
                axis,
                NOMINAL_LENGTHS[i - 1],
                measured[i - 1],
                axis,
                NOMINAL_LENGTHS[i],
                measured[i]
            ))
        end
    end

    for i = 1, #NOMINAL_LENGTHS do
        local deviation = math.abs(measured[i] - NOMINAL_LENGTHS[i])
        if deviation > MAX_NOMINAL_DEVIATION_MM then
            error(string.format(
                "%s%.0f measurement %.4f mm differs from nominal by " ..
                "%.4f mm (limit %.2f mm); check the gauge label and value.",
                axis,
                NOMINAL_LENGTHS[i],
                measured[i],
                deviation,
                MAX_NOMINAL_DEVIATION_MM
            ))
        end
    end
end

local function fit_axis(axis, measured)
    validate_measurements(axis, measured)

    local nominal_mean = 0.0
    local measured_mean = 0.0
    for i = 1, #NOMINAL_LENGTHS do
        nominal_mean = nominal_mean + NOMINAL_LENGTHS[i]
        measured_mean = measured_mean + measured[i]
    end
    nominal_mean = nominal_mean / #NOMINAL_LENGTHS
    measured_mean = measured_mean / #NOMINAL_LENGTHS

    local covariance = 0.0
    local nominal_variance = 0.0
    for i = 1, #NOMINAL_LENGTHS do
        local nominal_delta = NOMINAL_LENGTHS[i] - nominal_mean
        covariance = covariance + nominal_delta * (measured[i] - measured_mean)
        nominal_variance = nominal_variance + nominal_delta * nominal_delta
    end

    local slope = covariance / nominal_variance
    local intercept = measured_mean - slope * nominal_mean

    if slope < 0.8 or slope > 1.2 then
        error(string.format(
            "%s calculated scale %.6f is outside the plausible " ..
            "80%%-120%% range; check measurements.",
            axis,
            slope
        ))
    end

    local squared_error = 0.0
    local max_residual = 0.0
    for i = 1, #NOMINAL_LENGTHS do
        local predicted = slope * NOMINAL_LENGTHS[i] + intercept
        local residual = measured[i] - predicted
        squared_error = squared_error + residual * residual
        max_residual = math.max(max_residual, math.abs(residual))
    end
    local rms = math.sqrt(squared_error / #NOMINAL_LENGTHS)

    if max_residual > MAX_POINT_RESIDUAL_MM then
        error(string.format(
            "%s has an individual fit deviation of %.4f mm (limit " ..
            "%.2f mm); repeat the measurements and check for an outlier.",
            axis,
            max_residual,
            MAX_POINT_RESIDUAL_MM
        ))
    end
    if rms > MAX_FIT_RMS_MM then
        error(string.format(
            "%s fit RMS %.4f mm exceeds the %.2f mm quality limit; " ..
            "repeat the measurements before applying compensation.",
            axis,
            rms,
            MAX_FIT_RMS_MM
        ))
    end
    if math.abs(intercept) > MAX_ABS_INTERCEPT_MM then
        error(string.format(
            "%s fitted observed additive term %.4f mm exceeds the +/-%.2f mm " ..
            "quality limit; inspect first-layer effects and measurements.",
            axis,
            intercept,
            MAX_ABS_INTERCEPT_MM
        ))
    end

    return {
        slope = slope,
        intercept = intercept,
        correction_scale = 1.0 / slope,
        contour_compensation = -intercept / (2.0 * slope),
        rms = rms,
        max_residual = max_residual
    }
end

local function calculate_axis(opts, key, label)
    local measured, repeated = measurements_for_axis(opts, key, label)
    local fit = fit_axis(label, measured)
    fit.measurements = repeated
    return fit
end

local function calculate_xy(opts)
    local x = calculate_axis(opts, "x", "X")
    local y = calculate_axis(opts, "y", "Y")

    local anisotropy_percent = math.abs(x.slope - y.slope) * 100.0
    if anisotropy_percent > MAX_XY_ANISOTROPY_PERCENT then
        error(string.format(
            "X/Y anisotropy %.4f%% exceeds the %.2f%% quality limit. " ..
            "PrusaSlicer exposes only one common XY scale, so applying " ..
            "this result would hide an axis-specific problem.",
            anisotropy_percent,
            MAX_XY_ANISOTROPY_PERCENT
        ))
    end

    local mean_measured_scale = (x.slope + y.slope) / 2.0
    return {
        x = x,
        y = y,
        anisotropy_percent = anisotropy_percent,
        shrinkage_percent = checked_shrinkage_for_scale("XY", mean_measured_scale),
        xy_size_compensation =
            (x.contour_compensation + y.contour_compensation) / 2.0
    }
end

local function calculate_z(opts)
    local z = calculate_axis(opts, "z", "Z")
    return {
        fit = z,
        shrinkage_percent = checked_shrinkage_for_scale("Z", z.slope)
    }
end

local function calculate_plan_v1(opts)
    local plan = {}
    if opts.calibrate_xy then
        plan.xy = calculate_xy(opts)
    end
    if opts.calibrate_z then
        plan.z = calculate_z(opts)
    end
    return plan
end

local function diagnostic_model(measured, slope, additive_term, parameters)
    local residuals, sse, maximum = {}, 0, 0
    for i, nominal in ipairs(NOMINAL_LENGTHS) do
        residuals[i] = measured[i] - slope * nominal - additive_term
        sse = sse + residuals[i] ^ 2
        maximum = math.max(maximum, math.abs(residuals[i]))
    end
    return {
        slope = slope, observed_additive_term_mm = additive_term,
        residuals_mm = residuals, sse_mm2 = sse, rms_mm = math.sqrt(sse / #measured),
        max_residual_mm = maximum, parameters = parameters,
        residual_degrees_of_freedom = #measured - parameters,
        descriptive_shrinkage_percent = 100 * (1 - slope)
    }
end

local function compare_models(fit)
    local measured, sum_nm, sum_nn, maximum_range = {}, 0, 0, 0
    for i, observation in ipairs(fit.measurements) do
        measured[i] = observation.median_mm
        sum_nm = sum_nm + NOMINAL_LENGTHS[i] * measured[i]
        sum_nn = sum_nn + NOMINAL_LENGTHS[i] ^ 2
        maximum_range = math.max(maximum_range, observation.range_mm)
    end
    local m0 = diagnostic_model(measured, sum_nm / sum_nn, 0, 1)
    local m1 = diagnostic_model(measured, fit.slope, fit.intercept, 2)
    return {
        M0 = m0, M1 = m1,
        rms_reduction_mm = m0.rms_mm - m1.rms_mm,
        slope_difference = m1.slope - m0.slope,
        curvature_hint_mm = measured[2] - (measured[1] + measured[3]) / 2,
        maximum_repeat_range_mm = maximum_range,
        selection_status = "NOT_ESTABLISHED",
        contour_correction_status = "NOT_SUPPORTED_BY_OUTER_SPANS_ALONE",
        reason = "M1 has only one residual degree of freedom. Smaller RMS does not establish a physical cause or a better correction; independent prints and a correction trial are required.",
        descriptive_proposal_model = "M1_LEGACY",
        uncertainty_status = "NOT_ESTIMATED"
    }
end

local function calculate_plan_v2(opts)
    local plan = calculate_plan_v1(opts)
    if plan.xy then
        plan.xy.x.models = compare_models(plan.xy.x)
        plan.xy.y.models = compare_models(plan.xy.y)
        plan.xy.contour_status = "DIAGNOSTIC_ONLY"
    end
    if plan.z then plan.z.fit.models = compare_models(plan.z.fit) end
    return plan
end

-- XY-S separates same-facing depth intervals from opposite outside faces.
-- m_depth = s*N; m_outside = s*N + 2*c_outer. Related widths/steps/windows
-- are checks, not extra independent votes in the primary fit.
local function calculate_stepped_axis(opts, axis)
    local primary, additional, by_id = {}, setmetatable({}, {json_array = true}), {}
    for _, feature in ipairs(XY_FEATURES) do
        if feature.axis == axis then
            local raw = opts[feature.id]
            if feature.required or (raw ~= nil and tostring(raw):match("%S")) then
                local observation = parse_repeated_measurement(feature.id, raw)
                observation.feature_id, observation.nominal_mm = feature.id, feature.nominal_mm
                observation.method, observation.group = feature.method, feature.group
                observation.contour_coefficient = feature.contour_coefficient
                observation.inner_coefficient = feature.inner_coefficient
                if math.abs(observation.median_mm - feature.nominal_mm) > MAX_NOMINAL_DEVIATION_MM then
                    error(feature.id .. " differs from nominal by more than 5 mm; check the feature and value")
                end
                local target = feature.required and primary or additional
                target[#target + 1] = observation
                by_id[feature.id] = observation
            end
        end
    end
    local overall, short, long = primary[1], primary[2], primary[3]
    local slope = (short.nominal_mm * short.median_mm + long.nominal_mm * long.median_mm) /
        (short.nominal_mm ^ 2 + long.nominal_mm ^ 2)
    local intercept = overall.median_mm - slope * overall.nominal_mm
    local sse, maximum = 0, 0
    for _, observation in ipairs({short, long}) do
        observation.predicted_mm = slope * observation.nominal_mm
        observation.residual_mm = observation.median_mm - observation.predicted_mm
        sse = sse + observation.residual_mm ^ 2
        maximum = math.max(maximum, math.abs(observation.residual_mm))
    end
    local rms = math.sqrt(sse / 2)
    if maximum > MAX_POINT_RESIDUAL_MM or rms > MAX_FIT_RMS_MM then
        error(string.format("%s depth readings disagree with a common scale (max residual %.4f mm, RMS %.4f mm); repeat the measurements", axis:upper(), maximum, rms))
    end
    if math.abs(intercept) > MAX_ABS_INTERCEPT_MM then
        error(axis:upper() .. " observed outside additive term exceeds the +/-1 mm quality limit")
    end
    local fit = {
        slope = slope, intercept = intercept, correction_scale = 1 / slope,
        contour_compensation = -intercept / (2 * slope), rms = rms, max_residual = maximum,
        measurements = primary, additional_measurements = additional,
        model = "DEPTH_SCALE_OUTSIDE_BIAS", validation_status = "EXPERIMENTAL",
        uncertainty_status = "NOT_ESTIMATED", additional_status = "NOT_COLLECTED"
    }
    -- An internal additive term is descriptive only. Keep per-window errors:
    -- two nominal sizes can disagree and one cannot verify a shared offset.
    local inner_sum, inner_count = 0, 0
    for _, observation in ipairs(additional) do
        if observation.group == "windows" then
            observation.scale_only_error_mm = observation.median_mm - slope * observation.nominal_mm
            inner_sum, inner_count = inner_sum + observation.scale_only_error_mm, inner_count + 1
        end
    end
    if inner_count > 0 then
        local additive = inner_sum / inner_count
        fit.inner = {
            observed_additive_term_mm = additive,
            hypothetical_boundary_expansion_mm = -additive / (2 * slope),
            observations = inner_count, status = "DIAGNOSTIC_ONLY",
            consistency_status = inner_count > 1 and "CONSISTENT" or "NOT_TESTABLE"
        }
    end
    local inconsistent = false
    for _, observation in ipairs(additional) do
        if observation.inner_coefficient == 0 or fit.inner then
            local inner_offset = fit.inner and -fit.inner.observed_additive_term_mm / 2 or 0
            observation.predicted_mm = slope * observation.nominal_mm +
                observation.contour_coefficient * intercept / 2 + observation.inner_coefficient * inner_offset
            observation.residual_mm = observation.median_mm - observation.predicted_mm
            observation.status = math.abs(observation.residual_mm) <= MAX_POINT_RESIDUAL_MM and "CONSISTENT" or "INCONSISTENT"
            -- An extreme internal bias is also suspicious even if both windows agree.
            if observation.group == "windows" and math.abs(fit.inner.observed_additive_term_mm) > MAX_ABS_INTERCEPT_MM then
                observation.status = "INCONSISTENT"
            end
            if observation.status == "INCONSISTENT" then
                inconsistent = true
                if observation.group == "windows" then fit.inner.consistency_status = "INCONSISTENT" end
            elseif observation.group == "windows" and inner_count == 1 then
                observation.status = "DESCRIPTIVE_ONLY"
            end
        else
            observation.status = "NEEDS_WINDOW_MEASUREMENT"
        end
    end
    local crossing = by_id[axis .. "_cross15"]
    if crossing then
        fit.chain = {
            sum_mm = short.median_mm + crossing.median_mm + long.median_mm,
            overall_mm = overall.median_mm
        }
        fit.chain.closure_error_mm = fit.chain.sum_mm - fit.chain.overall_mm
        fit.chain.status = math.abs(fit.chain.closure_error_mm) <= MAX_POINT_RESIDUAL_MM and "CONSISTENT" or "INCONSISTENT"
        inconsistent = inconsistent or fit.chain.status == "INCONSISTENT"
    end
    if #additional > 0 then fit.additional_status = inconsistent and "INCONSISTENT" or "REVIEWED" end
    return fit
end

local function calculate_plan(opts)
    local plan = {}
    if opts.calibrate_xy then
        local x, y = calculate_stepped_axis(opts, "x"), calculate_stepped_axis(opts, "y")
        local anisotropy = math.abs(x.slope - y.slope) * 100
        if anisotropy > MAX_XY_ANISOTROPY_PERCENT then
            error(string.format("X/Y anisotropy %.4f%% exceeds the %.2f%% quality limit", anisotropy, MAX_XY_ANISOTROPY_PERCENT))
        end
        plan.xy = {
            x = x, y = y, anisotropy_percent = anisotropy,
            shrinkage_percent = checked_shrinkage_for_scale("XY", (x.slope + y.slope) / 2),
            xy_size_compensation = (x.contour_compensation + y.contour_compensation) / 2,
            contour_status = "DIAGNOSTIC_ONLY", artifact_id = GAUGE_ARTIFACTS.xy.id
        }
    end
    if opts.calibrate_z then
        plan.z = calculate_z(opts)
        plan.z.fit.models = compare_models(plan.z.fit)
    end
    return plan
end

local function calculate_plan_version(opts, version)
    if version == "1.0.0" then return calculate_plan_v1(opts) end
    if version == "2.0.0" then return calculate_plan_v2(opts) end
    if version == SOLVER_VERSION then return calculate_plan(opts) end
    error("Unsupported solver version: " .. tostring(version))
end

local function current_fff_settings(calibrate_xy, calibrate_z)
    local ok, state_or_error = pcall(function()
        local bed = api.project:current_bed()
        local state = {
            bed = bed,
            material = bed:material_presets(0),
            current = {}
        }

        if calibrate_xy then
            state.print_settings = bed:print_presets()
            state.current.xy_shrinkage =
                state.material:value("filament_shrinkage_compensation_xy")
            state.current.xy_size =
                state.print_settings:value("xy_size_compensation")
        end
        if calibrate_z then
            state.current.z_shrinkage =
                state.material:value("filament_shrinkage_compensation_z")
        end
        return state
    end)

    if not ok then
        error(
            "Could not access dimensional compensation in the active preset. " ..
            "Use an FFF printer preset with physical material slot 1 available " ..
            "(the Lua API addresses it as index 0). " ..
            "PrusaSlicer reported: " .. tostring(state_or_error)
        )
    end
    return state_or_error
end

local function config_number(raw_value, recursion_depth)
    local value_type = type(raw_value)
    if value_type == "number" then
        if is_finite(raw_value) then
            return raw_value
        end
        return nil
    end
    if value_type == "string" then
        return parse_decimal_text(raw_value, true)
    end

    -- Percentage currently crosses some Plugin API builds as userdata even
    -- though ConfigBox:value() documents a scalar. Use a numeric `value`
    -- member when that build exposes one, otherwise report it as unreadable.
    local depth = recursion_depth or 0
    if depth < 2 and (value_type == "userdata" or value_type == "table") then
        local ok, member = pcall(function()
            return raw_value.value
        end)
        if ok and member ~= nil and member ~= raw_value then
            local parsed_member = config_number(member, depth + 1)
            if parsed_member ~= nil then
                return parsed_member
            end
        end
    end

    local ok, text_value = pcall(tostring, raw_value)
    if ok and type(text_value) == "string" then
        return parse_decimal_text(text_value, true)
    end
    return nil
end

local function current_setting_entries(state, calibrate_xy, calibrate_z)
    local entries = {}
    if calibrate_xy then
        entries[#entries + 1] = {
            label = "Filament shrinkage compensation XY",
            value = state.current.xy_shrinkage
        }
        entries[#entries + 1] = {
            label = "XY size compensation",
            value = state.current.xy_size
        }
    end
    if calibrate_z then
        entries[#entries + 1] = {
            label = "Filament shrinkage compensation Z",
            value = state.current.z_shrinkage
        }
    end
    return entries
end

local function verify_zero_baseline(state, opts, apply_requested)
    local nonzero = {}
    local unreadable = {}

    for _, entry in ipairs(current_setting_entries(
        state,
        opts.calibrate_xy,
        opts.calibrate_z
    )) do
        local numeric = config_number(entry.value)
        if numeric == nil then
            unreadable[#unreadable + 1] = entry.label
        elseif math.abs(numeric) > ZERO_TOLERANCE then
            nonzero[#nonzero + 1] = string.format(
                "%s is %.6f",
                entry.label,
                numeric
            )
        end
    end

    if #nonzero > 0 then
        local details = table.concat(nonzero, "; ")
        if apply_requested then
            error(
                "Calibration requires a gauge printed with the selected " ..
                "compensation settings at zero, but " .. details .. ". " ..
                "Set them to zero, print a new gauge, and rerun; no settings " ..
                "were changed."
            )
        end
        print(
            "WARNING: Preview assumes a zero-compensation gauge, but " ..
            details .. ". Do not apply these results to that compensated print."
        )
    end

    if #unreadable > 0 then
        local labels = table.concat(unreadable, ", ")
        if apply_requested and not opts.confirm_zero_compensation then
            error(
                "PrusaSlicer did not expose a readable numeric value for: " ..
                labels .. ". Verify those settings are zero and enable " ..
                "'I printed the gauge with selected compensation settings at " ..
                "zero' before applying; no settings were changed."
            )
        elseif apply_requested then
            print("Zero-compensation baseline manually confirmed for: " .. labels)
        else
            print(
                "WARNING: PrusaSlicer could not verify the current value of: " ..
                labels .. ". This is a preview only; verify a zero baseline " ..
                "before applying it."
            )
        end
    end
end

local function print_axis_result(axis, result)
    for _, observation in ipairs(result.measurements or {}) do
        print(string.format(
            "%s: raw [%s], n=%d, median %.6f mm, mean %.6f mm, range %.6f mm, sample SD %s, MAD %.6f mm",
            observation.feature_id, table.concat(observation.raw_tokens, ";"), observation.n,
            observation.median_mm, observation.mean_mm, observation.range_mm,
            observation.sample_sd_mm and string.format("%.6f mm", observation.sample_sd_mm) or "unavailable",
            observation.mad_mm
        ))
    end
    print(string.format(
        "%s: measured scale %.6f, correction scale %.4f%%, observed additive term %.4f mm, " ..
        "RMS %.4f mm, max residual %.4f mm",
        axis,
        result.slope,
        result.correction_scale * 100.0,
        result.intercept,
        result.rms,
        result.max_residual
    ))
    if result.models then
        for _, name in ipairs({"M0", "M1"}) do
            local model = result.models[name]
            print(string.format(
                "%s %s: slope %.9f, observed additive term %.6f mm, RMS %.6f mm, SSE %.9f mm^2, residual dof %d",
                axis, name, model.slope, model.observed_additive_term_mm,
                model.rms_mm, model.sse_mm2, model.residual_degrees_of_freedom
            ))
        end
        print(axis .. " model selection: NOT_ESTABLISHED. " .. result.models.reason)
    end
end

local function print_plan(plan)
    print("Dimensional accuracy calibration results")
    if plan.xy ~= nil then
        print_axis_result("X", plan.xy.x)
        print_axis_result("Y", plan.xy.y)
        print(string.format("X/Y anisotropy: %.4f%%", plan.xy.anisotropy_percent))
        print(string.format(
            "Common filament shrinkage compensation XY: %.4f%%",
            plan.xy.shrinkage_percent
        ))
        print(string.format(
            "Hypothetical XY size compensation (diagnostic only): %.4f mm",
            plan.xy.xy_size_compensation
        ))
    end
    if plan.z ~= nil then
        local z = plan.z.fit
        print_axis_result("Z", z)
        print(string.format(
            "Z: measured scale %.6f, correction scale %.4f%%, observed additive term " ..
            "%.4f mm, RMS %.4f mm, max residual %.4f mm",
            z.slope,
            z.correction_scale * 100.0,
            z.intercept,
            z.rms,
            z.max_residual
        ))
        print(string.format(
            "Filament shrinkage compensation Z: %.4f%%",
            plan.z.shrinkage_percent
        ))
    end
end

local function requested_operations(settings, plan, opts)
    local operations = {}

    if plan.xy ~= nil and opts.apply_uniform_scale then
        operations[#operations + 1] = {
            settings = settings.material,
            name = "filament_shrinkage_compensation_xy",
            value = plan.xy.shrinkage_percent,
            label = "filament shrinkage compensation XY"
        }
    end
    if plan.z ~= nil and opts.apply_z_shrinkage then
        operations[#operations + 1] = {
            settings = settings.material,
            name = "filament_shrinkage_compensation_z",
            value = plan.z.shrinkage_percent,
            label = "filament shrinkage compensation Z"
        }
    end

    return operations
end

local function apply_plan(settings, plan, opts)
    -- Every selected axis has already been computed and validated, and the zero
    -- baseline precondition was read or manually confirmed before the first
    -- set(). ConfigBox:set has no success result or transaction support, so a
    -- normal return confirms only that the call did not raise a Lua error. If a
    -- later setter raises, make an explicitly unverified, best-effort rollback
    -- attempt; this cannot make the multi-setting operation atomic.
    local operations = requested_operations(settings, plan, opts)

    for index, operation in ipairs(operations) do
        local ok, set_error = pcall(function()
            operation.settings:set(operation.name, operation.value)
        end)
        if not ok then
            local rollback_failures = {}
            for rollback_index = index, 1, -1 do
                local attempted = operations[rollback_index]
                local rollback_ok, rollback_error = pcall(function()
                    attempted.settings:set(attempted.name, 0.0)
                end)
                if not rollback_ok then
                    rollback_failures[#rollback_failures + 1] = string.format(
                        "%s (%s)",
                        attempted.label,
                        tostring(rollback_error)
                    )
                end
            end

            local message = string.format(
                "A write attempt for %s raised an error: %s. " ..
                "Best-effort rollback calls to zero were attempted for every " ..
                "setting reached in this run.",
                operation.label,
                tostring(set_error)
            )
            if #rollback_failures > 0 then
                message = message ..
                    " Some rollback calls also raised errors: " ..
                    table.concat(rollback_failures, "; ") ..
                    "."
            end
            message = message ..
                " The active presets may be partially changed. Check the final " ..
                "setting readback and restore zero before retrying; rollback " ..
                "calls alone do not confirm that the settings were restored."
            error(message)
        end

        print(string.format(
            "Attempted active-setting write: %s (host returned no status)",
            operation.label
        ))
    end

    print("Write calls completed; checking the active settings.")
end

local function validate_apply_selection(opts)
    if (opts.apply_uniform_scale or opts.apply_contour_offset) and
       not opts.calibrate_xy then
        error("Enable 'Calibrate XY' before selecting an XY apply option")
    end
    if opts.apply_z_shrinkage and not opts.calibrate_z then
        error("Enable 'Calibrate Z' before selecting 'Apply Z shrinkage compensation'")
    end
end

local function json_array(values)
    return setmetatable(values or {}, {json_array = true})
end

local function read_back_settings(operations, record)
    record.readback = {tolerance_percent = READBACK_TOLERANCE_PERCENT, settings = json_array()}
    -- Reacquire after all writes (and any rollback); the pre-write ConfigBox
    -- may be a stale snapshot. Failure to read one key must not hide the others.
    local accessible, material = pcall(function()
        return api.project:current_bed():material_presets(0)
    end)
    local mismatch, unreadable = false, false
    for _, operation in ipairs(operations) do
        local entry = {key = operation.name, expected_percent = operation.value}
        record.readback.settings[#record.readback.settings + 1] = entry
        local ok, failure = pcall(function()
            if not accessible then error(tostring(material)) end
            local raw = material:value(operation.name)
            entry.raw = tostring(raw)
            entry.actual_percent = config_number(raw)
            if entry.actual_percent == nil then error("No readable numeric percentage value") end
        end)
        if not ok then
            entry.status, entry.error = "UNREADABLE", tostring(failure)
            unreadable = true
            print("Could not read back " .. operation.label .. ": " .. entry.error)
        else
            entry.error_percent = entry.actual_percent - entry.expected_percent
            entry.status = math.abs(entry.error_percent) <= READBACK_TOLERANCE_PERCENT and "MATCHED" or "MISMATCH"
            mismatch = mismatch or entry.status == "MISMATCH"
            print(string.format("Readback %s: expected %.9f%%, actual %.9f%% (%s)",
                operation.label, entry.expected_percent, entry.actual_percent, entry.status))
        end
    end
    record.readback_status = mismatch and "MISMATCH" or (unreadable and "UNREADABLE" or "MATCHED")
end

local function json_encode(value)
    local kind = type(value)
    if kind == "nil" then return "null" end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then
        if not is_finite(value) then error("Cannot encode a non-finite result") end
        return string.format("%.17g", value)
    end
    if kind == "string" then
        local escaped = value:gsub('[%z\1-\31\\"]', function(character)
            if character == '"' then return '\\"' end
            if character == '\\' then return '\\\\' end
            return string.format("\\u%04x", string.byte(character))
        end)
        return '"' .. escaped .. '"'
    end
    if kind ~= "table" then error("Unsupported structured-result value") end
    local entries = {}
    if #value > 0 or (getmetatable(value) or {}).json_array then
        for _, item in ipairs(value) do entries[#entries + 1] = json_encode(item) end
        return "[" .. table.concat(entries, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        entries[#entries + 1] = json_encode(key) .. ":" .. json_encode(value[key])
    end
    return "{" .. table.concat(entries, ",") .. "}"
end

local function result_metadata(opts)
    local metadata = {source = "operator_entered", missing = json_array()}
    for _, key in ipairs({"session_id", "operator_id", "caliper_id", "slicer_version",
                           "printer_nozzle", "filament", "preset_ids"}) do
        metadata[key] = opts[key] or ""
        if metadata[key] == "" then metadata.missing[#metadata.missing + 1] = key end
    end
    for _, key in ipairs({"resolution_mm", "mpe_mm"}) do
        if opts[key] ~= nil and opts[key] ~= "" then
            metadata[key] = parse_measurement(key, opts[key])
        else
            metadata.missing[#metadata.missing + 1] = key
        end
    end
    -- MPE remains an instrument error bound, never an assumed standard deviation.
    return metadata
end

local function assess_repeats(plan, apply_requested, record)
    local fits = {}
    if plan.xy then fits[#fits + 1] = plan.xy.x; fits[#fits + 1] = plan.xy.y end
    if plan.z then fits[#fits + 1] = plan.z.fit end
    for _, fit in ipairs(fits) do
        local observations = {}
        for _, observation in ipairs(fit.measurements) do observations[#observations + 1] = observation end
        for _, observation in ipairs(fit.additional_measurements or {}) do observations[#observations + 1] = observation end
        for _, observation in ipairs(observations) do
            if observation.n < 3 then
                record.warnings[#record.warnings + 1] = observation.feature_id .. ": single reading; repeatability unknown"
                if apply_requested then
                    error("Applying requires 3-5 full re-seat readings for every selected dimension")
                end
            end
            if observation.range_mm > math.abs(observation.median_mm - observation.nominal_mm) then
                record.warnings[#record.warnings + 1] = observation.feature_id ..
                    ": measurement range exceeds the observed dimensional deviation"
            end
            if observation.status == "INCONSISTENT" then
                record.warnings[#record.warnings + 1] = observation.feature_id .. ": inconsistent with the primary estimate"
            elseif observation.status == "NEEDS_WINDOW_MEASUREMENT" then
                record.warnings[#record.warnings + 1] = observation.feature_id .. ": collected; enter a window measurement on this axis to assess this wall"
            end
        end
        if fit.additional_status == "INCONSISTENT" and apply_requested then
            error("Additional XY measurements disagree with the estimate; inspect the results and repeat measurements before applying")
        end
    end
end

local function execute_run(opts, record)
    record.metadata = result_metadata(opts)
    if #record.metadata.missing > 0 then
        record.warnings[#record.warnings + 1] = "Incomplete provenance: " .. table.concat(record.metadata.missing, ", ")
    end
    if not opts.calibrate_xy and not opts.calibrate_z then
        error("Select at least one calibration axis: XY or Z")
    end
    validate_apply_selection(opts)
    if opts.apply_contour_offset then
        error("XY size compensation is diagnostic only: outer spans do not establish a physical contour error; no settings were changed")
    end

    local apply_requested =
        (opts.calibrate_xy and
            (opts.apply_uniform_scale or opts.apply_contour_offset)) or
        (opts.calibrate_z and opts.apply_z_shrinkage) or false

    -- Plugin API 1.0.0 has no capability/version query that can distinguish
    -- the public alpha11 setter from a host carrying the preset-update fixes.
    -- Require a separate, explicit assertion in addition to the apply flags.
    if apply_requested and not opts.confirm_apply_capable_host then
        error(
            "Automatic apply requires a validated PrusaSlicer build with " ..
            "the Lua preset-update and material-override fixes. Leave all " ..
            "Apply options cleared for preview, or explicitly confirm the " ..
            "apply-capable host; no settings were changed."
        )
    end
    if apply_requested and not opts.confirm_zero_compensation then
        error(
            "Automatic apply requires confirmation that this exact gauge was " ..
            "printed with every selected compensation setting at zero. The " ..
            "current preset cannot prove how the gauge was printed; no " ..
            "settings were changed."
        )
    end

    -- Calculate all selected axes first. A bad Z input therefore cannot occur
    -- after an XY write attempt (and vice versa).
    local plan = calculate_plan(opts)
    record.plan = plan
    assess_repeats(plan, apply_requested, record)
    local settings = current_fff_settings(opts.calibrate_xy, opts.calibrate_z)
    record.baseline = {}
    local baseline_keys = {}
    if opts.calibrate_xy then baseline_keys = {"xy_shrinkage", "xy_size"} end
    if opts.calibrate_z then baseline_keys[#baseline_keys + 1] = "z_shrinkage" end
    for _, key in ipairs(baseline_keys) do
        local value = settings.current[key]
        record.baseline[key] = {raw = tostring(value), numeric = config_number(value),
                                known = config_number(value) ~= nil}
        if config_number(value) == nil or math.abs(config_number(value)) > ZERO_TOLERANCE then
            record.warnings[#record.warnings + 1] = "Zero baseline not confirmed by current setting: " .. key
        end
    end
    verify_zero_baseline(settings, opts, apply_requested)
    record.workflow_state = "ESTIMATED"
    record.artifacts = {}
    if opts.calibrate_xy then record.artifacts.xy = GAUGE_ARTIFACTS.xy end
    if opts.calibrate_z then record.artifacts.z = GAUGE_ARTIFACTS.z end
    if plan.xy then
        record.warnings[#record.warnings + 1] = "XY-S depth-scale estimate is experimental: it assumes equal displacement of same-facing surfaces. Additional dimensions are related checks, not independent fit observations. Outside and inside offsets are diagnostic only."
    end
    if plan.z then
        record.warnings[#record.warnings + 1] = "Z M0/M1 model selection is not established; the legacy M1 proposal remains experimental"
    end
    record.artifact_identity_source = "expected_selected_gauge; match the physical print label"
    record.proposed_settings = json_array()
    local function proposal(key, owner, baseline_key, value, requested)
        local before = record.baseline[baseline_key]
        record.proposed_settings[#record.proposed_settings + 1] = {
            key = key, owner = owner, before = before, proposed = value,
            delta = before.numeric and value - before.numeric or nil,
            write_requested = requested or false
        }
    end
    if plan.xy then
        proposal("filament_shrinkage_compensation_xy", "filament_slot_1", "xy_shrinkage", plan.xy.shrinkage_percent, opts.apply_uniform_scale)
        proposal("xy_size_compensation", "print", "xy_size", plan.xy.xy_size_compensation, false)
        record.proposed_settings[#record.proposed_settings].status = "DIAGNOSTIC_ONLY"
    end
    if plan.z then
        proposal("filament_shrinkage_compensation_z", "filament_slot_1", "z_shrinkage", plan.z.shrinkage_percent, opts.apply_z_shrinkage)
    end
    for _, warning in ipairs(record.warnings) do print("WARNING: " .. warning) end
    record.severity = #record.warnings > 0 and "WARN" or "PASS"
    print_plan(plan)

    if not apply_requested then
        print(
            "Preview only: no settings were changed. Enable only the apply " ..
            "options you want after reviewing these results."
        )
        return
    end

    -- Persist a full preview in the log before any host mutation. The final
    -- record below reports the outcome of this attempt separately.
    print("DA_RESULT_JSON " .. json_encode(record))
    record.workflow_state = "APPLY_ATTEMPTED"
    record.apply_status = "UNCONFIRMED"
    local applied, apply_error = pcall(apply_plan, settings, plan, opts)
    read_back_settings(requested_operations(settings, plan, opts), record)
    -- A setter exception remains a failure even if rollback leaves a value
    -- matching a zero proposal. Readback describes final state, not history.
    if not applied then error(apply_error) end
    if record.readback_status == "MATCHED" then
        record.apply_status = "CONFIRMED"
        print("Written and checked: all selected active settings match the calculation.")
    elseif record.readback_status == "MISMATCH" then
        error("Active settings do not match the calculation. Check the expected and actual values before slicing or retrying.")
    else
        record.warnings[#record.warnings + 1] = "Could not verify every written value. Manually inspect the selected active settings before slicing."
        print("WARNING: " .. record.warnings[#record.warnings])
    end
end

local function result_text(record)
    local summary, details = {}, {}
    if record.error then
        summary[#summary + 1] = record.apply_status == "ERROR_UNCONFIRMED" and
            "Apply failed; settings may be partially changed." or
            "Calculation stopped; no settings were changed."
        summary[#summary + 1] = record.error:gsub("^.-:%d+: ", "", 1)
    elseif record.apply_status == "CONFIRMED" then
        summary[#summary + 1] = "Written and checked: active settings match the calculation."
    elseif record.apply_status == "UNCONFIRMED" then
        summary[#summary + 1] = "Write attempted; could not verify all current values."
        summary[#summary + 1] = "Inspect the active settings before slicing."
    else
        summary[#summary + 1] = "Preview: no settings were changed."
    end

    local labels = {
        filament_shrinkage_compensation_xy = "XY shrinkage",
        filament_shrinkage_compensation_z = "Z shrinkage",
        xy_size_compensation = "XY size (diagnostic only)"
    }
    local readbacks = {}
    for _, entry in ipairs((record.readback or {}).settings or {}) do readbacks[entry.key] = entry end
    for _, setting in ipairs(record.proposed_settings or {}) do
        local percent = setting.key ~= "xy_size_compensation"
        local unit = percent and "%" or " mm"
        local before = setting.before.numeric
        local current = before and string.format("%.4f%s", before, unit) or "unavailable"
        local change = setting.delta and string.format("%+.4f%s", setting.delta,
            percent and " percentage points" or " mm") or "unavailable"
        local line = string.format("%s: %s -> %.4f%s; change %s",
            labels[setting.key], current, setting.proposed, unit, change)
        local readback = readbacks[setting.key]
        if readback then
            details[#details + 1] = line .. " (before -> proposed)"
            local actual = readback.actual_percent and string.format("%.6f%%", readback.actual_percent) or "unavailable"
            local status = ({MATCHED = "matches", MISMATCH = "MISMATCH", UNREADABLE = "not verified"})[readback.status]
            summary[#summary + 1] = string.format("%s: current %s; expected %.6f%% (%s)",
                labels[setting.key], actual, readback.expected_percent, status)
            if before and readback.actual_percent then
                summary[#summary] = summary[#summary] .. string.format("\nChange from before: %+.6f percentage points",
                    readback.actual_percent - before)
            end
            if readback.error then details[#details + 1] = labels[setting.key] .. ": " .. readback.error end
        else
            local target = percent and summary or details
            target[#target + 1] = line .. (record.readback and " (proposal only)" or "")
        end
    end
    if #(record.proposed_settings or {}) > 0 and not record.readback then
        summary[#summary + 1] = "Values above: current -> proposed."
    end
    for _, setting in pairs(record.baseline or {}) do
        if not setting.known then
            summary[#summary + 1] = record.readback and
                "Some values before writing were unavailable; their changes cannot be calculated." or
                "PrusaSlicer could not read all current values; their changes are unavailable."
            break
        end
    end
    if not record.error then
        summary[#summary + 1] = "Assumes a gauge printed with selected compensation at zero."
        for _, setting in pairs(record.baseline or {}) do
            if setting.numeric and math.abs(setting.numeric) > ZERO_TOLERANCE then
                summary[#summary + 1] = "Warning: a current compensation is nonzero. Check the print baseline."
                break
            end
        end
        summary[#summary + 1] = "Experimental estimate; improvement requires a verification print."
        summary[#summary + 1] = string.format("%d notes and warnings in Show details.", #record.warnings)
    end

    local function axis_details(axis, fit)
        details[#details + 1] = string.format(
            "%s: correction scale %.4f%%; additive term %+.4f mm; fit RMS %.4f mm",
            axis, fit.correction_scale * 100, fit.intercept, fit.rms)
        if fit.models then
            details[#details + 1] = string.format(
                "%s shrinkage estimates: M0 %.4f%%; M1 %.4f%% (physical model not established)",
                axis, fit.models.M0.descriptive_shrinkage_percent,
                fit.models.M1.descriptive_shrinkage_percent)
        end
        if fit.model then
            details[#details + 1] = axis .. ": scale from 30/100 mm depth intervals; outside additive term from the 145 mm span. RMS describes the two depth intervals."
        end
        for _, observation in ipairs(fit.measurements or {}) do
            details[#details + 1] = string.format("%s: n=%d; median %.4f mm; range %.4f mm",
                observation.feature_id:upper(), observation.n,
                observation.median_mm, observation.range_mm)
        end
        if fit.inner then
            details[#details + 1] = string.format(
                "%s windows: observed additive term %+.4f mm; hypothetical boundary expansion %+.4f mm (diagnostic only, never applied); %s",
                axis, fit.inner.observed_additive_term_mm, fit.inner.hypothetical_boundary_expansion_mm,
                fit.inner.consistency_status)
        end
        for _, observation in ipairs(fit.additional_measurements or {}) do
            details[#details + 1] = string.format("%s: n=%d; median %.4f mm; range %.4f mm; %s%s",
                observation.feature_id:upper(), observation.n, observation.median_mm, observation.range_mm,
                observation.status, observation.residual_mm and string.format("; check residual %+.4f mm", observation.residual_mm) or "")
        end
        if fit.chain then
            details[#details + 1] = string.format("%s chain: short depth + crossing width + long depth = %.4f mm; overall %.4f mm; closure error %+.4f mm (%s)",
                axis, fit.chain.sum_mm, fit.chain.overall_mm, fit.chain.closure_error_mm, fit.chain.status)
        end
    end
    local plan = record.plan or {}
    if plan.xy then
        axis_details("X", plan.xy.x)
        axis_details("Y", plan.xy.y)
        details[#details + 1] = string.format("X/Y anisotropy: %.4f percentage points", plan.xy.anisotropy_percent)
    end
    if plan.z then axis_details("Z", plan.z.fit) end
    for _, warning in ipairs(record.warnings) do details[#details + 1] = warning end
    return table.concat(summary, "\n\n"), table.concat(details, "\n\n")
end

local function show_result(record)
    -- This optional dialog extension is absent on the public alpha11 host.
    -- Keep the log/replay contract and apply status independent of presentation.
    if type(api) ~= "table" or type(api.show_result) ~= "function" then return end
    local ok, message = pcall(function()
        api.show_result(result_text(record))
    end)
    if not ok then print("Could not display calculation result: " .. tostring(message)) end
end

function execute(opts)
    local record = {
        schema_version = RESULT_SCHEMA_VERSION, solver_version = SOLVER_VERSION,
        plugin_version = PLUGIN_VERSION, inputs = {}, warnings = json_array(),
        workflow_state = "INVALID_INPUT", apply_status = "NOT_REQUESTED",
        readback_status = "NOT_PERFORMED", verification_status = "NOT_VERIFIED"
    }
    -- Whitelist declared inputs so foreign host values cannot enter serialization.
    for _, param in ipairs(info.params) do record.inputs[param.name] = opts[param.name] end
    if opts.apply_contour_offset ~= nil then record.inputs.apply_contour_offset = opts.apply_contour_offset end
    local ok, error_message = pcall(execute_run, opts, record)
    if not ok then
        record.error = tostring(error_message)
        if record.workflow_state == "APPLY_ATTEMPTED" then record.apply_status = "ERROR_UNCONFIRMED" end
    end
    record.severity = not ok and "FAIL" or (#record.warnings > 0 and "WARN" or "PASS")
    print("DA_RESULT_JSON " .. json_encode(record))
    show_result(record)
    if not ok then error(error_message) end
    return record
end

-- The production plugin keeps its implementation local. A standalone Lua
-- harness may pre-create this table to exercise the pure calculation helpers.
if type(dimensional_accuracy_test) == "table" then
    dimensional_accuracy_test.parse_measurement = parse_measurement
    dimensional_accuracy_test.fit_axis = fit_axis
    dimensional_accuracy_test.checked_shrinkage_for_scale =
        checked_shrinkage_for_scale
    dimensional_accuracy_test.calculate_plan = calculate_plan
    dimensional_accuracy_test.calculate_plan_version = calculate_plan_version
    dimensional_accuracy_test.compare_models = compare_models
    dimensional_accuracy_test.config_number = config_number
    dimensional_accuracy_test.parse_repeated_measurement = parse_repeated_measurement
    dimensional_accuracy_test.json_encode = json_encode
    dimensional_accuracy_test.result_text = result_text
    dimensional_accuracy_test.solver_version = SOLVER_VERSION
    dimensional_accuracy_test.xy_features = XY_FEATURES
    dimensional_accuracy_test.plugin_version = PLUGIN_VERSION
    dimensional_accuracy_test.limits = {
        max_nominal_deviation_mm = MAX_NOMINAL_DEVIATION_MM,
        max_point_residual_mm = MAX_POINT_RESIDUAL_MM,
        max_fit_rms_mm = MAX_FIT_RMS_MM,
        max_abs_intercept_mm = MAX_ABS_INTERCEPT_MM,
        max_xy_anisotropy_percent = MAX_XY_ANISOTROPY_PERCENT
    }
end
