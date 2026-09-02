-- SPDX-License-Identifier: AGPL-3.0-only
-- Copyright (C) 2026 pOmelchenko

info = {
    id = "dev.omelchenko.dimensional-accuracy.calculate",
    type = "project.plugin",
    title = "Calculate dimensional compensation",
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
        {name = "x40", label = "Measured X40 [mm]", type = "float", default = 40.0},
        {name = "x80", label = "Measured X80 [mm]", type = "float", default = 80.0},
        {name = "x120", label = "Measured X120 [mm]", type = "float", default = 120.0},
        {name = "y40", label = "Measured Y40 [mm]", type = "float", default = 40.0},
        {name = "y80", label = "Measured Y80 [mm]", type = "float", default = 80.0},
        {name = "y120", label = "Measured Y120 [mm]", type = "float", default = 120.0},
        {name = "z40", label = "Measured Z40 [mm]", type = "float", default = 40.0},
        {name = "z80", label = "Measured Z80 [mm]", type = "float", default = 80.0},
        {name = "z120", label = "Measured Z120 [mm]", type = "float", default = 120.0},
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
        },
        {
            name = "apply_z_shrinkage",
            label = "Apply Z shrinkage compensation",
            type = "bool",
            default = true
        }
    }
}

local NOMINAL_LENGTHS = {40.0, 80.0, 120.0}
local MIN_SHRINKAGE_PERCENT = -10.0
local MAX_SHRINKAGE_PERCENT = 10.0

local function current_fff_bed(calibrate_xy, calibrate_z)
    local bed = api.project:current_bed()
    local supports_fff_settings = pcall(function()
        local material = bed:material_presets(0)
        if calibrate_xy then
            material:value("filament_shrinkage_compensation_xy")
            bed:print_presets():value("xy_size_compensation")
        end
        if calibrate_z then
            material:value("filament_shrinkage_compensation_z")
        end
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

local function shrinkage_for_scale(measured_scale)
    local calculated = 100.0 * (1.0 - measured_scale)
    local limited = clamp(
        calculated,
        MIN_SHRINKAGE_PERCENT,
        MAX_SHRINKAGE_PERCENT
    )
    return limited, calculated
end

local function warn_if_shrinkage_limited(axis, shrinkage, calculated)
    if shrinkage ~= calculated then
        print(string.format(
            "WARNING: Calculated %s shrinkage %.4f%% is outside " ..
            "PrusaSlicer's supported %.0f%% to %.0f%% range and was " ..
            "limited to %.4f%%.",
            axis,
            calculated,
            MIN_SHRINKAGE_PERCENT,
            MAX_SHRINKAGE_PERCENT,
            shrinkage
        ))
    end
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

local function run_xy_calibration(bed, opts)
    local x = fit_axis({opts.x40, opts.x80, opts.x120})
    local y = fit_axis({opts.y40, opts.y80, opts.y120})

    -- PrusaSlicer currently exposes one shrinkage value for both X and Y and
    -- one isotropic contour offset. Use the mean of the independent estimates,
    -- while retaining the per-axis results in the log for diagnosing anisotropy.
    local mean_measured_scale = (x.slope + y.slope) / 2.0
    local shrinkage_percent, calculated_shrinkage_percent =
        shrinkage_for_scale(mean_measured_scale)
    local xy_size_compensation =
        (x.contour_compensation + y.contour_compensation) / 2.0
    local anisotropy_percent = math.abs(x.slope - y.slope) * 100.0

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

    warn_if_shrinkage_limited(
        "XY",
        shrinkage_percent,
        calculated_shrinkage_percent
    )

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

local function run_z_calibration(bed, opts)
    local z = fit_axis({opts.z40, opts.z80, opts.z120})

    local shrinkage_percent, calculated_shrinkage_percent =
        shrinkage_for_scale(z.slope)

    print(string.format(
        "Z: measured scale %.6f, correction scale %.4f%%, " ..
        "fixed offset %.4f mm, RMS %.4f mm",
        z.slope,
        z.correction_scale * 100.0,
        z.intercept,
        z.rms
    ))
    print(string.format(
        "Filament shrinkage compensation Z: %.4f%%",
        shrinkage_percent
    ))

    warn_if_shrinkage_limited(
        "Z",
        shrinkage_percent,
        calculated_shrinkage_percent
    )

    if opts.apply_z_shrinkage then
        bed:material_presets(0):set(
            "filament_shrinkage_compensation_z",
            string.format("%.6f%%", shrinkage_percent)
        )
    end
end

function execute(opts)
    if not opts.calibrate_xy and not opts.calibrate_z then
        error("Select at least one calibration axis: XY or Z")
    end

    local bed = current_fff_bed(opts.calibrate_xy, opts.calibrate_z)

    print("Dimensional accuracy calibration results")
    if opts.calibrate_xy then
        run_xy_calibration(bed, opts)
    end
    if opts.calibrate_z then
        run_z_calibration(bed, opts)
    end
end
