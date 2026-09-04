# Artifact specification

`artifacts.json` schema 1.0.0 assigns stable artifact IDs and geometry revisions,
measurement features, methods, contour sensitivity assumptions, SCAD defaults
and overrides, bounds/volume/measurement-plane checks and layout components.
Z's contour coefficient is null: the external Z datum is not an XY contour
offset model. These coefficients describe an idealized geometry, not proven
physical causes.

```bash
python3 tools/artifact_spec.py check
python3 tools/artifact_spec.py sync
```

`check` runs in `make test`/CI. It detects drift in SCAD constants, Lua nominal
values and labels, generator file/identity mappings and Makefile build/verifier
recipes. `sync` regenerates only marked projections; it does not change geometry
or regenerate STL. Build and verifier arguments come directly from the catalog.
The trial generator uses the same feature list and only schedules features
shared by control and challenger (Z40 for Z-C40).

The existing unmarked meshes are revision 1. No new physical geometry is claimed
by assigning IDs to them. Label the actual print's non-working surface with its
print ID; the frozen print table maps that ID to artifact ID/revision and mesh
SHA-256. Keep the trial's blind mapping hidden during measurement. Identity
therefore does not depend on changing or engraving a measurement surface.
The generator logs artifact ID/revision, and the calculator's structured result
uses these same identifiers. If the mesh or working features change, increment
the geometry revision and run the appropriate geometry/physical gates before
release replacement. Old results remain associated with revision 1.

The catalog is a development source; checked Lua projections keep the runtime
payload at exactly seven files and avoid loading research helpers as plugins.
