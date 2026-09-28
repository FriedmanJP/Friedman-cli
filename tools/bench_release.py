#!/usr/bin/env python3
"""Release latency budgets (C074/#79, wired by W6/#141).

Agent-first mandate: per-call latency is a reliability property. Two cases,
each run N times as a COLD process start (cold start IS the metric; the
reported number is the minimum, which filters scheduler noise while keeping
the full cold-start cost):

    version:   $BIN --version                                      (default budget 3000 ms)
    estimate:  $BIN --quiet estimate multivariate var <data> --lags 1
                                                                   (default budget 3500 ms)

`estimate multivariate` is a family node. The timed command is the `var`
leaf — the same leaf the release smoke step runs and `build_release.jl`
precompiles. The smoke step adds `--format json`; this bench does not,
because the budget is the default-table cold start. Passing the CSV where
the leaf name belongs is `usage/unknown-command` (exit 2), not a slow run.

Markdown table to stdout and, when set, $GITHUB_STEP_SUMMARY. A budget breach
exits non-zero ONLY under --enforce (release CI enforces on ubuntu; macOS and
Windows report). A case that FAILS to run exits non-zero regardless — a broken
binary must never look like a slow one — and the CLI's stderr is printed.

Budget calibration (2026-08, #79 measure-first baseline): the JuMP+Ipopt-bundled
sysimage costs ~2.3 s of pure runtime boot per cold invocation on ubuntu-latest
runners — for --version and real work alike — so the budgets are set to the
measured floor (2259/2301 ms minimums) plus ~30% regression headroom. They exist
to catch REGRESSION (a new heavyweight dep, broken sysimage baking), and from
these calibrated numbers they are never relaxed to make a red run green: a real
JIT-coverage breach is fixed by expanding the build_release.jl precompile
workload; a floor change requires a new recorded calibration on #79.
"""

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path


# Leaf timed by the release. Keep this in lockstep with the smoke step in
# .github/workflows/release.yml, the local timer in tools/bench_binary.sh,
# and the precompile dispatch in build_release.jl.
ESTIMATE_LEAF = ("estimate", "multivariate", "var")

_STDERR_LIMIT = 4000


def estimate_argv(prefix, bin_path, data):
    """Argv for one cold `estimate multivariate var` start."""
    return prefix + [bin_path, "--quiet", *ESTIMATE_LEAF, data, "--lags", "1"]


def _clip(text: str, limit: int = _STDERR_LIMIT) -> str:
    text = text.strip()
    if len(text) <= limit:
        return text
    return "…\n" + text[-limit:]


def _fail_broken(cmd, returncode, stdout, stderr):
    detail = _clip(stderr) or _clip(stdout) or "(no stdout or stderr)"
    sys.exit(f"FAIL: {' '.join(cmd)} exited {returncode} — broken, not slow\n{detail}")


def _require_same_leaf() -> None:
    """Fail before timing if the smoke step, local bench, or precompile
    stopped naming this leaf. A missing source file is skipped so a copied
    script can still time a binary."""
    root = Path(__file__).resolve().parents[1]
    leaf = " ".join(ESTIMATE_LEAF)
    problems = []

    yml = root / ".github" / "workflows" / "release.yml"
    if yml.is_file():
        # The smoke invocation, not a nearby comment: it names the fixture.
        matched = any(
            leaf in line and "smoke.csv" in line and "--lags 1" in line
            for line in yml.read_text(encoding="utf-8").splitlines()
        )
        if not matched:
            problems.append(f"{yml}: smoke step does not run `{leaf}` on smoke.csv --lags 1")

    sh = root / "tools" / "bench_binary.sh"
    if sh.is_file():
        matched = any(
            'estimate multivariate var "$FIX" --lags 1' in line
            for line in sh.read_text(encoding="utf-8").splitlines()
        )
        if not matched:
            problems.append(f"{sh}: local bench does not run `{leaf} --lags 1`")

    jl = root / "build_release.jl"
    if jl.is_file():
        needle = ", ".join(f'"{part}"' for part in ESTIMATE_LEAF)
        matched = any(
            needle in line and '"--lags", "1"' in line
            for line in jl.read_text(encoding="utf-8").splitlines()
        )
        if not matched:
            problems.append(
                f"{jl}: precompile does not dispatch `{leaf}` with --lags 1"
            )

    if problems:
        sys.exit("FAIL: latency bench drifted from the release leaf\n" + "\n".join(problems))


def run_case(cmd, n):
    times = []
    for _ in range(n):
        t0 = time.perf_counter()
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        dt_ms = (time.perf_counter() - t0) * 1000.0
        if r.returncode != 0:
            _fail_broken(cmd, r.returncode, r.stdout or "", r.stderr or "")
        times.append(dt_ms)
    return times


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bin", required=True, help="path to the built friedman binary")
    ap.add_argument("--data", required=True, help="CSV fixture for the estimate case")
    ap.add_argument("--runs", type=int, default=3, help="cold runs per case (default 3)")
    ap.add_argument("--budget-version-ms", type=float, default=3000.0)
    ap.add_argument("--budget-estimate-ms", type=float, default=3500.0)
    ap.add_argument("--enforce", action="store_true",
                    help="exit non-zero on budget breach (release CI: ubuntu only)")
    args = ap.parse_args()

    if args.runs < 1:
        sys.exit("FAIL: --runs must be ≥ 1")

    _require_same_leaf()

    # Windows ships friedman.cmd — CreateProcess cannot exec a .cmd directly,
    # and cmd.exe does not resolve forward-slash paths (the CI step passes
    # build/friedman/bin/friedman.cmd from bash) — normpath converts to
    # backslashes on Windows and is a no-op elsewhere.
    bin_path = os.path.normpath(args.bin)
    if not os.path.isfile(bin_path):
        sys.exit(f"FAIL: binary not found: {bin_path}")
    data_path = args.data
    if not os.path.isfile(data_path):
        sys.exit(f"FAIL: estimate fixture not found: {data_path}")

    prefix = ["cmd", "/c"] if bin_path.lower().endswith((".cmd", ".bat")) else []

    cases = [
        ("--version", prefix + [bin_path, "--version"], args.budget_version_ms),
        ("estimate multivariate var",
         estimate_argv(prefix, bin_path, data_path),
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
