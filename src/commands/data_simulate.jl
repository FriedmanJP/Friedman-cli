# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# `data simulate` (#177): truth-returning DGPs plus DSGE paths from MEMs `simulate`.
#
# Envelope (every leaf, three singleton tables):
#   simulated_data       — observables an estimator would read (index + columns)
#   population_truth     — population parameters, matrices flattened
#                          (parameter, row, col, value); row=col=0 is a scalar.
#                          Conditional variance `h` is included for garch/sv
#                          (the latent the estimator recovers). Structural
#                          shocks are not; `seed` reproduces them.
#   simulation_settings  — model, effective seed, and the kind/dist string
# Upstream simulators take a positional rng, so the handler builds `Xoshiro`.
# DSGE / HA / OLG / CT have no `dgp_*`; they are solved and then `simulate`d.

const _SIM_TABLES = [
    TableSpec(name=:simulated_data,
              description="Simulated observables with an index column (time, obs, or id/time)"),
    TableSpec(name=:population_truth,
              description="Population parameters flattened to parameter, row, col, value (row=col=0 is a scalar)"),
    TableSpec(name=:simulation_settings,
              description="Simulator name, effective seed, and kind or distribution"),
]

const _SVAR_DISTS = ["gauss", "t", "laplace", "mixture", "skew"]
const _HET_KINDS = ["markov", "garch", "smooth", "external"]
const _GARCH_KINDS = ["arch", "garch", "egarch", "gjr", "aparch", "igarch",
                      "cgarch", "figarch", "fiegarch"]
const _REGIME_KINDS = ["ms", "setar", "lstar", "estr"]
const _XSEC_KINDS = ["ols", "hc", "cluster", "iv", "logit", "probit", "ordered",
                     "mlogit", "poisson", "nb", "tobit", "truncreg", "heckman",
                     "qreg", "rdd"]
const _PANEL_KINDS = ["linear", "logit", "probit"]
const _GMM_KINDS = ["ols", "iv"]

_opt_seed() = OptionSpec(name="seed", type=Int, default=0,
    description="RNG seed (0 defers to the global --seed, else Xoshiro(0))")
_opt_periods(default::Int) = OptionSpec(name="periods", type=Int, default=default,
    description="Sample length after burn-in")
_opt_burn(default::Int) = OptionSpec(name="burn", type=Int, default=default,
    description="Burn-in draws dropped from the sample")

function _sim_spec(leaf::String, summary::String, handler::Function;
                   args::Vector{ArgSpec}=ArgSpec[],
                   options::Vector{OptionSpec}=OptionSpec[],
                   flags::Vector{FlagSpec}=FlagSpec[])
    return CommandSpec(
        path=["data", "simulate", leaf],
        summary=summary,
        args=args,
        options=vcat(options, OUTPUT_OPTIONS),
        flags=flags,
        tables=_SIM_TABLES,
        category="data",
        handler=wrap_legacy(handler),
    )
end

function data_simulate_specs()::Vector{CommandSpec}
    return [
        _sim_spec("var", "Reference stationary VAR(1) with population A, B0, Sigma",
                  _data_simulate_var;
                  options=[_opt_periods(200), _opt_burn(50), _opt_seed()]),
        _sim_spec("svar", "Non-Gaussian SVAR (independent structural shocks)",
                  _data_simulate_svar;
                  options=[
                      OptionSpec(name="dist", type=String, default="t",
                                 description="gauss|t|laplace|mixture|skew",
                                 choices=_SVAR_DISTS),
                      OptionSpec(name="nu", type=Float64, default=5.0,
                                 description="Student-t degrees of freedom (--dist t; must be > 2)"),
                      _opt_periods(200), _opt_burn(50), _opt_seed()]),
        _sim_spec("heteroskedastic-var", "Heteroskedastic SVAR (Markov, GARCH, smooth, or break)",
                  _data_simulate_hetvar;
                  options=[
                      OptionSpec(name="kind", type=String, default="markov",
                                 description="markov|garch|smooth|external",
                                 choices=_HET_KINDS),
                      _opt_periods(200), _opt_burn(50), _opt_seed()]),
        _sim_spec("arima", "Gaussian ARIMA (optional seasonal AR/MA left at zero)",
                  _data_simulate_arima;
                  options=[
                      OptionSpec(name="phi", type=String, default="0.5",
                                 description="AR coefficients, comma-separated"),
                      OptionSpec(name="theta", type=String, default="",
                                 description="MA coefficients, comma-separated"),
                      OptionSpec(name="diff", type=Int, default=0,
                                 description="Integration order d"),
                      OptionSpec(name="sigma", type=Float64, default=1.0,
                                 description="Innovation standard deviation"),
                      OptionSpec(name="drift", type=Float64, default=0.0,
                                 description="Intercept in the stationary representation"),
                      _opt_periods(200), _opt_burn(50), _opt_seed()]),
        _sim_spec("garch", "GARCH-family returns with the conditional-variance path in the truth table",
                  _data_simulate_garch;
                  options=[
                      OptionSpec(name="kind", type=String, default="garch",
                                 description="arch|garch|egarch|gjr|aparch|igarch|cgarch|figarch|fiegarch",
                                 choices=_GARCH_KINDS),
                      _opt_periods(300), _opt_burn(50), _opt_seed()]),
        _sim_spec("sv", "Stochastic volatility (Gaussian, no leverage by default)",
                  _data_simulate_sv;
                  options=[
                      OptionSpec(name="mu", type=Float64, default=-0.5,
                                 description="Unconditional mean of log variance"),
                      OptionSpec(name="phi", type=Float64, default=0.95,
                                 description="AR(1) persistence of log variance"),
                      OptionSpec(name="sigma-eta", type=Float64, default=0.2,
                                 description="Volatility-of-volatility"),
                      _opt_periods(200), _opt_burn(50), _opt_seed()]),
        _sim_spec("vecm", "Rank-1 VECM with population alpha, beta, Gamma, Sigma",
                  _data_simulate_vecm;
                  options=[_opt_periods(200), _opt_burn(50), _opt_seed()]),
        _sim_spec("cointreg", "Cointegrating regression with endogenous regressors",
                  _data_simulate_cointreg;
                  options=[
                      OptionSpec(name="endog-rho", type=Float64, default=0.7,
                                 description="Correlation of the equilibrium error with Δx"),
                      OptionSpec(name="sigma-u", type=Float64, default=1.0,
                                 description="Equilibrium-error scale"),
                      _opt_periods(200), _opt_seed()],
                  flags=[FlagSpec(name="spurious",
                                  description="Independent random walks (no cointegration)")]),
        _sim_spec("ardl", "ARDL(1,1) with the long-run multiplier theta",
                  _data_simulate_ardl;
                  options=[
                      OptionSpec(name="phi", type=Float64, default=0.6,
                                 description="Lagged dependent-variable coefficient"),
                      OptionSpec(name="beta0", type=Float64, default=0.8,
                                 description="Contemporaneous regressor coefficient"),
                      OptionSpec(name="beta1", type=Float64, default=0.4,
                                 description="Lagged regressor coefficient"),
                      _opt_periods(200), _opt_burn(50), _opt_seed()]),
        _sim_spec("factors", "Dynamic factor model (VAR factors, random loadings)",
                  _data_simulate_factors;
                  options=[
                      OptionSpec(name="series", type=Int, default=12,
                                 description="Number of observed series N"),
                      _opt_periods(80), _opt_burn(20), _opt_seed()]),
        _sim_spec("lp-iv", "Local-projection IV (instrument z, endogenous s, outcome y)",
                  _data_simulate_lpiv;
                  options=[
                      OptionSpec(name="pi1", type=Float64, default=1.5,
                                 description="First-stage coefficient on the instrument"),
                      OptionSpec(name="theta", type=Float64, default=1.0,
                                 description="Impact response of y to s"),
                      _opt_periods(200), _opt_seed()]),
        _sim_spec("panel", "Linear or binary panel with optional correlated effects",
                  _data_simulate_panel;
                  options=[
                      OptionSpec(name="kind", type=String, default="linear",
                                 description="linear|logit|probit",
                                 choices=_PANEL_KINDS),
                      OptionSpec(name="n", type=Int, default=30,
                                 description="Cross-sectional units"),
                      _opt_periods(12), _opt_seed()]),
        _sim_spec("pvar", "Panel VAR(1) with random effects",
                  _data_simulate_pvar;
                  options=[
                      OptionSpec(name="n", type=Int, default=15,
                                 description="Cross-sectional units"),
                      _opt_periods(20), _opt_seed()]),
        _sim_spec("did", "Staggered adoption with the realized ATT",
                  _data_simulate_did;
                  options=[
                      OptionSpec(name="n", type=Int, default=80,
                                 description="Units"),
                      _opt_periods(20), _opt_seed()]),
        _sim_spec("gmm", "Heteroskedastic OLS or IV moments",
                  _data_simulate_gmm;
                  options=[
                      OptionSpec(name="kind", type=String, default="iv",
                                 description="ols|iv", choices=_GMM_KINDS),
                      OptionSpec(name="n", type=Int, default=200,
                                 description="Observations"),
                      OptionSpec(name="pi1", type=Float64, default=1.0,
                                 description="First-stage strength (--kind iv)"),
                      _opt_seed()]),
        _sim_spec("regime", "Markov-switching, SETAR, LSTAR, or ESTAR",
                  _data_simulate_regime;
                  options=[
                      OptionSpec(name="kind", type=String, default="ms",
                                 description="ms|setar|lstar|estr",
                                 choices=_REGIME_KINDS),
                      _opt_periods(200), _opt_burn(40), _opt_seed()]),
        _sim_spec("cross-section", "Cross-section DGP (OLS through RDD)",
                  _data_simulate_xsec;
                  options=[
                      OptionSpec(name="kind", type=String, default="ols",
                                 description="ols|hc|cluster|iv|logit|probit|ordered|mlogit|poisson|nb|tobit|truncreg|heckman|qreg|rdd",
                                 choices=_XSEC_KINDS),
                      OptionSpec(name="n", type=Int, default=200,
                                 description="Observations"),
                      _opt_seed()]),
        _sim_spec("dsge", "Representative-agent DSGE path from solve + simulate",
                  _data_simulate_dsge;
                  args=[ArgSpec(name="model", type=String, required=true,
                                description=".jl or .toml DSGE spec")],
                  options=[
                      OptionSpec(name="method", type=String, default="gensys",
                                 description="gensys|klein|blanchard-kahn|perturbation|projection|pfi|vfi",
                                 choices=collect(_RA_METHOD_CHOICES)),
                      OptionSpec(name="order", type=Int, default=1,
                                 description="Perturbation order (1–3; only with --method perturbation)"),
                      OptionSpec(name="meas-sd", type=String, default="",
                                 description="Measurement-error standard deviations (one value or one per variable)"),
                      _opt_periods(80), _opt_burn(20), _opt_seed()]),
        _sim_spec("ha", "Heterogeneous-agent aggregate path from solve + simulate",
                  _data_simulate_ha;
                  args=[ArgSpec(name="model", type=String, required=true,
                                description="HA builtin (huggett, krusell-smith, …) or .jl ModelSpec")],
                  options=[
                      OptionSpec(name="method", type=String, default="reiter",
                                 description="ssj|reiter (krusell-smith has no aggregate simulate)",
                                 choices=["ssj", "reiter", "krusell-smith"]),
                      OptionSpec(name="n-reduced", type=Int, default=10,
                                 description="Reduced states for the linear solution"),
                      OptionSpec(name="distribution", type=String, default="young",
                                 description="young|winberry",
                                 choices=["young", "winberry"]),
                      OptionSpec(name="hh-solver", type=String, default="egm",
                                 description="egm|vfi", choices=["egm", "vfi"]),
                      _opt_periods(20), _opt_seed()]),
        _sim_spec("olg", "Blanchard OLG saddle path (deterministic)",
                  _data_simulate_olg;
                  options=[
                      OptionSpec(name="alpha", type=Float64, default=0.36, description="Capital share"),
                      OptionSpec(name="beta", type=Float64, default=0.96, description="Discount factor"),
                      OptionSpec(name="delta", type=Float64, default=0.08, description="Depreciation"),
                      OptionSpec(name="gamma", type=Float64, default=0.98, description="Survival probability"),
                      OptionSpec(name="z", type=Float64, default=1.0, description="TFP"),
                      OptionSpec(name="debt", type=Float64, default=0.0, description="Government debt b"),
                      OptionSpec(name="k0", type=Float64, default=0.0,
                                 description="Initial capital (0 = 0.8 × steady state)"),
                      _opt_periods(40), _opt_seed()]),
        _sim_spec("ct", "Continuous-time Aiyagari MIT transition",
                  _data_simulate_ct;
                  options=[
                      OptionSpec(name="alpha", type=Float64, default=0.36, description="Capital share"),
                      OptionSpec(name="rho", type=Float64, default=0.05, description="Discount rate"),
                      OptionSpec(name="sigma", type=Float64, default=2.0, description="CRRA"),
                      OptionSpec(name="delta", type=Float64, default=0.05, description="Depreciation"),
                      OptionSpec(name="z", type=Float64, default=1.0, description="Steady-state TFP"),
                      OptionSpec(name="shock-size", type=Float64, default=0.95,
                                 description="Impact TFP as a fraction of steady-state Z"),
                      OptionSpec(name="grid-size", type=Int, default=40, description="Asset grid points"),
                      OptionSpec(name="a-max", type=Float64, default=30.0, description="Asset-grid upper bound"),
                      OptionSpec(name="max-iter", type=Int, default=80, description="Steady-state / transition iterations"),
                      OptionSpec(name="tol", type=Float64, default=1e-5, description="Convergence tolerance"),
                      OptionSpec(name="dt", type=Float64, default=0.25, description="Transition step"),
                      _opt_periods(12), _opt_seed()]),
    ]
end

# ── Shared emit ──────────────────────────────────────────────

function _one_of(flag::String, value::String, choices)
    value in choices || throw(CliError("usage/invalid",
        "invalid --$flag '$value'; must be $(join(choices, '|'))"))
    return value
end

function _sim_ge(name::String, v::Real, lo::Real)
    v >= lo || throw(CliError("usage/invalid", "--$name must be >= $lo (got $v)"))
    return v
end

function _sim_pos(name::String, v::Real)
    v > 0 || throw(CliError("usage/invalid", "--$name must be > 0 (got $v)"))
    return v
end

function _sim_open_unit(name::String, v::Real)
    abs(v) < 1 || throw(CliError("usage/invalid",
        "--$name must lie in (-1, 1) (got $v)"))
    return v
end

"""Effective seed and the `Xoshiro` the simulator actually draws from.

Leaf `--seed 0` defers to the global `--seed`. With neither set, the draw is
`Xoshiro(0)` so an unseeded call is still reproducible.
"""
function _sim_rng(seed::Int)
    seed >= 0 || throw(CliError("usage/invalid", "--seed must be >= 0 (got $seed)"))
    eff = seed > 0 ? seed : (_SEED[] === nothing ? 0 : Int(_SEED[]))
    return eff, Random.Xoshiro(eff)
end

function _sim_len(periods::Int, burn::Int)
    _sim_ge("periods", periods, 1)
    _sim_ge("burn", burn, 0)
    return periods, burn
end

function _parse_floats(s::String, opt::String)
    isempty(strip(s)) && return Float64[]
    out = Float64[]
    for part in split(s, ",")
        v = tryparse(Float64, strip(part))
        v === nothing && throw(CliError("usage/invalid",
            "bad --$opt value '$(strip(part))' (expected comma-separated numbers)"))
        push!(out, v)
    end
    return out
end

function _dgp(f, rng, args...; kwargs...)
    try
        return f(rng, args...; kwargs...)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "data simulate"))
    end
end

function _truth_push!(rows, name::AbstractString, x)
    if x isa Real
        push!(rows, (parameter=String(name), row=0, col=0, value=Float64(x)))
    elseif x isa AbstractMatrix{<:Real}
        nr, nc = size(x)
        for j in 1:nc, i in 1:nr
            push!(rows, (parameter=String(name), row=i, col=j, value=Float64(x[i, j])))
        end
    elseif x isa AbstractVector && !isempty(x) && first(x) isa AbstractMatrix
        for (k, M) in enumerate(x)
            _truth_push!(rows, string(name, "_", k), M)
        end
    elseif x isa AbstractVector && (isempty(x) || eltype(x) <: Real ||
                                    all(v -> v isa Real, x))
        for (i, v) in enumerate(x)
            push!(rows, (parameter=String(name), row=i, col=0, value=Float64(v)))
        end
    elseif x isa Tuple && all(v -> v isa Real, x)
        for (i, v) in enumerate(x)
            push!(rows, (parameter=String(name), row=i, col=0, value=Float64(v)))
        end
    end
    return rows
end

function _truth_push_dict!(rows, prefix::AbstractString, d)
    d isa AbstractDict || return rows
    for k in sort!(collect(keys(d)); by=string)
        k === nothing && continue
        v = d[k]
        # An empty post-treatment window is `mean([]) == NaN`. JSON has no
        # NaN, so the envelope would stringify it and break numeric readers.
        v isa Real && !isfinite(Float64(v)) && continue
        _truth_push!(rows, string(prefix, string(k)), v)
    end
    return rows
end

"""Adoption dates that are treated inside `1:periods`.

`dgp_staggered_did` defaults to cohorts `[6, 11, 16]`. A date past the sample
has no treated observation (`t = g` is not in `1:T`), and the cohort ATT is
`NaN`. Keep the upstream dates that fit; a shorter panel gets one date that
still falls inside it.
"""
function _did_cohorts(periods::Int)
    canon = (6, 11, 16)
    fit = Int[g for g in canon if 1 <= g <= periods]
    isempty(fit) || return fit
    return Int[clamp(cld(periods, 2), 1, periods)]
end

_truth_rows() = NamedTuple{(:parameter, :row, :col, :value),Tuple{String,Int,Int,Float64}}[]

function _ynames(n::Int)
    return ["y$i" for i in 1:n]
end

function _indexed_sample(M::AbstractMatrix; names::Vector{String}, id=nothing, time=nothing)
    size(M, 2) == length(names) || throw(CliError("internal/error",
        "simulated sample has $(size(M, 2)) columns but $(length(names)) names"))
    df = DataFrame(Matrix{Float64}(M), names)
    tcol = time === nothing ? collect(1:size(M, 1)) : collect(Int, time)
    insertcols!(df, 1, :time => tcol)
    if id !== nothing
        insertcols!(df, 1, :id => collect(Int, id))
    end
    return df
end

function _series_sample(y::AbstractVector; name::String="y")
    return _indexed_sample(reshape(collect(Float64, y), :, 1); names=[name])
end

function _obs_col(v)
    if v isa BitVector || eltype(v) <: Bool
        return Float64.(v)
    elseif eltype(v) <: Integer
        return collect(Int, v)
    else
        return collect(Float64, v)
    end
end

function _settings(model::String, seed::Int; extra...)
    rows = Pair{String,String}["model" => model, "seed" => string(seed)]
    for (k, v) in pairs(extra)
        push!(rows, string(k) => string(v))
    end
    return rows
end

function _finish_sim(sample::DataFrame, truth, settings; format::String, output::String)
    isempty(truth) && throw(CliError("internal/error", "population truth is empty"))
    isempty(sample) && throw(CliError("internal/error", "simulated sample is empty"))
    output_result(sample; format=Symbol(format), output=output,
                  title="Simulated Data", key="simulated_data")
    output_result(DataFrame(truth); format=Symbol(format),
                  output=_per_var_output_path(output, "truth"),
                  title="Population Truth", key="population_truth")
    output_kv(settings; format=format,
              output=_per_var_output_path(output, "settings"),
              title="Simulation Settings", key="simulation_settings")
    return nothing
end

# ── Time-series DGPs ─────────────────────────────────────────

function _data_simulate_var(; periods::Int=200, burn::Int=50, seed::Int=0,
                            format::String="table", output::String="")
    periods, burn = _sim_len(periods, burn)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_var, rng; T=periods, burn=burn)
    rows = _truth_rows()
    _truth_push!(rows, "A", nt.A)
    _truth_push!(rows, "B0", nt.B0)
    _truth_push!(rows, "Sigma", nt.Sigma)
    _truth_push!(rows, "c", nt.c)
    sample = _indexed_sample(nt.Y; names=_ynames(size(nt.Y, 2)))
    _finish_sim(sample, rows, _settings("var", eff; periods, burn);
                format, output)
end

function _data_simulate_svar(; dist::String="t", nu::Float64=5.0,
                             periods::Int=200, burn::Int=50, seed::Int=0,
                             format::String="table", output::String="")
    _one_of("dist", dist, _SVAR_DISTS)
    dist == "t" && _sim_pos("nu-2", nu - 2)
    periods, burn = _sim_len(periods, burn)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_nongaussian_var, rng;
              dist=Symbol(dist), nu=nu, T=periods, burn=burn)
    rows = _truth_rows()
    _truth_push!(rows, "A", nt.A)
    _truth_push!(rows, "B0", nt.B0)
    _truth_push!(rows, "Sigma", nt.Sigma)
    dist == "t" && _truth_push!(rows, "nu", nu)
    sample = _indexed_sample(nt.Y; names=_ynames(size(nt.Y, 2)))
    _finish_sim(sample, rows, _settings("svar", eff; dist, periods, burn); format, output)
end

function _data_simulate_hetvar(; kind::String="markov", periods::Int=200, burn::Int=50,
                               seed::Int=0, format::String="table", output::String="")
    _one_of("kind", kind, _HET_KINDS)
    periods, burn = _sim_len(periods, burn)
    eff, rng = _sim_rng(seed)
    P = [0.95 0.05; 0.05 0.95]
    nt = _dgp(MacroEconometricModels.dgp_heteroskedastic_var, rng;
              kind=Symbol(kind), T=periods, burn=burn, P=P)
    rows = _truth_rows()
    _truth_push!(rows, "B0", nt.B0)
    _truth_push!(rows, "Sigma", nt.Sigma_full)
    _truth_push!(rows, "Lambda", nt.Lambda)
    kind == "markov" && _truth_push!(rows, "P", P)
    sample = _indexed_sample(nt.Y; names=_ynames(size(nt.Y, 2)))
    _finish_sim(sample, rows, _settings("heteroskedastic-var", eff; kind, periods, burn);
                format, output)
end

function _data_simulate_arima(; phi::String="0.5", theta::String="", diff::Int=0,
                              sigma::Float64=1.0, drift::Float64=0.0,
                              periods::Int=200, burn::Int=50, seed::Int=0,
                              format::String="table", output::String="")
    ph = _parse_floats(phi, "phi")
    th = _parse_floats(theta, "theta")
    _sim_ge("diff", diff, 0)
    _sim_pos("sigma", sigma)
    periods, burn = _sim_len(periods, burn)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_arima, rng; phi=ph, theta=th, d=diff,
              sigma=sigma, c=drift, T=periods, burn=burn)
    rows = _truth_rows()
    _truth_push!(rows, "phi", nt.phi)
    _truth_push!(rows, "theta", nt.theta)
    _truth_push!(rows, "d", nt.d)
    _truth_push!(rows, "sigma", nt.sigma)
    _truth_push!(rows, "c", nt.c)
    _finish_sim(_series_sample(nt.y), rows,
                _settings("arima", eff; periods, burn); format, output)
end

function _data_simulate_garch(; kind::String="garch", periods::Int=300, burn::Int=50,
                              seed::Int=0, format::String="table", output::String="")
    _one_of("kind", kind, _GARCH_KINDS)
    periods, burn = _sim_len(periods, burn)
    eff, rng = _sim_rng(seed)
    omega, alpha, beta = 0.02, 0.08, 0.88
    gamma, delta, dpar, theta, mu = 0.06, 1.5, 0.4, -0.05, 0.0
    nt = _dgp(MacroEconometricModels.dgp_garch_family, rng; kind=Symbol(kind),
              omega=omega, alpha=alpha, beta=beta, gamma=gamma, delta=delta,
              d=dpar, theta=theta, mu=mu, T=periods, burn=burn)
    rows = _truth_rows()
    _truth_push!(rows, "omega", omega)
    _truth_push!(rows, "alpha", alpha)
    _truth_push!(rows, "beta", kind == "arch" ? 0.0 : beta)
    _truth_push!(rows, "gamma", gamma)
    _truth_push!(rows, "mu", mu)
    kind in ("figarch", "fiegarch") && _truth_push!(rows, "d", dpar)
    kind == "fiegarch" && _truth_push!(rows, "theta", theta)
    kind == "aparch" && _truth_push!(rows, "delta", delta)
    _truth_push!(rows, "h", nt.h)
    _finish_sim(_series_sample(nt.y), rows,
                _settings("garch", eff; kind, periods, burn); format, output)
end

function _data_simulate_sv(; mu::Float64=-0.5, phi::Float64=0.95, sigma_eta::Float64=0.2,
                           periods::Int=200, burn::Int=50, seed::Int=0,
                           format::String="table", output::String="")
    _sim_open_unit("phi", phi)
    _sim_pos("sigma-eta", sigma_eta)
    periods, burn = _sim_len(periods, burn)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_sv, rng; mu=mu, phi=phi, sigma_eta=sigma_eta,
              T=periods, burn=burn)
    rows = _truth_rows()
    _truth_push!(rows, "mu", mu)
    _truth_push!(rows, "phi", phi)
    _truth_push!(rows, "sigma_eta", sigma_eta)
    _truth_push!(rows, "h", nt.h)
    _finish_sim(_series_sample(nt.y), rows,
                _settings("sv", eff; periods, burn); format, output)
end

function _data_simulate_vecm(; periods::Int=200, burn::Int=50, seed::Int=0,
                             format::String="table", output::String="")
    periods, burn = _sim_len(periods, burn)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_vecm, rng; T=periods, burn=burn)
    rows = _truth_rows()
    _truth_push!(rows, "alpha", nt.alpha)
    _truth_push!(rows, "beta", nt.beta)
    _truth_push!(rows, "Gamma", nt.Gamma)
    _truth_push!(rows, "mu", nt.mu)
    _truth_push!(rows, "Sigma", nt.Sigma)
    sample = _indexed_sample(nt.Y; names=_ynames(size(nt.Y, 2)))
    _finish_sim(sample, rows, _settings("vecm", eff; periods, burn); format, output)
end

function _data_simulate_cointreg(; endog_rho::Float64=0.7, sigma_u::Float64=1.0,
                                 spurious::Bool=false, periods::Int=200, seed::Int=0,
                                 format::String="table", output::String="")
    _sim_open_unit("endog-rho", endog_rho)
    _sim_pos("sigma-u", sigma_u)
    _sim_ge("periods", periods, 1)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_cointreg, rng; T=periods,
              endog_rho=endog_rho, sigma_u=sigma_u, spurious=spurious)
    rows = _truth_rows()
    _truth_push!(rows, "beta", nt.beta)
    _truth_push!(rows, "endog_rho", endog_rho)
    _truth_push!(rows, "sigma_u", sigma_u)
    _truth_push!(rows, "spurious", spurious ? 1.0 : 0.0)
    names = vcat(["y"], ["x$i" for i in 1:size(nt.X, 2)])
    sample = _indexed_sample(hcat(nt.y, nt.X); names=names)
    _finish_sim(sample, rows, _settings("cointreg", eff; periods, spurious); format, output)
end

function _data_simulate_ardl(; phi::Float64=0.6, beta0::Float64=0.8, beta1::Float64=0.4,
                             periods::Int=200, burn::Int=50, seed::Int=0,
                             format::String="table", output::String="")
    _sim_open_unit("phi", phi)
    periods, burn = _sim_len(periods, burn)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_ardl, rng; phi=phi, beta0=beta0, beta1=beta1,
              T=periods, burn=burn)
    rows = _truth_rows()
    _truth_push!(rows, "phi", nt.phi)
    _truth_push!(rows, "beta", nt.beta)
    _truth_push!(rows, "theta", nt.theta)
    sample = _indexed_sample(hcat(nt.y, nt.x); names=["y", "x"])
    _finish_sim(sample, rows, _settings("ardl", eff; periods, burn); format, output)
end

function _data_simulate_factors(; series::Int=12, periods::Int=80, burn::Int=20,
                                seed::Int=0, format::String="table", output::String="")
    _sim_ge("series", series, 1)
    periods, burn = _sim_len(periods, burn)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_dynamic_factors, rng;
              N=series, T=periods, burn=burn)
    rows = _truth_rows()
    _truth_push!(rows, "Lambda", nt.Lambda)
    _truth_push!(rows, "A", nt.A)
    _truth_push!(rows, "Sigma_F", nt.Sigma_F)
    _truth_push!(rows, "r", nt.r)
    _truth_push!(rows, "p", nt.p)
    _truth_push!(rows, "idio_var", nt.idio_var)
    sample = _indexed_sample(nt.X; names=["x$i" for i in 1:size(nt.X, 2)])
    _finish_sim(sample, rows, _settings("factors", eff; series, periods, burn);
                format, output)
end

function _data_simulate_lpiv(; pi1::Float64=1.5, theta::Float64=1.0, periods::Int=200,
                             seed::Int=0, format::String="table", output::String="")
    _sim_ge("periods", periods, 2)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_lp_iv, rng; T=periods, pi1=pi1, theta=theta)
    rows = _truth_rows()
    _truth_push!(rows, "pi1", nt.pi1)
    _truth_push!(rows, "theta", nt.theta)
    Z = nt.Z isa AbstractVector ? reshape(collect(Float64, nt.Z), :, 1) : Matrix{Float64}(nt.Z)
    names = vcat(["s", "y", "x2"], ["z$i" for i in 1:size(Z, 2)])
    sample = _indexed_sample(hcat(nt.Y, Z); names=names)
    _finish_sim(sample, rows, _settings("lp-iv", eff; periods); format, output)
end

# ── Panels, micro, regime ────────────────────────────────────

function _data_simulate_panel(; kind::String="linear", n::Int=30, periods::Int=12,
                              seed::Int=0, format::String="table", output::String="")
    _one_of("kind", kind, _PANEL_KINDS)
    _sim_ge("n", n, 1)
    _sim_ge("periods", periods, 1)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_panel, rng; kind=Symbol(kind), N=n, T=periods)
    rows = _truth_rows()
    _truth_push!(rows, "beta", nt.beta)
    _truth_push!(rows, "sigma_u", nt.sigma_u)
    _truth_push!(rows, "sigma_e", nt.sigma_e)
    _truth_push!(rows, "alpha", nt.alpha)
    _truth_push!(rows, "mundlak", nt.mundlak)
    _truth_push!(rows, "rho_ar", nt.rho_ar)
    _truth_push!(rows, "dynamic_rho", nt.dynamic_rho)
    _finish_sim(nt.df, rows, _settings("panel", eff; kind, n, periods); format, output)
end

function _data_simulate_pvar(; n::Int=15, periods::Int=20, seed::Int=0,
                             format::String="table", output::String="")
    _sim_ge("n", n, 1)
    _sim_ge("periods", periods, 1)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_panel_var, rng; N=n, T=periods)
    rows = _truth_rows()
    _truth_push!(rows, "A1", nt.A1)
    _truth_push!(rows, "Sigma", nt.Sigma)
    _truth_push!(rows, "mu", nt.mu)
    sample = _indexed_sample(nt.Y; names=_ynames(size(nt.Y, 2)), id=nt.id, time=nt.time)
    _finish_sim(sample, rows, _settings("pvar", eff; n, periods); format, output)
end

function _data_simulate_did(; n::Int=80, periods::Int=20, seed::Int=0,
                            format::String="table", output::String="")
    _sim_ge("n", n, 1)
    _sim_ge("periods", periods, 1)
    eff, rng = _sim_rng(seed)
    cohorts = _did_cohorts(periods)
    nt = _dgp(MacroEconometricModels.dgp_staggered_did, rng;
              N=n, T=periods, cohorts=cohorts)
    rows = _truth_rows()
    _truth_push!(rows, "overall_att", nt.overall_att)
    _truth_push_dict!(rows, "att_e:", nt.att_by_event_time)
    _truth_push_dict!(rows, "att_c:", nt.att_by_cohort)
    _finish_sim(nt.df, rows, _settings("did", eff; n, periods); format, output)
end

function _data_simulate_gmm(; kind::String="iv", n::Int=200, pi1::Float64=1.0,
                            seed::Int=0, format::String="table", output::String="")
    _one_of("kind", kind, _GMM_KINDS)
    _sim_ge("n", n, 2)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_gmm, rng; kind=Symbol(kind), n=n, pi1=pi1)
    rows = _truth_rows()
    _truth_push!(rows, "beta", nt.beta)
    _truth_push!(rows, "pi1", nt.pi1)
    y = _obs_col(nt.y)
    X = Matrix{Float64}(nt.X)
    cols = Pair{String,Any}["y" => y]
    for j in 1:size(X, 2)
        push!(cols, "x$j" => X[:, j])
    end
    if kind != "ols"
        Z = Matrix{Float64}(nt.Z)
        for j in 1:size(Z, 2)
            push!(cols, "z$j" => Z[:, j])
        end
    end
    _finish_sim(_obs_frame(cols), rows, _settings("gmm", eff; kind, n); format, output)
end

function _data_simulate_regime(; kind::String="ms", periods::Int=200, burn::Int=40,
                               seed::Int=0, format::String="table", output::String="")
    _one_of("kind", kind, _REGIME_KINDS)
    periods, burn = _sim_len(periods, burn)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_regime_switching, rng;
              kind=Symbol(kind), T=periods, burn=burn)
    rows = _truth_rows()
    if kind == "ms"
        _truth_push!(rows, "mu", nt.mu)
        _truth_push!(rows, "phi", nt.phi)
        _truth_push!(rows, "P", nt.P)
    else
        _truth_push!(rows, "phi_lo", nt.phi_lo)
        _truth_push!(rows, "phi_hi", nt.phi_hi)
        _truth_push!(rows, "c", nt.c)
        kind != "setar" && _truth_push!(rows, "gamma", nt.gamma)
    end
    _finish_sim(_series_sample(nt.y), rows,
                _settings("regime", eff; kind, periods, burn); format, output)
end

function _obs_frame(cols)
    n = length(last(first(cols)))
    df = DataFrame(obs=collect(1:n))
    for (name, v) in cols
        length(v) == n || throw(CliError("internal/error",
            "column $name has length $(length(v)); expected $n"))
        df[!, name] = v
    end
    return df
end

function _data_simulate_xsec(; kind::String="ols", n::Int=200, seed::Int=0,
                             format::String="table", output::String="")
    _one_of("kind", kind, _XSEC_KINDS)
    _sim_ge("n", n, 2)
    eff, rng = _sim_rng(seed)
    nt = _dgp(MacroEconometricModels.dgp_cross_section, rng; kind=Symbol(kind), n=n)
    rows = _truth_rows()
    _truth_push!(rows, "beta", nt.beta)
    for key in (:ame, :cutpoints, :dispersion, :censor, :select_rho, :iia_rho,
                :pi1, :rho, :cutoff, :tau)
        haskey(nt, key) && _truth_push!(rows, string(key), getfield(nt, key))
    end
    haskey(nt, :hetero) && _truth_push!(rows, "hetero", nt.hetero ? 1.0 : 0.0)
    cols = Pair{String,Any}["y" => _obs_col(nt.y)]
    X = Matrix{Float64}(nt.X)
    # truncreg drops rows of X to match y; both lengths are the kept sample.
    for j in 1:size(X, 2)
        push!(cols, "x$j" => X[:, j])
    end
    if haskey(nt, :Z)
        Z = Matrix{Float64}(nt.Z)
        for j in 1:size(Z, 2)
            push!(cols, "z$j" => Z[:, j])
        end
    end
    haskey(nt, :clust) && push!(cols, "cluster" => _obs_col(nt.clust))
    haskey(nt, :r) && push!(cols, "r" => _obs_col(nt.r))
    haskey(nt, :selected) && push!(cols, "selected" => _obs_col(nt.selected))
    _finish_sim(_obs_frame(cols), rows, _settings("cross-section", eff; kind, n);
                format, output)
end

# ── DSGE family (no dgp_*; solve then simulate) ─────────────

function _data_simulate_dsge(; model::String, method::String="gensys", order::Int=1,
                             meas_sd::String="", periods::Int=80, burn::Int=20,
                             seed::Int=0, format::String="table", output::String="")
    isempty(strip(model)) && throw(CliError("usage/missing-arg",
        "a .jl or .toml DSGE spec is required"))
    _one_of("method", method, _RA_METHOD_CHOICES)
    order in 1:3 || throw(CliError("usage/invalid",
        "--order must be 1, 2, or 3 (got $order)"))
    method != "perturbation" && order != 1 && throw(CliError("usage/invalid",
        "--order applies only to --method perturbation (got --method $method, --order $order)"))
    periods, burn = _sim_len(periods, burn)
    eff, rng = _sim_rng(seed)
    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec; method=method, order=order)
    spec_out = hasproperty(sol, :spec) ? sol.spec : spec
    raw = try
        MacroEconometricModels.simulate(sol, periods + burn; rng=rng)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "data simulate dsge"))
    end
    size(raw, 1) >= periods + burn || throw(CliError("model/error",
        "DSGE simulate returned $(size(raw, 1)) rows; expected at least $(periods + burn)"))
    Y = raw[(burn + 1):(burn + periods), :]
    names = _dsge_sim_names(spec_out, size(Y, 2))
    rows = _truth_rows()
    if hasproperty(spec_out, :param_values)
        for k in sort!(collect(keys(spec_out.param_values)); by=string)
            _truth_push!(rows, string(k), spec_out.param_values[k])
        end
    end
    ss = hasproperty(spec_out, :steady_state) ? spec_out.steady_state : Float64[]
    if ss isa AbstractVector && length(ss) >= length(names)
        idx = _dsge_name_index(spec_out, names)
        for (j, name) in enumerate(names)
            i = idx[j]
            i === nothing && continue
            _truth_push!(rows, "ss:" * name, ss[i])
        end
    end
    if !isempty(strip(meas_sd))
        sd = _parse_meas_sd(meas_sd, size(Y, 2))
        obs = _dgp(MacroEconometricModels.dgp_dsge_observed, rng, Y; H=sd .^ 2)
        Y = obs.y_obs
        _truth_push!(rows, "meas_sd", sd)
        _truth_push!(rows, "H", obs.H)
    end
    sample = _indexed_sample(Y; names=names)
    _finish_sim(sample, rows, _settings("dsge", eff; method, order, periods, burn);
                format, output)
end

function _dsge_sim_names(spec, ncols::Int)
    if hasproperty(spec, :augmented) && spec.augmented &&
       hasproperty(spec, :original_endog) && length(spec.original_endog) == ncols
        return String[string(v) for v in spec.original_endog]
    elseif hasproperty(spec, :varnames) && length(spec.varnames) == ncols
        return String[string(v) for v in spec.varnames]
    else
        return _ynames(ncols)
    end
end

function _dsge_name_index(spec, names::Vector{String})
    if hasproperty(spec, :augmented) && spec.augmented &&
       hasproperty(spec, :original_endog) && hasproperty(spec, :endog) &&
       length(spec.original_endog) == length(names)
        return Any[findfirst(==(v), spec.endog) for v in spec.original_endog]
    elseif hasproperty(spec, :varnames) && length(spec.varnames) == length(names)
        return collect(1:length(names))
    else
        return collect(1:length(names))
    end
end

function _parse_meas_sd(s::String, n::Int)
    vals = _parse_floats(s, "meas-sd")
    any(<(0), vals) && throw(CliError("usage/invalid",
        "--meas-sd values must be >= 0"))
    if length(vals) == 1
        return fill(vals[1], n)
    end
    length(vals) == n || throw(CliError("usage/invalid",
        "--meas-sd needs 1 value or $n values (got $(length(vals)))"))
    return vals
end

function _data_simulate_ha(; model::String, method::String="reiter", n_reduced::Int=10,
                           distribution::String="young", hh_solver::String="egm",
                           periods::Int=20, seed::Int=0,
                           format::String="table", output::String="")
    isempty(strip(model)) && throw(CliError("usage/missing-arg",
        "an HA builtin or .jl ModelSpec is required"))
    meth = _parse_ha_method(method)
    meth === :krusell_smith && throw(CliError("usage/invalid",
        "data simulate ha has no aggregate path for krusell-smith";
        hint="use --method ssj or reiter"))
    _sim_ge("n-reduced", n_reduced, 1)
    _sim_ge("periods", periods, 1)
    hh = _parse_hh_solver(hh_solver)
    eff, rng = _sim_rng(seed)
    spec = _load_ha_model(model; distribution=distribution)
    sol = _solve_ha(spec; method=meth, n_reduced=n_reduced, hh_solver=hh)
    sol isa MacroEconometricModels.HADSGESolution || throw(CliError("model/unsupported",
        "method=$meth did not produce a linearized HADSGESolution ($(typeof(sol)))"))
    path = try
        MacroEconometricModels.simulate(sol, periods; rng=rng)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "data simulate ha"))
    end
    n_out = size(path, 2)
    names = _ynames(n_out)
    try
        ir0 = MacroEconometricModels.irf(sol, 1)
        if length(ir0.variables) == n_out
            names = String[string(v) for v in ir0.variables]
        end
    catch
    end
    rows = _truth_rows()
    if hasproperty(spec, :param_values)
        for k in sort!(collect(keys(spec.param_values)); by=string)
            _truth_push!(rows, "param:" * string(k), spec.param_values[k])
        end
    end
    ss = sol.steady_state
    _truth_push_dict!(rows, "ss_agg:", ss.aggregates)
    _truth_push_dict!(rows, "ss_price:", ss.prices)
    hasproperty(ss, :converged) && _truth_push!(rows, "ss_converged", ss.converged ? 1.0 : 0.0)
    sample = _indexed_sample(path; names=names)
    _status("HA path is in aggregate deviations; steady-state levels are in population_truth")
    _finish_sim(sample, rows, _settings("ha", eff; method, periods, distribution);
                format, output)
end

function _data_simulate_olg(; alpha::Float64=0.36, beta::Float64=0.96, delta::Float64=0.08,
                            gamma::Float64=0.98, z::Float64=1.0, debt::Float64=0.0,
                            k0::Float64=0.0, periods::Int=40, seed::Int=0,
                            format::String="table", output::String="")
    (0 < alpha < 1) || throw(CliError("usage/invalid",
        "--alpha must lie in (0, 1) (got $alpha)"))
    (0 < beta < 1) || throw(CliError("usage/invalid",
        "--beta must lie in (0, 1) (got $beta)"))
    _sim_pos("delta", delta)
    (0 < gamma <= 1) || throw(CliError("usage/invalid",
        "--gamma must lie in (0, 1] (got $gamma)"))
    _sim_pos("z", z)
    _sim_ge("periods", periods, 1)
    eff, rng = _sim_rng(seed)
    # The saddle path is deterministic. `rng` is drawn so the seed still
    # consumes a generator and two calls with the same seed match.
    rand(rng)
    debt != 0 && _status("debt b=$debt — verify MEMs Blanchard debt accounting")
    m = MacroEconometricModels.BlanchardOLG(;
        alpha=alpha, beta=beta, delta=delta, gamma=gamma, Z=z, b=debt)
    sol = try
        MacroEconometricModels.blanchard_solve(m)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "data simulate olg"))
    end
    k_init = k0 == 0.0 ? 0.8 * sol.ss.k : k0
    paths = try
        MacroEconometricModels.blanchard_transition(m, sol, k_init; H=periods)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "data simulate olg"))
    end
    sample = DataFrame(
        time=collect(0:periods),
        k=collect(Float64, paths.k),
        C=collect(Float64, paths.C),
        r=collect(Float64, paths.r),
        w=collect(Float64, paths.w),
    )
    rows = _truth_rows()
    _truth_push!(rows, "alpha", alpha)
    _truth_push!(rows, "beta", beta)
    _truth_push!(rows, "delta", delta)
    _truth_push!(rows, "gamma", gamma)
    _truth_push!(rows, "z", z)
    _truth_push!(rows, "debt", debt)
    ss = sol.ss
    for (name, val) in (("k", ss.k), ("C", ss.C), ("r", ss.r), ("w", ss.w),
                        ("H", ss.H), ("mpc", ss.mpc), ("b", ss.b))
        _truth_push!(rows, "ss:" * name, val)
    end
    _truth_push!(rows, "ss_converged", ss.converged ? 1.0 : 0.0)
    _truth_push!(rows, "stable_eig", sol.stable_eig)
    _truth_push!(rows, "determinate", sol.determinate ? 1.0 : 0.0)
    _finish_sim(sample, rows, _settings("olg", eff; periods, deterministic=true);
                format, output)
end

function _data_simulate_ct(; alpha::Float64=0.36, rho::Float64=0.05, sigma::Float64=2.0,
                           delta::Float64=0.05, z::Float64=1.0, shock_size::Float64=0.95,
                           grid_size::Int=40, a_max::Float64=30.0, max_iter::Int=80,
                           tol::Float64=1e-5, dt::Float64=0.25, periods::Int=12,
                           seed::Int=0, format::String="table", output::String="")
    _sim_pos("alpha", alpha)
    _sim_pos("rho", rho)
    _sim_pos("sigma", sigma)
    _sim_pos("delta", delta)
    _sim_pos("z", z)
    _sim_pos("shock-size", shock_size)
    _sim_ge("grid-size", grid_size, 4)
    _sim_pos("a-max", a_max)
    _sim_ge("max-iter", max_iter, 1)
    _sim_pos("tol", tol)
    _sim_pos("dt", dt)
    _sim_ge("periods", periods, 2)
    eff, rng = _sim_rng(seed)
    rand(rng)
    m = MacroEconometricModels.CTAiyagari(;
        alpha=alpha, rho=rho, sigma=sigma, delta=delta, Z=z,
        a_min=0.0, a_max=a_max, I=grid_size)
    ss = try
        MacroEconometricModels.ct_steady_state(m; max_iter=max_iter, tol=tol)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "data simulate ct"))
    end
    Z_path = fill(Float64(z), periods)
    Z_path[1] = shock_size * Float64(z)
    tr = try
        MacroEconometricModels.ct_mit_shock(m, ss, Z_path; dt=dt, max_iter=max_iter, tol=tol)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "data simulate ct"))
    end
    sample = DataFrame(
        time=collect(Float64, tr.t),
        Z=collect(Float64, tr.Z),
        K=collect(Float64, tr.K),
        r=collect(Float64, tr.r),
        w=collect(Float64, tr.w),
        C=collect(Float64, tr.C),
    )
    rows = _truth_rows()
    _truth_push!(rows, "alpha", alpha)
    _truth_push!(rows, "rho", rho)
    _truth_push!(rows, "sigma", sigma)
    _truth_push!(rows, "delta", delta)
    _truth_push!(rows, "z", z)
    _truth_push!(rows, "ss:r", ss.r)
    _truth_push!(rows, "ss:w", ss.w)
    _truth_push!(rows, "ss:K", ss.K)
    _truth_push!(rows, "ss:L", ss.L)
    _truth_push!(rows, "ss_converged", ss.converged ? 1.0 : 0.0)
    _truth_push!(rows, "transition_converged", tr.converged ? 1.0 : 0.0)
    _finish_sim(sample, rows, _settings("ct", eff; periods, grid_size, deterministic=true);
                format, output)
end
