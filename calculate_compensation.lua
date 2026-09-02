-- SPDX-License-Identifier: AGPL-3.0-only
-- Copyright (C) 2026 pOmelchenko

info = {
    id = "dev.omelchenko.dimensional-accuracy.calculate",
    type = "project.plugin",
    title = "Calculate dimensional compensation",
    menu = "Calibration/Dimensional accuracy/2. Calculate and apply",
    params = {
        {name = "x40", label = "Measured X40 [mm]", type = "float", default = 40.0},
        {name = "x80", label = "Measured X80 [mm]", type = "float", default = 80.0},
        {name = "x120", label = "Measured X120 [mm]", type = "float", default = 120.0},
        {name = "y40", label = "Measured Y40 [mm]", type = "float", default = 40.0},
        {name = "y80", label = "Measured Y80 [mm]", type = "float", default = 80.0},
        {name = "y120", label = "Measured Y120 [mm]", type = "float", default = 120.0},
        {
            name = "apply_uniform_scale",
            label = "Apply common XY shrinkage compensation",
            type = "bool",
            default = true
        },
        {
            name = "apply_contour_offset",
            label = "Apply XY size compensation",
            type = "bool",
            default = true
        }
    }
}

local NOMINAL_LENGTHS = {40.0, 80.0, 120.0}
local MIN_SHRINKAGE_PERCENT = -10.0
local MAX_SHRINKAGE_PERCENT = 10.0

local function current_fff_bed()
    local bed = api.project:current_bed()
    local supports_fff_settings = pcall(function()
        bed:material_presets(0):value("filament_shrinkage_compensation_xy")
        bed:print_presets():value("xy_size_compensation")
    end)

    if not supports_fff_settings then
        error(
            "Dimensional accuracy calibration is supported only for FFF " ..
            "printer presets; switch from SLA to an FFF printer preset"
        )
    end

    return bed
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function fit_axis(measured)
    local nominal_mean = 0.0
    local measured_mean = 0.0

    for i = 1, #NOMINAL_LENGTHS do
        if measured[i] <= 0.0 then
            error("All measured dimensions must be greater than zero")
        end
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
        error("Calculated scale is outside the plausible 80%-120% range; check measurements")
    end

    local squared_error = 0.0
    for i = 1, #NOMINAL_LENGTHS do
        local predicted = slope * NOMINAL_LENGTHS[i] + intercept
        local residual = measured[i] - predicted
        squared_error = squared_error + residual * residual
    end

    return {
        slope = slope,
        intercept = intercept,
        correction_scale = 1.0 / slope,
        contour_compensation = -intercept / (2.0 * slope),
        rms = math.sqrt(squared_error / #NOMINAL_LENGTHS)
    }
end

local function print_axis_result(axis, result)
    print(string.format(
        "%s: measured scale %.6f, correction scale %.4f%%, contour %.4f mm, RMS %.4f mm",
        axis,
        result.slope,
        result.correction_scale * 100.0,
        result.contour_compensation,
        result.rms
    ))
end

function execute(opts)
    local bed = current_fff_bed()
    local x = fit_axis({opts.x40, opts.x80, opts.x120})
    local y = fit_axis({opts.y40, opts.y80, opts.y120})

    -- PrusaSlicer currently exposes one shrinkage value for both X and Y and
    -- one isotropic contour offset. Use the mean of the independent estimates,
    -- while retaining the per-axis results in the log for diagnosing anisotropy.
    local mean_measured_scale = (x.slope + y.slope) / 2.0
    local calculated_shrinkage_percent = 100.0 * (1.0 - mean_measured_scale)
    local shrinkage_percent = clamp(
        calculated_shrinkage_percent,
        MIN_SHRINKAGE_PERCENT,
        MAX_SHRINKAGE_PERCENT
    )
    local xy_size_compensation =
        (x.contour_compensation + y.contour_compensation) / 2.0
    local anisotropy_percent = math.abs(x.slope - y.slope) * 100.0

    print("Dimensional accuracy calibration results")
    print_axis_result("X", x)
    print_axis_result("Y", y)
    print(string.format("X/Y anisotropy: %.4f%%", anisotropy_percent))
    print(string.format(
        "Common filament shrinkage compensation XY: %.4f%%",
        shrinkage_percent
    ))
    print(string.format(
        "Common XY size compensation: %.4f mm",
        xy_size_compensation
    ))

    if shrinkage_percent ~= calculated_shrinkage_percent then
        print(string.format(
            "WARNING: Calculated shrinkage %.4f%% is outside PrusaSlicer's " ..
            "supported %.0f%% to %.0f%% range and was limited to %.4f%%.",
            calculated_shrinkage_percent,
            MIN_SHRINKAGE_PERCENT,
            MAX_SHRINKAGE_PERCENT,
            shrinkage_percent
        ))
    end

    if opts.apply_uniform_scale then
        bed:material_presets(0):set(
            "filament_shrinkage_compensation_xy",
            string.format("%.6f%%", shrinkage_percent)
        )
    end

    if opts.apply_contour_offset then
        bed:print_presets():set(
            "xy_size_compensation",
            xy_size_compensation
        )
    end

    if anisotropy_percent > 0.1 then
        print(
            "WARNING: X/Y anisotropy exceeds 0.1%. The current Lua API cannot " ..
            "apply independent X and Y scale factors."
        )
    end
end
