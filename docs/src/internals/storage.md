# [Storage & Handle Architecture](@id int-storage)

Friedman-cli implements a four-layer persistence architecture (`src/storage/`) over `MacroEconometricModels.jl` handles so data containers, estimated models, derived results, and in-memory session objects share one URI grammar, one atomic write protocol, one header-only inspection path, and one provenance-backed reproduction model.

---

## Canonical Format Contract

Three on-disk container formats and four in-memory session namespaces are supported:

| Format / Scheme | Role | Semantics |
|---|---|---|
| `.jld2` | Canonical portable handle | Native `MacroEconometricModels.save_model` / `load_model` HDF5/JLD2 containers (all registered types) plus plain `.jld2` tabular/array archives (`DataFrame`, `NamedTuple`, `Dict`, `Array`) and `#key` sub-entry selectors. |
| `.jls` | Ephemeral / unregistered handle | Versioned `FrdcJlsEnvelope` wrapping Julia `Serialization` payloads (carries `type_name`, `dims`, `varnames`, `note`, `provenance`, and optional `source_model`). Fast within the same Julia minor release; migrate long-lived handles to `.jld2`. |
| `.fmod` | Legacy read-only handle | Deprecated pre-v1.1 serialization container. Reads emit a stderr migration notice recommending `frdc model convert <path> --to jld2`; writes remain only for explicit `.fmod` paths. |
| `data://`, `model://`, `result://`, `mem://` | Session-scoped in-memory URIs | Active inside `frdc repl` and `frdc serve --mcp`. Carry the same metadata and provenance as on-disk handles; rejected outside a session with `usage/session-uri-requires-session` (exit `2`). |

Bare stems without an extension resolve deterministically via `resolve_stem` (`src/storage/ref.jl`):

- **Save paths:** bare stems append `.jld2` automatically (`--save-model model_v1.2` writes `model_v1.2.jld2`). Dotted stems whose suffix is not a known handle extension (`.jld2`, `.jls`, `.fmod`, `.csv`, `.toml`, `.json`, `.html`) preserve the dots and append `.jld2`.
- **Load paths:** when a bare stem matches multiple sibling files (for example both `shared.csv` and `shared.jld2` on a data slot), Friedman-cli throws `data/ambiguous-path` (exit `3`) rather than guessing silently. Pass the explicit extension to disambiguate.

---

## HandleRef URI Grammar

`parse_handle_ref` (`src/storage/ref.jl`) parses every path/URI before any filesystem or session lookup:

```text
HandleRef := BuiltinDataset          # :denmark, :fred_md, :pwt, :wiot, ...
           | SessionURI              # (data|model|result|mem)://<name>
           | FilePath [# KeySelector] # path/to/file.jld2, ~/archive.jld2#df1
```

Key properties enforced uniformly across all slots:

- **Tilde expansion & normalization:** Leading `~` expands via `homedir()` before confinement checks.
- **Multi-key selection (`#key`):** Plain `.jld2` archives and MEMs bundles expose individual entries via `archive.jld2#key`. Use [`frdc model keys`](@ref ref-model-keys) or `frdc model info --keys` to inspect available keys without loading unrelated payloads.
- **Data + model coexistence:** Leaves that declare `allow_data_with_model=true` (for example out-of-sample `predict`, proxy SVAR with external instruments, `nowcast gdfm`, and `dsge var`) accept both `<data>` and `--model` simultaneously; all other leaves reject ambiguous combinations with `usage/invalid`.
- **Dual persistence:** Leaves returning `(; model, result)` (such as `nowcast`) and post-estimation pipelines accept `--save-model` and `--save-result` in the same invocation, recording every written path in the JSON envelope's `artifacts` array.

---

## Metadata, Atomic Writes & Confinement

Every `.jld2` handle written by `save_handle!` (`src/storage/codec.jl`) attaches a lightweight `_frdc_meta` group alongside the payload, and every `.jls` handle wraps its payload in `FrdcJlsEnvelope`:

- **`_frdc_meta` fields:** `cli_version`, `mems_version`, `type_name`, `kind` (`data`, `model`, `result`, `result_collection`), `dims` (dimension dictionary), `varnames`, `note`, `provenance` (`command`, `argv`, `seed`, `source_model_path`), and optional attached `source_model` metadata.
- **Header-only inspection:** [`frdc model info`](@ref ref-model-info) reads `_frdc_meta` and HDF5/JLD2 dataset headers directly with **zero full deserialization** (`_HANDLE_LOAD_COUNTER == 0`) and never invokes `Core.eval` on stored DSGE/HA expressions. Pass `--deep` only when inspecting legacy handles that predate `_frdc_meta`.
- **Atomic writes:** `_atomic_write` writes to a sibling temporary file in the destination directory and renames atomically into place. Same-file overwrites (`frdc data fix f.jld2 -o f.jld2`) and failed writes never corrupt the existing file and leave zero `.tmp` files behind.
- **Magic-byte sniffing:** `sniff_handle_format` validates HDF5 (`\x89HDF\r\n\x1a\n`) vs Julia Serialization (`7JL`) magic bytes before opening a container. Truncated, 0-byte, random, or mismatched-extension handles fail immediately with typed `data/corrupt-handle` (exit `3`) and zero `JLD2.MmapIO` warnings.
- **Path confinement:** Setting `FRDC_DATA_ROOT` (with `FRIEDMAN_DATA_ROOT` fallback) restricts every read and write — including `model info`, `model keys`, `model convert`, `model reproduce`, `show`, `io`, `data`, and all estimators — to realpaths inside the configured root, blocking `..` and symlink escapes with `data/bad-path` (exit `3`).
- **Invocation cache:** `with_handle_cache` (`src/storage/cache.jl`) caches decoded handles per CLI invocation so multi-stage handlers never deserialize the same handle twice.

---

## Provenance & Reproduction

`src/storage/provenance.jl` captures command provenance (`command`, `argv`, `seed`, `cli_version`, `mems_version`) and source-model linkage during every save:

- **Direct upstream reproduction:** [`frdc model reproduce`](@ref ref-model-reproduce) invokes `MacroEconometricModels.reproduce` for all stochastic models and results carrying a `ReproManifest` (including two-argument `reproduce(irf, var_model)` across `.jld2`, `.jls`, `.fmod`, and session URIs).
- **Derived CLI reproduction:** For deterministic and seeded derived outputs whose attached source model is embedded or supplied via `--model` (`FEVD`, `LPFEVD`, `HistoricalDecomposition`, `VARForecast`, `BVARForecast`, `ARIMAForecast`, `FactorForecast`, `VECMForecast`), `reproduce_handle` re-runs the upstream calculation with matching horizon, confidence level, CI method, and RNG seed and reports per-field `max_abs_diff` against `--tol`.
- **Format migration:** [`frdc model convert`](@ref ref-model-convert) migrates any `.fmod`, `.jls`, `.jld2`, `archive.jld2#key`, or session URI atomically to `.jld2` or `.jls`, preserving `note`, `varnames`, `dims`, and `source_model` provenance.
- **Bounded inspection:** [`frdc show`](@ref ref-show) previews data, models, results, and bundles with `--max-rows` (default `20`) and `--max-cols` (default `12`), summarizing large arrays concisely instead of dumping raw matrices.

---

## References

- [Architecture](@ref int-architecture) — overall execution flow and command registry
- [Pipelines, Handles & Reproducibility](@ref gs-pipelines) — user workflows for typed handles and JSON envelopes
- [Interactive REPL](@ref gs-repl) — session URI usage in interactive sessions
- [Agent Guide](../agent-guide.md) — frozen envelope v1 schema and error codes
