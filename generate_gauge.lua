info = {
    id = "dev.omelchenko.dimensional-accuracy.generate",
    type = "project.plugin",
    title = "Generate dimensional accuracy gauge",
    menu = "Calibration/Dimensional accuracy/1. Generate gauge",
    params = {
        {
            name = "height",
            label = "Gauge height [mm]",
            type = "float",
            default = 5.0
        }
    }
}

local NOMINAL_LENGTHS = {40.0, 80.0, 120.0}
local BAR_WIDTH = 8.0
local BAR_GAP = 6.0

local function solid_box(x, y, z, tx, ty)
    return {
        mesh = api.make_cube(x, y, z),
        translate = {x = tx, y = ty, z = 0.0},
        type = VolumeType.Solid
    }
end

function execute(opts)
    if opts.height <= 0.0 then
        error("Gauge height must be greater than zero")
    end

    local pitch = BAR_WIDTH + BAR_GAP
    local other_volumes = {}

    -- Horizontal bars provide the X40, X80 and X120 measurements.
    -- The first horizontal bar is the primary volume below.
    for i = 2, #NOMINAL_LENGTHS do
        table.insert(
            other_volumes,
            solid_box(
                NOMINAL_LENGTHS[i],
                BAR_WIDTH,
                opts.height,
                0.0,
                (i - 1) * pitch
            )
        )
    end

    -- Vertical bars provide the Y40, Y80 and Y120 measurements. Their
    -- intersections with the horizontal bars keep the gauge a single object.
    for i = 1, #NOMINAL_LENGTHS do
        table.insert(
            other_volumes,
            solid_box(
                BAR_WIDTH,
                NOMINAL_LENGTHS[i],
                opts.height,
                (i - 1) * pitch,
                0.0
            )
        )
    end

    api.project:add_object {
        mesh = api.make_cube(NOMINAL_LENGTHS[1], BAR_WIDTH, opts.height),
        other_volumes = other_volumes
    }

    print("Dimensional accuracy gauge generated")
    print("Horizontal bars from bottom to top: X40, X80, X120")
    print("Vertical bars from left to right: Y40, Y80, Y120")
end
