-- SPDX-License-Identifier: AGPL-3.0-only
-- Copyright (C) 2026 pOmelchenko

info = {
    id = "dev.omelchenko.dimensional-accuracy.generate",
    type = "project.plugin",
    title = "Generate dimensional accuracy gauge (experimental)",
    menu = "Calibration/Dimensional accuracy/1. Generate gauge",
    params = {
        {
            name = "generate_xy",
            label = "Generate XY gauge",
            type = "bool",
            default = true
        },
        {
            name = "generate_z",
            label = "Generate Z gauge",
            type = "bool",
            default = false
        }
    }
}

local XY_MODEL_FILE = "dimensional_accuracy_gauge.stl"
local Z_MODEL_FILE = "dimensional_accuracy_z_gauge.stl"
local XYZ_MODEL_FILE = "dimensional_accuracy_xyz_gauge.stl"

local function add_gauge(model_file)
    return api.project:add_object {
        mesh = api.load_stl(model_file),
        -- The calculator writes shrinkage compensation to material slot 1.
        -- Keep the generated standard on the same physical extruder instead
        -- of inheriting multi-material routing from the active print profile.
        object_params = {
            extruder = 1
        }
    }
end

function execute(opts)
    if not opts.generate_xy and not opts.generate_z then
        error("Select at least one calibration gauge: XY or Z")
    end

    local model_file
    if opts.generate_xy and opts.generate_z then
        model_file = XYZ_MODEL_FILE
    elseif opts.generate_xy then
        model_file = XY_MODEL_FILE
    else
        model_file = Z_MODEL_FILE
    end

    add_gauge(model_file)
    print("EXPERIMENTAL gauge: physical validation has not been completed")
    print("Gauge assigned to extruder 1 / material slot 1; use a single-material print")

    if opts.generate_xy then
        print("Dimensional accuracy XY-A grid gauge generated")
        print("Horizontal bars from bottom to top: X40, X80, X120")
        print("Vertical bars from left to right: Y40, Y80, Y120")
        print("Measure between the flat end faces near the middle of the height")
    end
    if opts.generate_z then
        print("Dimensional accuracy Z-B stepped plate generated")
        print("Z steps from left to right: Z40, Z80, Z120")
        print("Measure from the common base datum to each upper step")
    end
    if opts.generate_xy and opts.generate_z then
        print("XY and Z are pre-arranged with a 10 mm gap in one slicer object")
    end
end
