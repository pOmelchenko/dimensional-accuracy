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
            label = "Generate XY-S stepped cross",
            type = "bool",
            default = true,
            tooltip = "XY-S revision 1: 145 x 145 x 4.5 mm stepped cross, 10 x 45 mm windows. Print with XY shrinkage and XY size compensation at zero."
        },
        {
            name = "generate_z",
            label = "Generate Z gauge",
            type = "bool",
            default = false
        }
    }
}

-- BEGIN GENERATED ARTIFACT SPEC
local XY_MODEL_FILE = "dimensional_accuracy_gauge.stl"
local Z_MODEL_FILE = "dimensional_accuracy_z_gauge.stl"
local XYZ_MODEL_FILE = "dimensional_accuracy_xyz_gauge.stl"
local GAUGE_ARTIFACTS = {
    xy = {id = "DA-XY-S", revision = 1},
    z = {id = "DA-Z-B", revision = 1},
    xyz = {id = "DA-XYZ-SB", revision = 1},
}
-- END GENERATED ARTIFACT SPEC

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
        print(string.format("Artifact %s revision %d (external identity label required)", GAUGE_ARTIFACTS.xy.id, GAUGE_ARTIFACTS.xy.revision))
        print("Dimensional accuracy XY-S stepped cross generated (145 x 145 x 4.5 mm)")
        print("Long X arm points right; long Y arm points down. Windows: 10 x 45 mm.")
        print("Primary readings per axis: outside 145 mm, short depth 30 mm, long depth 100 mm.")
        print("Measure flat faces at mid-height, away from chamfers and corner reliefs. Extra widths, steps, windows and walls are optional checks.")
    end
    if opts.generate_z then
        print(string.format("Artifact %s revision %d (external identity label required)", GAUGE_ARTIFACTS.z.id, GAUGE_ARTIFACTS.z.revision))
        print("Dimensional accuracy Z-B stepped plate generated")
        print("Z steps from left to right: Z40, Z80, Z120")
        print("Measure from the common base datum to each upper step")
    end
    if opts.generate_xy and opts.generate_z then
        print("XY and Z are pre-arranged with a 10 mm gap in one slicer object")
    end
end
