# XY-S-FIRST — PHYSICAL

One baseline print at zero compensation, then a separate verification print.
Fill environment.json and prints.csv with actual provenance. The initial mesh hash
identifies the generated file, not proof that it was printed.

In measurements.csv retain one row per full re-seat. Use status OK with measured_mm
and zero checks, SKIPPED with a reason for an omitted optional feature, or FAILED
with a reason and no value. Blank rows remain missing; never enter nominal values
as placeholders. Fill baseline first. All six primary fields are required.

Export baseline input strings with tools/xy_experiment.py inputs. Apply them using
the normal plugin workflow. Record the actual verification-print shrinkage in
prints.csv, then fill verification rows and run analyze. Do not feed compensated
verification readings back into the zero-baseline calculator.

Related dimensions are not independent samples. The comparison margin is a
declared descriptive threshold, not a confidence interval or certified tolerance.
See model/xy-reference.md and research/xy-s-experiment.md in the repository.
