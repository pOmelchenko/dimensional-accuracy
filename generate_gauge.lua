-- SPDX-License-Identifier: AGPL-3.0-only
-- Copyright (C) 2026 pOmelchenko

info = {
    id = "dev.omelchenko.dimensional-accuracy.generate",
    type = "project.plugin",
    title = "Generate dimensional accuracy gauge",
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
            label = "Generate Z coupon",
            type = "bool",
            default = false
        }
    }
}

local Z_STEP_SIZE = 20.0
local Z_STEP_SPACING = 18.0
local Z_STEP_HEIGHTS = {40.0, 80.0, 120.0}

local function z_steps()
    local steps = {}
    for index, height in ipairs(Z_STEP_HEIGHTS) do
        table.insert(steps, {
            mesh = api.make_cube(Z_STEP_SIZE, Z_STEP_SIZE, height),
            translate = {
                x = (index - 2) * Z_STEP_SPACING - Z_STEP_SIZE / 2.0,
                y = -Z_STEP_SIZE / 2.0
            }
        })
    end
    return steps
end

function execute(opts)
    if not opts.generate_xy and not opts.generate_z then
        error("Select at least one calibration gauge: XY or Z")
    end

    if opts.generate_xy and opts.generate_z then
        api.project:add_object {
            mesh = api.load_stl("dimensional_accuracy_gauge.stl"),
            other_volumes = z_steps()
        }
    elseif opts.generate_xy then
        api.project:add_object {
            mesh = api.load_stl("dimensional_accuracy_gauge.stl")
        }
    else
        local steps = z_steps()
        local first_step = table.remove(steps, 1)
        first_step.other_volumes = steps
        api.project:add_object(first_step)
    end

    if opts.generate_xy then
        print("Dimensional accuracy XY grid gauge generated")
        print("Horizontal bars from bottom to top: X40, X80, X120")
        print("Vertical bars from left to right: Y40, Y80, Y120")
        print("Measure between the flat end faces near the middle of the height")
    end
    if opts.generate_z then
        print("Dimensional accuracy Z40/Z80/Z120 step gauge generated")
        print("Z steps from left to right: Z40, Z80, Z120")
        print("Measure each step height after it cools to room temperature")
    end
end
