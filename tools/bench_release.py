#!/usr/bin/env python3
"""Release latency budgets (C074/#79, wired by W6/#141).

Agent-first mandate: per-call latency is a reliability property. Two cases,
each run N times as a COLD process start (cold start IS the metric; the
reported number is the minimum, which filters scheduler noise while keeping
the full cold-start cost):

    version:   $BIN --version                                   (default budget  500 ms)
    estimate:  $BIN --quiet estimate var <data> --lags 1        (default budget 1500 ms)

Markdown table to stdout and, when set, $GITHUB_STEP_SUMMARY. A budget breach
exits non-zero ONLY under --enforce (release CI enforces on ubuntu; macOS and
Windows report). A case that FAILS to run exits non-zero regardless — a broken
binary must never look like a slow one.

Budgets are never relaxed to make a red run green (#79): the remedy for a real
breach is expanding the sysimage precompile workload in build_release.jl.
"""

import argparse
import os
import subprocess
import sys
import time


def run_case(cmd, n):
    times = []
    for _ in range(n):
        t0 = time.perf_counter()
        r = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        dt_ms = (time.perf_counter() - t0) * 1000.0
        if r.returncode != 0:
            sys.exit(f"FAIL: {' '.join(cmd)} exited {r.returncode} — broken, not slow")
        times.append(dt_ms)
    return times


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bin", required=True, help="path to the built friedman binary")
    ap.add_argument("--data", required=True, help="CSV fixture for the estimate case")
    ap.add_argument("--runs", type=int, default=3, help="cold runs per case (default 3)")
    ap.add_argument("--budget-version-ms", type=float, default=500.0)
    ap.add_argument("--budget-estimate-ms", type=float, default=1500.0)
    ap.add_argument("--enforce", action="store_true",
                    help="exit non-zero on budget breach (release CI: ubuntu only)")
    args = ap.parse_args()

    # Windows ships friedman.cmd — CreateProcess cannot exec a .cmd directly.
    prefix = ["cmd", "/c"] if args.bin.lower().endswith((".cmd", ".bat")) else []

    cases = [
        ("--version", prefix + [args.bin, "--version"], args.budget_version_ms),
        ("first estimate var",
         prefix + [args.bin, "--quiet", "estimate", "var", args.data, "--lags", "1"],
         args.budget_estimate_ms),
    ]

    rows = []
    breached = []
    for label, cmd, budget in cases:
        times = run_case(cmd, args.runs)
        best = min(times)
        ok = best <= budget
        ok or breached.append(label)
        rows.append((label, best, budget, "ok" if ok else "**OVER**",
                     ", ".join(f"{t:.0f}" for t in times)))

    lines = [
        "| case | best (ms) | budget (ms) | status | cold runs (ms) |",
        "|------|-----------|-------------|--------|----------------|",
    ]
    lines += [f"| {l} | {b:.0f} | {bud:.0f} | {s} | {ts} |" for l, b, bud, s, ts in rows]
    table = "\n".join(lines)
    print(table)

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write("## Latency budgets (C074/#79)\n\n" + table + "\n")

    if breached:
        msg = f"latency budget breached: {', '.join(breached)}"
        if args.enforce:
            print(f"FAIL: {msg} — expand the build_release.jl precompile workload; "
                  "budgets are never relaxed (#79)", file=sys.stderr)
            return 1
        print(f"WARN: {msg} (report-only on this OS)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
