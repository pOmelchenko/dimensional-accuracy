# Gauge prototype trial

These experimental models are not loaded by the plugin:

- `dimensional_accuracy_xy_7x5.stl`: 7 × 5 mm XY challenger; control is the
  bundled 6.5 × 4.5 mm XY-A gauge, compared at all six X/Y spans.
- `dimensional_accuracy_zc40.stl`: short window challenger; control is Z-B,
  compared at Z40 only. Z80/Z120 are not matched observations.

## Executable protocol

The authoritative template is [protocol v1](../research/protocol-v1.md), with
[machine-readable design and raw schema](../research/protocol-v1.json).
[Decision D001](../research/decisions.md) resolves differences from the former
unversioned instructions. In particular, Gate B uses **per-print medians**;
G-code provenance is per batch so bed positions can be balanced; an explicitly
inconclusive Gate A may motivate Gate B, but a clearly worse challenger stops.

Prepare a draft outside the physical results directory:

```bash
python3 tools/trial.py init build/trials/example --trial-id example --seed 7321
python3 tools/trial.py validate build/trials/example
```

Use `--families xy` or `--families z` for one comparison. `--calipers 2` creates
an exploratory pilot, which cannot receive full v1 PASS. Full Gate A requires
2 operators × 3 calipers × 10 complete re-seats: 720 XY and 120 Z attempts.
Gate B takes 5 new readings per feature on 3 independent matched print batches
(including the Gate A batch): 180 XY and 30 Z attempts.

Complete the process signature, instrument metadata, print positions, artifact
and G-code hashes and the preregistered cost rule before freezing:

```bash
python3 tools/trial.py freeze build/trials/example
python3 tools/trial.py verify-frozen build/trials/example
```

`freeze` rejects incomplete metadata, changed designs and observations already
recorded. Preserve its checksums in version control or an immutable archive
before the first print. The frozen execution copy governs that trial. Neither
validation nor freezing is a physical PASS. Follow all manual Gate 0 checks,
including `make verify-all`, slicing inspection and documented jaw approach.

Append observations to `measurements.csv`; the generated header includes all
scheduled identity fields, actual order, before/after zero checks, installation
status and a correction chain. Keep failed installations without replacement
numbers and preserve original transcription rows. The analyzer must count
missing attempts in the scheduled denominator. See the protocol for stop rules,
zero-invalid blocks, raw preservation and the exact analysis formulas.

Commit actual results under `prototypes/results/<trial-id>/` only after running
the trial. Include the frozen execution copy, raw observations, derived report,
photos and deviations. Do not add generated drafts or synthetic test data there.
The repository has no physical results and makes no physical pass claim.

A challenger passing geometry selection still needs an independent correction
trial before release replacement. Define post-correction bias/RMS and improvement
relative to uncertainty before that trial. Retain at least three independent
baseline prints and three verification prints. Reprinting the same artifact
is not a holdout/generalization test. Never replace the bundled geometry solely
on appearance or material use.
