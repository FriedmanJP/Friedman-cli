# [Model Cards & Config Grammar](@id cfg-overview)

`Friedman-cli` accepts complex model specifications in two formats that lower cleanly to the same internal settings: **model cards** (plain-text files with named stanzas) and **TOML** files. Use this page for format detection, stanza rules, override precedence (`--config`, `--config-json`, `--set`), and `--strict` validation, then consult the domain schema pages below for per-key definitions.

## Companion Schema Pages

| Guide | Schema Coverage | Primary Chapters |
|---|---|---|
| [Priors, SVAR & VECM Identification](@ref cfg-identification) | Minnesota prior, Sign/Narrative/Arias/Uhlig/ADRR/A0/elasticity/magnitude/cumulative/Lewis TVV/SV-SVAR, `[svar]`, `[svec]`, `[svar_hypothesis]`, `[nongaussian]`, `[vecm_restriction]` | [VAR, BVAR, VECM & Factor Models](@ref chap-multivariate), [Structural ID, LP & Innovation Accounting](@ref chap-structural), [Hypothesis Testing & Diagnostics](@ref chap-tests) |
| [DSGE Specs, Priors & OccBin Constraints](@ref cfg-dsge) | `@dsge` `.jl` preamble vs TOML model files, `priors:` / `[priors.*]`, `[determinacy]`, `constraints:` / `[[constraints.*]]` (`madnlp` default) | [Representative-Agent & Bayesian DSGE](@ref chap-dsge) |
| [GMM, SMM, Systems, State-Space & Policy](@ref cfg-models-policy) | `gmm lp:`/`gmm iv:`/`[gmm]`, `smm:`/`[smm]`, `equations:`/`instruments:`, `[statespace]` (incl. `G`), `[garch_midas]`, `[rule]`/`[loss]`/`[[constraint]]`, `[ri]`/`[ri.mw]`/`[ri.discrete]`/`[ri.logit]` | [Regression, Systems & GMM/SMM](@ref chap-regression), [Univariate, Filters & Spectral](@ref chap-univariate), [Volatility & Multivariate GARCH](@ref chap-volatility), [Policy Counterfactuals & Optimal Policy](@ref chap-policy), [Rational Inattention](@ref chap-ri) |

---

## Model Cards vs TOML Files

- A **model card** is plain text organized into named stanzas. Any file extension other than `.toml` (including files with no extension) is parsed as a model card.
  - For `gmm lp:`, `gmm iv:`, `smm:`, `equations:`, and `instruments:`, pass the file with `--config <path>` on `estimate regression gmm`, `estimate regression smm`, `estimate regression sur`, or `estimate regression 3sls`—the four estimation leaves supporting card configs via `--config`.
  - For `priors:` and `constraints:`, place the stanza in the preamble above an `@dsge begin ... end` block inside a `.jl` model file, or pass repeatable `--prior` / `--constraint` flags on the command line (no `dsge` command accepts `--config`).
- A **TOML file** is valid for all configuration sections below and supports runtime overrides via `--config-json` and `--set`.

### File Extension & Format Enforcement

- **`.toml` is always TOML:** A card misnamed `config.toml` fails with exit `4` (`config/malformed-toml`) pointing to the stanza line where TOML parsing failed.
- **TOML under a non-`.toml` filename:** Fails with a typed error naming the format detected so errors are never silently ignored.
- **Overrides belong to TOML:** `--set` and `--config-json` merge into TOML configurations; passing them alongside a model card is refused with an actionable hint rather than silently ignored.

---

## The Seven Stanza Headers

Exactly seven card stanza headers exist. Any other bare `word:` header at column 0 fails with exit `4` (`config/invalid`) naming the line:

| Stanza | Family | Used By |
|---|---|---|
| `priors:` | Bayesian DSGE priors | [`dsge bayes`](@ref ref-dsge) leaves |
| `constraints:` | OccBin regime bounds | [`dsge solve`](@ref ref-dsge-solve), [`dsge irf`](@ref ref-dsge-irf), [`dsge steady-state`](@ref ref-dsge-steady-state), [`dsge perfect-foresight`](@ref ref-dsge-perfect-foresight) |
| `gmm lp:` | Horizon-0 LP-GMM | [`estimate regression gmm`](@ref ref-estimate-regression-gmm) |
| `gmm iv:` | Linear instrumental-variables GMM | [`estimate regression gmm`](@ref ref-estimate-regression-gmm) |
| `smm:` | Simulated method of moments | [`estimate regression smm`](@ref ref-estimate-regression-smm) |
| `equations:` | Simultaneous system equations | [`estimate regression sur`](@ref ref-estimate-regression-sur), [`estimate regression 3sls`](@ref ref-estimate-regression-3sls) |
| `instruments:` | Shared 3SLS instrument set | [`estimate regression 3sls`](@ref ref-estimate-regression-3sls) |

### Card Syntax Rules

- Body lines inside a stanza must be **indented** (spaces or tabs); the stanza ends at the next non-blank line starting at column 0.
- `#` introduces a line comment through end-of-line.
- Numeric entries are plain decimal literals; card files are parsed strictly as data and never executed as code.
- **Empty stanzas are refused** with `config/invalid`.
- `gmm lp:` and `gmm iv:` are **mutually exclusive alternatives**: putting both in one card triggers `config/invalid` naming both headers.
- `--prior 'name ~ dist(a, b)'` and `--constraint 'var[t] >= expr'` are **repeatable** flags forming one combined set with any preamble stanza or TOML table; naming the same parameter or same variable-and-side in two places triggers `config/invalid` naming both sources.

---

## TOML Override Precedence & `--strict`

For commands taking TOML configuration, layers merge strictly left-to-right:

```text
--config <file.toml>  <  --config-json <json-object>  <  --set <dotted.key=value> (repeatable)
```

Every TOML key is validated by the typed parser; unrecognized keys emit a warning by default, or terminate execution with **exit code `4`** (`config/invalid`) when `--strict` is set. Passing `--output` / `--format csv` writes one file per declared output table; see [Pipelines, Handles & Reproducibility](@ref gs-pipelines) for table naming and the [Agent Guide](../agent-guide.md) for JSON error envelopes.
