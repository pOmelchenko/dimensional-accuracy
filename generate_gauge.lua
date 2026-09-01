-- SPDX-License-Identifier: AGPL-3.0-only
-- Copyright (C) 2026 pOmelchenko

info = {
    id = "dev.omelchenko.dimensional-accuracy.generate",
    type = "project.plugin",
    title = "Generate dimensional accuracy gauge",
    menu = "Calibration/Dimensional accuracy/1. Generate gauge",
    params = {}
}

function execute()
    api.project:add_object {
        mesh = api.load_stl("dimensional_accuracy_gauge.stl")
    }

    print("Dimensional accuracy grid gauge generated")
    print("Horizontal bars from bottom to top: X40, X80, X120")
    print("Vertical bars from left to right: Y40, Y80, Y120")
    print("Measure between the flat end faces near the middle of the height")
end
