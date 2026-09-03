# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 pOmelchenko

OPENSCAD ?= openscad
PYTHON ?= python3
MODEL := model/dimensional_accuracy_gauge.scad
PROTOTYPE_DIR := prototypes

.PHONY: all gauges prototypes verify

all: gauges prototypes

gauges: \
	dimensional_accuracy_gauge.stl \
	dimensional_accuracy_z_gauge.stl \
	dimensional_accuracy_xyz_gauge.stl

prototypes: \
	$(PROTOTYPE_DIR)/dimensional_accuracy_xy_7x5.stl \
	$(PROTOTYPE_DIR)/dimensional_accuracy_zc40.stl

dimensional_accuracy_gauge.stl: $(MODEL)
	$(OPENSCAD) -D 'gauge_mode="xy"' --export-format binstl -o $@ $<

dimensional_accuracy_z_gauge.stl: $(MODEL)
	$(OPENSCAD) -D 'gauge_mode="z"' --export-format binstl -o $@ $<

dimensional_accuracy_xyz_gauge.stl: $(MODEL)
	$(OPENSCAD) -D 'gauge_mode="xyz"' --export-format binstl -o $@ $<

$(PROTOTYPE_DIR)/dimensional_accuracy_xy_7x5.stl: $(MODEL)
	mkdir -p $(PROTOTYPE_DIR)
	$(OPENSCAD) -D 'gauge_mode="xy"' -D 'xy_bar_width=7' \
		-D 'xy_gauge_height=5' --export-format binstl -o $@ $<

$(PROTOTYPE_DIR)/dimensional_accuracy_zc40.stl: $(MODEL)
	mkdir -p $(PROTOTYPE_DIR)
	$(OPENSCAD) -D 'gauge_mode="zc40"' --export-format binstl -o $@ $<

verify: all
	$(PYTHON) tools/verify_stl.py dimensional_accuracy_gauge.stl \
		--expect-bounds 120 120 4.5 --expect-volume 10 14 \
		--min-plane-area 15 \
		--require-plane x=-20 --require-plane x=20 \
		--require-plane x=-40 --require-plane x=40 \
		--require-plane x=-60 --require-plane x=60 \
		--require-plane y=-20 --require-plane y=20 \
		--require-plane y=-40 --require-plane y=40 \
		--require-plane y=-60 --require-plane y=60
	$(PYTHON) tools/verify_stl.py dimensional_accuracy_z_gauge.stl \
		--expect-bounds 52 24 120 --expect-volume 21 27 \
		--min-plane-area 70 \
		--require-plane z=0 --require-plane z=40 \
		--require-plane z=80 --require-plane z=120
	$(PYTHON) tools/verify_stl.py dimensional_accuracy_xyz_gauge.stl \
		--expect-bounds 120 154 120 --expect-volume 24 41 \
		--expect-components 2 --expect-gap y=10 --min-plane-area 15 \
		--require-plane x=-20 --require-plane x=20 \
		--require-plane x=-40 --require-plane x=40 \
		--require-plane x=-60 --require-plane x=60 \
		--require-plane y=-20 --require-plane y=20 \
		--require-plane y=-40 --require-plane y=40 \
		--require-plane y=-60 --require-plane y=60 \
		--require-plane z=0 --require-plane z=40 \
		--require-plane z=80 --require-plane z=120
	$(PYTHON) tools/verify_stl.py \
		$(PROTOTYPE_DIR)/dimensional_accuracy_xy_7x5.stl \
		--expect-bounds 120 120 5 \
		--min-plane-area 20 \
		--require-plane x=-20 --require-plane x=20 \
		--require-plane x=-40 --require-plane x=40 \
		--require-plane x=-60 --require-plane x=60 \
		--require-plane y=-20 --require-plane y=20 \
		--require-plane y=-40 --require-plane y=40 \
		--require-plane y=-60 --require-plane y=60
	$(PYTHON) tools/verify_stl.py \
		$(PROTOTYPE_DIR)/dimensional_accuracy_zc40.stl \
		--expect-bounds 52 24 50 \
		--min-plane-area 50 \
		--require-plane z=0 --require-plane z=40
