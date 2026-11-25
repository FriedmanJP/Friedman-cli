# [DSGE Specs, Priors & OccBin Constraints](@id cfg-dsge)

Reference schema for representative-agent `@dsge` `.jl` and `.toml` model files, Bayesian estimation priors (`priors:` / `--prior` / `[priors.*]`), Blanchard-Kahn / Sims determinacy maps (`[determinacy]`), and OccBin / perfect-foresight constraints (`constraints:` / `--constraint` / `[[constraints.*]]`). See [Representative-Agent & Bayesian DSGE](@ref chap-dsge) for end-to-end estimation and solver workflows.

---

## Model Specification (`.jl` vs `.toml`)

A DSGE model is written either inside an `@dsge begin ... end` `.jl` file (with optional indented card stanzas placed strictly **above** `@dsge`) or in a standalone `.toml` file:

```julia
@dsge begin
    parameters: alpha = 0.36, beta = 0.99, delta = 0.025, sigma = 1.0, phi_n = 1.0
    endogenous: y, c, k, n
    exogenous: eps_a

    c[t]^(-sigma) = beta * c[t+1]^(-sigma) * (alpha * k[t]^(alpha-1) * n[t+1]^(1-alpha) + 1 - delta)
    k[t] = (1-delta) * k[t-1] + y[t] - c[t]
    y[t] = exp(eps_a[t]) * k[t-1]^alpha * n[t]^(1-alpha)
    phi_n * n[t]^phi_n = c[t]^(-sigma) * (1-alpha) * exp(eps_a[t]) * k[t-1]^alpha * n[t]^(-alpha)
end
```

### TOML Model Schema

```toml
[model]
endogenous = ["y", "c", "k", "n"]
exogenous = ["eps_a"]
# linear = true            # optional pre-linearized model
# utility = "log(c[t])"    # optional Bellman VFI felicity
# beta = "0.99"            # optional VFI discount expression
# controls = ["c"]         # optional VFI control variables

[model.parameters]
alpha = 0.36
beta = 0.99
delta = 0.025
sigma = 1.0
phi_n = 1.0

[[model.equations]]
expr = "c[t]^(-sigma) = beta * c[t+1]^(-sigma) * (alpha * k[t]^(alpha-1) * n[t+1]^(1-alpha) + 1 - delta)"
```

| Section | Description |
|---|---|
| `[model]` | `endogenous` and `exogenous` arrays; optional `linear`, `utility`, `beta`, `controls` |
| `[model.parameters]` | Parameter values matching symbols referenced in equations |
| `[[model.equations]]` | Array of equation tables, each carrying an `expr` string (one per endogenous variable) |

### Syntax Rules & Restrictions

- Equations must use explicit `[t]`, `[t-1]`, or `[t+1]` timing (`x[t+1]` denotes `E_t x_{t+1}`). Bare variables, `x(+1)`/`x(-1)`, and `E[t](expr)` fail with `config/invalid`.
- Exogenous shocks may only appear at `[t]` (`exp(eps_a[t+1])` fails with `config/invalid`).
- A `priors:` stanza and a `constraints:` stanza cannot appear in the same file preamble: `dsge bayes` commands accept priors and reject `constraints:`, while constraint-aware commands (`solve`, `irf`, `steady-state`, `perfect-foresight`) accept constraints and reject `priors:`.
- An optional `[solver]` TOML section is parsed for backward compatibility without error; select solvers using `--method`, `--order`, `--degree`, and `--grid` CLI options.

---

## Bayesian DSGE Priors (`priors:`, `--prior`, `[priors.*]`)

Used by [`dsge bayes`](@ref ref-fam-dsge-ra) estimation leaves ([Representative-Agent & Bayesian DSGE](@ref chap-dsge)). Accepted distributions (each taking two shape/moment arguments): `beta`, `normal` (alias `gaussian`), `inv_gamma` (`inverse_gamma`, `invgamma`), `gamma`, and `uniform`.

```text
priors:
  rho ~ beta(2, 2)
  sigma ~ inv_gamma(2, 0.5)
```

Equivalent command-line or TOML forms (naming the same parameter in more than one source is a `config/invalid` error):

```toml
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0

[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.5
```

| Key | Where | Description |
|---|---|---|
| `dist` | `[priors.<name>]` | Distribution family (`beta`, `normal`/`gaussian`, `inv_gamma`, `gamma`, `uniform`; required) |
| `a` | `[priors.<name>]` | First distribution argument (default `0.0`) |
| `b` | `[priors.<name>]` | Second distribution argument (default `1.0`) |

---

## Determinacy Map (`[determinacy]`)

Used by [`dsge determinacy-map`](@ref ref-dsge-determinacy-map) to classify Blanchard-Kahn / Sims existence and uniqueness over 1D or 2D parameter grids:

```toml
[determinacy]
params = ["phi_pi", "phi_y"]  # 1 or 2 distinct parameter names
lower = [0.0, 0.0]            # grid starts
upper = [3.0, 1.0]            # grid ends
points = [61, 41]             # resolution (>= 2 each; or scalar)
method = "gensys"             # gensys | klein | blanchard-kahn
div = 1.00000001              # eigenvalue modulus split (default 1.0 + 1e-8)
```

Provide `grids = [[...], [...]]` (or a single flat list for one parameter, `>= 2` elements) in place of `lower`/`upper`/`points` for explicit custom grids.

---

## OccBin & Perfect-Foresight Constraints (`constraints:`, `--constraint`, `[[constraints.*]]`)

Used by [`dsge solve`](@ref ref-dsge-solve), [`dsge irf`](@ref ref-dsge-irf), [`dsge steady-state`](@ref ref-dsge-steady-state), and [`dsge perfect-foresight`](@ref ref-dsge-perfect-foresight) (select backend via `--constraint-solver madnlp|nonlinearsolve|optim|nlopt|ipopt|path`; `madnlp` is the built-in GPL-3.0-compatible default, while `ipopt` and `path` remain optional source-only weak dependencies).

```text
constraints:
  i_rate[t] >= 0.0
  investment[t] <= 100.0
```

- Card lines and `--constraint` accept `var[t] >= expr` or `var[t] <= expr` with plain numeric right-hand-side expressions.
- Two-sided bounds `lo <= var[t] <= hi` are valid only on `dsge perfect-foresight` and `dsge steady-state`; `dsge solve` and `dsge irf` accept at most one bound per constrained variable because each OccBin constraint swaps an equation for an alternate regime.
- Note that an `@dsge constraint:` block written *inside* `@dsge begin ... end` declares the model's binding regime equation internally rather than supplying OccBin constraints.

### TOML Constraint Schema

TOML constraint files (`--constraints <file.toml>`) also support `[[constraints.nonlinear]]`, which has no card equivalent:

```toml
[constraints]

[[constraints.bounds]]
variable = "i_rate"
lower = 0.0

[[constraints.nonlinear]]
expr = "i_rate[t] - 0.5 * y[t]"
label = "taylor-gap"
```

| Key | Where | Description |
|---|---|---|
| `variable` | `[[constraints.bounds]]` | Constrained variable name (required) |
| `lower`, `upper` | `[[constraints.bounds]]` | Numeric lower/upper bounds |
| `expr` | `[[constraints.nonlinear]]` | Nonlinear inequality/path expression (required) |
| `label` | `[[constraints.nonlinear]]` | Optional constraint identifier |
