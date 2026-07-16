# Documentation Rules — Friedman-cli

Adapted from the agent-first overhaul Appendix D. These rules keep docs from drifting relative to the declarative command registry.

## 1. Page types & skeletons

### 1.1 Generated Reference

Never hand-edit generated pages. Edits go to registry `CommandSpec` descriptions / option text, then regenerate:

```bash
julia --project docs/generate_cli_reference.jl
```

Generated artifacts:

| Artifact | Path |
|----------|------|
| Overview tree + counts | `docs/src/commands/overview.md` (generated body between markers) |
| Per-top-level command tables | `docs/src/commands/generated/*.md` |
| Shell completions | `completions/{friedman.bash,friedman.zsh,_friedman.fish}` |
| CLAUDE inventory (local) | `CLAUDE.md` between `<!-- BEGIN GENERATED -->` markers |

### 1.2 Workflow Guide

Hand-written narrative pages:

- Goal → dataset → 3–6 progressive invocations with captured output → interpretation → pitfalls → links
- Defaults/choices never in prose — point at generated tables
- Examples must run against shipped fixtures (`<!-- capture -->` blocks)

### 1.3 Contract

Envelope, exit codes, deprecation. Schema-review required for contract changes.

### 1.4 Landing

Short; no hard-coded leaf counts (use generated overview).

## 2. Integrity rules

1. Examples run against shipped datasets — copy-paste must work.
2. Shown output is captured by `docs/capture_examples.jl`, never hand-typed.
3. Defaults/choices never in prose — transclude generated tables.
4. No hard-coded counts; no version literals (use Project.toml / generator).
5. Interpretation quotes only numbers visible in the captured block above.

## 3. Voice

Present, active, no hedging; econometrics-textbook register; terms **bold** on first use.

## 4. Structure mechanics

H1–H3 only; `---` between H2 sections; References last; guide ↔ reference cross-links both ways.

## 5. Verification protocol

Any PR touching `src/commands/` or `src/registry/` must pass:

```bash
julia --project docs/generate_cli_reference.jl --check
julia --project docs/capture_examples.jl --check   # when capture blocks exist
```

Both are CI gates (see `.github/workflows/CI.yml`).

## 6. Anti-patterns

- Hand-copied flag tables
- Typed output blocks
- Counts in prose (`~204 subcommands`)
- Narrating datasets the example doesn't load
- `TODO` / “not yet implemented” in shipped docs
