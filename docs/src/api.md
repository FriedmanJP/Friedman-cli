# API Reference

Agents use the `friedman` command line, not this page. The Julia API below exists for embedding the CLI engine (REPL, scripts, the MCP server) and for developers hacking on the command tree. End-user behavior — options, output tables, envelope schema — is documented under the [CLI Reference](commands/overview.md) and generated per command; nothing here replaces it.

---

## Exported entry points

```@docs
Friedman.main
Friedman.build_app
Friedman.run_cli
Friedman.julia_main
```

---

## References

- [CLI overview](commands/overview.md) — the supported surface; agents start here.
- Upstream estimator semantics: [MacroEconometricModels.jl](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/) (pinned **1.0.0**; see `Project.toml`).
- Unwrapped upstream surface: [Not wrapped](commands/not-wrapped.md).
