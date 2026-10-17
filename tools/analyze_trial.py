#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
"""Reproduce Gate A/B analysis from an immutable trial plan and append-only rows."""
from __future__ import annotations

import argparse
import collections
import hashlib
import html
import json
import math
import random
import statistics as stats
from decimal import Decimal
from pathlib import Path

from trial import finite, read_csv, verify_frozen, write_json

ANALYSIS_VERSION = "1.0.1"
EPSILON = 1e-10  # Numerical roundoff only, not an additional engineering margin.


def summary(values):
    if not values:
        return dict(n=0, median=None, mean=None, minimum=None, maximum=None,
                    range=None, sd=None, mad=None, scaled_mad=None)
    center = stats.median(values)
    mad = stats.median(abs(value - center) for value in values)
    return dict(n=len(values), median=center, mean=stats.mean(values), minimum=min(values),
                maximum=max(values), range=max(values) - min(values),
                sd=stats.stdev(values) if len(values) > 1 else None,
                mad=mad, scaled_mad=1.4826 * mad)


def pooled_sd(cells):
    eligible = [values for values in cells if len(values) > 1]
    denominator = sum(len(values) - 1 for values in eligible)
    return math.sqrt(sum((len(v) - 1) * stats.variance(v) for v in eligible) / denominator) if denominator else None


def quantile(values, probability):
    ordered = sorted(values)
    position = (len(ordered) - 1) * probability
    low = math.floor(position)
    fraction = position - low
    return ordered[low] * (1 - fraction) + ordered[min(low + 1, len(ordered) - 1)] * fraction


def bootstrap_ratio(control, candidate, iterations, confidence, seed):
    """Stratified percentile bootstrap, with undefined denominators kept visible."""
    base, challenger = pooled_sd(control), pooled_sd(candidate)
    result = dict(control_sd=base, candidate_sd=challenger, ratio=None,
                  interval=None, iterations=iterations, undefined_iterations=0)
    if base is None or challenger is None or base <= EPSILON or challenger <= EPSILON:
        result["reason"] = "indistinguishable_at_instrument_resolution_or_insufficient_data"
        return result
    result["ratio"] = challenger / base
    rng = random.Random(seed)
    ratios = []
    for _ in range(iterations):
        samples = [[rng.choices(values, k=len(values)) for values in groups] for groups in (control, candidate)]
        denominator, numerator = (pooled_sd(groups) for groups in samples)
        if denominator is None or numerator is None or denominator <= EPSILON:
            result["undefined_iterations"] += 1
        else:
            ratios.append(numerator / denominator)
    if result["undefined_iterations"]:
        result["reason"] = "bootstrap_ratio_has_undefined_denominators"
    else:
        tail = (1 - confidence) / 2
        result["interval"] = [quantile(ratios, tail), quantile(ratios, 1 - tail)]
    return result


def validate_observations(directory, config, schedule):
    rows = read_csv(directory / "measurements.csv")
    # Check even an empty file's header (DictReader does not retain it in rows).
    import csv
    with (directory / "measurements.csv").open(newline="") as stream:
        if next(csv.reader(stream), None) != config["measurement_columns"]:
            raise ValueError("measurement header differs from the versioned schema")
    planned = {row["observation_id"]: row for row in schedule}
    history, roots, effective, superseded = {}, {}, {}, set()
    for row in rows:
        observation = row["observation_id"]
        previous = row["supersedes_observation_id"]
        if not observation or observation in history:
            raise ValueError("raw observation IDs must be unique and nonempty")
        if previous:
            if previous not in history or previous in superseded or observation in planned:
                raise ValueError("invalid or branching correction chain")
            prior = history[previous]
            if prior["installation_status"] not in ("OK", "TRANSCRIPTION_ERROR"):
                raise ValueError("cannot replace a failed physical installation with a correction")
            if row["installation_status"] not in ("OK", "TRANSCRIPTION_ERROR") or not row["notes"]:
                raise ValueError("transcription corrections require an explicit reason in notes")
            if row["actual_order"] != prior["actual_order"]:
                raise ValueError("a transcription correction cannot create a new physical attempt")
            root = roots[previous]
            superseded.add(previous)
        else:
            root = observation
            if root not in planned:
                raise ValueError(f"unplanned observation: {root}")
        for key, value in planned[root].items():
            if key != "observation_id" and row[key] != value:
                raise ValueError(f"{observation}: {key} differs from the schedule")
        status = row["installation_status"]
        if status not in config["installation_statuses"]:
            raise ValueError(f"{observation}: invalid installation status")
        if not row["actual_order"].isdigit() or int(row["actual_order"]) < 1:
            raise ValueError("actual_order must be a positive integer")
        if status == "OK":
            finite(row["measured_mm"], observation, positive=True)
        elif row["measured_mm"] or not row["failure_reason"]:
            raise ValueError("non-OK rows require a reason and an empty measured_mm")
        if status != "SKIPPED":
            for key in ("zero_before_mm", "zero_after_mm", "elapsed_since_print_h"):
                value = finite(row[key], key)
                if key == "elapsed_since_print_h" and value < 0:
                    raise ValueError("elapsed cooling time cannot be negative")
        history[observation], roots[observation], effective[root] = row, root, row
    orders = [row["actual_order"] for row in effective.values()]
    if len(set(orders)) != len(orders):
        raise ValueError("physical attempts must have unique actual_order values")
    instruments = {row["caliper_id"]: row for row in read_csv(directory / "instruments.csv")}
    zero_values = collections.defaultdict(set)
    invalid_blocks = set()
    for row in effective.values():
        if row["installation_status"] == "SKIPPED":
            continue
        before, after = float(row["zero_before_mm"]), float(row["zero_after_mm"])
        resolution = Decimal(instruments[row["caliper_id"]]["resolution_mm"])
        for key in ("zero_before_mm", "zero_after_mm", "measured_mm"):
            if row[key]:
                try:
                    remainder = Decimal(row[key]) % resolution
                except ArithmeticError:
                    raise ValueError(f"{row['observation_id']}: {key} cannot be represented at the declared resolution") from None
                if remainder != 0:
                    raise ValueError(f"{row['observation_id']}: {key} is finer than the declared display resolution")
        zero_values[row["block_id"]].add((before, after))
        if abs(after - before) > float(instruments[row["caliper_id"]]["resolution_mm"]) + EPSILON:
            invalid_blocks.add(row["block_id"])
        if row["installation_status"] == "ZERO_CHECK_FAILED":
            invalid_blocks.add(row["block_id"])
    if any(len(values) > 1 for values in zero_values.values()):
        raise ValueError("block zero checks are inconsistent; preserve rows and document a correction")
    deviations = read_csv(directory / "deviations.csv") if (directory / "deviations.csv").exists() else []
    known_scopes = {row[key] for row in schedule for key in ("block_id", "print_id", "print_batch_id")} | set(config["families"])
    invalid_scopes = set()
    for row in deviations:
        if set(row) != {"event_id", "scope_id", "reason", "action"} or not row["reason"]:
            raise ValueError("invalid deviation record")
        if row["scope_id"] not in known_scopes or row["action"] not in (
            "INVALIDATE", "NOTE", "CONTINUE_GATE_B", "COST_ACCEPTED", "COST_REJECTED"
        ):
            raise ValueError("unknown deviation scope/action")
        if row["action"] == "INVALIDATE":
            invalid_scopes.add(row["scope_id"])
    if len({row["event_id"] for row in deviations}) != len(deviations):
        raise ValueError("duplicate deviation ID")
    environment = json.loads((directory / "environment.json").read_text())
    minimum_cooling = finite(environment["minimum_cooling_h"], "minimum_cooling_h")
    observations = []
    for scheduled in schedule:
        row = effective.get(scheduled["observation_id"])
        reason, measured = "MISSING", None
        if row:
            reason = row["installation_status"]
            if scheduled["block_id"] in invalid_blocks:
                reason = "ZERO_CHECK_FAILED"
            if any(scheduled[key] in invalid_scopes for key in ("block_id", "print_id", "print_batch_id")):
                reason = "INVALIDATED"
            family = "xy" if scheduled["axis"] in "xy" else "z"
            if family in invalid_scopes:
                reason = "INVALIDATED"
            if row["installation_status"] != "SKIPPED" and float(row["elapsed_since_print_h"]) < minimum_cooling:
                reason = "INSUFFICIENT_COOLING"
            if reason == "OK":
                measured = float(row["measured_mm"])
        observations.append(dict(scheduled, raw=row, analysis_status=reason, value=measured))
    return observations, dict(raw_rows=len(rows), corrections=len(superseded),
                              invalid_zero_blocks=sorted(invalid_blocks), deviations=deviations)


def group_summary(rows):
    values = [row["value"] for row in rows if row["value"] is not None]
    counts = collections.Counter(row["analysis_status"] for row in rows)
    return dict(summary(values), scheduled=len(rows), valid=len(values),
                failed=len(rows) - len(values), missing=counts["MISSING"],
                failure_rate=(len(rows) - len(values)) / len(rows), statuses=dict(counts))


def axis_fit(nominals, values):
    nmean, mean = stats.mean(nominals), stats.mean(values)
    slope = sum((n - nmean) * (v - mean) for n, v in zip(nominals, values)) / sum((n - nmean) ** 2 for n in nominals)
    return dict(scale=slope, observed_additive_term_mm=mean - slope * nmean,
                curvature_hint_mm=values[1] - (values[0] + values[2]) / 2)


def strict_status(rows, breaches):
    failures = [row for row in rows if row["analysis_status"] not in ("OK", "MISSING", "SKIPPED", "TRANSCRIPTION_ERROR")]
    if failures or breaches:
        return "FAIL"
    if any(row["analysis_status"] != "OK" for row in rows):
        return "INCONCLUSIVE"
    return "PASS"


def analyze(directory):
    directory = Path(directory)
    config, schedule = verify_frozen(directory)
    observations, audit = validate_observations(directory, config, schedule)
    artifact_rows = read_csv(directory / "artifacts.csv")
    result = dict(analysis_version=ANALYSIS_VERSION, protocol_version=config["protocol_version"],
                  schema_version=config["schema_version"], trial_id=config["trial_id"],
                  study_kind=config["study_kind"], audit=audit, families={},
                  calibration_status="NOT_VERIFIED",
                  input_sha256={name: hashlib.sha256((directory / name).read_bytes()).hexdigest()
                                for name in ("checksums.sha256", "measurements.csv")})
    if (directory / "deviations.csv").exists():
        result["input_sha256"]["deviations.csv"] = hashlib.sha256((directory / "deviations.csv").read_bytes()).hexdigest()
    for family in config["families"]:
        models = {row["role"]: row["artifact_id"] for row in artifact_rows if row["family"] == family}
        selected = [row for row in observations if row["artifact_id"] in models.values()]
        arows, brows = ([row for row in selected if row["gate"] == gate] for gate in ("A", "B"))
        cells, copies = collections.defaultdict(list), collections.defaultdict(list)
        for row in arows:
            cells[(row["artifact_id"], row["feature_id"], row["operator_id"], row["caliper_id"])].append(row)
        for row in brows:
            copies[(row["artifact_id"], row["feature_id"], row["print_batch_id"])].append(row)
        astats = {key: group_summary(rows) for key, rows in cells.items()}
        bstats = {key: group_summary(rows) for key, rows in copies.items()}
        abreach, bbreach, spans = [], [], {}
        for key, cell in astats.items():
            if cell["range"] is not None and cell["range"] > config["range_margin_mm"] + EPSILON:
                abreach.append(f"cell_range:{'/'.join(key)}")
        for feature in sorted({row["feature_id"] for row in selected}):
            per_model = {}
            for role, model in models.items():
                model_cells = {key: cell for key, cell in astats.items() if key[:2] == (model, feature)}
                operator_shifts, caliper_shifts = [], []
                for position, target in ((2, operator_shifts), (3, caliper_shifts)):
                    fixed_position = 3 if position == 2 else 2
                    for fixed in sorted({key[fixed_position] for key in model_cells}):
                        medians = [cell["median"] for key, cell in model_cells.items()
                                   if key[fixed_position] == fixed and cell["median"] is not None]
                        if len(medians) > 1:
                            target.append(max(medians) - min(medians))
                model_copies = {key[2]: cell for key, cell in bstats.items() if key[:2] == (model, feature)}
                copy_medians = [cell["median"] for cell in model_copies.values() if cell["median"] is not None]
                print_stats = summary(copy_medians)
                nominal = next(float(row["nominal_mm"]) for row in selected if row["feature_id"] == feature)
                per_model[role] = dict(operator_shift_mm=max(operator_shifts, default=None),
                                       caliper_shift_mm=max(caliper_shifts, default=None),
                                       copies=model_copies, print_summary=print_stats,
                                       descriptive_bias_mm=print_stats["mean"] - nominal if print_stats["mean"] is not None else None)
                if print_stats["range"] is not None and print_stats["range"] > config["range_margin_mm"] + EPSILON:
                    bbreach.append(f"print_median_range:{model}/{feature}")
            pairs = sorted({key[2:] for key in cells if key[1] == feature})
            shifts = [astats[(models["challenger"], feature, *pair)]["median"] - astats[(models["control"], feature, *pair)]["median"]
                      for pair in pairs if all(astats[(models[role], feature, *pair)]["median"] is not None for role in models)]
            if any(abs(shift) > config["shift_margin_mm"] + EPSILON for shift in shifts):
                abreach.append(f"matched_shift:{feature}")
            groups = [[ [row["value"] for row in cells[(models[role], feature, *pair)] if row["value"] is not None]
                        for pair in pairs] for role in ("control", "challenger")]
            seed = int(hashlib.sha256(f"{config['seed']}:{family}:{feature}".encode()).hexdigest(), 16)
            comparison = bootstrap_ratio(*groups, config["bootstrap_iterations"], config["bootstrap_confidence"], seed)
            matched_prints = []
            for batch in sorted(per_model["control"]["copies"]):
                control = per_model["control"]["copies"][batch]
                candidate = per_model["challenger"]["copies"][batch]
                shift = candidate["median"] - control["median"] if candidate["median"] is not None and control["median"] is not None else None
                if shift is not None and abs(shift) > config["shift_margin_mm"] + EPSILON:
                    bbreach.append(f"matched_shift:{batch}/{feature}")
                direction = candidate["sd"] is not None and control["sd"] is not None and candidate["sd"] < control["sd"] - EPSILON
                matched_prints.append(dict(batch=batch, shift_mm=shift, handling_advantage=direction))
            spans[feature] = dict(models=per_model, matched_cell_shifts_mm=shifts,
                                  comparison=comparison, matched_prints=matched_prints)
        astatus, bstatus = strict_status(arows, abreach), strict_status(brows, bbreach)
        # Report the original strict failure even if somebody collected B anyway.
        continuing = any(d["scope_id"] == family and d["action"] == "CONTINUE_GATE_B" for d in audit["deviations"])
        badvance = astatus == "PASS" or (astatus == "INCONCLUSIVE" and continuing)
        qualifying = []
        no_worse = True
        for feature, span in spans.items():
            comparison, models_stats = span["comparison"], span["models"]
            qualifies = (comparison["ratio"] is not None and comparison["ratio"] <= config["improvement_ratio"] + EPSILON
                         and comparison["interval"] is not None and comparison["interval"][1] < 1
                         and all(p["handling_advantage"] for p in span["matched_prints"]))
            if qualifies:
                qualifying.append(feature)
            if comparison["ratio"] is None or comparison["ratio"] > config["worsening_ratio"] + EPSILON:
                no_worse = False
            if comparison["interval"] is None or (
                comparison["interval"][0] <= config["improvement_ratio"] and
                comparison["interval"][1] >= config["worsening_ratio"]
            ):
                no_worse = False
            for metric in ("operator_shift_mm", "caliper_shift_mm"):
                c, t = models_stats["control"][metric], models_stats["challenger"][metric]
                if c is None or t is None or t > c + EPSILON:
                    no_worse = False
        costs = [d["action"] for d in audit["deviations"] if d["scope_id"] == family and d["action"] in ("COST_ACCEPTED", "COST_REJECTED")]
        cost_accepted = bool(costs) and costs[-1] == "COST_ACCEPTED"
        comparative = len(qualifying) >= (4 if family == "xy" else 1) and no_worse and cost_accepted
        verdict = "NOT_SUPPORTED" if "FAIL" in (astatus, bstatus) else "INCONCLUSIVE"
        if astatus == bstatus == "PASS" and badvance and comparative and config["study_kind"] == "confirmatory":
            verdict = "SUPPORTED"
        fits = []
        if family == "xy":
            for model in models.values():
                for batch in sorted({row["print_batch_id"] for row in brows}):
                    for axis in "xy":
                        features = sorted((f for f in spans if f.startswith(axis)), key=lambda f: float(f[1:]))
                        values = [bstats[(model, feature, batch)]["median"] for feature in features]
                        if len(values) == 3 and all(value is not None for value in values):
                            fits.append(dict(artifact_id=model, batch=batch, axis=axis,
                                             **axis_fit([float(f[1:]) for f in features], values)))
        result["families"][family] = dict(
            verdict=verdict, gate_a=dict(status=astatus, breaches=abreach, counts=group_summary(arows)),
            gate_b=dict(status=bstatus, breaches=bbreach, counts=group_summary(brows), progression_supported=badvance),
            comparative=dict(qualifying_spans=qualifying, no_span_or_operator_caliper_regression=no_worse,
                             cost_accepted=cost_accepted), spans=spans,
            cells=[dict(artifact_id=key[0], feature_id=key[1], operator_id=key[2], caliper_id=key[3], **cell)
                   for key, cell in sorted(astats.items())], per_print_fits=fits,
            worst_span_within_sd={role: max((s["comparison"][f"{'control' if role == 'control' else 'candidate'}_sd"]
                                            for s in spans.values() if s["comparison"][f"{'control' if role == 'control' else 'candidate'}_sd"] is not None), default=None)
                                  for role in models})
    return result, observations


def report_markdown(result):
    lines = [f"# Trial {result['trial_id']}", "", f"Analysis {ANALYSIS_VERSION}; protocol {result['protocol_version']}; {result['study_kind']}.",
             "", "Geometry selection only. Calibration: **NOT_VERIFIED**.", "",
             "All original rows are retained in measurements.csv; corrections only change the effective view.", ""]
    for family, report in result["families"].items():
        lines += [f"## {family.upper()}: {report['verdict']}", "",
                  f"Gate A: {report['gate_a']['status']}; Gate B: {report['gate_b']['status']}.",
                  f"Gate B progression supported: {report['gate_b']['progression_supported']}. Cost accepted: {report['comparative']['cost_accepted']}.", "",
                  "| Model / feature / operator / caliper | Scheduled | Valid | Missing | Failure rate | Median | Mean | Range | SD | MAD |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
        def number(value):
            return "—" if value is None else f"{value:.6g}"
        for cell in report["cells"]:
            label = " / ".join(cell[key] for key in ("artifact_id", "feature_id", "operator_id", "caliper_id"))
            lines.append("| " + label + " | " + " | ".join(number(cell[key]) for key in
                         ("scheduled", "valid", "missing", "failure_rate", "median", "mean", "range", "sd", "mad")) + " |")
        lines += ["", "### Per-span and per-print outcomes", ""]
        for feature, span in report["spans"].items():
            comparison = span["comparison"]
            lines.append(f"- {feature}: SD ratio {number(comparison['ratio'])}; 90% interval {comparison['interval']}; matched cell shifts {span['matched_cell_shifts_mm']}.")
            for role, model in span["models"].items():
                lines.append(f"  {role} per-print medians: " + ", ".join(f"{batch}={number(cell['median'])}" for batch, cell in model["copies"].items()) + ".")
        lines += ["", "Strict breaches: " + "; ".join(report["gate_a"]["breaches"] + report["gate_b"]["breaches"] or ["none demonstrated"]), ""]
    lines += ["Complete metrics, fit diagnostics and input hashes: `analysis.json`. Raw observation-order plots: `observations.html`.", ""]
    return "\n".join(lines)


def observations_html(observations):
    """Standalone vector strip plots; every planned attempt remains a table row."""
    groups = collections.defaultdict(list)
    for row in observations:
        groups[(row["gate"], row["artifact_id"], row["feature_id"], row["operator_id"], row["caliper_id"])].append(row)
    parts = ['<!doctype html><meta charset="utf-8"><title>Raw trial observations</title>',
             '<style>body{font:15px system-ui;max-width:1000px;margin:32px auto}table{border-collapse:collapse;width:100%}td,th{padding:5px;border-bottom:1px solid #ddd;text-align:left}svg{width:100%;max-width:900px}section{margin:40px 0}</style>',
             '<h1>Raw observations in actual order</h1><p>Dots are effective valid measurements. Red crosses are failed/invalid attempts; grey crosses are missing. Original raw text and corrections remain in the CSV. Missing attempts are shown at the end in planned order.</p>']
    for key, rows in sorted(groups.items()):
        rows.sort(key=lambda row: (row["raw"] is None, int(row["raw"]["actual_order"]) if row["raw"] else int(row["scheduled_order"])))
        values = [row["value"] for row in rows if row["value"] is not None]
        center = float(rows[0]["nominal_mm"])
        low, high = min(values, default=center) - 0.01, max(values, default=center) + 0.01
        parts.append('<section><h2>' + html.escape(" / ".join(key)) + '</h2>')
        parts.append(f'<svg viewBox="0 0 900 240" role="img" aria-label="Measured millimetres by observation order"><path d="M90 20 V190 H880" fill="none" stroke="#555"/><text x="0" y="25">{high:.4f} mm</text><text x="0" y="190">{low:.4f} mm</text><text x="300" y="230">Observation order (actual; missing appended)</text>')
        for index, row in enumerate(rows):
            x = 100 + index * 770 / max(len(rows) - 1, 1)
            title = html.escape(row["observation_id"] + ": " + row["analysis_status"])
            if row["value"] is None:
                colour = "#888" if row["raw"] is None else "#b22"
                parts.append(f'<path d="M{x-3} 199 l6 6 m-6 0 l6 -6" stroke="{colour}"><title>{title}</title></path>')
            else:
                y = 185 - (row["value"] - low) * 160 / (high - low)
                parts.append(f'<circle cx="{x}" cy="{y}" r="3" fill="#176b9a"><title>{title}: {row["value"]}</title></circle>')
        parts.append('</svg><table><tr><th>Observation</th><th>Print</th><th>Actual order</th><th>Raw display mm</th><th>Analysis status</th></tr>')
        for row in rows:
            raw = row["raw"] or {}
            parts.append('<tr>' + ''.join('<td>' + html.escape(str(value)) + '</td>' for value in
                         (row["observation_id"], row["print_id"], raw.get("actual_order", ""), raw.get("measured_mm", ""), row["analysis_status"])) + '</tr>')
        parts.append('</table></section>')
    return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trial", type=Path)
    parser.add_argument("--output", type=Path, required=True, help="new directory; existing reports are never overwritten")
    args = parser.parse_args()
    try:
        result, rows = analyze(args.trial)
        args.output.mkdir(parents=True, exist_ok=False)
        write_json(args.output / "analysis.json", result)
        (args.output / "analysis.md").write_text(report_markdown(result), encoding="utf-8")
        (args.output / "observations.html").write_text(observations_html(rows), encoding="utf-8")
        print(json.dumps({family: data["verdict"] for family, data in result["families"].items()}))
    except (ValueError, OSError, KeyError) as exc:
        parser.exit(1, f"ERROR: {exc}\n")


if __name__ == "__main__":
    main()
