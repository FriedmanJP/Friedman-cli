# Documentation Rules — Friedman-cli

Authoritative documentation constitution for `Friedman-cli`. Every page under `docs/src/` is classified into one of six page types and verified by `docs/generate_cli_reference.jl --check`, `docs/lint_docs.jl`, `docs/capture_examples.jl --check`, and a strict `Documenter.jl` build (`checkdocs = :exports`, zero `warnonly`).

---

## 1. Page Types & Required Skeletons

| Type | Directory / Path | Purpose | Mandatory Elements |
|---|---|---|---|
| **Landing** | `docs/src/index.md` | Site home page & entry navigation | `@id home`, Feature / chapter routing table, compact Quick Start, `@contents` |
| **Getting Started** | `docs/src/getting-started/*.md`, `src/commands/agent_guide.md` | Installation, `.jld2`/`.jls` pipelines, method selection, REPL, agent contract | `@id gs-*` (not on `agent_guide.md`), runnable `<!-- capture -->` examples on `pipelines.md`, cross-links |
| **Domain Chapter** | `docs/src/chapters/*.md` | End-to-end econometric workflow covering estimation, testing, post-estimation, and rendering | `@id chap-*`, `## Quick Start`, `---` between H2s, concise framing equations, live `--format table` `<!-- capture -->` blocks + numeric interpretation, `## Common Pitfalls`, `## References` |
| **Configuration** | `docs/src/config/*.md` | Normative Model Card stanzas & TOML key schemas | `@id cfg-*`, complete key/type/default/constraints tables, owning `@ref chap-*` & `@ref ref-*` links |
| **Generated Reference** | `docs/src/commands/overview.md`, `docs/src/commands/generated/*.md` | Machine-derived per-verb & per-family flag/arg/option/handle/table tables | `@id ref-*` anchors, H2 family grouping, repeatable & handle metadata, bidirectional chapter `@ref` links |
| **Internals** | `docs/src/internals/*.md` | CLI architecture, Julia embedding API, unwrapped upstream surface | `@id int-*`, up-to-date architectural invariants, `@docs` for exported symbols |

### Domain Chapter Skeleton

Every file under `docs/src/chapters/` must follow this skeleton:

```markdown
# [Chapter Title](@id chap-slug)

[2–4 sentence overview of what workflows this chapter covers and which top-level CLI verbs/families implement them, linking to generated reference anchors and upstream MacroEconometricModels.jl docs.]

## Quick Start

[2–4 progressive CLI workflows spanning data/handle loading → estimation/solving → post-estimation/diagnostics. Include at least one `<!-- capture -->` block.]

---

## Domain Section Title

[Concise 2–3 sentence econometric framing + 1–2 governing display equations (`math` fence) + identifying assumptions.]

<!-- capture -->
```bash
friedman ...
```
```text
<captured --format table output>
```

[Concrete numeric interpretation quoting values printed directly above, plus the stable JSON `data` table key(s) returned under `--format json`. Cross-link to the full option table: [`friedman ...`](@ref ref-...)]

---

## Common Pitfalls

1. [Numbered CLI, handle, identification, or econometric pitfalls and typed error/exit codes.]

---

## References

- Academic citations.
- Upstream method manual: [MacroEconometricModels.jl](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/...)
- CLI options & tables: [Generated Reference](@ref ref-...)
```

---

## 2. Integrity Rules (Zero Drift)

1. **Zero hand-copied option tables:** Narrative pages (`index.md`, `getting-started/`, `chapters/`, `agent_guide.md`) must never hand-maintain `| Option |`, `| Flag |`, or `| Argument |` markdown tables. Always link to `@ref ref-<leaf-slug>` in `docs/src/commands/generated/`. Config schema key tables live exclusively in `docs/src/config/*.md`.
2. **Never hand-type command outputs:** Every shown command output must come from a `<!-- capture -->` fence verified by `docs/capture_examples.jl --check`. Quote only numbers visible in the captured block immediately above.
3. **Human-first tables in domain chapters; JSON in pipelines & agent guide:** Domain chapters default to `--format table` (`text` fence) and state the stable JSON `data` keys in prose. Full `--format json` envelopes belong in `getting-started/pipelines.md` and `src/commands/agent_guide.md`.
4. **H1–H3 hierarchy only:** One `#` H1 per page (at line 1 of hand-written files), H2 (`##`) separated by `---` horizontal rules, and H3 (`###`) for subsections. Never skip directly from `#` to `###`, and never use `####` or deeper.
5. **Dual-role `agent_guide.md` constraint:** `src/commands/agent_guide.md` is embedded at precompile time for `friedman schema --docs` and copied to `docs/src/agent-guide.md` by `docs/make.jl`. Keep it raw Markdown (no Documenter `@id` or `@ref` directives) and preserve the `# Agent Guide` heading.
6. **No hardcoded counts or stale version literals:** Never hardcode total leaf/command counts outside generated overview blocks or hardcode pinned MEMs versions in prose (point to `Project.toml`).
7. **Bidirectional links:** Every domain chapter links to its generated `@ref ref-*` pages and upstream `MacroEconometricModels.jl` manual page; every generated verb/family section links back to its owning domain chapter `@ref chap-*`.
8. **No shipped placeholders:** No `TODO`, `FIXME`, or "not yet implemented" notes outside code fences.

---

## 3. Writing Voice & Style

- Present tense, active voice, direct econometrics textbook register ("OLS estimates...", "The solver linearizes..."). Define domain terms in **bold** on first use.
- Keep chapters crisp (~250–900 lines). Scale equation detail strictly to what the user needs to choose options and interpret output.
- Explain configuration files cleanly with concise inline TOML/model-card examples when needed and link to `docs/src/config/*.md` for full key definitions.

---

## 4. Verification Protocol

Every documentation or command-surface change must pass:

```bash
julia --project docs/generate_cli_reference.jl --check
julia --project docs/lint_docs.jl
julia --project docs/capture_examples.jl --check
julia --project=docs docs/make.jl   # strict build, zero warnonly
```
