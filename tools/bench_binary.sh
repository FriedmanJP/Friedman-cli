#!/bin/bash
# Usage: tools/bench_binary.sh <label>   — run after `julia build_release.jl`
set -euo pipefail
BIN=build/friedman/bin/friedman
LIB=$(ls build/friedman/lib/friedman.*)
FIX=$(mktemp -t bench_fixture).csv
python3 - "$FIX" <<'EOF'
import math, sys
with open(sys.argv[1], "w") as f:
    f.write("y1,y2,y3\n")
    for t in range(1, 121):
        f.write(f"{math.sin(t/3):.6f},{math.cos(t/4):.6f},{math.sin(t/5)+math.cos(t/7):.6f}\n")
EOF
echo "== $1 =="
echo "sysimage size: $(du -h "$LIB" | cut -f1)"

# Isolate child I/O so /usr/bin/time -p real line is not swallowed by redirections.
time_cmd() {
    /usr/bin/time -p sh -c '"$@" >/dev/null 2>&1' _ "$@" 2>&1 | awk '/^real/{print $2}'
}

run_pair() {
    local display=$1
    shift
    local T1 T2
    T1=$(time_cmd "$@")
    T2=$(time_cmd "$@")
    echo "  [$display]  run1=${T1}s run2=${T2}s"
}

run_pair "--version" "$BIN" --version
run_pair "--help" "$BIN" --help
run_pair "estimate var <fixture> --lags 1" "$BIN" estimate var "$FIX" --lags 1
run_pair "estimate var <fixture> --lags 1 --format json" "$BIN" estimate var "$FIX" --lags 1 --format json

rm -f "$FIX"
