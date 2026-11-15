# [API Reference](@id int-api)

Agents invoke the `friedman` executable from the shell rather than importing the Julia package directly; see [Automated Pipelines & JSON Envelopes](@ref gs-pipelines) and [Agent Guide](../agent-guide.md) for the supported CLI contract. The exported Julia functions below exist for embedding the CLI dispatcher inside external scripts, custom harnesses, REPL wrappers, and the JSON-RPC MCP loop.

---

## Exported Entry Points

```@docs
Friedman.main
Friedman.build_app
Friedman.run_cli
Friedman.julia_main
```

All user-facing command semantics, flags, typed-handle expectations, and JSON `data` table names are documented automatically under [CLI Reference Overview](@ref cli-overview).

---

## References

- [CLI Reference Overview](@ref cli-overview) — full per-command option and output table specs
- [Architecture](@ref int-architecture) — dispatcher flow, handle resolution, and rendering router
- [Unwrapped Upstream Surface](@ref int-not-wrapped) — upstream APIs intentionally excluded from CLI leaves
- Upstream package documentation: [MacroEconometricModels.jl](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/) (exact pinned version in `Project.toml`)
