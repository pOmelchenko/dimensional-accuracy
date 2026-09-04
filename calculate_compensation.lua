-- SPDX-License-Identifier: AGPL-3.0-only
-- Copyright (C) 2026 pOmelchenko

info = {
    id = "dev.omelchenko.dimensional-accuracy.calculate",
    type = "project.plugin",
    title = "Calculate dimensional compensation (experimental)",
    menu = "Calibration/Dimensional accuracy/2. Calculate and apply",
    params = {
        {
            name = "calibrate_xy",
            label = "Calibrate XY",
            type = "bool",
            default = true
        },
        {
            name = "calibrate_z",
            label = "Calibrate Z",
            type = "bool",
            default = false
        },
        -- String controls intentionally avoid the float/int control swap in
        -- affected PrusaSlicer 3.0 alpha builds. Values are parsed strictly in
        -- execute(), so invalid text cannot silently become a measurement.
        {name = "x40", label = "Measured X40 [mm]", type = "string", default = "40.00"},
        {name = "x80", label = "Measured X80 [mm]", type = "string", default = "80.00"},
        {name = "x120", label = "Measured X120 [mm]", type = "string", default = "120.00"},
        {name = "y40", label = "Measured Y40 [mm]", type = "string", default = "40.00"},
        {name = "y80", label = "Measured Y80 [mm]", type = "string", default = "80.00"},
        {name = "y120", label = "Measured Y120 [mm]", type = "string", default = "120.00"},
        {name = "z40", label = "Measured Z40 [mm]", type = "string", default = "40.00"},
        {name = "z80", label = "Measured Z80 [mm]", type = "string", default = "80.00"},
        {name = "z120", label = "Measured Z120 [mm]", type = "string", default = "120.00"},
        {
            name = "apply_uniform_scale",
            label = "Apply common XY shrinkage compensation",
            type = "bool",
            default = false
        },
        {
            name = "apply_contour_offset",
            label = "Apply XY size compensation",
            type = "bool",
            default = false
        },
        {
            name = "apply_z_shrinkage",
            label = "Apply Z shrinkage compensation",
            type = "bool",
            default = false
        },
        {
            name = "confirm_zero_compensation",
            label = "I printed the gauge with selected compensation settings at zero",
            type = "bool",
            default = false
        },
        {
            name = "confirm_apply_capable_host",
            label = "I am using a validated apply-capable PrusaSlicer build",
            type = "bool",
            default = false
        }
    }
}

-- BEGIN GENERATED ARTIFACT SPEC
local NOMINAL_LENGTHS = {40, 80, 120}
local GAUGE_ARTIFACTS = {
    xy = {id = "DA-XY-A", revision = 1},
    z = {id = "DA-Z-B", revision = 1},
    xyz = {id = "DA-XYZ-AB", revision = 1},
}
-- END GENERATED ARTIFACT SPEC
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

local function measurements_for_axis(opts, axis_key, axis_label)
    return {
        parse_measurement(axis_label .. "40", opts[axis_key .. "40"]),
        parse_measurement(axis_label .. "80", opts[axis_key .. "80"]),
        parse_measurement(axis_label .. "120", opts[axis_key .. "120"])
    }
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
            "%s fitted fixed offset %.4f mm exceeds the +/-%.2f mm " ..
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

local function calculate_xy(opts)
    local x = fit_axis("X", measurements_for_axis(opts, "x", "X"))
    local y = fit_axis("Y", measurements_for_axis(opts, "y", "Y"))

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
    local z = fit_axis("Z", measurements_for_axis(opts, "z", "Z"))
    return {
        fit = z,
        shrinkage_percent = checked_shrinkage_for_scale("Z", z.slope)
    }
end

local function calculate_plan(opts)
    local plan = {}
    if opts.calibrate_xy then
        plan.xy = calculate_xy(opts)
    end
    if opts.calibrate_z then
        plan.z = calculate_z(opts)
    end
    return plan
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
    print(string.format(
        "%s: measured scale %.6f, correction scale %.4f%%, contour %.4f mm, " ..
        "RMS %.4f mm, max residual %.4f mm",
        axis,
        result.slope,
        result.correction_scale * 100.0,
        result.contour_compensation,
        result.rms,
        result.max_residual
    ))
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
            "Common XY size compensation: %.4f mm",
            plan.xy.xy_size_compensation
        ))
    end
    if plan.z ~= nil then
        local z = plan.z.fit
        print(string.format(
            "Z: measured scale %.6f, correction scale %.4f%%, fixed offset " ..
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
    if plan.xy ~= nil and opts.apply_contour_offset then
        operations[#operations + 1] = {
            settings = settings.print_settings,
            name = "xy_size_compensation",
            value = plan.xy.xy_size_compensation,
            label = "XY size compensation"
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
                " The Lua setter returns no success status, so the write and " ..
                "rollback effects cannot be confirmed. The active " ..
                "presets may be partially changed; manually inspect every " ..
                "selected compensation setting and restore zero before retrying."
            error(message)
        end

        print(string.format(
            "Attempted active-setting write: %s (host returned no status)",
            operation.label
        ))
    end

    print(
        "Write attempts completed without a Lua error, but PrusaSlicer's Lua " ..
        "setter does not confirm persistence or slicing-state updates. Manually " ..
        "inspect every selected active setting before slicing."
    )
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

function execute(opts)
    if not opts.calibrate_xy and not opts.calibrate_z then
        error("Select at least one calibration axis: XY or Z")
    end
    validate_apply_selection(opts)

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
    local settings = current_fff_settings(opts.calibrate_xy, opts.calibrate_z)
    verify_zero_baseline(settings, opts, apply_requested)
    print_plan(plan)

    if not apply_requested then
        print(
            "Preview only: no settings were changed. Enable only the apply " ..
            "options you want after reviewing these results."
        )
        return
    end

    apply_plan(settings, plan, opts)
end

-- The production plugin keeps its implementation local. A standalone Lua
-- harness may pre-create this table to exercise the pure calculation helpers.
if type(dimensional_accuracy_test) == "table" then
    dimensional_accuracy_test.parse_measurement = parse_measurement
    dimensional_accuracy_test.fit_axis = fit_axis
    dimensional_accuracy_test.checked_shrinkage_for_scale =
        checked_shrinkage_for_scale
    dimensional_accuracy_test.calculate_plan = calculate_plan
    dimensional_accuracy_test.config_number = config_number
    dimensional_accuracy_test.limits = {
        max_nominal_deviation_mm = MAX_NOMINAL_DEVIATION_MM,
        max_point_residual_mm = MAX_POINT_RESIDUAL_MM,
        max_fit_rms_mm = MAX_FIT_RMS_MM,
        max_abs_intercept_mm = MAX_ABS_INTERCEPT_MM,
        max_xy_anisotropy_percent = MAX_XY_ANISOTROPY_PERCENT
    }
end
