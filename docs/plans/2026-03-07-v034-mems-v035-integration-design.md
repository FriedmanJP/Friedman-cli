# Friedman-cli v0.3.4 — MEMs v0.3.5 Integration Design

## Scope

Two changes:

1. **Bump MEMs compat** from v0.3.4 to v0.3.5, update mocks for `OccBinSolution.constraints` field
2. **Add `--warranty` / `--conditions` root flags** that print GPL notice text and exit

## 1. MEMs compat bump

- `Project.toml`: change `MacroEconometricModels = "0.3.4"` → `"0.3.5"` under `[compat]`
- `src/Friedman.jl`: bump `FRIEDMAN_VERSION` to `"0.3.4"`
- `src/cli/types.jl`: update `Entry` default version if hardcoded
- `test/runtests.jl`: update version string refs
- `test/mocks.jl`: add `constraints::Vector` field to mock `OccBinSolution` struct, update constructor

## 2. Root flags `--warranty` / `--conditions`

Handle in `src/Friedman.jl`'s `main(args)` before `dispatch()`. If `--warranty` or `--conditions` found in args, call `MacroEconometricModels.warranty()` or `.conditions()` and return.

Mock: add `warranty()` and `conditions()` stubs to `test/mocks.jl`. Test that flags produce output and exit cleanly.

## Out of scope

- `dsge irf --constraints` stays with direct `occbin_irf()` (not adopting `irf(::OccBinSolution)`)
- `report()` dispatches not exposed
- No new commands or subcommands

## Documentation updates

- `CLAUDE.md`: version bump, mention `--warranty`/`--conditions`
- `README.md`: version refs, add flags
- `docs/`: update version refs
