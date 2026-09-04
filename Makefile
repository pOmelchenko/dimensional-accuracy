# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 pOmelchenko

OPENSCAD ?= openscad
PYTHON ?= python3
LUA ?= lua
LUAC ?= luac

override MODEL := model/dimensional_accuracy_gauge.scad
override PROTOTYPE_DIR := prototypes
override RELEASE_STLS := \
	dimensional_accuracy_gauge.stl \
	dimensional_accuracy_z_gauge.stl \
	dimensional_accuracy_xyz_gauge.stl
override PROTOTYPE_STLS := \
	$(PROTOTYPE_DIR)/dimensional_accuracy_xy_7x5.stl \
	$(PROTOTYPE_DIR)/dimensional_accuracy_zc40.stl
override PLUGIN_FILES := \
	LICENSE \
	manifest.json \
	generate_gauge.lua \
	calculate_compensation.lua \
	$(RELEASE_STLS)
override PLUGIN_STAGE_DIR := build/dev.omelchenko.dimensional-accuracy
override PLUGIN_STAGE_TMP := build/.dev.omelchenko.dimensional-accuracy.tmp

.DEFAULT_GOAL := all
.DELETE_ON_ERROR:

.PHONY: \
	all release gauges prototypes \
	verify verify-release verify-release-existing verify-existing \
	verify-prototypes verify-prototypes-existing verify-all \
	test test-python test-lua test-runtime test-manifest test-makefile-safety \
	stage-plugin stage-plugin-existing \
	clean clean-release clean-prototypes clean-stage

# The default build is the user-facing plugin payload. Research prototypes
# remain opt-in through the explicit prototypes/verify-prototypes targets.
all: release

release: $(RELEASE_STLS)

# Backward-compatible alias used by existing local workflows.
gauges: release

prototypes: $(PROTOTYPE_STLS)

# Makefile is an input because its command-line -D values and export recipes
# affect generated geometry just as much as the OpenSCAD source does.
dimensional_accuracy_gauge.stl: $(MODEL) Makefile
	$(OPENSCAD) -D 'gauge_mode="xy"' --export-format binstl -o $@ $<

dimensional_accuracy_z_gauge.stl: $(MODEL) Makefile
	$(OPENSCAD) -D 'gauge_mode="z"' --export-format binstl -o $@ $<

dimensional_accuracy_xyz_gauge.stl: $(MODEL) Makefile
	$(OPENSCAD) -D 'gauge_mode="xyz"' --export-format binstl -o $@ $<

$(PROTOTYPE_DIR)/dimensional_accuracy_xy_7x5.stl: $(MODEL) Makefile
	mkdir -p $(PROTOTYPE_DIR)
	$(OPENSCAD) -D 'gauge_mode="xy"' -D 'xy_bar_width=7' \
		-D 'xy_gauge_height=5' --export-format binstl -o $@ $<

$(PROTOTYPE_DIR)/dimensional_accuracy_zc40.stl: $(MODEL) Makefile
	mkdir -p $(PROTOTYPE_DIR)
	$(OPENSCAD) -D 'gauge_mode="zc40"' --export-format binstl -o $@ $<

define VERIFY_XY
	$(PYTHON) tools/verify_stl.py dimensional_accuracy_gauge.stl \
		--expect-bounds 120 120 4.5 --expect-volume 10 14 \
		--min-plane-area 15 \
		--require-plane x=-20 --require-plane x=20 \
		--require-plane x=-40 --require-plane x=40 \
		--require-plane x=-60 --require-plane x=60 \
		--require-plane y=-20 --require-plane y=20 \
		--require-plane y=-40 --require-plane y=40 \
		--require-plane y=-60 --require-plane y=60
endef

define VERIFY_Z
	$(PYTHON) tools/verify_stl.py dimensional_accuracy_z_gauge.stl \
		--expect-bounds 52 24 120 --expect-volume 21 27 \
		--min-plane-area 70 \
		--require-plane z=0 --require-plane z=40 \
		--require-plane z=80 --require-plane z=120
endef

define VERIFY_XYZ
	$(PYTHON) tools/verify_stl.py dimensional_accuracy_xyz_gauge.stl \
		--expect-bounds 120 154 120 --expect-volume 24 41 \
		--expect-components 2 --expect-gap y=10 --min-plane-area 15 \
		--expect-component-bounds 1:120:120:4.5 \
		--expect-component-bounds 2:52:24:120 \
		--expect-component-volume 1:10:14 \
		--expect-component-volume 2:21:27 \
		--require-component-plane 1:x=-20 \
		--require-component-plane 1:x=20 \
		--require-component-plane 1:x=-40 \
		--require-component-plane 1:x=40 \
		--require-component-plane 1:x=-60 \
		--require-component-plane 1:x=60 \
		--require-component-plane 1:y=-20 \
		--require-component-plane 1:y=20 \
		--require-component-plane 1:y=-40 \
		--require-component-plane 1:y=40 \
		--require-component-plane 1:y=-60 \
		--require-component-plane 1:y=60 \
		--require-component-plane 2:z=0 \
		--require-component-plane 2:z=40 \
		--require-component-plane 2:z=80 \
		--require-component-plane 2:z=120
endef

define VERIFY_PROTOTYPE_XY
	$(PYTHON) tools/verify_stl.py \
		$(PROTOTYPE_DIR)/dimensional_accuracy_xy_7x5.stl \
		--expect-bounds 120 120 5 --expect-volume 12 17 \
		--min-plane-area 20 \
		--require-plane x=-20 --require-plane x=20 \
		--require-plane x=-40 --require-plane x=40 \
		--require-plane x=-60 --require-plane x=60 \
		--require-plane y=-20 --require-plane y=20 \
		--require-plane y=-40 --require-plane y=40 \
		--require-plane y=-60 --require-plane y=60
endef

define VERIFY_PROTOTYPE_Z
	$(PYTHON) tools/verify_stl.py \
		$(PROTOTYPE_DIR)/dimensional_accuracy_zc40.stl \
		--expect-bounds 52 24 50 --expect-volume 8 11 \
		--min-plane-area 50 \
		--require-plane z=0 --require-plane z=40
endef

# verify/verify-release honor staleness and regenerate release artifacts.
verify: verify-release

verify-release: release
	$(VERIFY_XY)
	$(VERIFY_Z)
	$(VERIFY_XYZ)

# Read-only inspection is useful on machines without OpenSCAD. It deliberately
# does not hide stale generated files; use verify for the release gate.
verify-existing: verify-release-existing

verify-release-existing:
	$(VERIFY_XY)
	$(VERIFY_Z)
	$(VERIFY_XYZ)

verify-prototypes: prototypes
	$(VERIFY_PROTOTYPE_XY)
	$(VERIFY_PROTOTYPE_Z)

verify-prototypes-existing:
	$(VERIFY_PROTOTYPE_XY)
	$(VERIFY_PROTOTYPE_Z)

verify-all: verify-release verify-prototypes

test: test-python test-lua test-runtime test-manifest test-makefile-safety

test-python:
	$(PYTHON) -m unittest discover -s tests -p 'test_*.py'

test-lua:
	@command -v $(LUA) >/dev/null 2>&1 || { \
		echo "ERROR: Lua interpreter '$(LUA)' is required; set LUA=/path/to/lua" >&2; \
		exit 1; \
	}
	$(LUA) tests/test_calculate_compensation.luatest
	$(LUA) tests/test_generate_gauge.luatest

test-runtime:
	@command -v $(LUAC) >/dev/null 2>&1 || { \
		echo "ERROR: Lua compiler '$(LUAC)' is required; set LUAC=/path/to/luac" >&2; \
		exit 1; \
	}
	$(LUAC) -p calculate_compensation.lua generate_gauge.lua

test-manifest:
	$(PYTHON) -m json.tool manifest.json >/dev/null

# Exercise destructive/build recipes with hostile command-line overrides. The
# dry run must contain only the fixed repository paths and literal rm commands.
test-makefile-safety:
	@plan="$$( $(MAKE) --no-print-directory -Bn \
		RELEASE_STLS='/tmp/unsafe-release.stl' \
		PROTOTYPE_DIR='/tmp/unsafe-prototypes' \
		PROTOTYPE_STLS='/tmp/unsafe-prototype.stl' \
		PLUGIN_FILES='/tmp/unsafe-payload' \
		PLUGIN_STAGE_DIR='/tmp/unsafe-stage' \
		PLUGIN_STAGE_TMP='/tmp/unsafe-stage-tmp' \
		RM='printf UNSAFE_RM' clean release prototypes )"; \
	case "$$plan" in \
		*'/tmp/'*|*'UNSAFE_RM'*) \
			echo "ERROR: unsafe Makefile override reached a recipe" >&2; \
			echo "$$plan" >&2; \
			exit 1 ;; \
	esac; \
	for path in \
		dimensional_accuracy_gauge.stl \
		dimensional_accuracy_z_gauge.stl \
		dimensional_accuracy_xyz_gauge.stl \
		prototypes/dimensional_accuracy_xy_7x5.stl \
		prototypes/dimensional_accuracy_zc40.stl; do \
		case "$$plan" in \
			*"$$path"*) ;; \
			*) echo "ERROR: safe path $$path missing from dry run" >&2; exit 1 ;; \
		esac; \
	done

# Stage exactly the verified runtime payload. Fixed, non-overridable paths and
# a temporary directory keep cleanup contained and preserve the previous stage
# until every payload file has been copied successfully.
stage-plugin: test verify-release
	@test "$(PLUGIN_STAGE_DIR)" = "build/dev.omelchenko.dimensional-accuracy"
	@test "$(PLUGIN_STAGE_TMP)" = "build/.dev.omelchenko.dimensional-accuracy.tmp"
	rm -rf -- "build/.dev.omelchenko.dimensional-accuracy.tmp"
	mkdir -p "$(PLUGIN_STAGE_TMP)"
	cp $(PLUGIN_FILES) "$(PLUGIN_STAGE_TMP)/"
	rm -rf -- "build/dev.omelchenko.dimensional-accuracy"
	mv "$(PLUGIN_STAGE_TMP)" "$(PLUGIN_STAGE_DIR)"

# Development-only staging for systems without OpenSCAD. The target name and
# verifier output make explicit that committed meshes are checked but not
# regenerated; release packaging must use stage-plugin instead.
stage-plugin-existing: test verify-release-existing
	@test "$(PLUGIN_STAGE_DIR)" = "build/dev.omelchenko.dimensional-accuracy"
	@test "$(PLUGIN_STAGE_TMP)" = "build/.dev.omelchenko.dimensional-accuracy.tmp"
	rm -rf -- "build/.dev.omelchenko.dimensional-accuracy.tmp"
	mkdir -p "$(PLUGIN_STAGE_TMP)"
	cp $(PLUGIN_FILES) "$(PLUGIN_STAGE_TMP)/"
	rm -rf -- "build/dev.omelchenko.dimensional-accuracy"
	mv "$(PLUGIN_STAGE_TMP)" "$(PLUGIN_STAGE_DIR)"

clean: clean-release clean-prototypes clean-stage

clean-release:
	rm -f -- \
		dimensional_accuracy_gauge.stl \
		dimensional_accuracy_z_gauge.stl \
		dimensional_accuracy_xyz_gauge.stl

clean-prototypes:
	rm -f -- \
		prototypes/dimensional_accuracy_xy_7x5.stl \
		prototypes/dimensional_accuracy_zc40.stl

clean-stage:
	@test "$(PLUGIN_STAGE_DIR)" = "build/dev.omelchenko.dimensional-accuracy"
	@test "$(PLUGIN_STAGE_TMP)" = "build/.dev.omelchenko.dimensional-accuracy.tmp"
	rm -rf -- \
		"build/dev.omelchenko.dimensional-accuracy" \
		"build/.dev.omelchenko.dimensional-accuracy.tmp"
