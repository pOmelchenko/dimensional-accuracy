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
        {name = "x40", label = "Measured X40 [mm; 3-5 readings separated by ;]", type = "string", default = ""},
        {name = "x80", label = "Measured X80 [mm; 3-5 readings separated by ;]", type = "string", default = ""},
        {name = "x120", label = "Measured X120 [mm; 3-5 readings separated by ;]", type = "string", default = ""},
        {name = "y40", label = "Measured Y40 [mm; 3-5 readings separated by ;]", type = "string", default = ""},
        {name = "y80", label = "Measured Y80 [mm; 3-5 readings separated by ;]", type = "string", default = ""},
        {name = "y120", label = "Measured Y120 [mm; 3-5 readings separated by ;]", type = "string", default = ""},
        {name = "z40", label = "Measured Z40 [mm; 3-5 readings separated by ;]", type = "string", default = ""},
        {name = "z80", label = "Measured Z80 [mm; 3-5 readings separated by ;]", type = "string", default = ""},
        {name = "z120", label = "Measured Z120 [mm; 3-5 readings separated by ;]", type = "string", default = ""},
        {name = "session_id", label = "Measurement session / print ID", type = "string", default = ""},
        {name = "operator_id", label = "Operator ID", type = "string", default = ""},
        {name = "caliper_id", label = "Caliper ID", type = "string", default = ""},
        {name = "resolution_mm", label = "Caliper resolution [mm, optional]", type = "string", default = ""},
        {name = "mpe_mm", label = "Manufacturer accuracy bound [mm, optional]", type = "string", default = ""},
        {name = "slicer_version", label = "PrusaSlicer version / commit", type = "string", default = ""},
        {name = "printer_nozzle", label = "Printer / nozzle", type = "string", default = ""},
        {name = "filament", label = "Filament / spool / lot", type = "string", default = ""},
        {name = "preset_ids", label = "Printer / print / filament preset IDs", type = "string", default = ""},
        {
            name = "apply_uniform_scale",
            label = "Apply common XY shrinkage compensation",
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
local PLUGIN_VERSION = "0.6.0"
local NOMINAL_LENGTHS = {40, 80, 120}
local GAUGE_ARTIFACTS = {
    xy = {id = "DA-XY-A", revision = 1},
    z = {id = "DA-Z-B", revision = 1},
    xyz = {id = "DA-XYZ-AB", revision = 1},
}
-- END GENERATED ARTIFACT SPEC
local SOLVER_VERSION = "2.0.0"
local RESULT_SCHEMA_VERSION = "1.1.0"

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

local function calculate_plan(opts)
    local plan = calculate_plan_v1(opts)
    if plan.xy then
        plan.xy.x.models = compare_models(plan.xy.x)
        plan.xy.y.models = compare_models(plan.xy.y)
        plan.xy.contour_status = "DIAGNOSTIC_ONLY"
    end
    if plan.z then plan.z.fit.models = compare_models(plan.z.fit) end
    return plan
end

local function calculate_plan_version(opts, version)
    if version == "1.0.0" then return calculate_plan_v1(opts) end
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

local function json_array(values)
    return setmetatable(values or {}, {json_array = true})
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
        for _, observation in ipairs(fit.measurements) do
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
    for key, value in pairs(settings.current) do
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
    record.warnings[#record.warnings + 1] = "M0/M1 model selection is not established; legacy M1 scale proposals remain experimental and the observed additive term is diagnostic only"
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
    apply_plan(settings, plan, opts)
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
    dimensional_accuracy_test.solver_version = SOLVER_VERSION
    dimensional_accuracy_test.plugin_version = PLUGIN_VERSION
    dimensional_accuracy_test.limits = {
        max_nominal_deviation_mm = MAX_NOMINAL_DEVIATION_MM,
        max_point_residual_mm = MAX_POINT_RESIDUAL_MM,
        max_fit_rms_mm = MAX_FIT_RMS_MM,
        max_abs_intercept_mm = MAX_ABS_INTERCEPT_MM,
        max_xy_anisotropy_percent = MAX_XY_ANISOTROPY_PERCENT
    }
end
