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

# Mock MacroEconometricModels module for testing command handlers
# Provides minimal types and functions that src/commands/ files reference.

module MacroEconometricModels

using LinearAlgebra: I, diagm, Diagonal
using Statistics: mean
using Random
import Serialization
import DataFrames
using DataFrames: DataFrame   # for long_table (Tables.jl tidy exports, real MEMs #346)

# ─── Distributions re-export (real MEMs re-exports Distributions) ──────────
# Minimal stand-in so the CLI's prior bridge (_dsge_priors_distributions →
# MacroEconometricModels.Distributions.Beta/Normal/...) resolves under the mock.
# Stores constructor args and supports Statistics.mean (used to seed theta0).
module Distributions
    import Statistics
    abstract type VariateForm end
    abstract type Univariate <: VariateForm end
    abstract type ValueSupport end
    abstract type Continuous <: ValueSupport end
    abstract type Distribution{F<:VariateForm,S<:ValueSupport} end
    const ContinuousUnivariateDistribution = Distribution{Univariate,Continuous}
    struct Beta{T<:Real} <: ContinuousUnivariateDistribution; α::T; β::T; end
    struct Normal{T<:Real} <: ContinuousUnivariateDistribution; μ::T; σ::T; end
    struct InverseGamma{T<:Real} <: ContinuousUnivariateDistribution; α::T; θ::T; end
    struct Gamma{T<:Real} <: ContinuousUnivariateDistribution; α::T; θ::T; end
    struct Uniform{T<:Real} <: ContinuousUnivariateDistribution; a::T; b::T; end
    Beta(a, b) = Beta{Float64}(Float64(a), Float64(b))
    Normal(a, b) = Normal{Float64}(Float64(a), Float64(b))
    InverseGamma(a, b) = InverseGamma{Float64}(Float64(a), Float64(b))
    Gamma(a, b) = Gamma{Float64}(Float64(a), Float64(b))
    Uniform(a, b) = Uniform{Float64}(Float64(a), Float64(b))
    Statistics.mean(d::Beta) = d.α / (d.α + d.β)
    Statistics.mean(d::Normal) = d.μ
    Statistics.mean(d::InverseGamma) = d.α > 1 ? d.θ / (d.α - 1) : d.θ
    Statistics.mean(d::Gamma) = d.α * d.θ
    Statistics.mean(d::Uniform) = (d.a + d.b) / 2
    export Distribution, Beta, Normal, InverseGamma, Gamma, Uniform
end
using .Distributions: Distribution, Beta, Normal, InverseGamma, Gamma, Uniform

# ─── Typed exception hierarchy (MEMs 0.7.0 / #245; mocked for C050) ─────────
# Real MEMs roots all domain errors at `MacroModelError <: Exception`. The CLI's
# `_domain_error_class` (src/output/errors.jl) matches these by type NAME, so the
# mock only needs same-named throwable types with a `.msg` field.
abstract type MacroModelError <: Exception end
struct ConvergenceError <: MacroModelError
    msg::String; iters::Int; residual::Float64
end
ConvergenceError(msg::AbstractString) = ConvergenceError(String(msg), 0, NaN)
struct IdentificationError <: MacroModelError
    msg::String
end
struct SingularSystemError <: MacroModelError
    msg::String; cond::Float64
end
SingularSystemError(msg::AbstractString) = SingularSystemError(String(msg), Inf)
struct SerializationError <: MacroModelError
    msg::String
end
Base.showerror(io::IO, e::MacroModelError) = print(io, nameof(typeof(e)), ": ", e.msg)

# ─── Repro manifest + versioned save/load (MEMs 0.7.0 #345/#347; CLI C052) ────
# JLD2 is not a test dep, so the mock persists a version-tagged container via
# Serialization, mirroring real save_model/load_model version + type semantics.
const SERIALIZATION_FORMAT_VERSION = 1

struct ReproManifest
    seed::Union{Int,Nothing}
    n_threads::Int
    julia_version::String
    package_version::String
    dependency_versions::Dict{String,String}
    os::String
    machine::String
    timestamp::String
    git_sha::String
    git_dirty::Bool
    settings::Dict{String,Any}
end

capture_manifest(; seed::Union{Integer,Nothing}=nothing,
                   settings::AbstractDict=Dict{String,Any}()) =
    ReproManifest(seed === nothing ? nothing : Int(seed), Threads.nthreads(),
                  string(VERSION), "0.7.0",
                  Dict("Distributions" => "0.25", "StatsAPI" => "1.7"),
                  string(Sys.KERNEL), string(Sys.MACHINE),
                  "2026-01-01T00:00:00Z", "unknown", false,
                  Dict{String,Any}(settings))

const _MOCK_NATIVE_SAVE_TYPES = Set([
    "VARModel", "BVARPosterior", "RegModel", "LogitModel", "ProbitModel", "LPModel",
])

function save_model(model, path::AbstractString)
    tname = string(nameof(typeof(model)))
    tname in _MOCK_NATIVE_SAVE_TYPES || throw(SerializationError(
        "save_model does not support $(typeof(model))"))
    open(p -> Serialization.serialize(p,
        Dict{String,Any}("format_version" => SERIALIZATION_FORMAT_VERSION,
                         "type" => tname, "payload" => model)), path, "w")
    return path
end

function load_model(path::AbstractString)
    isfile(path) || throw(SerializationError("no such model file: $path"))
    c = open(Serialization.deserialize, path)
    (c isa AbstractDict && haskey(c, "format_version")) ||
        throw(SerializationError("file '$path' is not a model container"))
    c["format_version"] == SERIALIZATION_FORMAT_VERSION || throw(SerializationError(
        "unsupported serialization format_version $(c["format_version"]): " *
        "this build reads $SERIALIZATION_FORMAT_VERSION"))
    return c["payload"]
end

# ─── New abstract model supertypes (MEMs 0.7.0 modules; wrapped in C062–C073) ─
abstract type AbstractMGARCHModel end
abstract type AbstractNonlinearTSModel end
abstract type AbstractStateSpaceModel end

# ─── Core Types ───────────────────────────────────────────

struct VARModel{T<:Real}
    Y::Matrix{T}; p::Int; B::Matrix{T}; U::Matrix{T}; Sigma::Matrix{T}
    aic::T; bic::T; hqic::T
    varnames::Vector{String}
end

# Real MEMs VARModel carries varnames with this default (var/types.jl:31-35)
VARModel(Y::Matrix{T}, p::Int, B::Matrix{T}, U::Matrix{T}, Sigma::Matrix{T},
         aic::T, bic::T, hqic::T) where {T<:Real} =
    VARModel(Y, p, B, U, Sigma, aic, bic, hqic, ["y$i" for i in 1:size(Y, 2)])

(::Type{VARModel{T}})(Y::Matrix{T}, p::Int, B::Matrix{T}, U::Matrix{T}, Sigma::Matrix{T},
                      aic::T, bic::T, hqic::T) where {T<:Real} =
    VARModel{T}(Y, p, B, U, Sigma, aic, bic, hqic, ["y$i" for i in 1:size(Y, 2)])

struct MockChains end

struct BVARPosterior{T}
    B_draws::Array{T,3}
    Sigma_draws::Array{T,3}
    n_draws::Int
    p::Int
    n::Int
    data::Matrix{T}
end

struct MinnesotaHyperparameters
    tau::Float64; decay::Float64; lambda::Float64; mu::Float64; omega::Vector{Float64}
end
MinnesotaHyperparameters(; tau=0.2, decay=1.0, lambda=0.5, mu=1.0, omega=[1.0]) =
    MinnesotaHyperparameters(tau, decay, lambda, mu, omega)

struct ImpulseResponse{T}
    values::Array{T,3}; ci_lower::Union{Array{T,3},Nothing}; ci_upper::Union{Array{T,3},Nothing}
    horizon::Int; variables::Vector{String}; shocks::Vector{String}; ci_type::Symbol
end
# Convenience 3-arg constructor for backward compat with existing handler tests
ImpulseResponse(v::Array{T,3}, cl, cu) where T = ImpulseResponse(v, cl, cu, size(v,1),
    ["var$i" for i in 1:size(v,2)], ["shock$i" for i in 1:size(v,3)], :cholesky)

struct BayesianImpulseResponse{T}
    quantiles::Array{T,4}
    point_estimate::Array{T,3}
    horizon::Int
    variables::Vector{String}
    shocks::Vector{String}
    quantile_levels::Vector{T}
    _draws::Array{T,4}
    n_requested::Int
    n_effective::Int
    n_failed::Int
end
# Convenience 3-arg constructor for backward compat
BayesianImpulseResponse(m::Array{T,3}, q::Array{T,4}, ql::Vector{T}) where T =
    BayesianImpulseResponse(q, m, size(m,1),
    ["var$i" for i in 1:size(m,2)], ["shock$i" for i in 1:size(m,3)], ql,
    zeros(T, size(q)...), 0, size(q, 4), 0)

struct FEVD{T}
    decomposition::Array{T,3}; proportions::Array{T,3}
    variables::Vector{String}; shocks::Vector{String}
end
# 2-arg backward-compat constructor
FEVD(d::Array{T,3}, p::Array{T,3}) where T =
    FEVD(d, p, ["var$i" for i in 1:size(p,1)], ["shock$i" for i in 1:size(p,2)])
struct BayesianFEVD{T}
    quantiles::Array{T,4}
    point_estimate::Array{T,3}
    horizon::Int
    variables::Vector{String}
    shocks::Vector{String}
    quantile_levels::Vector{T}
    n_requested::Int
    n_effective::Int
    n_failed::Int
end
# Convenience 3-arg constructor for backward compat
BayesianFEVD(m::Array{T,3}, q::Array{T,4}, ql::Vector{T}) where T =
    BayesianFEVD(q, m, size(m,1),
    ["var$i" for i in 1:size(m,2)], ["shock$i" for i in 1:size(m,3)], ql,
    0, size(q, 4), 0)

struct HistoricalDecomposition{T}
    contributions::Array{T,3}; initial_conditions::Matrix{T}; actual::Matrix{T}
    shocks::Matrix{T}; T_eff::Int; variables::Vector{String}; shock_names::Vector{String}
    method::Symbol
end
# Convenience 5-arg constructor for backward compat
HistoricalDecomposition(c::Array{T,3}, ic, a, s, te::Int) where T =
    HistoricalDecomposition(c, ic, a, s, te,
    ["var$i" for i in 1:size(c,2)], ["shock$i" for i in 1:size(c,3)], :cholesky)

struct BayesianHistoricalDecomposition{T}
    quantiles::Array{T,4}
    point_estimate::Array{T,3}
    initial_quantiles::Array{T,3}
    initial_point_estimate::Matrix{T}
    shocks_point_estimate::Matrix{T}
    actual::Matrix{T}
    T_eff::Int
    variables::Vector{String}
    shock_names::Vector{String}
    quantile_levels::Vector{T}
    method::Symbol
    n_requested::Int
    n_effective::Int
    n_failed::Int
end
# Convenience 4-arg constructor for backward compat
BayesianHistoricalDecomposition(m::Array{T,3}, im::Matrix{T}, q::Array{T,4}, ql::Vector{T}) where T =
    BayesianHistoricalDecomposition(q, m, zeros(T, 0, 0, 0), im, zeros(T, size(m,1), size(m,3)), zeros(T, size(m,1), size(m,2)),
    size(m,1), ["var$i" for i in 1:size(m,2)], ["shock$i" for i in 1:size(m,3)], ql, :cholesky,
    0, size(q, 4), 0)

struct ZeroRestriction
    variable::Int; shock::Int; horizon::Int
end
struct SignRestriction
    variable::Int; shock::Int; sign::Symbol; horizon::Int
end
struct SVARRestrictions
    n_vars::Int; zeros::Vector{ZeroRestriction}; signs::Vector{SignRestriction}
end
SVARRestrictions(n::Int; zeros=ZeroRestriction[], signs=SignRestriction[]) =
    SVARRestrictions(n, zeros, signs)
struct AriasSVARResult{T}
    Q_draws::Vector{Matrix{T}}; irf_draws::Array{T,4}; weights::Vector{T}; acceptance_rate::T
    restrictions::SVARRestrictions
end

struct UhligSVARResult{T}
    Q::Matrix{T}; irf::Array{T,3}; penalty::T; shock_penalties::Vector{T}
    restrictions::SVARRestrictions; converged::Bool
end

# ─── LP Types ─────────────────────────────────────────────

struct LPModel{T}
    Y::Matrix{T}; shock_var::Int; horizon::Int; lags::Int
    B::Matrix{T}; residuals::Matrix{T}; vcov::Matrix{T}; T_eff::Int
end
struct LPIVModel{T}
    Y::Matrix{T}; instruments::Matrix{T}; first_stage_F::T; horizon::Int; T_eff::Int
end
struct SmoothLPModel{T}
    Y::Matrix{T}; lambda::T; horizon::Int
end
struct StateLPModel{T}
    Y::Matrix{T}; B_expansion::Matrix{T}; B_recession::Matrix{T}; horizon::Int
end
struct PropensityLPModel{T}
    Y::Matrix{T}; ate::T; ate_se::T; horizon::Int
end
struct LPImpulseResponse{T}
    values::Matrix{T}; ci_lower::Matrix{T}; ci_upper::Matrix{T}; se::Matrix{T}
end
struct StructuralLP{T}
    irf::ImpulseResponse{T}; var_model::VARModel{T}; Q::Matrix{T}
    method::Symbol; se::Array{T,3}; lp_models::Vector{LPModel{T}}
end
struct LPFEVD{T}
    proportions::Array{T,3}; bias_corrected::Array{T,3}; se::Array{T,3}
    ci_lower::Array{T,3}; ci_upper::Array{T,3}
    method::Symbol; horizon::Int; n_boot::Int; conf_level::T; bias_correction::Bool
end
# Convenience constructor for backward compat (old tests use R2/lp_a/lp_b fields)
LPFEVD(R2::Array{T,3}, lp_a, lp_b, bc, bse, h::Int, v::Int, s::Int) where T =
    LPFEVD(R2, bc, bse, R2, R2, :R2, h, 200, T(0.95), true)

struct LPForecast{T}
    forecast::Matrix{T}; ci_lower::Matrix{T}; ci_upper::Matrix{T}
    se::Matrix{T}; horizon::Int; response_vars::Vector{Int}; shock_var::Int
    shock_path::Vector{T}; conf_level::T; ci_method::Symbol
end
# Convenience 5-arg constructor for backward compat
LPForecast(f::Matrix{T}, cl, cu, se, h::Int) where T =
    LPForecast(f, cl, cu, se, h, collect(1:size(f,2)), 1, T[1.0], T(0.95), :analytical)

# ─── Factor Types ─────────────────────────────────────────

struct FactorModel{T}
    X::Matrix{T}; factors::Matrix{T}; loadings::Matrix{T}; eigenvalues::Vector{T}
    explained_variance::Vector{T}; cumulative_variance::Vector{T}; r::Int; standardized::Bool
end
# Convenience 4-arg constructor for backward compat
FactorModel(d::Matrix{T}, f, l, e) where T =
    FactorModel(d, f, l, e, fill(T(0.5), length(e)), cumsum(fill(T(0.5), length(e))),
    size(f, 2), true)

struct DynamicFactorModel{T}
    X::Matrix{T}; factors::Matrix{T}; loadings::Matrix{T}; A::Vector{Matrix{T}}
    factor_residuals::Matrix{T}; Sigma_eta::Matrix{T}; Sigma_e::Matrix{T}
    eigenvalues::Vector{T}; explained_variance::Vector{T}; cumulative_variance::Vector{T}
    r::Int; p::Int; method::Symbol; standardized::Bool; converged::Bool
    iterations::Int; loglik::T
end
# Convenience 3-arg constructor for backward compat
DynamicFactorModel(f::Matrix{T}, l, c) where T =
    DynamicFactorModel(zeros(T, 100, size(l,1)), f, l, Matrix{T}[c],
    zeros(T, 99, size(f,2)), Matrix{T}(I(size(f,2))), Matrix{T}(I(size(l,1))),
    ones(T, size(f,2)), fill(T(0.5), size(f,2)), cumsum(fill(T(0.5), size(f,2))),
    size(f, 2), 1, :twostep, true, true, 100, T(-250.0))
struct GeneralizedDynamicFactorModel{T}
    X::Matrix{T}
    factors::Matrix{T}
    common_component::Matrix{T}
    idiosyncratic::Matrix{T}
    loadings_spectral::Array{T,3}
    spectral_density_X::Array{T,3}
    spectral_density_chi::Array{T,3}
    eigenvalues_spectral::Matrix{T}
    frequencies::Vector{T}
    q::Int
    r::Int
    bandwidth::Int
    kernel::Symbol
    standardized::Bool
    variance_explained::Vector{T}
end
struct FactorForecast{T}
    factors::Matrix{T}; observables::Matrix{T}
    factors_lower::Matrix{T}; factors_upper::Matrix{T}
    observables_lower::Matrix{T}; observables_upper::Matrix{T}
    factors_se::Matrix{T}; observables_se::Matrix{T}
    horizon::Int; conf_level::T; ci_method::Symbol
end
# Convenience constructor for backward compat (some old tests may use 7-arg form)
FactorForecast(f::Matrix{T}, o, ol, ou, ose, h::Int, cl::T) where T =
    FactorForecast(f, o, f, f, isnothing(ol) ? o : ol, isnothing(ou) ? o : ou,
    f, isnothing(ose) ? o : ose, h, cl, :analytical)

# ─── ARIMA Types ──────────────────────────────────────────

struct ARModel{T}
    y::Vector{T}
    p::Int
    c::T
    phi::Vector{T}
    sigma2::T
    residuals::Vector{T}
    fitted::Vector{T}
    loglik::T
    aic::T
    bic::T
    method::Symbol
    converged::Bool
    iterations::Int
end
struct MAModel{T}
    y::Vector{T}
    q::Int
    c::T
    theta::Vector{T}
    sigma2::T
    residuals::Vector{T}
    fitted::Vector{T}
    loglik::T
    aic::T
    bic::T
    method::Symbol
    converged::Bool
    iterations::Int
end
struct ARMAModel{T}
    y::Vector{T}
    p::Int
    q::Int
    c::T
    phi::Vector{T}
    theta::Vector{T}
    sigma2::T
    residuals::Vector{T}
    fitted::Vector{T}
    loglik::T
    aic::T
    bic::T
    method::Symbol
    converged::Bool
    iterations::Int
end
struct ARIMAModel{T}
    y::Vector{T}
    y_diff::Vector{T}
    p::Int
    d::Int
    q::Int
    c::T
    phi::Vector{T}
    theta::Vector{T}
    sigma2::T
    residuals::Vector{T}
    fitted::Vector{T}
    loglik::T
    aic::T
    bic::T
    method::Symbol
    converged::Bool
    iterations::Int
end
struct ARIMAForecast{T}
    forecast::Vector{T}; ci_lower::Vector{T}; ci_upper::Vector{T}; se::Vector{T}
    horizon::Int; conf_level::T
end
# Convenience 5-arg constructor for backward compat
ARIMAForecast(f::Vector{T}, cl, cu, se, h::Int) where T =
    ARIMAForecast(f, cl, cu, se, h, T(0.95))

# ARFIMA (fractional integration / long memory) — fields mirror real MEMs
struct ARFIMAModel{T}
    y::Vector{T}
    p::Int
    d::T
    q::Int
    c::T
    phi::Vector{T}
    theta::Vector{T}
    sigma2::T
    d_se::T
    residuals::Vector{T}
    fitted::Vector{T}
    loglik::T
    aic::T
    bic::T
    method::Symbol
    converged::Bool
    iterations::Int
end

# ─── VAR Forecast Type ──────────────────────────────────

struct VARForecast{T<:AbstractFloat}
    forecast::Matrix{T}
    ci_lower::Matrix{T}
    ci_upper::Matrix{T}
    horizon::Int
    ci_method::Symbol
    conf_level::T
    varnames::Vector{String}
end

# ─── Non-Gaussian Types ──────────────────────────────────

struct ICASVARResult{T}
    B0::Matrix{T}; W::Matrix{T}; Q::Matrix{T}; shocks::Matrix{T}
    method::Symbol; converged::Bool; iterations::Int; objective::T
end
struct NonGaussianMLResult{T}
    B0::Matrix{T}; Q::Matrix{T}; shocks::Matrix{T}
    distribution::Symbol; loglik::T; loglik_gaussian::T
    dist_params::Dict{Symbol,Any}; vcov::Matrix{T}; se::Vector{T}; aic::T; bic::T
end
struct MarkovSwitchingSVARResult{T}
    B0::Matrix{T}
end
struct GARCHSVARResult{T}
    B0::Matrix{T}
end
struct SmoothTransitionSVARResult{T}
    B0::Matrix{T}
end
struct ExternalVolatilitySVARResult{T}
    B0::Matrix{T}
end
struct NormalityTestResult{T}
    test_name::Symbol; statistic::T; pvalue::T; df::Int
end
struct NormalityTestSuite{T}
    results::Vector{NormalityTestResult{T}}
end

# ─── Test Types ───────────────────────────────────────────

struct ADFResult{T}
    statistic::T; pvalue::T; lags::Int
end
struct KPSSResult{T}
    statistic::T
    pvalue::T
end
struct PPResult{T}
    statistic::T; pvalue::T
end
struct ZAResult{T}
    statistic::T; break_index::Int
end
struct NgPerronResult{T}
    MZa::T; MZt::T; MSB::T; MPT::T
end
# Long-memory d estimators (fields mirror real MEMs)
struct GPHResult{T}
    d::T; se::T; tstat::T; pval::T; m::Int; n::Int; trim::Int
end
struct LocalWhittleResult{T}
    d::T; se::T; tstat::T; pval::T; m::Int; n::Int; objective::T
end
struct JohansenResult{T}
    trace_stats::Vector{T}; trace_pvalues::Vector{T}
    max_eigen_stats::Vector{T}; max_eigen_pvalues::Vector{T}
end

# ─── GMM Types ────────────────────────────────────────────

struct GMMModel{T}
    theta::Vector{T}; vcov::Matrix{T}; n_moments::Int; n_params::Int
    W::Matrix{T}; g_bar::Vector{T}; J_stat::T; J_pvalue::T
end

# ─── Volatility Types ────────────────────────────────────

struct ARCHModel{T<:Real}
    y::Vector{T}; q::Int; mu::T; omega::T; alpha::Vector{T}
    conditional_variance::Vector{T}; standardized_residuals::Vector{T}
    residuals::Vector{T}; fitted::Vector{T}
    loglik::T; aic::T; bic::T; method::Symbol; converged::Bool; iterations::Int
end
# Convenience 1-arg constructor for backward compat
# Convenience: c has length q+2 (mu, omega, alpha_1...alpha_q)
ARCHModel(c::Vector{T}) where T = let q = length(c) - 2
    ARCHModel(zeros(T, 100), q, c[1], c[2], c[3:end],
        ones(T, 100), zeros(T, 100), zeros(T, 100), zeros(T, 100),
        T(-150.0), T(310.0), T(320.0), :mle, true, 50)
end

struct GARCHModel{T<:Real}
    y::Vector{T}; p::Int; q::Int; mu::T; omega::T; alpha::Vector{T}; beta::Vector{T}
    conditional_variance::Vector{T}; standardized_residuals::Vector{T}
    residuals::Vector{T}; fitted::Vector{T}
    loglik::T; aic::T; bic::T; method::Symbol; converged::Bool; iterations::Int
end
# Convenience: c has length p+q+2 (mu, omega, alpha_1...alpha_q, beta_1...beta_p)
GARCHModel(c::Vector{T}) where T = let np = length(c) - 2; q = div(np, 2); p = np - q
    GARCHModel(zeros(T, 100), p, q, c[1], c[2], c[3:3+q-1], c[3+q:end],
        ones(T, 100), zeros(T, 100), zeros(T, 100), zeros(T, 100),
        T(-150.0), T(310.0), T(320.0), :mle, true, 50)
end

struct EGARCHModel{T<:Real}
    y::Vector{T}; p::Int; q::Int; mu::T; omega::T; alpha::Vector{T}; gamma::Vector{T}; beta::Vector{T}
    conditional_variance::Vector{T}; standardized_residuals::Vector{T}
    residuals::Vector{T}; fitted::Vector{T}
    loglik::T; aic::T; bic::T; method::Symbol; converged::Bool; iterations::Int
end
# Convenience: c has length 2*q+p+2 (mu, omega, alpha_1...alpha_q, gamma_1...gamma_q, beta_1...beta_p)
EGARCHModel(c::Vector{T}) where T = let np = length(c) - 2; q = div(np, 3); p = np - 2*q
    EGARCHModel(zeros(T, 100), p, q, c[1], c[2], c[3:3+q-1], c[3+q:3+2*q-1], c[3+2*q:end],
        ones(T, 100), zeros(T, 100), zeros(T, 100), zeros(T, 100),
        T(-150.0), T(310.0), T(320.0), :mle, true, 50)
end

struct GJRGARCHModel{T<:Real}
    y::Vector{T}; p::Int; q::Int; mu::T; omega::T; alpha::Vector{T}; gamma::Vector{T}; beta::Vector{T}
    conditional_variance::Vector{T}; standardized_residuals::Vector{T}
    residuals::Vector{T}; fitted::Vector{T}
    loglik::T; aic::T; bic::T; method::Symbol; converged::Bool; iterations::Int
end
# Convenience: c has length 2*q+p+2 (mu, omega, alpha_1...alpha_q, gamma_1...gamma_q, beta_1...beta_p)
GJRGARCHModel(c::Vector{T}) where T = let np = length(c) - 2; q = div(np, 3); p = np - 2*q
    GJRGARCHModel(zeros(T, 100), p, q, c[1], c[2], c[3:3+q-1], c[3+q:3+2*q-1], c[3+2*q:end],
        ones(T, 100), zeros(T, 100), zeros(T, 100), zeros(T, 100),
        T(-150.0), T(310.0), T(320.0), :mle, true, 50)
end

struct SVModel{T<:Real}
    y::Vector{T}; h_draws::Matrix{T}
    mu_post::Vector{T}; phi_post::Vector{T}; sigma_eta_post::Vector{T}
    volatility_mean::Vector{T}; volatility_quantiles::Matrix{T}; quantile_levels::Vector{T}
    dist::Symbol; leverage::Bool; n_samples::Int
end
# Convenience 1-arg constructor: c is ignored, just for backward compat
SVModel(c::Vector{T}) where T = SVModel(zeros(T, 100), zeros(T, 10, 100),
    zeros(T, 10), zeros(T, 10), zeros(T, 10), ones(T, 100),
    ones(T, 100, 3), T[0.16, 0.5, 0.84], :normal, false, 10)

struct VolatilityForecast{T<:Real}
    forecast::Vector{T}; ci_lower::Vector{T}; ci_upper::Vector{T}; se::Vector{T}
    horizon::Int; conf_level::T; model_type::Symbol
end
# Convenience 2-arg constructor for backward compat
VolatilityForecast(f::Vector{T}, h::Int) where T =
    VolatilityForecast(f, f, f, abs.(f) .* T(0.1), h, T(0.95), :garch)

# ─── Multivariate GARCH Types (C064b; MEMs 0.7.0 src/mgarch) ──
# Fields mirror the real MGARCHModel exactly (TS-3 field-subset conformance).
struct MGARCHModel{T<:Real} <: AbstractMGARCHModel
    Y::Matrix{T}
    mu::Vector{T}
    margins::Vector{GARCHModel{T}}
    H::Array{T,3}
    R::Union{Matrix{T},Array{T,3}}
    Rbar::Matrix{T}
    params::Vector{T}
    param_names::Vector{String}
    param_vcov::Matrix{T}
    loglik::T
    aic::T
    bic::T
    kind::Symbol
    correction::Symbol
    bekk_kind::Symbol
    converged::Bool
    n::Int
end

# ─── VECM Types ──────────────────────────────────────────

struct VECMModel{T<:Real}
    Y::Matrix{T}; p::Int; rank::Int
    alpha::Matrix{T}; beta::Matrix{T}; Pi::Matrix{T}
    Gamma::Vector{Matrix{T}}; mu::Vector{T}
    U::Matrix{T}; Sigma::Matrix{T}
    aic::T; bic::T; hqic::T; loglik::T
    deterministic::Symbol; method::Symbol
    johansen_result::Union{Nothing,JohansenResult{T}}  # align with real MEMs (C020)
    varnames::Vector{String}
end

# Real MEMs VECMModel carries johansen_result + varnames
VECMModel(Y::Matrix{T}, p::Int, rank::Int, alpha::Matrix{T}, beta::Matrix{T},
          Pi::Matrix{T}, Gamma::Vector{Matrix{T}}, mu::Vector{T}, U::Matrix{T},
          Sigma::Matrix{T}, aic::T, bic::T, hqic::T, loglik::T,
          deterministic::Symbol, method::Symbol) where {T<:Real} =
    VECMModel(Y, p, rank, alpha, beta, Pi, Gamma, mu, U, Sigma,
              aic, bic, hqic, loglik, deterministic, method, nothing,
              ["y$i" for i in 1:size(Y, 2)])

VECMModel(Y::Matrix{T}, p::Int, rank::Int, alpha::Matrix{T}, beta::Matrix{T},
          Pi::Matrix{T}, Gamma::Vector{Matrix{T}}, mu::Vector{T}, U::Matrix{T},
          Sigma::Matrix{T}, aic::T, bic::T, hqic::T, loglik::T,
          deterministic::Symbol, method::Symbol, varnames::Vector{String}) where {T<:Real} =
    VECMModel(Y, p, rank, alpha, beta, Pi, Gamma, mu, U, Sigma,
              aic, bic, hqic, loglik, deterministic, method, nothing, varnames)

# VECM restriction test result (C071) — fields mirror real MEMs VECMRestrictionTest.
struct VECMRestrictionTest{T<:Real}
    kind::Symbol
    lr_stat::T
    df::Int
    pvalue::T
    rank::Int
    description::String
    beta_restricted::Matrix{T}
    beta_unrestricted::Matrix{T}
    eigenvalues_restricted::Vector{T}
    eigenvalues_unrestricted::Vector{T}
    converged::Bool
    restricted_model::VECMModel{T}
end

struct VECMForecast{T<:Real}
    levels::Matrix{T}; differences::Matrix{T}
    ci_lower::Union{Matrix{T},Nothing}; ci_upper::Union{Matrix{T},Nothing}
    horizon::Int; ci_method::Symbol
end

struct VECMGrangerResult{T<:Real}
    short_run_stat::T; short_run_pvalue::T; short_run_df::Int
    long_run_stat::T; long_run_pvalue::T; long_run_df::Int
    strong_stat::T; strong_pvalue::T; strong_df::Int
    cause_var::Int; effect_var::Int
end

# ─── Mock Helper ──────────────────────────────────────────

function _mock_var(Y::Matrix{Float64}, p::Int)
    T_obs, n = size(Y)
    k = n * p + 1
    B = zeros(k, n)
    for i in 1:min(n, k)
        B[i, i] = 0.5
    end
    U = zeros(T_obs - p, n) .+ 0.01
    Sigma = Matrix{Float64}(I(n)) * 0.01
    VARModel(Y, p, B, U, Sigma, -100.0, -95.0, -97.0)
end

# ─── Mock Functions ───────────────────────────────────────

select_lag_order(Y, max_p; criterion=:aic) = min(2, max(1, max_p))
estimate_var(Y, p; check_stability=true) = _mock_var(Y, p)

estimate_bvar(Y, p; sampler=:direct, n_draws=1000, prior=:normal, hyper=nothing, seed=nothing) =
    BVARPosterior(zeros(10, size(Y,2)*p+1, size(Y,2)), zeros(10, size(Y,2), size(Y,2)),
                  10, p, size(Y,2), Y)
posterior_mean_model(post::BVARPosterior; data=nothing) = _mock_var(post.data, post.p)
posterior_median_model(post::BVARPosterior; data=nothing) = _mock_var(post.data, post.p)
# Keep old (chain, p, n) signatures for backward compat
posterior_mean_model(chain::MockChains, p, n; data=nothing) =
    _mock_var(isnothing(data) ? ones(100, n) : data, p)
posterior_median_model(chain::MockChains, p, n; data=nothing) =
    _mock_var(isnothing(data) ? ones(100, n) : data, p)
optimize_hyperparameters(Y, p) = MinnesotaHyperparameters(tau=0.2, decay=1.0, lambda=0.5, omega=ones(size(Y,2)))

# StatsAPI-like functions
coef(m::VARModel) = m.B
coef(m::Union{ARModel,MAModel,ARMAModel,ARIMAModel}) = m.coefficients
loglikelihood(m::VARModel) = -500.0
loglikelihood(m::Union{ARModel,MAModel,ARMAModel,ARIMAModel}) = m.ll
stderror(m::GMMModel) = fill(0.1, length(m.theta))
stderror(m::Union{ARModel,MAModel,ARMAModel,ARIMAModel}) = fill(0.01, length(m.coefficients))
stderror(m::ARCHModel) = fill(0.01, 2 + m.q)  # mu, omega, alpha...
stderror(m::GARCHModel) = fill(0.01, 2 + m.q + m.p)  # mu, omega, alpha..., beta...
stderror(m::EGARCHModel) = fill(0.01, 2 + m.q + m.q + m.p)  # mu, omega, alpha..., gamma..., beta...
stderror(m::GJRGARCHModel) = fill(0.01, 2 + m.q + m.q + m.p)  # mu, omega, alpha..., gamma..., beta...

# predict: return fitted values
predict(m::VARModel) = m.Y[m.p+1:end, :]
predict(m::Union{ARModel,MAModel,ARMAModel,ARIMAModel}) = zeros(Float64, 50)

# residuals: return residuals
residuals(m::VARModel) = m.U
residuals(m::Union{ARModel,MAModel,ARMAModel,ARIMAModel}) = fill(0.01, 50)

# Factor model predict/residuals
predict(m::FactorModel) = m.factors * m.loadings'  # T × n common component
predict(m::DynamicFactorModel) = m.factors * m.loadings'  # T × n common component
predict(m::GeneralizedDynamicFactorModel) = m.common_component  # T × n
residuals(m::FactorModel) = m.X .- m.factors * m.loadings'  # T × n idiosyncratic
residuals(m::DynamicFactorModel) = ones(size(m.factors, 1), size(m.loadings, 1)) * 0.01
residuals(m::GeneralizedDynamicFactorModel) = ones(size(m.common_component)) * 0.01

# Volatility model predict/residuals
predict(m::Union{ARCHModel,GARCHModel,EGARCHModel,GJRGARCHModel}) = m.fitted
predict(m::SVModel) = m.volatility_mean
residuals(m::Union{ARCHModel,GARCHModel,EGARCHModel,GJRGARCHModel}) = m.residuals
residuals(m::SVModel) = m.y .- m.volatility_mean

report(::VARModel) = nothing
report(::ImpulseResponse) = nothing
report(::BayesianImpulseResponse) = nothing
report(::FEVD) = nothing
report(::BayesianFEVD) = nothing
report(::HistoricalDecomposition) = nothing
report(::BayesianHistoricalDecomposition) = nothing
report(::UhligSVARResult) = nothing

# Global flag to control mock behavior for testing edge cases
const _MOCK_FLAGS = Dict{Symbol,Any}(
    :var_stationary => true,
    :pvar_stable => true,
    :verify_decomposition => true,
    :normality_all_pass => false,
    :lp_iv_weak => false,
)

function is_stationary(m::VARModel)
    if _MOCK_FLAGS[:var_stationary]
        (is_stationary=true, eigenvalues=[0.5+0.1im, 0.5-0.1im, 0.3+0.0im])
    else
        (is_stationary=false, eigenvalues=[1.2+0.0im, 0.5-0.1im, 0.3+0.0im])
    end
end
is_stationary(m::DynamicFactorModel) = (is_stationary=true,)

function companion_matrix(B::AbstractMatrix, n::Int, p::Int)
    np = n * p
    np == 0 && return zeros(1, 1)
    C = zeros(np, np)
    for j in 1:n, i in 1:min(size(B, 1), np)
        C[j, i] = B[i, j] * 0.3
    end
    np > n && (C[n+1:np, 1:np-n] = Matrix{Float64}(I(np - n)))
    C
end
companion_matrix_factors(m::DynamicFactorModel) = length(m.A) > 0 ? m.A[1] : zeros(m.r, m.r)
nvars(m::VARModel) = size(m.Y, 2)
nvars(m::VECMModel) = size(m.Y, 2)

# IRF
function irf(model::VARModel, horizon::Int; method=:cholesky, check_func=nothing,
             narrative_check=nothing, ci_type=:none, reps=200, conf_level=0.95,
             stationary_only=false, seed=nothing)
    n = size(model.Y, 2)
    vals = ones(horizon + 1, n, n) * 0.1
    ci_lo = ci_type == :none ? nothing : vals .- 0.5
    ci_hi = ci_type == :none ? nothing : vals .+ 0.5
    ImpulseResponse(vals, ci_lo, ci_hi)
end
function irf(chain::MockChains, p::Int, n::Int, horizon::Int;
             method=:cholesky, data=nothing, quantiles=[0.16, 0.5, 0.84],
             check_func=nothing, narrative_check=nothing)
    vals = ones(horizon + 1, n, n) * 0.1
    q_vals = ones(horizon + 1, n, n, length(quantiles)) * 0.1
    BayesianImpulseResponse(vals, q_vals, Float64.(quantiles))
end
function irf(post::BVARPosterior, horizon::Int;
             method=:cholesky, quantiles=[0.16, 0.5, 0.84],
             check_func=nothing, narrative_check=nothing)
    n = post.n
    vals = ones(horizon + 1, n, n) * 0.1
    q_vals = ones(horizon + 1, n, n, length(quantiles)) * 0.1
    BayesianImpulseResponse(vals, q_vals, Float64.(quantiles))
end

# Cumulative IRF
cumulative_irf(r::ImpulseResponse) = r
cumulative_irf(r::BayesianImpulseResponse) = r

# Sign-Identified Set
struct SignIdentifiedSet{T<:AbstractFloat}
    Q_draws::Vector{Matrix{T}}
    irf_draws::Array{T,4}
    n_accepted::Int
    n_total::Int
    acceptance_rate::T
    variables::Vector{String}
    shocks::Vector{String}
end

irf_bounds(s::SignIdentifiedSet; quantiles=[0.16, 0.84]) = (zeros(size(s.irf_draws)[2:4]...), ones(size(s.irf_draws)[2:4]...))
irf_median(s::SignIdentifiedSet) = fill(0.5, size(s.irf_draws)[2:4]...)

function identify_sign(model::VARModel, horizon::Int, check_func; max_draws=1000, store_all=false)
    n = size(model.Y, 2)
    if store_all
        n_d = 10
        irf_draws = ones(n_d, horizon + 1, n, n) * 0.1
        Q_draws = [Matrix{Float64}(I(n)) for _ in 1:n_d]
        return SignIdentifiedSet(Q_draws, irf_draws, n_d, max_draws, Float64(n_d/max_draws),
            ["var$i" for i in 1:n], ["shock$i" for i in 1:n])
    end
    Q = Matrix{Float64}(I(n))
    irf_vals = ones(horizon + 1, n, n) * 0.1
    return (Q, irf_vals)
end

# FEVD
function fevd(model::VARModel, horizon::Int; method=:cholesky, check_func=nothing, narrative_check=nothing)
    n = size(model.Y, 2)
    props = ones(n, n, horizon) / n
    FEVD(props, props)
end
function fevd(chain::MockChains, p::Int, n::Int, horizon::Int;
              data=nothing, quantiles=[0.16, 0.5, 0.84])
    props = ones(n, n, horizon) / n
    q = ones(n, n, horizon, length(quantiles)) / n
    BayesianFEVD(props, q, Float64.(quantiles))
end
function fevd(post::BVARPosterior, horizon::Int;
              quantiles=[0.16, 0.5, 0.84])
    n = post.n
    props = ones(n, n, horizon) / n
    q = ones(n, n, horizon, length(quantiles)) / n
    BayesianFEVD(props, q, Float64.(quantiles))
end

# Historical Decomposition
function historical_decomposition(model::VARModel, horizon::Int; method=:cholesky,
                                   check_func=nothing, narrative_check=nothing)
    n = size(model.Y, 2)
    T_eff = min(horizon, size(model.Y, 1) - model.p)
    contribs = ones(T_eff, n, n) * 0.1
    actual = ones(T_eff, n)
    initial = ones(T_eff, n) * 0.01
    shocks_mat = ones(T_eff, n)
    HistoricalDecomposition(contribs, initial, actual, shocks_mat, T_eff)
end
function historical_decomposition(chain::MockChains, p::Int, n::Int, horizon::Int;
                                   data=nothing, method=:cholesky, quantiles=[0.16, 0.5, 0.84])
    T_eff = isnothing(data) ? horizon : size(data, 1) - p
    mean_c = ones(T_eff, n, n) * 0.1
    initial_m = ones(T_eff, n) * 0.01
    q = ones(T_eff, n, n, length(quantiles)) * 0.1
    BayesianHistoricalDecomposition(mean_c, initial_m, q, Float64.(quantiles))
end
function historical_decomposition(post::BVARPosterior, horizon::Int;
                                   method=:cholesky, quantiles=[0.16, 0.5, 0.84])
    n = post.n; p = post.p; data = post.data
    T_eff = size(data, 1) - p
    mean_c = ones(T_eff, n, n) * 0.1
    initial_m = ones(T_eff, n) * 0.01
    q = ones(T_eff, n, n, length(quantiles)) * 0.1
    BayesianHistoricalDecomposition(mean_c, initial_m, q, Float64.(quantiles))
end
function historical_decomposition(slp::StructuralLP, T_hd::Int)
    n = size(slp.var_model.Y, 2)
    T_eff = min(T_hd, size(slp.var_model.Y, 1) - slp.var_model.p)
    contribs = ones(T_eff, n, n) * 0.1
    actual = ones(T_eff, n)
    initial = ones(T_eff, n) * 0.01
    shocks_mat = ones(T_eff, n)
    HistoricalDecomposition(contribs, initial, actual, shocks_mat, T_eff)
end
verify_decomposition(hd::HistoricalDecomposition; tol=1e-6) = _MOCK_FLAGS[:verify_decomposition]
contribution(hd::HistoricalDecomposition, var::Int, shock::Int) = hd.contributions[:, var, shock]

# SVAR restrictions
zero_restriction(variable, shock; horizon=0) = ZeroRestriction(variable, shock, horizon)
sign_restriction(variable, shock, sign::Symbol; horizon=0) = SignRestriction(variable, shock, sign, horizon)
function identify_arias(model::VARModel, restrictions::SVARRestrictions, horizon::Int;
                        n_draws=1000, n_rotations=1000)
    n = size(model.Y, 2)
    n_d = 10
    irf_draws = ones(n_d, horizon + 1, n, n) * 0.1
    AriasSVARResult([Matrix{Float64}(I(n)) for _ in 1:n_d], irf_draws, ones(n_d), 0.5, restrictions)
end
using Statistics: mean as _mean
function irf_mean(result::AriasSVARResult)
    dropdims(_mean(result.irf_draws; dims=1); dims=1)
end

function identify_uhlig(model::VARModel, restrictions::SVARRestrictions, horizon::Int;
                        n_starts=50, n_refine=10, max_iter_coarse=500, max_iter_fine=2000,
                        tol_coarse=1e-4, tol_fine=1e-8)
    n = size(model.Y, 2)
    Q = Matrix{Float64}(I(n))
    irf_vals = ones(horizon + 1, n, n) * 0.1
    UhligSVARResult(Q, irf_vals, 1e-6, fill(1e-7, n), restrictions, true)
end

# Chain parameter extraction (BVAR forecast)
function extract_chain_parameters(chain::MockChains)
    n_draws = 10
    b_vecs = ones(n_draws, 9) * 0.1
    sigmas = ones(n_draws, 6) * 0.01
    (b_vecs, sigmas)
end
function extract_chain_parameters(post::BVARPosterior)
    nd = post.n_draws
    k = post.n * post.p + 1
    b_vecs = ones(nd, k * post.n) * 0.1
    sigmas = ones(nd, post.n * (post.n + 1) ÷ 2) * 0.01
    (b_vecs, sigmas)
end
parameters_to_model(b_vec, sigma_vec, p, n, data) = parameters_to_model(b_vec, sigma_vec, p, n; data=data)
function parameters_to_model(b_vec, sigma_vec, p, n; data=nothing)
    Y = isnothing(data) ? ones(100, n) : data
    k = n * p + 1
    B = zeros(k, n)
    nb = min(length(b_vec), k * n)
    for i in 1:nb
        row = ((i - 1) % k) + 1
        col = ((i - 1) ÷ k) + 1
        col <= n && (B[row, col] = b_vec[i])
    end
    U = zeros(size(Y, 1) - p, n) .+ 0.01
    Sigma = Matrix{Float64}(I(n)) * 0.01
    VARModel(Y, p, B, U, Sigma, -100.0, -95.0, -97.0)
end

# LP functions
function estimate_lp(Y, shock_var, horizon; lags=4, cov_type=:newey_west)
    T_obs, n = size(Y)
    LPModel(Y, shock_var, horizon, lags, ones(lags+1, n)*0.1, ones(T_obs-lags, n)*0.01, Matrix{Float64}(I(n)) * 0.01, T_obs-lags)
end
function lp_irf(model::LPModel; conf_level=0.95)
    n = size(model.Y, 2); h = model.horizon + 1
    vals = ones(h, n) * 0.1
    LPImpulseResponse(vals, vals .- 0.5, vals .+ 0.5, abs.(ones(h, n)) * 0.1)
end
function estimate_lp_iv(Y, shock_var, Z, horizon; lags=4, cov_type=:newey_west)
    T_obs = size(Y, 1)
    f_val = _MOCK_FLAGS[:lp_iv_weak] ? 5.0 : 15.0
    LPIVModel(Y, Z, f_val, horizon, T_obs-4)
end
function lp_iv_irf(model::LPIVModel; conf_level=0.95)
    n = size(model.Y, 2); h = model.horizon + 1
    vals = ones(h, n) * 0.1
    LPImpulseResponse(vals, vals .- 0.5, vals .+ 0.5, ones(h, n) * 0.1)
end
weak_instrument_test(model::LPIVModel; threshold=10.0) = (F_stat=model.first_stage_F, is_weak=model.first_stage_F < threshold)
function estimate_smooth_lp(Y, shock_var, horizon; n_knots=3, lambda=0.0, degree=3)
    SmoothLPModel(Y, lambda, horizon)
end
function smooth_lp_irf(model::SmoothLPModel; conf_level=0.95)
    n = size(model.Y, 2); h = model.horizon + 1
    vals = ones(h, n) * 0.1
    LPImpulseResponse(vals, vals .- 0.5, vals .+ 0.5, ones(h, n) * 0.1)
end
cross_validate_lambda(Y, shock, horizon; k_folds=5) = 0.5
function estimate_state_lp(Y, shock_var, state_var, horizon; gamma=1.5, lags=4)
    n = size(Y, 2)
    StateLPModel(Y, ones(5, n)*0.1, ones(5, n)*0.1, horizon)
end
function state_irf(model::StateLPModel; regime=:both, conf_level=0.95)
    n = size(model.Y, 2); h = model.horizon + 1
    exp_vals = ones(h, n) * 0.1; rec_vals = ones(h, n) * 0.2
    (expansion=LPImpulseResponse(exp_vals, exp_vals .- 0.5, exp_vals .+ 0.5, ones(h, n)*0.1),
     recession=LPImpulseResponse(rec_vals, rec_vals .- 0.5, rec_vals .+ 0.5, ones(h, n)*0.1))
end
test_regime_difference(model::StateLPModel; h=nothing) =
    (joint_test=(avg_t_stat=2.5, p_value=0.012),)
function estimate_propensity_lp(Y, treatment, covariates, horizon; ps_method=:logit, trimming=(0.01,0.99))
    PropensityLPModel(Y, 0.5, 0.1, horizon)
end
function propensity_irf(model::PropensityLPModel; conf_level=0.95)
    n = size(model.Y, 2); h = model.horizon + 1
    vals = ones(h, n) * 0.1
    LPImpulseResponse(vals, vals .- 0.5, vals .+ 0.5, ones(h, n) * 0.1)
end
propensity_diagnostics(model::PropensityLPModel) =
    (propensity_summary=(treated=(mean=0.7,), control=(mean=0.3,)), balance=(max_weighted=0.05,))
doubly_robust_lp(Y, treatment, covariates, horizon; ps_method=:logit) =
    PropensityLPModel(Y, 0.6, 0.12, horizon)

function structural_lp(Y, horizon; method=:cholesky, lags=4, var_lags=4,
                       cov_type=:newey_west, ci_type=:none, reps=200, conf_level=0.95,
                       check_func=nothing, narrative_check=nothing, max_draws=1000)
    T_obs, n = size(Y); p = var_lags
    model = _mock_var(Y, p)
    irf_vals = ones(horizon + 1, n, n) * 0.1
    ci_lo = ci_type == :none ? nothing : irf_vals .- 0.5
    ci_hi = ci_type == :none ? nothing : irf_vals .+ 0.5
    irf_res = ImpulseResponse(irf_vals, ci_lo, ci_hi)
    Q = Matrix{Float64}(I(n))
    lp_models = [LPModel(Y, i, horizon, lags, ones(5, n)*0.1, ones(T_obs-lags, n)*0.01, Matrix{Float64}(I(n))*0.01, T_obs-lags) for i in 1:n]
    StructuralLP(irf_res, model, Q, method, ones(horizon+1, n, n)*0.1, lp_models)
end
function lp_fevd(slp::StructuralLP, horizons::Int; estimator=:R2, n_boot=200, conf_level=0.95)
    n = size(slp.var_model.Y, 2)
    props = ones(n, n, horizons) / n
    LPFEVD(props, props, props, props, ones(n, n, horizons)*0.01, horizons, n, n)
end
function forecast(model::LPModel, shock_path; ci_method=:analytical, conf_level=0.95, n_boot=500)
    n = size(model.Y, 2); h = length(shock_path)
    fc = ones(h, n) * 0.1
    LPForecast(fc, fc .- 0.5, fc .+ 0.5, ones(h, n) * 0.1, h)
end

# Factor functions
function estimate_factors(X, r; standardize=true)
    T_obs, n = size(X)
    FactorModel(X, ones(T_obs, r)*0.1, ones(n, r)*0.3, Float64[r-i+1 for i in 1:r])
end
function ic_criteria(X, max_factors; standardize=true)
    r = min(2, max_factors)
    (ic1=ones(max_factors), ic2=ones(max_factors), ic3=ones(max_factors),
     r_IC1=r, r_IC2=r, r_IC3=r)
end
function scree_plot_data(model::FactorModel)
    r = size(model.factors, 2)
    ev = Float64[r - i + 1 for i in 1:r]
    cv = cumsum(ev) ./ sum(ev)
    (factors=1:r, explained_variance=ev, cumulative_variance=cv)
end
function estimate_dynamic_factors(X, r, p; method=:twostep, max_iter=100, tol=1e-6)
    T_obs, n = size(X)
    DynamicFactorModel(ones(T_obs, r)*0.1, ones(n, r)*0.3, diagm(ones(r))*0.5)
end
function ic_criteria_gdfm(X, max_q; standardize=true)
    (q_ratio=min(2, max_q), q_opt=min(2, max_q))
end
function estimate_gdfm(X, q; r=2, standardize=true, bandwidth=0, kernel=:bartlett)
    T_obs, n = size(X)
    bw = bandwidth == 0 ? 5 : bandwidth
    fac = ones(T_obs, r) * 0.1
    cc = ones(T_obs, n) * 0.5
    idio = ones(T_obs, n) * 0.1
    load_s = ones(n, r, 10) * 0.3
    sx = ones(n, n, 10) * 0.1
    schi = ones(n, n, 10) * 0.05
    eigs = ones(r, 10)
    freqs = collect(range(0, stop=π, length=10))
    GeneralizedDynamicFactorModel(Float64.(X), fac, cc, idio, load_s, sx, schi, eigs, freqs,
        q, r, bw, kernel, standardize, fill(0.5, r))
end
function common_variance_share(model::GeneralizedDynamicFactorModel)
    n = size(model.common_component, 2)
    fill(0.5, n)
end
function forecast(model::FactorModel, h::Int; ci_method=:none, conf_level=0.95)
    n = size(model.X, 2)
    r = size(model.factors, 2)
    obs = ones(h, n) * 0.1
    fac = ones(h, r) * 0.1
    FactorForecast(fac, obs, fac, fac, obs .- 0.5, obs .+ 0.5,
        abs.(fac) .* 0.1, ones(h, n)*0.1, h, conf_level, :analytical)
end
function forecast(model::DynamicFactorModel, h::Int; ci=false, ci_method=:none, conf_level=0.95, n_boot=500, ci_level=0.95)
    r = size(model.factors, 2)
    n = size(model.loadings, 1)
    factors = ones(h, r) * 0.1
    obs = factors * model.loadings'
    FactorForecast(factors, obs, factors, factors, obs .- 0.5, obs .+ 0.5,
        abs.(factors) .* 0.1, ones(h, n)*0.1, h, conf_level, :analytical)
end

function forecast(model::GeneralizedDynamicFactorModel, h::Int; kwargs...)
    n = size(model.common_component, 2)
    r = 2
    factors = ones(h, r) * 0.1
    obs = ones(h, n) * 0.1
    FactorForecast(factors, obs, factors, factors, obs .- 0.5, obs .+ 0.5,
        abs.(factors) .* 0.1, ones(h, n)*0.1, h, 0.95, :analytical)
end

# Unit root / cointegration tests
adf_test(y; lags=:aic, regression=:constant) = ADFResult(-3.5, 0.01, 2)
kpss_test(y; regression=:constant) = KPSSResult(0.3, 0.01)
pp_test(y; regression=:constant) = PPResult(-3.2, 0.02)
za_test(y; regression=:both, trim=0.15) = ZAResult(-4.5, 50)
ngperron_test(y; regression=:constant) = NgPerronResult(-20.0, -3.1, 0.15, 4.0)
function johansen_test(Y, p; deterministic=:constant)
    n = size(Y, 2)
    JohansenResult([30.0,10.0,2.0][1:n], [0.01,0.1,0.5][1:n],
                   [25.0,8.0,1.5][1:n], [0.02,0.15,0.6][1:n])
end

# GMM functions
function estimate_lp_gmm(Y, shock_var, horizon; lags=4, weighting=:two_step)
    theta = ones(3) * 0.1
    vcov = Matrix{Float64}(I(3)) * 0.01
    [GMMModel(theta, vcov, 4, 3, Matrix{Float64}(I(4)), ones(4)*0.01, 2.5, 0.65)]
end
gmm_summary(model::GMMModel) = (n_moments=model.n_moments, n_params=model.n_params, theta=model.theta)
j_test(model::GMMModel) = (J_stat=model.J_stat, p_value=model.J_pvalue, df=model.n_moments - model.n_params)

# ARIMA functions
function _ar_like_y(y)
    v = Float64.(vec(y))
    T = length(v)
    return v, ones(T) * 0.01, ones(T) * 0.1
end
function estimate_ar(y, p; method=:ols)
    v, res, fit = _ar_like_y(y)
    ARModel(v, p, 0.0, ones(p)*0.3, 0.5, res, fit, -50.0, -100.0, -95.0, method, true, 10)
end
function estimate_ma(y, q; method=:css_mle)
    v, res, fit = _ar_like_y(y)
    MAModel(v, q, 0.0, ones(q)*0.3, 0.5, res, fit, -50.0, -100.0, -95.0, method, true, 10)
end
function estimate_arma(y, p, q; method=:css_mle)
    v, res, fit = _ar_like_y(y)
    ARMAModel(v, p, q, 0.0, ones(p)*0.3, ones(q)*0.3, 0.5, res, fit, -50.0, -100.0, -95.0, method, true, 10)
end
function estimate_arima(y, p, d, q; method=:css_mle)
    v, res, fit = _ar_like_y(y)
    ARIMAModel(v, v, p, d, q, 0.0, ones(max(p,1))*0.3, ones(max(q,1))*0.3, 0.5, res, fit, -50.0, -100.0, -95.0, method, true, 10)
end
function auto_arima(y; max_p=5, max_q=5, max_d=2, criterion=:bic, method=:mle)
    estimate_arima(y, 1, 1, 1; method=method)
end
function estimate_arfima(y, p, q; method=:css, d0=nothing, trunc=200, max_iter=500)
    v, res, fit = _ar_like_y(y)
    d = isnothing(d0) ? 0.3 : Float64(d0)
    phi = p > 0 ? ones(p) * 0.2 : Float64[]
    theta = q > 0 ? ones(q) * 0.1 : Float64[]
    ARFIMAModel(v, p, d, q, 0.0, phi, theta, 0.5, 0.05, res, fit,
                -50.0, -100.0, -95.0, method, true, 10)
end
function gph_test(y; m=:default, trim=0)
    n = length(vec(y))
    n < 8 && throw(ArgumentError("Series too short for GPH (n=$n)."))
    mm = m === :default ? floor(Int, sqrt(n)) : Int(m)
    GPHResult(0.3, 0.08, 3.75, 0.0002, mm, n, trim)
end
function local_whittle(y; m=:default)
    n = length(vec(y))
    n < 8 && throw(ArgumentError("Series too short for local Whittle (n=$n)."))
    mm = m === :default ? floor(Int, sqrt(n)) : Int(m)
    LocalWhittleResult(0.3, 0.06, 5.0, 1.0e-6, mm, n, -0.5)
end

ar_order(m::ARModel) = m.p;       ar_order(m::MAModel) = 0
ar_order(m::ARMAModel) = m.p;     ar_order(m::ARIMAModel) = m.p
ma_order(m::ARModel) = 0;         ma_order(m::MAModel) = m.q
ma_order(m::ARMAModel) = m.q;     ma_order(m::ARIMAModel) = m.q
diff_order(m::ARModel) = 0;       diff_order(m::MAModel) = 0
diff_order(m::ARMAModel) = 0;     diff_order(m::ARIMAModel) = m.d
aic(m::Union{ARModel,MAModel,ARMAModel,ARIMAModel}) = m.aic
bic(m::Union{ARModel,MAModel,ARMAModel,ARIMAModel}) = m.bic
# ARFIMA accessors (coef ordering [c, d, phi.., theta..], matching real MEMs)
ar_order(m::ARFIMAModel) = m.p
ma_order(m::ARFIMAModel) = m.q
diff_order(m::ARFIMAModel) = m.d
aic(m::ARFIMAModel) = m.aic
bic(m::ARFIMAModel) = m.bic
loglikelihood(m::ARFIMAModel) = m.loglik
coef(m::ARFIMAModel) = vcat(m.c, m.d, m.phi, m.theta)
stderror(m::ARFIMAModel) = fill(0.05, 2 + length(m.phi) + length(m.theta))
function forecast(m::Union{ARModel,MAModel,ARMAModel,ARIMAModel}, h::Int; conf_level=0.95)
    fc = ones(h) * 0.1
    ARIMAForecast(fc, fc .- 0.5, fc .+ 0.5, ones(h) * 0.1, h)
end

# Volatility model functions
estimate_arch(y, q) = ARCHModel(ones(q+2) * 0.1)
estimate_garch(y, p, q) = GARCHModel(ones(p+q+2) * 0.1)
estimate_egarch(y, p, q) = EGARCHModel(ones(2*q+p+2) * 0.1)
estimate_gjr_garch(y, p, q) = GJRGARCHModel(ones(2*q+p+2) * 0.1)
estimate_sv(y; n_samples=5000) = SVModel(ones(3) * 0.1)
coef(m::ARCHModel) = [m.mu, m.omega, m.alpha...]
coef(m::GARCHModel) = [m.mu, m.omega, m.alpha..., m.beta...]
coef(m::EGARCHModel) = [m.mu, m.omega, m.alpha..., m.gamma..., m.beta...]
coef(m::GJRGARCHModel) = [m.mu, m.omega, m.alpha..., m.gamma..., m.beta...]
coef(m::SVModel) = [mean(m.mu_post), mean(m.phi_post), mean(m.sigma_eta_post)]
persistence(m::Union{ARCHModel,GARCHModel,EGARCHModel,GJRGARCHModel,SVModel}) = 0.85
halflife(m::Union{GARCHModel,GJRGARCHModel}) = 4.3
unconditional_variance(m::Union{ARCHModel,GARCHModel}) = 0.02
function forecast(m::Union{ARCHModel,GARCHModel,EGARCHModel,GJRGARCHModel,SVModel}, h::Int)
    VolatilityForecast(ones(h) * 0.01, h)
end

# VAR forecast with bootstrap CI
function forecast(model::VARModel, h::Int; ci_method=:none, reps=500, conf_level=0.95)
    n = size(model.Y, 2)
    fc = ones(h, n) * 0.1
    VARForecast(fc, fc .- 0.5, fc .+ 0.5, h, ci_method, conf_level,
                ["var$i" for i in 1:n])
end

# Volatility test functions
arch_lm_test(y, lags) = (statistic=15.0, pvalue=0.01)
ljung_box_squared(y, lags) = (statistic=20.0, pvalue=0.005)

# ─── Multivariate GARCH functions (C064b) ────────────────
# Mirror the real _mgarch_validate, estimators, accessors, StatsAPI, and diagnostics so
# T1/T2 catch shape bugs in the wide correlation rendering + typed error mapping.
function _mock_mgarch_validate(Y)
    Ymat = Matrix{Float64}(Y)
    Tn, n = size(Ymat)
    n >= 2 || throw(ArgumentError("multivariate GARCH requires at least 2 series (got n=$n)"))
    Tn >= 2 || throw(ArgumentError("need at least 2 observations (got T=$Tn)"))
    all(isfinite, Ymat) || throw(ArgumentError("Y contains non-finite values"))
    return Ymat, Tn, n
end

# Build a plausible n×n correlation matrix (unit diagonal, 0.3 off-diagonal) and a
# unit-variance covariance path Hₜ = R.
function _mock_mgarch_RH(n::Int, Tn::Int)
    R = fill(0.3, n, n)
    for i in 1:n; R[i, i] = 1.0; end
    H = Array{Float64,3}(undef, n, n, Tn)
    for t in 1:Tn; H[:, :, t] .= R; end
    return R, H
end

function estimate_ccc(Y; p::Int=1, q::Int=1)
    Ymat, Tn, n = _mock_mgarch_validate(Y)
    R, H = _mock_mgarch_RH(n, Tn)
    margins = GARCHModel{Float64}[GARCHModel(ones(p + q + 2) * 0.1) for _ in 1:n]
    MGARCHModel{Float64}(Ymat, zeros(n), margins, H, R, R, Float64[], String[],
        fill(NaN, 0, 0), -300.0, 620.0, 640.0, :ccc, :none, :none, true, n)
end

function estimate_dcc(Y; p::Int=1, q::Int=1, correction::Symbol=:none)
    correction in (:none, :aielli) ||
        throw(ArgumentError("correction must be :none or :aielli, got :$correction"))
    Ymat, Tn, n = _mock_mgarch_validate(Y)
    R, H = _mock_mgarch_RH(n, Tn)
    margins = GARCHModel{Float64}[GARCHModel(ones(p + q + 2) * 0.1) for _ in 1:n]
    ab = [0.03, 0.95]
    MGARCHModel{Float64}(Ymat, zeros(n), margins, H, R, R, ab, ["a", "b"],
        Matrix{Float64}(0.0001I, 2, 2), -300.0, 620.0, 640.0, :dcc, correction, :none, true, n)
end

function estimate_bekk(Y; kind::Symbol=:scalar)
    kind in (:scalar, :diagonal) ||
        throw(ArgumentError("kind must be :scalar or :diagonal, got :$kind"))
    Ymat, Tn, n = _mock_mgarch_validate(Y)
    R, H = _mock_mgarch_RH(n, Tn)
    params, pnames = kind === :scalar ?
        ([0.05, 0.9], ["a", "b"]) :
        (vcat(fill(0.05, n), fill(0.9, n)), vcat(["a$i" for i in 1:n], ["b$i" for i in 1:n]))
    k = length(params)
    MGARCHModel{Float64}(Ymat, zeros(n), GARCHModel{Float64}[], H, R, R, params, pnames,
        Matrix{Float64}(0.0001I, k, k), -300.0, 620.0, 640.0, :bekk, :none, kind, true, n)
end

covariances(m::MGARCHModel) = m.H
function correlations(m::MGARCHModel)
    m.R isa Array{Float64,3} && return m.R
    Rc = m.R
    Tn = size(m.H, 3)
    out = Array{Float64,3}(undef, m.n, m.n, Tn)
    for t in 1:Tn; out[:, :, t] .= Rc; end
    return out
end
function variances(m::MGARCHModel)
    Tn = size(m.H, 3)
    out = Matrix{Float64}(undef, Tn, m.n)
    for t in 1:Tn, i in 1:m.n; out[t, i] = m.H[i, i, t]; end
    return out
end

coef(m::MGARCHModel) = m.params
loglikelihood(m::MGARCHModel) = m.loglik
nobs(m::MGARCHModel) = size(m.Y, 1)
function stderror(m::MGARCHModel)
    isempty(m.params) && return Float64[]
    V = m.param_vcov
    (size(V, 1) == length(m.params) && all(isfinite, V)) || return fill(NaN, length(m.params))
    return Float64[sqrt(max(V[i, i], 0.0)) for i in 1:length(m.params)]
end

# ─── Volatility residual diagnostics (C064b) ─────────────
function sign_bias_test(z::AbstractVector)
    length(z) < 10 && throw(ArgumentError("Need at least 10 observations for sign-bias test"))
    return (sign_bias=0.05, sign_bias_t=1.2, sign_bias_p=0.23,
            neg_size_t=-0.8, neg_size_p=0.42, pos_size_t=0.5, pos_size_p=0.62,
            joint_statistic=4.5, joint_pvalue=0.21, dof=3)
end
sign_bias_test(m::Union{GARCHModel,EGARCHModel,GJRGARCHModel}) =
    sign_bias_test(m.standardized_residuals)

nyblom_test(m::Union{GARCHModel,EGARCHModel,GJRGARCHModel}) =
    (individual=fill(0.3, 4), joint=0.8, k=4, cv_individual=0.470, cv_joint=1.24,
     param_names=["μ", "ω", "α1", "β1"])

# Non-Gaussian identification
function _mock_ica(model::VARModel, method_sym::Symbol)
    n = size(model.Y, 2); T_u = size(model.U, 1)
    ICASVARResult(ones(n,n)*0.3, ones(n,n)*0.3, Matrix{Float64}(I(n)),
                  ones(T_u, n)*0.1, method_sym, true, 50, 0.001)
end
identify_fastica(model::VARModel; contrast=:logcosh, max_iter=200, tol=1e-6) = _mock_ica(model, :fastica)
identify_jade(model::VARModel) = _mock_ica(model, :jade)
identify_sobi(model::VARModel) = _mock_ica(model, :sobi)
identify_dcov(model::VARModel) = _mock_ica(model, :dcov)
identify_hsic(model::VARModel) = _mock_ica(model, :hsic)

function _mock_ngml(model::VARModel, dist::Symbol)
    n = size(model.Y, 2); T_u = size(model.U, 1)
    NonGaussianMLResult(ones(n,n)*0.3, Matrix{Float64}(I(n)), ones(T_u, n)*0.1,
        dist, -200.0, -210.0, Dict{Symbol,Any}(:df => 5.0), ones(n,n)*0.01,
        ones(n*n)*0.05, -180.0, -175.0)
end
identify_nongaussian_ml(model::VARModel; distribution=:student_t, max_iter=500, tol=1e-6) = _mock_ngml(model, distribution)
identify_mixture_normal(model::VARModel) = _mock_ngml(model, :mixture_normal)
identify_pml(model::VARModel) = _mock_ngml(model, :pml)
identify_skew_normal(model::VARModel) = _mock_ngml(model, :skew_normal)

identify_markov_switching(model::VARModel; n_regimes=2, max_iter=200, tol=1e-6) =
    MarkovSwitchingSVARResult(ones(size(model.Y,2), size(model.Y,2))*0.3)
identify_garch(model::VARModel; max_iter=200, tol=1e-6) =
    GARCHSVARResult(ones(size(model.Y,2), size(model.Y,2))*0.3)
identify_smooth_transition(model::VARModel, transition_var; gamma=1.0, c=0.0) =
    SmoothTransitionSVARResult(ones(size(model.Y,2), size(model.Y,2))*0.3)
identify_external_volatility(model::VARModel, regime_indicator; regimes=2) =
    ExternalVolatilitySVARResult(ones(size(model.Y,2), size(model.Y,2))*0.3)

function normality_test_suite(model::VARModel)
    if _MOCK_FLAGS[:normality_all_pass]
        NormalityTestSuite([
            NormalityTestResult(:jarque_bera, 1.5, 0.47, 2),
            NormalityTestResult(:skewness, 0.8, 0.37, 1),
            NormalityTestResult(:kurtosis, 0.3, 0.58, 1),
        ])
    else
        NormalityTestSuite([
            NormalityTestResult(:jarque_bera, 15.0, 0.001, 2),
            NormalityTestResult(:skewness, 8.0, 0.02, 1),
            NormalityTestResult(:kurtosis, 3.0, 0.08, 1),
        ])
    end
end
test_identification_strength(model::VARModel) = (statistic=25.0, pvalue=0.001)
test_shock_gaussianity(result::ICASVARResult) = (statistic=12.0, pvalue=0.005)
test_shock_independence(result::ICASVARResult) = (statistic=3.0, pvalue=0.08)
test_overidentification(model::VARModel, result::ICASVARResult) = (statistic=1.5, pvalue=0.45)
test_overidentification(result::ICASVARResult) = (statistic=1.5, pvalue=0.45)
test_gaussian_vs_nongaussian(model::VARModel) = (statistic=18.0, pvalue=0.001)

# ─── VECM Functions ──────────────────────────────────────

function estimate_vecm(Y::AbstractMatrix, p::Int; rank=nothing, deterministic=:constant,
                       method=:johansen, significance=0.05)
    T_obs, n = size(Y)
    r = isnothing(rank) ? min(1, n - 1) : rank
    alpha = ones(n, r) * 0.1
    beta = ones(n, r) * 0.2
    Pi = alpha * beta'
    Gamma = [ones(n, n) * 0.05 for _ in 1:max(1, p - 1)]
    mu = zeros(n)
    U = zeros(T_obs - p, n) .+ 0.01
    Sigma = Matrix{Float64}(I(n)) * 0.01
    VECMModel(Y, p, r, alpha, beta, Pi, Gamma, mu, U, Sigma,
              -100.0, -95.0, -97.0, -500.0, deterministic, method)
end

select_vecm_rank(Y::AbstractMatrix, p::Int; criterion=:trace, significance=0.05) =
    min(1, size(Y, 2) - 1)

function to_var(vecm::VECMModel)
    _mock_var(vecm.Y, vecm.p)
end

cointegrating_rank(m::VECMModel) = m.rank
coef(m::VECMModel) = m.Pi
loglikelihood(m::VECMModel) = m.loglik
report(::VECMModel) = nothing

function forecast(vecm::VECMModel, h::Int; ci_method=:none, reps=500, conf_level=0.95)
    n = size(vecm.Y, 2)
    levels = ones(h, n) * 0.1
    diffs = ones(h, n) * 0.01
    has_ci = ci_method != :none
    VECMForecast(levels, diffs,
        has_ci ? levels .- 0.5 : nothing,
        has_ci ? levels .+ 0.5 : nothing,
        h, ci_method)
end

function granger_causality_vecm(vecm::VECMModel, cause::Int, effect::Int)
    VECMGrangerResult(
        8.5, 0.014, 2,   # short-run
        5.2, 0.023, 1,   # long-run
        12.3, 0.006, 3,  # strong (joint)
        cause, effect)
end

# ── VECM restriction tests (C071) ─────────────────────────
# Validate the same way real MEMs does (r≥1, matrix rows==nvars, s/a≥r, var range)
# so T1/T2 catch the bad-input→typed-error mapping; df formulas are faithful, other
# constants are placeholders (like arch_lm_test).
function _vecm_restriction_result(kind::Symbol, m::VECMModel, df::Int, desc::String;
                                  converged::Bool=true)
    r = m.rank
    VECMRestrictionTest(kind, 3.2, df, 0.36, r, desc,
        m.beta, m.beta, fill(0.3, r), fill(0.3, r), converged, m)
end

function test_beta_restriction(m::VECMModel, H::AbstractMatrix)
    n = nvars(m); r = m.rank
    r >= 1 || throw(ArgumentError("β restriction test requires cointegrating rank ≥ 1 (got r=$r)"))
    size(H, 1) == n || throw(DimensionMismatch("H must have $n rows (nvars), got $(size(H,1))"))
    s = size(H, 2)
    s >= r || throw(ArgumentError("H must have at least r=$r columns, got s=$s"))
    _vecm_restriction_result(:beta, m, r * (n - s), "β = Hφ (restricted to span(H), s=$s)")
end

function test_alpha_restriction(m::VECMModel, A::AbstractMatrix)
    n = nvars(m); r = m.rank
    r >= 1 || throw(ArgumentError("α restriction test requires cointegrating rank ≥ 1 (got r=$r)"))
    size(A, 1) == n || throw(DimensionMismatch("A must have $n rows (nvars), got $(size(A,1))"))
    a = size(A, 2)
    a >= r || throw(ArgumentError("A must have at least r=$r columns, got a=$a"))
    _vecm_restriction_result(:alpha, m, r * (n - a), "α = Aψ (restricted to span(A), a=$a)")
end

function test_weak_exogeneity(m::VECMModel, vars)
    n = nvars(m); r = m.rank
    r >= 1 || throw(ArgumentError("weak-exogeneity test requires cointegrating rank ≥ 1 (got r=$r)"))
    vv = vars isa Union{AbstractVector,Tuple} ? collect(vars) : [vars]
    ex_idx = Int[]
    for v in vv
        if v isa Integer
            push!(ex_idx, Int(v))
        else
            name = String(v)
            j = findfirst(==(name), m.varnames)
            j === nothing && throw(ArgumentError("Variable '$name' not found. Available: $(m.varnames)"))
            push!(ex_idx, j)
        end
    end
    all(1 .<= ex_idx .<= n) || throw(ArgumentError("variable index out of range 1:$n"))
    isempty(setdiff(1:n, ex_idx)) && throw(ArgumentError("cannot make all variables weakly exogenous"))
    labels = join([m.varnames[i] for i in ex_idx], ", ")
    _vecm_restriction_result(:weak_exogeneity, m, r * length(ex_idx),
        "Weak exogeneity of {$labels} (α rows = 0, df = r·m)")
end

function test_known_beta(m::VECMModel, b::AbstractMatrix)
    n = nvars(m); r = m.rank
    r >= 1 || throw(ArgumentError("known-β test requires cointegrating rank ≥ 1 (got r=$r)"))
    size(b, 1) == n || throw(DimensionMismatch("b must have $n rows (nvars), got $(size(b,1))"))
    size(b, 2) == r || throw(DimensionMismatch("b must have exactly r=$r columns, got $(size(b,2))"))
    _vecm_restriction_result(:known_beta, m, r * (n - r), "β = b (fully known cointegrating space)")
end

function test_joint_restriction(m::VECMModel, H::AbstractMatrix, A::AbstractMatrix;
                                maxiter::Int=1000, tol::Real=1e-8)
    n = nvars(m); r = m.rank
    r >= 1 || throw(ArgumentError("joint restriction test requires cointegrating rank ≥ 1 (got r=$r)"))
    size(H, 1) == n || throw(DimensionMismatch("H must have $n rows, got $(size(H,1))"))
    size(A, 1) == n || throw(DimensionMismatch("A must have $n rows, got $(size(A,1))"))
    s = size(H, 2); a = size(A, 2)
    (s >= r && a >= r) || throw(ArgumentError("need s ≥ r and a ≥ r (got s=$s, a=$a, r=$r)"))
    _vecm_restriction_result(:joint, m, r * (n - s) + r * (n - a),
        "Joint β=Hφ (s=$s), α=Aψ (a=$a) via switching")
end

# ─── Panel VAR Types ────────────────────────────────────────

struct PanelData{T<:Real}
    data::Matrix{T}; varnames::Vector{String}; group_id::Vector{Int}; time_id::Vector{Int}
    n_groups::Int; n_vars::Int; T_obs::Int; balanced::Bool
end

struct PVARModel{T<:Real}
    Phi::Matrix{T}; Sigma::Matrix{T}; se::Matrix{T}; pvalues::Matrix{T}
    m::Int; p::Int; method::Symbol; transformation::Symbol; steps::Symbol
    n_groups::Int; n_periods::Int; n_obs::Int; n_instruments::Int
end

struct PVARStability{T<:Real}
    eigenvalues::Vector{Complex{T}}; moduli::Vector{T}; is_stable::Bool
end

struct PVARTestResult{T<:Real}
    test_name::String; statistic::T; pvalue::T; df::Int; n_instruments::Int; n_params::Int
end

struct GrangerCausalityResult{T<:Real}
    statistic::T; pvalue::T; df::Int; test_type::Symbol; cause::String; effect::String
end

struct LRTestResult{T<:Real}
    statistic::T; pvalue::T; df::Int; loglik_restricted::T; loglik_unrestricted::T
end

struct LMTestResult{T<:Real}
    statistic::T; pvalue::T; df::Int; nobs::Int; score_norm::T
end

# ─── Panel VAR Functions ────────────────────────────────────

# MEMs 0.7.0 signature: xtset(df, group_col::Symbol, time_col::Symbol; ...).
# `df` is left untyped so the mock module needs no DataFrames import — column
# access dispatches on the passed DataFrame via Base (propertynames/size/getindex).
function xtset(df, group_col::Symbol, time_col::Symbol;
               varnames=nothing, frequency=nothing, tcode=nothing,
               desc="", vardesc=nothing, cohort=nothing)
    exclude = Set{Symbol}([group_col, time_col])
    cohort === nothing || push!(exclude, cohort)
    num_cols = [c for c in propertynames(df)
                if !(c in exclude) && eltype(df[!, c]) <: Union{Missing,Number}]
    n = length(num_cols)
    vn = varnames === nothing ? String[string(c) for c in num_cols] : Vector{String}(varnames)
    T_obs = size(df, 1)
    data = Matrix{Float64}(undef, T_obs, n)
    for (j, c) in enumerate(num_cols)
        col = df[!, c]
        for i in 1:T_obs
            v = col[i]
            data[i, j] = ismissing(v) ? NaN : Float64(v)
        end
    end
    raw_g = df[!, group_col]
    ug = unique(raw_g)
    gmap = Dict(g => i for (i, g) in enumerate(ug))
    gid = Int[gmap[g] for g in raw_g]
    raw_t = df[!, time_col]
    tid = eltype(raw_t) <: Integer ? Int.(raw_t) : begin
        ut = sort(unique(raw_t)); tmap = Dict(t => i for (i, t) in enumerate(ut))
        Int[tmap[t] for t in raw_t]
    end
    PanelData(data, vn, gid, tid, length(ug), n, T_obs, true)
end

isbalanced(pd::PanelData) = pd.balanced
ngroups(pd::PanelData) = pd.n_groups

# MEMs 0.7.0 kwargs (C054): system→system_instruments, dependent→dependent_vars,
# predetermined→predet_vars, exogenous→exog_vars. Kwargs enumerated (no catch-all)
# to stay within the check_mock_surface absorber budget.
function estimate_pvar(panel::PanelData, p::Int;
                       transformation=:fd, steps=:twostep, system_instruments=false,
                       collapse=false, dependent_vars=nothing,
                       predet_vars=String[], exog_vars=String[],
                       min_lag_endo=2, max_lag_endo=99)
    n = panel.n_vars
    k = n * p + 1
    Phi = ones(k, n) * 0.3
    Sigma = Matrix{Float64}(I(n)) * 0.01
    se = ones(k, n) * 0.05
    pvals = ones(k, n) * 0.02
    n_inst = system_instruments ? 2 * k : k + p
    PVARModel(Phi, Sigma, se, pvals, n, p, :gmm, transformation, steps,
              panel.n_groups, panel.T_obs ÷ panel.n_groups, panel.T_obs, n_inst)
end

function estimate_pvar_feols(panel::PanelData, p::Int;
                              dependent_vars=nothing, exog_vars=String[])
    n = panel.n_vars
    k = n * p + 1
    Phi = ones(k, n) * 0.25
    Sigma = Matrix{Float64}(I(n)) * 0.01
    se = ones(k, n) * 0.04
    pvals = ones(k, n) * 0.01
    PVARModel(Phi, Sigma, se, pvals, n, p, :feols, :fd, :onestep,
              panel.n_groups, panel.T_obs ÷ panel.n_groups, panel.T_obs, 0)
end

coef(m::PVARModel) = m.Phi
report(::PVARModel) = nothing

function pvar_oirf(model::PVARModel, horizon::Int)
    n = model.m
    vals = ones(horizon + 1, n, n) * 0.1
    ImpulseResponse(vals, nothing, nothing)
end

function pvar_girf(model::PVARModel, horizon::Int)
    n = model.m
    vals = ones(horizon + 1, n, n) * 0.12
    ImpulseResponse(vals, nothing, nothing)
end

# MEMs 0.7.0 (C054): kwargs n_boot→n_draws, conf_level→ci; returns a NamedTuple
# (irf, lower, upper, draws) of raw (H+1)×n×n arrays, not an ImpulseResponse.
function pvar_bootstrap_irf(model::PVARModel, horizon::Int;
                             n_draws=500, ci=0.95, irf_type=:oirf)
    n = model.m
    vals = ones(horizon + 1, n, n) * 0.1
    (irf=vals, lower=vals .- 0.5, upper=vals .+ 0.5,
     draws=ones(horizon + 1, n, n, n_draws) * 0.1)
end

# MEMs 0.7.0 (C054): returns a raw (H+1)×n×n array [horizon, variable, shock].
function pvar_fevd(model::PVARModel, horizon::Int)
    n = model.m
    ones(horizon + 1, n, n) / n
end

function pvar_stability(model::PVARModel)
    if _MOCK_FLAGS[:pvar_stable]
        eigs = [0.5 + 0.1im, 0.5 - 0.1im, 0.3 + 0.0im]
        moduli = abs.(eigs)
        PVARStability(eigs, moduli, true)
    else
        eigs = [1.2 + 0.0im, 0.5 - 0.1im, 0.3 + 0.0im]
        moduli = abs.(eigs)
        PVARStability(eigs, moduli, false)
    end
end

function pvar_hansen_j(model::PVARModel)
    PVARTestResult("Hansen J", 8.5, 0.38, model.n_instruments - model.m * model.p - model.m,
                   model.n_instruments, model.m * model.p + model.m)
end

# MEMs 0.7.0 (C054): pvar_mmsc is a single-model criterion (was a selection loop).
function pvar_mmsc(model::PVARModel; hq_criterion=2.1)
    (mbic=-100.0, maic=-110.0, mqic=-105.0)
end

# MEMs 0.7.0 (C054): returns (table, best_bic, best_aic, best_hqic, models);
# `.table` is a Matrix{Any} with columns [p, BIC, AIC, HQIC].
function pvar_lag_selection(panel::PanelData, max_p::Int; dependent_vars=nothing)
    tbl = Matrix{Any}(undef, max_p, 4)
    for p in 1:max_p
        tbl[p, 1] = p
        tbl[p, 2] = string(-100.0 + p)
        tbl[p, 3] = string(-110.0 + p)
        tbl[p, 4] = string(-105.0 + p)
    end
    (table=tbl, best_bic=1, best_aic=1, best_hqic=1, models=PVARModel[])
end

# Enhanced Granger causality for VAR
function granger_test(model::VARModel, cause::Int, effect::Int; lags=nothing)
    GrangerCausalityResult(12.5, 0.003, 2, :pairwise, "var$cause", "var$effect")
end

function granger_test_all(model::VARModel; lags=nothing)
    n = size(model.Y, 2)
    results = GrangerCausalityResult[]
    for i in 1:n, j in 1:n
        i == j && continue
        push!(results, GrangerCausalityResult(10.0 + i, 0.01, 2, :pairwise, "var$i", "var$j"))
    end
    results
end

# LR and LM tests
function lr_test(m_restricted::VARModel, m_unrestricted::VARModel)
    ll_r = -510.0
    ll_u = -500.0
    stat = 2 * (ll_u - ll_r)
    LRTestResult(stat, 0.02, 3, ll_r, ll_u)
end

function lm_test(m_restricted::VARModel, m_unrestricted::VARModel)
    LMTestResult(15.0, 0.005, 3, size(m_restricted.Y, 1), 3.87)
end

# ─── Filter Types & Functions ─────────────────────────────

struct HPFilterResult{T}
    trend::Vector{T}; cycle::Vector{T}; lambda::T; T_obs::Int
end

struct HamiltonFilterResult{T}
    trend::Vector{T}; cycle::Vector{T}; beta::Vector{T}; h::Int; p::Int; T_obs::Int; valid_range::UnitRange{Int}
end

struct BeveridgeNelsonResult{T}
    permanent::Vector{T}; transitory::Vector{T}; drift::T; long_run_multiplier::T; arima_order::Tuple{Int,Int,Int}; T_obs::Int
end

struct BaxterKingResult{T}
    cycle::Vector{T}; trend::Vector{T}; weights::Vector{T}; pl::Int; pu::Int; K::Int; T_obs::Int; valid_range::UnitRange{Int}
end

struct BoostedHPResult{T}
    trend::Vector{T}; cycle::Vector{T}; lambda::T; iterations::Int; stopping::Symbol; bic_path::Vector{T}; adf_pvalues::Vector{T}; T_obs::Int
end

trend(r::HPFilterResult) = r.trend
cycle(r::HPFilterResult) = r.cycle
trend(r::HamiltonFilterResult) = r.trend
cycle(r::HamiltonFilterResult) = r.cycle
trend(r::BeveridgeNelsonResult) = r.permanent
cycle(r::BeveridgeNelsonResult) = r.transitory
trend(r::BaxterKingResult) = r.trend
cycle(r::BaxterKingResult) = r.cycle
trend(r::BoostedHPResult) = r.trend
cycle(r::BoostedHPResult) = r.cycle

function hp_filter(y::AbstractVector; lambda=1600.0)
    T = length(y)
    t = cumsum(ones(T)) .* mean(y) / T
    c = y .- t
    HPFilterResult(t, c, Float64(lambda), T)
end

function hamilton_filter(y::AbstractVector; h=8, p=4)
    T = length(y)
    start = h + p
    valid = (start+1):T
    t = cumsum(ones(T)) .* mean(y) / T
    c = y .- t
    beta = ones(p + 1) * 0.1
    HamiltonFilterResult(t, c, beta, h, p, T, valid)
end

function beveridge_nelson(y::AbstractVector; p=:auto, q=:auto, max_terms=500, method=:arima)
    T = length(y)
    t = cumsum(ones(T)) .* mean(y) / T
    c = y .- t
    p_val = p == :auto ? 1 : p
    q_val = q == :auto ? 0 : q
    BeveridgeNelsonResult(t, c, 0.01, 1.5, (p_val, 0, q_val), T)
end

function baxter_king(y::AbstractVector; pl=6, pu=32, K=12)
    T = length(y)
    valid = (K+1):(T-K)
    t = cumsum(ones(T)) .* mean(y) / T
    c = y .- t
    weights = ones(2K + 1) / (2K + 1)
    BaxterKingResult(c, t, weights, pl, pu, K, T, valid)
end

function boosted_hp(y::AbstractVector; lambda=1600.0, stopping=:BIC, max_iter=100, sig_p=0.05)
    T = length(y)
    t = cumsum(ones(T)) .* mean(y) / T
    c = y .- t
    iters = 3
    bic_path = [10.0, 8.0, 9.0]
    adf_pvals = [0.5, 0.1, 0.01]
    BoostedHPResult(t, c, Float64(lambda), iters, stopping, bic_path, adf_pvals, T)
end

# ─── Exports ──────────────────────────────────────────────

export _MOCK_FLAGS
export VARModel, MockChains, BVARPosterior, MinnesotaHyperparameters
export ImpulseResponse, BayesianImpulseResponse, FEVD, BayesianFEVD
export HistoricalDecomposition, BayesianHistoricalDecomposition
export ZeroRestriction, SignRestriction, SVARRestrictions, AriasSVARResult, UhligSVARResult
export LPModel, LPIVModel, SmoothLPModel, StateLPModel, PropensityLPModel
export LPImpulseResponse, StructuralLP, LPFEVD, LPForecast
export FactorModel, DynamicFactorModel, GeneralizedDynamicFactorModel, FactorForecast
export ARModel, MAModel, ARMAModel, ARIMAModel, ARIMAForecast, ARFIMAModel
export ICASVARResult, NonGaussianMLResult
export MarkovSwitchingSVARResult, GARCHSVARResult, SmoothTransitionSVARResult, ExternalVolatilitySVARResult
export NormalityTestResult, NormalityTestSuite
export ADFResult, KPSSResult, PPResult, ZAResult, NgPerronResult, JohansenResult
export GPHResult, LocalWhittleResult
export GMMModel
export ARCHModel, GARCHModel, EGARCHModel, GJRGARCHModel, SVModel, VolatilityForecast
export VECMModel, VECMForecast, VECMGrangerResult, VECMRestrictionTest
export test_beta_restriction, test_alpha_restriction, test_weak_exogeneity
export test_known_beta, test_joint_restriction
export PanelData, PVARModel, PVARStability, PVARTestResult
export GrangerCausalityResult, LRTestResult, LMTestResult
export HPFilterResult, HamiltonFilterResult, BeveridgeNelsonResult, BaxterKingResult, BoostedHPResult

export select_lag_order, estimate_var, estimate_bvar, posterior_mean_model, posterior_median_model
export optimize_hyperparameters, coef, loglikelihood, stderror, predict, residuals, report
export is_stationary, companion_matrix, companion_matrix_factors, nvars
export irf, fevd, historical_decomposition, verify_decomposition, contribution
export cumulative_irf
export SignIdentifiedSet, identify_sign, irf_bounds, irf_median
export VARForecast
export zero_restriction, sign_restriction, identify_arias, irf_mean, identify_uhlig
export estimate_lp, lp_irf, estimate_lp_iv, lp_iv_irf, weak_instrument_test
export estimate_smooth_lp, smooth_lp_irf, cross_validate_lambda
export estimate_state_lp, state_irf, test_regime_difference
export estimate_propensity_lp, propensity_irf, propensity_diagnostics, doubly_robust_lp
export structural_lp, lp_fevd, forecast
export estimate_factors, ic_criteria, scree_plot_data
export estimate_dynamic_factors, ic_criteria_gdfm, estimate_gdfm, common_variance_share
export adf_test, kpss_test, pp_test, za_test, ngperron_test, johansen_test
export gph_test, local_whittle
export estimate_lp_gmm, gmm_summary, j_test
export estimate_ar, estimate_ma, estimate_arma, estimate_arima, auto_arima, estimate_arfima
export ar_order, ma_order, diff_order, aic, bic
export estimate_arch, estimate_garch, estimate_egarch, estimate_gjr_garch, estimate_sv
export persistence, halflife, unconditional_variance
export arch_lm_test, ljung_box_squared
export MGARCHModel, estimate_ccc, estimate_dcc, estimate_bekk
export covariances, correlations, variances, sign_bias_test, nyblom_test
export identify_fastica, identify_jade, identify_sobi, identify_dcov, identify_hsic
export identify_nongaussian_ml, identify_mixture_normal, identify_pml, identify_skew_normal
export identify_markov_switching, identify_garch, identify_smooth_transition, identify_external_volatility
export normality_test_suite, test_identification_strength, test_shock_gaussianity
export test_shock_independence, test_overidentification, test_gaussian_vs_nongaussian
export estimate_vecm, select_vecm_rank, to_var, cointegrating_rank, granger_causality_vecm
export xtset, isbalanced, ngroups, estimate_pvar, estimate_pvar_feols
export pvar_oirf, pvar_girf, pvar_bootstrap_irf, pvar_fevd, pvar_stability
export pvar_hansen_j, pvar_mmsc, pvar_lag_selection
export granger_test, granger_test_all, lr_test, lm_test
export hp_filter, hamilton_filter, beveridge_nelson, baxter_king, boosted_hp, trend, cycle

# ─── Data Module Types & Functions ────────────────────────

struct TimeSeriesData{T<:Real}
    data::Matrix{T}; varnames::Vector{String}; frequency::Symbol
    tcode::Vector{Int}; time_index::Vector{Int}; desc::String; vardesc::Vector{String}
end
# Keyword constructor matching MacroEconometricModels v0.2.2 interface
function TimeSeriesData(data::AbstractMatrix{T}; varnames=String[], frequency=:unknown,
                        tcode=fill(1, size(data, 2)), time_index=collect(1:size(data, 1)),
                        desc="", vardesc=fill("", size(data, 2)), source_refs=Symbol[]) where T<:Real
    TimeSeriesData{T}(Matrix{T}(data), varnames, frequency, tcode, time_index, desc, vardesc)
end

struct DataDiagnostic
    n_nan::Vector{Int}; n_inf::Vector{Int}; is_constant::Vector{Bool}
    is_short::Bool; is_clean::Bool
end

struct DataSummary{T<:Real}
    n::Int; mean::Vector{T}; std::Vector{T}; min::Vector{T}
    p25::Vector{T}; median::Vector{T}; p75::Vector{T}; max::Vector{T}
    skewness::Vector{T}; kurtosis::Vector{T}
end

function load_example(name::Symbol)
    if name == :fred_md
        n_vars = 126; T_obs = 804
        data = randn(T_obs, n_vars) .+ 1.0
        vn = ["INDPRO", "CPIAUCSL", "FEDFUNDS", ["var$i" for i in 4:n_vars]...]
        tc = vcat([5, 5, 1], [1 for _ in 4:n_vars])
        vd = vcat(["Industrial Production", "CPI All Urban", "Fed Funds Rate"],
                  ["Variable $i" for i in 4:n_vars])
        TimeSeriesData(data, vn, :monthly, tc, collect(1:T_obs),
            "FRED-MD Monthly Database (2024 vintage)", vd)
    elseif name == :fred_qd
        n_vars = 245; T_obs = 268
        data = randn(T_obs, n_vars) .+ 1.0
        vn = ["GDP", "PCECC96", ["var$i" for i in 3:n_vars]...]
        tc = vcat([5, 5], [1 for _ in 3:n_vars])
        vd = vcat(["Real GDP", "Real PCE"], ["Variable $i" for i in 3:n_vars])
        TimeSeriesData(data, vn, :quarterly, tc, collect(1:T_obs),
            "FRED-QD Quarterly Database", vd)
    elseif name == :pwt
        n_vars = 42; n_countries = 38; T_per = 74
        T_obs = n_countries * T_per
        data = randn(T_obs, n_vars) .+ 1.0
        vn = ["rgdpna", "pop", ["var$i" for i in 3:n_vars]...]
        group_ids = repeat(1:n_countries, inner=T_per)
        time_ids = repeat(1:T_per, outer=n_countries)
        PanelData(data, vn, group_ids, time_ids, n_countries, n_vars, T_obs, true)
    elseif name == :mpdta
        # Callaway-Sant'Anna (2021) minimum wage panel: 500 counties × 5 years × 3 vars
        n_groups = 500; n_years = 5; n_vars = 3
        T_obs = n_groups * n_years
        data = randn(T_obs, n_vars) .+ 1.0
        vn = ["lemp", "lpop", "first_treat"]
        group_ids = repeat(1:n_groups, inner=n_years)
        time_ids = repeat(2003:2007, outer=n_groups)
        PanelData(data, vn, group_ids, time_ids, n_groups, n_vars, T_obs, true)
    elseif name == :ddcg
        # Acemoglu et al. democracy-GDP panel: 184 countries × 51 years
        n_groups = 184; n_years = 51; n_vars = 5
        T_obs = n_groups * n_years
        data = randn(T_obs, n_vars) .+ 1.0
        vn = ["y", "dem", "tradewb", "lgdp", "lpop"]
        group_ids = repeat(1:n_groups, inner=n_years)
        time_ids = repeat(1960:2010, outer=n_groups)
        PanelData(data, vn, group_ids, time_ids, n_groups, n_vars, T_obs, true)
    elseif name == :wiot
        _mock_wiot()   # Miller & Blair (2009) IO fixture (defined below)
    else
        # Real load_example throws ArgumentError — match it so error-mapping is testable.
        throw(ArgumentError("Unknown dataset :$name. Available: fred_md, fred_qd, pwt, mpdta, ddcg, wiot"))
    end
end

to_matrix(d::TimeSeriesData) = d.data
to_matrix(d::PanelData) = d.data
varnames(d::TimeSeriesData) = d.varnames
varnames(d::PanelData) = d.varnames
frequency(d::TimeSeriesData) = d.frequency
desc(d::TimeSeriesData) = d.desc
vardesc(d::TimeSeriesData) = d.vardesc
nobs(d::TimeSeriesData) = size(d.data, 1)
nvars(d::TimeSeriesData) = size(d.data, 2)

function describe_data(d::TimeSeriesData)
    T_obs, n = size(d.data)
    m = vec(mean(d.data; dims=1))
    s = vec(std_mock(d.data))
    mn = vec(minimum(d.data; dims=1))
    mx = vec(maximum(d.data; dims=1))
    p25 = m .- 0.67 .* s
    med = copy(m)
    p75 = m .+ 0.67 .* s
    sk = fill(0.1, n)
    ku = fill(3.0, n)
    DataSummary(T_obs, m, s, mn, p25, med, p75, mx, sk, ku)
end

# Simple std without Distributions dependency
function std_mock(X::AbstractMatrix)
    T_obs = size(X, 1)
    m = mean(X; dims=1)
    sqrt.(sum((X .- m).^2; dims=1) ./ max(1, T_obs - 1))
end

function diagnose(d::TimeSeriesData)
    T_obs, n = size(d.data)
    n_nan = [count(isnan, d.data[:, i]) for i in 1:n]
    n_inf = [count(isinf, d.data[:, i]) for i in 1:n]
    is_const = [all(d.data[:, i] .== d.data[1, i]) for i in 1:n]
    is_short = T_obs < 30
    is_clean = all(n_nan .== 0) && all(n_inf .== 0) && !any(is_const) && !is_short
    DataDiagnostic(n_nan, n_inf, is_const, is_short, is_clean)
end

function fix(d::TimeSeriesData; method=:listwise)
    # Mock: return same data (pretend it was cleaned)
    TimeSeriesData(copy(d.data), d.varnames, d.frequency, d.tcode, d.time_index, d.desc, d.vardesc)
end

function apply_tcode(d::TimeSeriesData, codes::Vector{Int})
    # Mock: return same data (pretend transformations applied)
    TimeSeriesData(copy(d.data), d.varnames, d.frequency, codes, d.time_index, d.desc, d.vardesc)
end

function validate_for_model(d::TimeSeriesData, model_type::Symbol)
    n = nvars(d)
    T_obs = nobs(d)
    if model_type in (:arima, :arch, :garch, :egarch, :gjr_garch, :sv) && n > 1
        error("$model_type requires univariate data, got $n variables")
    end
    if T_obs < 10
        error("insufficient observations ($T_obs) for $model_type estimation")
    end
    nothing
end

function apply_filter(y::AbstractVector, method::Symbol; kwargs...)
    if method == :hp
        hp_filter(y; lambda=get(kwargs, :lambda, 1600.0))
    elseif method == :hamilton
        hamilton_filter(y; h=get(kwargs, :horizon, 8), p=get(kwargs, :lags, 4))
    elseif method == :bn
        beveridge_nelson(y)
    elseif method == :bk
        baxter_king(y; pl=get(kwargs, :pl, 6), pu=get(kwargs, :pu, 32), K=get(kwargs, :K, 12))
    elseif method == :bhp
        boosted_hp(y; lambda=get(kwargs, :lambda, 1600.0))
    else
        error("unknown filter method: $method")
    end
end

# ─── Plot Support ───────────────────────────────────────────

struct PlotOutput
    html::String
end

plot_result(x; kwargs...) = PlotOutput("<html><body>mock plot for $(typeof(x))</body></html>")
save_plot(p::PlotOutput, path::String) = (write(path, p.html); path)
display_plot(p::PlotOutput) = nothing  # no-op in tests

export PlotOutput, plot_result, save_plot, display_plot

# ─── Data Balance & Dates ────────────────────────────────────

function balance_panel(ts::TimeSeriesData; method::Symbol=:dfm, r::Int=3, p::Int=2)
    return ts  # mock returns unchanged
end

set_dates!(ts::TimeSeriesData, dt::AbstractVector{<:AbstractString}) = ts
dates(ts::TimeSeriesData) = String[]

export balance_panel, set_dates!, dates

# ─── Nowcast Types & Functions ──────────────────────────────

abstract type AbstractNowcastModel end

struct NowcastDFM{T<:AbstractFloat} <: AbstractNowcastModel
    X_sm::Matrix{T}; F::Matrix{T}; C::Matrix{T}; A::Matrix{T}; Q::Matrix{T}; R::Matrix{T}
    Mx::Vector{T}; Wx::Vector{T}; Z_0::Vector{T}; V_0::Matrix{T}
    r::Int; p::Int; blocks::Matrix{Int}; loglik::T; n_iter::Int
    nM::Int; nQ::Int; idio::Symbol; data::Matrix{T}
end

struct NowcastBVAR{T<:AbstractFloat} <: AbstractNowcastModel
    X_sm::Matrix{T}; beta::Matrix{T}; sigma::Matrix{T}
    lambda::T; theta::T; miu::T; alpha::T; lags::Int; loglik::T
    nM::Int; nQ::Int; data::Matrix{T}
end

struct NowcastBridge{T<:AbstractFloat} <: AbstractNowcastModel
    X_sm::Matrix{T}; Y_nowcast::Vector{T}; Y_individual::Matrix{T}; n_equations::Int
    coefficients::Vector{Vector{T}}; nM::Int; nQ::Int; lagM::Int; lagQ::Int; lagY::Int
    data::Matrix{T}
end

struct NowcastResult{T<:AbstractFloat}
    model::AbstractNowcastModel; X_sm::Matrix{T}; target_index::Int
    nowcast::T; forecast::T; method::Symbol
end

struct NowcastNews{T<:AbstractFloat}
    old_nowcast::T; new_nowcast::T; impact_news::Vector{T}; impact_revision::T
    impact_reestimation::T; group_impacts::Vector{T}; variable_names::Vector{String}
end

function nowcast_dfm(Y::AbstractMatrix, nM::Int, nQ::Int; r=2, p=1, idio=:ar1, blocks=nothing, max_iter=100, thresh=1e-4)
    T_obs, N = size(Y)
    sd = r * p
    NowcastDFM{Float64}(copy(Y), randn(T_obs, sd), randn(N, sd), randn(sd, sd),
        Matrix{Float64}(I(sd)), Matrix{Float64}(I(N)), zeros(N), ones(N),
        zeros(sd), Matrix{Float64}(I(sd)), r, p, ones(Int, N, 1), -100.0, 50, nM, nQ, idio, copy(Y))
end

function nowcast_bvar(Y::AbstractMatrix, nM::Int, nQ::Int; lags=5, kwargs...)
    T_obs, N = size(Y)
    NowcastBVAR{Float64}(copy(Y), randn(N*lags+1, N), Matrix{Float64}(I(N)),
        0.2, 1.0, 1.0, 2.0, lags, -100.0, nM, nQ, copy(Y))
end

function nowcast_bridge(Y::AbstractMatrix, nM::Int, nQ::Int; lagM=1, lagQ=1, lagY=1)
    T_obs, N = size(Y)
    nQ_act = max(nQ, 1)
    NowcastBridge{Float64}(copy(Y), randn(nQ_act), randn(nQ_act, max(nM, 1)),
        max(nM, 1), [randn(3) for _ in 1:max(nM, 1)], nM, nQ, lagM, lagQ, lagY, copy(Y))
end

function nowcast(model::AbstractNowcastModel; target_var=nothing)
    idx = isnothing(target_var) ? size(model.data, 2) : target_var
    NowcastResult{Float64}(model, model.X_sm, idx, 1.5, 1.2, :dfm)
end

function nowcast_news(X_new, X_old, model::AbstractNowcastModel, target_period; target_var=size(X_new, 2), groups=nothing)
    N = size(X_new, 2)
    NowcastNews{Float64}(1.0, 1.5, randn(N), 0.1, 0.05,
        isnothing(groups) ? randn(1) : randn(length(unique(groups))),
        ["var$i" for i in 1:N])
end

function forecast(model::AbstractNowcastModel, h::Int; target_var=nothing)
    N = size(model.data, 2)
    randn(h, N)
end

export AbstractNowcastModel, NowcastDFM, NowcastBVAR, NowcastBridge, NowcastResult, NowcastNews
export nowcast_dfm, nowcast_bvar, nowcast_bridge, nowcast, nowcast_news

export TimeSeriesData, DataDiagnostic, DataSummary
export load_example, to_matrix, varnames, frequency, desc, vardesc, nobs, nvars
export describe_data, diagnose, fix, apply_tcode, validate_for_model, apply_filter

# ─── DSGE Types ──────────────────────────────────────────────

abstract type AbstractDSGEModel end

struct DSGESpec{T<:Real}
    endog::Vector{Symbol}; exog::Vector{Symbol}; params::Vector{Symbol}
    param_values::Dict{Symbol,T}; n_endog::Int; n_exog::Int; n_params::Int
    varnames::Vector{String}; steady_state::Vector{T}
    linear::Bool
end
function DSGESpec(; n_endog=3, n_exog=1, linear::Bool=false, kwargs...)
    endog = [Symbol("y$i") for i in 1:n_endog]
    exog = [Symbol("e$i") for i in 1:n_exog]
    params = [:alpha, :beta, :delta]
    param_values = Dict{Symbol,Float64}(:alpha => 0.33, :beta => 0.99, :delta => 0.025)
    varnames = ["y$i" for i in 1:n_endog]
    ss = zeros(Float64, n_endog)
    DSGESpec{Float64}(endog, exog, params, param_values, n_endog, n_exog, length(params),
                      varnames, ss, linear)
end

# ── Mock @dsge macro (mirrors real MEMs' @dsge; C051/RA-DSGE loader) ────────
# The CLI loads RA DSGE models by evaluating an `@dsge begin … end` block (from a .jl
# file, or synthesized from TOML). Real MEMs parses the block into residual functions;
# the mock only needs the shape, so it counts endogenous/exogenous names and delegates
# to the keyword `DSGESpec` constructor. `linear: true` inside the block is honoured.
# Block line ASTs (see the real declaration syntax):
#   `endogenous: Y, C` → Expr(:tuple, Expr(:call, :(:), :endogenous, :Y), :C)
#   `exogenous: e`      → Expr(:call, :(:), :exogenous, :e)
#   `linear: true`      → Expr(:call, :(:), :linear, true)
function _mock_dsge_extract(block, kw::Symbol)
    (block isa Expr && block.head === :block) || return Any[]
    for arg in block.args
        arg isa Expr || continue
        if arg.head === :call && length(arg.args) == 3 && arg.args[1] === :(:) && arg.args[2] === kw
            return Any[arg.args[3]]
        end
        if arg.head === :tuple && !isempty(arg.args)
            f = arg.args[1]
            if f isa Expr && f.head === :call && length(f.args) == 3 &&
               f.args[1] === :(:) && f.args[2] === kw
                return vcat(Any[f.args[3]], arg.args[2:end])
            end
        end
    end
    return Any[]
end

macro dsge(block)
    ne = max(length(_mock_dsge_extract(block, :endogenous)), 1)
    nx = max(length(_mock_dsge_extract(block, :exogenous)), 1)
    lin_names = _mock_dsge_extract(block, :linear)
    is_linear = !isempty(lin_names) && lin_names[1] === true
    # Splice the constructor object so the expansion needs nothing in the caller's scope.
    return :($(DSGESpec)(; n_endog=$ne, n_exog=$nx, linear=$is_linear))
end

struct LinearDSGE{T<:Real}
    Gamma0::Matrix{T}; Gamma1::Matrix{T}; C::Vector{T}; Psi::Matrix{T}; Pi::Matrix{T}
    spec::DSGESpec{T}
end

struct DSGESolution{T<:Real}
    G1::Matrix{T}; impact::Matrix{T}; C_sol::Vector{T}; eu::Vector{Int}
    method::Symbol; eigenvalues::Vector{Complex{T}}; spec::DSGESpec{T}; linear::LinearDSGE{T}
end

struct PerturbationSolution{T<:Real}
    order::Int; gx::Matrix{T}; hx::Matrix{T}
    gxx::Union{Nothing,Array{T,3}}; hxx::Union{Nothing,Array{T,3}}
    gσσ::Union{Nothing,Vector{T}}; hσσ::Union{Nothing,Vector{T}}
    eta::Matrix{T}; steady_state::Vector{T}
    state_indices::Vector{Int}; control_indices::Vector{Int}
    eu::Vector{Int}; method::Symbol; spec::DSGESpec{T}; linear::LinearDSGE{T}
end

struct ProjectionSolution{T<:Real}
    coefficients::Matrix{T}; state_bounds::Matrix{T}; grid_type::Symbol; degree::Int
    residual_norm::T; converged::Bool; iterations::Int; method::Symbol
    spec::DSGESpec{T}; linear::LinearDSGE{T}; steady_state::Vector{T}
    state_indices::Vector{Int}; control_indices::Vector{Int}
end

struct PerfectForesightPath{T<:Real}
    path::Matrix{T}; deviations::Matrix{T}; converged::Bool; iterations::Int
    spec::DSGESpec{T}
end

struct DSGEEstimation{T<:Real} <: AbstractDSGEModel
    theta::Vector{T}; vcov::Matrix{T}; param_names::Vector{String}; method::Symbol
    J_stat::T; J_pvalue::T; converged::Bool; spec::DSGESpec{T}
end

struct OccBinConstraint{T<:Real}
    variable::Symbol; bound::T; direction::Symbol
end

struct NonlinearConstraint{T<:Real}
    fn::Function
    label::String
end

function nonlinear_constraint(fn::Function; label::String="")
    NonlinearConstraint{Float64}(fn, label)
end

struct OccBinSolution{T<:Real}
    linear_path::Matrix{T}; piecewise_path::Matrix{T}; steady_state::Vector{T}
    regime_history::Vector{Int}; converged::Bool; iterations::Int
    spec::DSGESpec{T}; varnames::Vector{String}
    constraints::Vector{OccBinConstraint{T}}
end

struct OccBinIRF{T<:Real}
    linear::Array{T,3}; piecewise::Array{T,3}; regime_history::Vector{Int}
    varnames::Vector{String}; shock_name::String
end

# ─── DSGE Mock Helpers & Functions ───────────────────────────

function _mock_linear(spec::DSGESpec{T}) where T
    n = spec.n_endog
    ne = spec.n_exog
    Gamma0 = Matrix{T}(I(n))
    Gamma1 = Matrix{T}(I(n)) * T(0.5)
    C_vec = zeros(T, n)
    Psi = zeros(T, n, ne)
    for i in 1:min(n, ne); Psi[i, i] = T(1.0); end
    Pi_mat = zeros(T, n, n)
    LinearDSGE{T}(Gamma0, Gamma1, C_vec, Psi, Pi_mat, spec)
end

function _mock_solution(spec::DSGESpec{T}; method=:gensys) where T
    n = spec.n_endog
    ne = spec.n_exog
    ld = _mock_linear(spec)
    G1 = Matrix{T}(I(n)) * T(0.5)
    impact = zeros(T, n, ne)
    for i in 1:min(n, ne); impact[i, i] = T(1.0); end
    C_sol = zeros(T, n)
    eu = [1, 1]
    eigs = [complex(T(0.5), T(0.1)), complex(T(0.5), T(-0.1)), complex(T(0.3), T(0.0))]
    DSGESolution{T}(G1, impact, C_sol, eu, method, eigs[1:min(n, length(eigs))], spec, ld)
end

function compute_steady_state(spec::DSGESpec; solver=nothing, constraints=[], kwargs...)
    spec
end

function linearize(spec::DSGESpec)
    _mock_linear(spec)
end

function solve(spec::DSGESpec{T}; method=:gensys, order=1, degree=5, grid=:auto, solver=nothing, constraints=[], kwargs...) where T
    n = spec.n_endog
    ne = spec.n_exog
    ld = _mock_linear(spec)
    if method == :perturbation
        n_states = max(1, n ÷ 2)
        n_controls = n - n_states
        gx = ones(T, n_controls, n_states) * T(0.1)
        hx = Matrix{T}(I(n_states)) * T(0.5)
        eta = zeros(T, n_states, ne)
        for i in 1:min(n_states, ne); eta[i, i] = T(1.0); end
        gxx = order >= 2 ? zeros(T, n_controls, n_states, n_states) : nothing
        hxx = order >= 2 ? zeros(T, n_states, n_states, n_states) : nothing
        gσσ = order >= 2 ? zeros(T, n_controls) : nothing
        hσσ = order >= 2 ? zeros(T, n_states) : nothing
        ss = zeros(T, n)
        state_idx = collect(1:n_states)
        control_idx = collect(n_states+1:n)
        return PerturbationSolution{T}(order, gx, hx, gxx, hxx, gσσ, hσσ, eta, ss,
            state_idx, control_idx, [1, 1], :perturbation, spec, ld)
    elseif method in (:projection, :pfi)
        n_states = max(1, n ÷ 2)
        n_controls = n - n_states
        coeffs = ones(T, n_controls, degree + 1) * T(0.1)
        bounds = hcat(fill(T(-2.0), n_states), fill(T(2.0), n_states))
        ss = zeros(T, n)
        state_idx = collect(1:n_states)
        control_idx = collect(n_states+1:n)
        return ProjectionSolution{T}(coeffs, bounds, grid == :auto ? :chebyshev : grid, degree,
            T(1e-8), true, 50, method, spec, ld, ss, state_idx, control_idx)
    else
        return _mock_solution(spec; method=method)
    end
end

function gensys(Γ0, Γ1, C, Ψ, Π)
    _mock_solution(DSGESpec())
end

function blanchard_kahn(ld::LinearDSGE, spec::DSGESpec)
    _mock_solution(spec; method=:blanchard_kahn)
end

function klein(Γ0, Γ1, C, Ψ, n_pre)
    _mock_solution(DSGESpec(); method=:klein)
end

function perturbation_solver(spec::DSGESpec; order=1)
    solve(spec; method=:perturbation, order=order)
end

function collocation_solver(spec::DSGESpec; degree=5, kwargs...)
    solve(spec; method=:projection, degree=degree)
end

function pfi_solver(spec::DSGESpec; kwargs...)
    solve(spec; method=:pfi)
end

function perfect_foresight(spec::DSGESpec{T}; shocks=nothing, T_periods=100, solver=nothing, constraints=[], kwargs...) where T
    n = spec.n_endog
    path = zeros(T, T_periods, n)
    devs = zeros(T, T_periods, n)
    PerfectForesightPath{T}(path, devs, true, 25, spec)
end

function occbin_solve(spec::DSGESpec{T}, shocks, constraints; T_periods=40, kwargs...) where T
    n = spec.n_endog
    lp = zeros(T, T_periods, n)
    pp = zeros(T, T_periods, n)
    ss = zeros(T, n)
    regimes = ones(Int, T_periods)
    cons = constraints isa Vector ? constraints : [constraints]
    OccBinSolution{T}(lp, pp, ss, regimes, true, 15, spec, spec.varnames, cons)
end

function occbin_irf(spec::DSGESpec{T}, constraints, shock_idx; shock_size=1.0, horizon=40, kwargs...) where T
    n = spec.n_endog
    ne = spec.n_exog
    lin = zeros(T, horizon + 1, n, ne)
    pw = zeros(T, horizon + 1, n, ne)
    # Set decaying response for shock_idx
    for h in 0:horizon
        for v in 1:n
            lin[h+1, v, min(shock_idx, ne)] = T(shock_size) * T(0.9)^h
            pw[h+1, v, min(shock_idx, ne)] = T(shock_size) * T(0.85)^h
        end
    end
    regimes = ones(Int, horizon + 1)
    OccBinIRF{T}(lin, pw, regimes, spec.varnames, "shock$shock_idx")
end

function parse_constraint(expr::String, spec::DSGESpec)
    nonlinear_constraint(x -> 0.0; label=expr)
end
function parse_constraint(expr, spec::DSGESpec)
    OccBinConstraint{Float64}(Symbol("x"), 0.0, :geq)
end

function variable_bound(var::Symbol; lower=-Inf, upper=Inf)
    if upper < Inf
        OccBinConstraint{Float64}(var, upper, :leq)
    else
        OccBinConstraint{Float64}(var, lower, :geq)
    end
end

function estimate_dsge(spec::DSGESpec{T}, data, param_names; method=:irf_matching, kwargs...) where T
    np = length(param_names)
    theta = ones(T, np) * T(0.5)
    vcov_mat = Matrix{T}(I(np)) * T(0.01)
    DSGEEstimation{T}(theta, vcov_mat, String.(param_names), method,
                      T(2.5), T(0.65), true, spec)
end

function simulate(sol::DSGESolution{T}, T_periods::Int; kwargs...) where T
    randn(T, T_periods, sol.spec.n_endog)
end
function simulate(sol::PerturbationSolution{T}, T_periods::Int; kwargs...) where T
    randn(T, T_periods, sol.spec.n_endog)
end
function simulate(sol::ProjectionSolution{T}, T_periods::Int; kwargs...) where T
    randn(T, T_periods, sol.spec.n_endog)
end

function irf(sol::DSGESolution{T}, horizon::Int; kwargs...) where T
    n = sol.spec.n_endog; ne = sol.spec.n_exog
    vals = zeros(T, horizon + 1, n, ne)
    for h in 0:horizon, v in 1:n, s in 1:ne
        vals[h+1, v, s] = T(0.1) * T(0.9)^h
    end
    ImpulseResponse(vals, nothing, nothing, horizon,
        sol.spec.varnames, ["shock$i" for i in 1:ne], :dsge)
end
function irf(sol::PerturbationSolution{T}, horizon::Int; kwargs...) where T
    n = sol.spec.n_endog; ne = sol.spec.n_exog
    vals = zeros(T, horizon + 1, n, ne)
    for h in 0:horizon, v in 1:n, s in 1:ne
        vals[h+1, v, s] = T(0.1) * T(0.9)^h
    end
    ImpulseResponse(vals, nothing, nothing, horizon,
        sol.spec.varnames, ["shock$i" for i in 1:ne], :perturbation)
end
function irf(sol::ProjectionSolution{T}, horizon::Int; kwargs...) where T
    n = sol.spec.n_endog; ne = sol.spec.n_exog
    vals = zeros(T, horizon + 1, n, ne)
    for h in 0:horizon, v in 1:n, s in 1:ne
        vals[h+1, v, s] = T(0.1) * T(0.9)^h
    end
    ImpulseResponse(vals, nothing, nothing, horizon,
        sol.spec.varnames, ["shock$i" for i in 1:ne], :projection)
end

function fevd(sol::DSGESolution{T}, horizon::Int; kwargs...) where T
    n = sol.spec.n_endog; ne = sol.spec.n_exog
    props = ones(T, n, ne, horizon) / T(ne)
    FEVD(props, props)
end
function fevd(sol::PerturbationSolution{T}, horizon::Int; unconditional::Bool=false, kwargs...) where T
    n = sol.spec.n_endog; ne = sol.spec.n_exog
    # Unconditional (order≥2) returns asymptotic H=1 proportions (MEMs Andreasen path)
    n_h = (unconditional && sol.order >= 2) ? 1 : horizon
    props = ones(T, n, ne, n_h) / T(ne)
    FEVD(props, props)
end

function is_determined(sol::Union{DSGESolution,PerturbationSolution,ProjectionSolution})
    true
end

function is_stable(sol::Union{DSGESolution,PerturbationSolution,ProjectionSolution})
    true
end

function nshocks(sol::Union{DSGESolution,PerturbationSolution,ProjectionSolution})
    sol.spec.n_exog
end

export AbstractDSGEModel, DSGESpec, LinearDSGE, DSGESolution, PerturbationSolution
export ProjectionSolution, PerfectForesightPath, DSGEEstimation
export OccBinConstraint, NonlinearConstraint, nonlinear_constraint, OccBinSolution, OccBinIRF
export compute_steady_state, linearize, solve, gensys, blanchard_kahn, klein
export perturbation_solver, collocation_solver, pfi_solver
export perfect_foresight, occbin_solve, occbin_irf, parse_constraint, variable_bound
export estimate_dsge, simulate, is_determined, is_stable, nshocks
export @dsge

# ─── SMM Types & Functions ───────────────────────────────────

struct SMMModel{T<:Real}
    theta::Vector{T}; vcov::Matrix{T}; n_moments::Int; n_params::Int; n_obs::Int
    J_stat::T; J_pvalue::T; converged::Bool; sim_ratio::Int
end

struct ParameterTransform{T<:Real}
    lower::Vector{T}; upper::Vector{T}
end

# Real MEMs 0.7.0 signature: estimate_smm(simulator_fn, moments_fn, theta0, data; ...).
# (Was 3-arg here, which hid the real command being broken — the exact panel/DiD-class
# blind spot. Keep this in lock-step with real so the T1/T2 mock can't mask arity drift.)
function estimate_smm(simulator_fn, moments_fn, theta0, data;
                      weighting=:two_step, sim_ratio=5, burn=100,
                      contributions_fn=nothing, bounds=nothing,
                      rng=nothing, kwargs...)
    np = length(theta0)
    m_data = moments_fn(data)
    nm = max(length(m_data), np)
    theta = Float64.(collect(theta0))
    vcov_mat = Matrix{Float64}(I(np)) * 0.01
    n_obs = size(data, 1)
    SMMModel{Float64}(theta, vcov_mat, nm, np, n_obs, 2.0, 0.7, true, sim_ratio)
end

function autocovariance_moments(data; lags=1)
    zeros(Float64, size(data, 2) * (lags + 1))
end

# Per-observation moment contributions (n × q); column-mean equals the moment vector.
function autocovariance_moment_contributions(data; lags=1)
    zeros(Float64, size(data, 1), size(data, 2) * (lags + 1))
end

# Real order is to_unconstrained(pt::ParameterTransform, theta); mock is order-agnostic.
to_unconstrained(t::ParameterTransform, x) = x
to_constrained(t::ParameterTransform, x) = x
transform_jacobian(t::ParameterTransform, x) = Matrix{Float64}(I(length(x)))

export SMMModel, ParameterTransform
export estimate_smm, autocovariance_moments, autocovariance_moment_contributions
export to_unconstrained, to_constrained, transform_jacobian

# ─── Systems: SUR & 3SLS (C063) ──────────────────────────────
# Fields match the real MEMs SURModel/ThreeSLSModel (system/types.jl). estimate_*
# compute genuine per-equation OLS so T1/T2 exercises the handler's table-shaping.
struct SURModel{T<:AbstractFloat}
    eqnames::Vector{String}
    varnames::Vector{Vector{String}}
    betas::Vector{Vector{T}}
    ses::Vector{Vector{T}}
    vcov_mat::Matrix{T}
    Sigma::Matrix{T}
    residuals::Vector{Vector{T}}
    fitted::Vector{Vector{T}}
    nobs::Int
    det_sigma::T
    mcelroy_r2::T
    loglik::T
    iterations::Int
    iterated::Bool
    restricted::Bool
end

struct ThreeSLSModel{T<:AbstractFloat}
    eqnames::Vector{String}
    varnames::Vector{Vector{String}}
    betas::Vector{Vector{T}}
    ses::Vector{Vector{T}}
    vcov_mat::Matrix{T}
    Sigma::Matrix{T}
    residuals::Vector{Vector{T}}
    fitted::Vector{Vector{T}}
    nobs::Int
    det_sigma::T
    mcelroy_r2::T
    n_instruments::Vector{Int}
end

# Per-equation OLS point estimates + textbook SEs (a stand-in for FGLS/3SLS; enough
# for T1/T2 to check the handler renders a well-formed per-(equation,term) table).
function _mock_system_fit(eqs::AbstractVector)
    M = length(eqs)
    betas = Vector{Vector{Float64}}(undef, M); ses = Vector{Vector{Float64}}(undef, M)
    vns = Vector{Vector{String}}(undef, M)
    resids = Vector{Vector{Float64}}(undef, M); fitted = Vector{Vector{Float64}}(undef, M)
    Tn = 0
    for (j, e) in enumerate(eqs)
        y = Float64.(collect(e[1])); X = Matrix{Float64}(e[2])
        Tn = length(y); k = size(X, 2)
        vns[j] = length(e) >= 3 ? String.(collect(e[3])) : ["eq$(j)_x$i" for i in 1:k]
        b = X \ y; r = y .- X * b
        s2 = sum(abs2, r) / max(Tn - k, 1)
        XtXinv = inv(X' * X)
        betas[j] = b
        ses[j] = [sqrt(abs(XtXinv[i, i]) * s2) for i in 1:k]
        resids[j] = r; fitted[j] = X * b
    end
    (betas, ses, vns, resids, fitted, Tn)
end

function estimate_sur(eqs::AbstractVector; iterate::Bool=false, tol::Real=1e-8,
                      maxiter::Int=100, restrict=nothing, eqnames=nothing)
    betas, ses, vns, resids, fitted, Tn = _mock_system_fit(eqs)
    M = length(eqs)
    enames = eqnames === nothing ? ["eq$(j)" for j in 1:M] : String.(collect(eqnames))
    K = sum(length(b) for b in betas)
    SURModel{Float64}(enames, vns, betas, ses, Matrix{Float64}(I(K)) .* 0.01,
                      Matrix{Float64}(I(M)), resids, fitted, Tn, 1.0, 0.8, -100.0,
                      iterate ? 3 : 1, iterate, restrict !== nothing)
end

function estimate_3sls(eqs::AbstractVector, Z; instruments::Symbol=:common, eqnames=nothing)
    instruments in (:common, :perequation) ||
        throw(ArgumentError("instruments must be :common or :perequation; got :$instruments"))
    betas, ses, vns, resids, fitted, Tn = _mock_system_fit(eqs)
    M = length(eqs)
    enames = eqnames === nothing ? ["eq$(j)" for j in 1:M] : String.(collect(eqnames))
    K = sum(length(b) for b in betas)
    ninstr = Z isa AbstractVector ? [size(Matrix{Float64}(z), 2) for z in Z] :
                                    fill(size(Matrix{Float64}(Z), 2), M)
    ThreeSLSModel{Float64}(enames, vns, betas, ses, Matrix{Float64}(I(K)) .* 0.01,
                           Matrix{Float64}(I(M)), resids, fitted, Tn, 1.0, 0.8, ninstr)
end

export SURModel, ThreeSLSModel, estimate_sur, estimate_3sls

# ─── Forecast evaluation & combination: fceval (C072) ────────
# Fields match the real MEMs fceval/types.jl. The estimate functions compute
# genuine simple metrics (RMSE=√mean(e²), OLS a/b, real combination weights) so
# T1/T2 exercises the handler's table-shaping; canned finite p-values suffice.
struct ForecastEvaluation{T<:AbstractFloat}
    models::Vector{String}
    metrics::Vector{String}
    values::Matrix{T}
    decomp::Matrix{T}
    n::Int
end

struct DMTestResult{T<:AbstractFloat}
    statistic::T
    pvalue::T
    dbar::T
    lrvar::T
    h::Int
    loss::Symbol
    hln::Bool
    alternative::Symbol
    T_obs::Int
end

struct ClarkWestResult{T<:AbstractFloat}
    statistic::T
    pvalue::T
    fbar::T
    lrvar::T
    h::Int
    alternative::Symbol
    T_obs::Int
end

struct MincerZarnowitzResult{T<:AbstractFloat}
    a::T
    b::T
    se::Vector{T}
    wald::T
    pvalue_wald::T
    fstat::T
    pvalue_f::T
    lags::Int
    kernel::Symbol
    T_obs::Int
end

struct ForecastEncompassingResult{T<:AbstractFloat}
    b1::T
    b2::T
    se_b2::T
    tstat::T
    pvalue::T
    lags::Int
    kernel::Symbol
    T_obs::Int
end

struct ForecastCombination{T<:AbstractFloat}
    weights::Vector{T}
    combined::Vector{T}
    method::Symbol
    mse::Vector{T}
    models::Vector{String}
end

const _MOCK_FCEVAL_METRICS = ["ME", "MAE", "RMSE", "MAPE", "sMAPE", "MASE", "U1", "U2"]

# Logistic approx to the standard-normal survival function P(Z > z) — for finite,
# monotone, in-(0,1) mock p-values (var/std/dot are not imported into this module).
_mock_pnorm_sf(z) = clamp(1.0 / (1.0 + exp(1.702 * z)), 0.0, 1.0)
_mock_var0(x) = mean(abs2, x .- mean(x))

function _mock_point_metrics(a::Vector{Float64}, f::Vector{Float64})
    tol = 1e-8
    e = a .- f
    me = mean(e); mae = mean(abs, e); mse = mean(abs2, e); rmse = sqrt(mse)
    mape_terms = Float64[abs(e[t] / a[t]) for t in eachindex(a) if abs(a[t]) > tol]
    mape = isempty(mape_terms) ? 0.0 : 100 * mean(mape_terms)
    smape_terms = Float64[2 * abs(e[t]) / (abs(a[t]) + abs(f[t])) for t in eachindex(a) if abs(a[t]) + abs(f[t]) > tol]
    smape = isempty(smape_terms) ? 0.0 : 100 * mean(smape_terms)
    da = diff(a)
    mase = mae / max(mean(abs, da), tol)
    u1 = rmse / max(sqrt(mean(abs2, a)) + sqrt(mean(abs2, f)), tol)
    u2 = rmse / max(sqrt(mean(abs2, da)), tol)
    vals = Float64[me, mae, rmse, mape, smape, mase, u1, u2]
    mf = mean(f); ma = mean(a)
    sf = sqrt(_mock_var0(f)); sa = sqrt(_mock_var0(a))
    bias = (mf - ma)^2 / max(mse, tol)
    varp = (sf - sa)^2 / max(mse, tol)
    covp = max(1.0 - bias - varp, 0.0)
    return vals, Float64[bias, varp, covp]
end

function forecast_evaluate(actual::AbstractVector, fc::AbstractVector;
                           seasonal_period::Int=1, insample=nothing, model_names=nothing)
    a = Float64.(collect(actual)); f = Float64.(collect(fc))
    v, d = _mock_point_metrics(a, f)
    names = model_names === nothing ? ["Model 1"] : String.(collect(model_names))
    ForecastEvaluation{Float64}(names, copy(_MOCK_FCEVAL_METRICS),
                                reshape(v, 1, :), reshape(d, 1, :), length(a))
end

function forecast_evaluate(actual::AbstractVector, fc::AbstractMatrix;
                           seasonal_period::Int=1, insample=nothing, model_names=nothing)
    a = Float64.(collect(actual)); M = size(fc, 2)
    K = length(_MOCK_FCEVAL_METRICS)
    vals = Matrix{Float64}(undef, M, K); decomp = Matrix{Float64}(undef, M, 3)
    for j in 1:M
        v, d = _mock_point_metrics(a, Float64.(collect(fc[:, j])))
        vals[j, :] = v; decomp[j, :] = d
    end
    names = model_names === nothing ? ["Model $j" for j in 1:M] : String.(collect(model_names))
    length(names) == M || throw(ArgumentError("model_names must have $M entries"))
    ForecastEvaluation{Float64}(names, copy(_MOCK_FCEVAL_METRICS), vals, decomp, length(a))
end

function diebold_mariano(e1::AbstractVector, e2::AbstractVector; h::Int=1, loss=:se,
                         hln::Bool=true, kernel::Symbol=:rectangular, alternative::Symbol=:two_sided)
    length(e1) == length(e2) || throw(DimensionMismatch("e1 and e2 must have equal length"))
    g = loss === :ad ? abs : (x -> x^2)
    d = Float64[g(Float64(e1[t])) - g(Float64(e2[t])) for t in eachindex(e1)]
    n = length(d); dbar = mean(d); V = max(_mock_var0(d), 1e-12)
    stat = dbar / sqrt(V / n)
    pval = alternative === :two_sided ? 2 * _mock_pnorm_sf(abs(stat)) :
           alternative === :greater   ? _mock_pnorm_sf(stat) :
                                         1.0 - _mock_pnorm_sf(stat)
    DMTestResult{Float64}(stat, clamp(pval, 0.0, 1.0), dbar, V, h,
                          loss isa Symbol ? loss : :custom, hln, alternative, n)
end

function clark_west(e_small::AbstractVector, e_big::AbstractVector, f_adj::AbstractVector;
                    h::Int=1, alternative::Symbol=:greater)
    n = length(e_small)
    (length(e_big) == n && length(f_adj) == n) ||
        throw(DimensionMismatch("e_small, e_big, f_adj must have equal length"))
    fhat = Float64[Float64(e_small[t])^2 - (Float64(e_big[t])^2 - Float64(f_adj[t])^2) for t in 1:n]
    fbar = mean(fhat); V = max(_mock_var0(fhat), 1e-12)
    stat = fbar / sqrt(V / n)
    pval = alternative === :two_sided ? 2 * _mock_pnorm_sf(abs(stat)) :
           alternative === :greater   ? _mock_pnorm_sf(stat) :
                                         1.0 - _mock_pnorm_sf(stat)
    ClarkWestResult{Float64}(stat, clamp(pval, 0.0, 1.0), fbar, V, h, alternative, n)
end

function mincer_zarnowitz(actual::AbstractVector, fc::AbstractVector; lags::Int=0, kernel::Symbol=:bartlett)
    y = Float64.(collect(actual)); n = length(y)
    X = hcat(ones(n), Float64.(collect(fc)))
    beta = (X' * X) \ (X' * y)
    u = y .- X * beta
    s2 = sum(abs2, u) / max(n - 2, 1)
    XtXinv = inv(X' * X)
    se = Float64[sqrt(abs(XtXinv[i, i]) * s2) for i in 1:2]
    a, b = beta[1], beta[2]
    dvec = Float64[a - 0.0, b - 1.0]
    wald = abs(dvec' * inv(XtXinv .* s2) * dvec)
    fstat = wald / 2
    pw = _mock_pnorm_sf(sqrt(max(wald, 0.0)))
    MincerZarnowitzResult{Float64}(a, b, se, wald, pw, fstat, pw, lags, kernel, n)
end

function forecast_encompassing(actual::AbstractVector, fc1::AbstractVector, fc2::AbstractVector;
                               lags::Int=0, kernel::Symbol=:bartlett)
    y = Float64.(collect(actual)); n = length(y)
    X = hcat(ones(n), Float64.(collect(fc1)), Float64.(collect(fc2)))
    beta = (X' * X) \ (X' * y)
    u = y .- X * beta
    s2 = sum(abs2, u) / max(n - 3, 1)
    XtXinv = inv(X' * X)
    se_b2 = sqrt(abs(XtXinv[3, 3]) * s2)
    b1, b2 = beta[2], beta[3]
    tstat = b2 / max(se_b2, 1e-12)
    pval = 2 * _mock_pnorm_sf(abs(tstat))
    ForecastEncompassingResult{Float64}(b1, b2, se_b2, tstat, clamp(pval, 0.0, 1.0), lags, kernel, n)
end

function combine_forecasts(F::AbstractMatrix, actual::AbstractVector; method::Symbol=:equal, model_names=nothing)
    method in (:equal, :bates_granger, :granger_ramanathan) ||
        throw(ArgumentError("method must be :equal, :bates_granger, or :granger_ramanathan; got :$method"))
    a = Float64.(collect(actual)); Fm = Matrix{Float64}(F); n, M = size(Fm)
    n == length(a) || throw(DimensionMismatch("F rows must match length(actual)"))
    mse = Float64[mean(abs2, a .- Fm[:, j]) for j in 1:M]
    w = if method === :equal
        fill(1.0 / M, M)
    elseif method === :bates_granger
        any(mse .<= 0) && throw(ArgumentError(":bates_granger requires strictly positive MSEs"))
        inv_mse = 1.0 ./ mse; inv_mse ./ sum(inv_mse)
    else
        Sigma = Fm' * Fm; c = Fm' * a; Sinv = inv(Sigma)
        Sc = Sinv * c; S1 = Sinv * ones(M)
        Sc .+ S1 .* ((1.0 - sum(Sc)) / sum(S1))
    end
    combined = Fm * w
    names = model_names === nothing ? ["Model $j" for j in 1:M] : String.(collect(model_names))
    length(names) == M || throw(ArgumentError("model_names must have $M entries"))
    ForecastCombination{Float64}(w, combined, method, mse, names)
end

export ForecastEvaluation, DMTestResult, ClarkWestResult, MincerZarnowitzResult,
       ForecastEncompassingResult, ForecastCombination
export forecast_evaluate, diebold_mariano, clark_west, mincer_zarnowitz,
       forecast_encompassing, combine_forecasts

# ─── C064a: univariate GARCH variants (igarch/cgarch/aparch/figarch/fiegarch/garch-midas) ───
# Minimal stand-ins for the MEMs 0.7.0 volatility variants (src/garch): enough fields
# for the estimate handlers' hand-built coef table + diagnostics kv. Field names/coef
# order mirror real; estimate_* compute plausible finite values from the series.
struct IGARCHModel{T<:Real}
    p::Int; q::Int; mu::T; omega::T; alpha::Vector{T}; beta::Vector{T}
    loglik::T; aic::T; bic::T; converged::Bool; iterations::Int
end
struct CGARCHModel{T<:Real}
    mu::T; omega::T; rho::T; phi::T; alpha::T; beta::T
    loglik::T; aic::T; bic::T; converged::Bool; iterations::Int
end
struct APARCHModel{T<:Real}
    p::Int; q::Int; mu::T; omega::T; alpha::Vector{T}; gamma::Vector{T}; beta::Vector{T}; delta::T
    n_params::Int; loglik::T; aic::T; bic::T; converged::Bool; iterations::Int
end
struct FIGARCHModel{T<:Real}
    p::Int; q::Int; mu::T; omega::T; phi::Vector{T}; beta::Vector{T}; d::T
    truncation::Int; n_neg_lambda::Int; loglik::T; aic::T; bic::T; converged::Bool; iterations::Int
end
struct FIEGARCHModel{T<:Real}
    p::Int; q::Int; mu::T; omega::T; theta::T; gamma::T; phi::Vector{T}; beta::Vector{T}; d::T
    truncation::Int; loglik::T; aic::T; bic::T; converged::Bool; iterations::Int
end
struct GarchMidasModel{T<:Real}
    mu::T; alpha::T; beta::T; m_const::T; theta::T; w::T
    variance_ratio::T; K::Int; m_freq::Int; n_blocks::Int; rv::Symbol; span::Symbol
    loglik::T; aic::T; bic::T; converged::Bool; iterations::Int
end

function estimate_igarch(y, p::Int=1, q::Int=1; method::Symbol=:mle)
    v = length(y) > 1 ? _mock_var0(Float64.(y)) : 1.0
    a = fill(0.1 / q, q); b = fill(0.9 / p, p)     # Σα+Σβ = 1 by construction
    IGARCHModel{Float64}(p, q, mean(y), 0.02 * v, a, b, -150.0, 306.0, 320.0, true, 45)
end
function estimate_cgarch(y; method::Symbol=:mle)
    v = length(y) > 1 ? _mock_var0(Float64.(y)) : 1.0
    CGARCHModel{Float64}(mean(y), v, 0.99, 0.05, 0.05, 0.85, -148.0, 308.0, 324.0, true, 60)
end
function estimate_aparch(y, p::Int=1, q::Int=1; fix_delta=nothing, fix_gamma=nothing, method::Symbol=:mle)
    v = length(y) > 1 ? _mock_var0(Float64.(y)) : 1.0
    a = fill(0.05, q); g = fill(0.1, q); b = fill(0.85 / p, p); delta = 1.5
    nfree = (3 + 2q + p) - (fix_delta === nothing ? 0 : 1) - (fix_gamma === nothing ? 0 : q)
    APARCHModel{Float64}(p, q, mean(y), (v^(delta / 2)) * 0.05, a, g, b, delta,
                         nfree, -147.0, 310.0, 330.0, true, 70)
end
function estimate_figarch(r; p::Int=1, q::Int=1, d0::Real=0.4, truncation::Int=1000, dist::Symbol=:normal)
    v = length(r) > 1 ? _mock_var0(Float64.(r)) : 1.0
    K = min(truncation, length(r) - 1)
    FIGARCHModel{Float64}(p, q, mean(r), 0.02 * v, fill(0.3 / q, q), fill(0.5 / p, p),
                          Float64(d0), K, 0, -149.0, 306.0, 322.0, true, 55)
end
function estimate_fiegarch(r; p::Int=1, q::Int=1, d0::Real=0.4, truncation::Int=1000, dist::Symbol=:normal)
    v = length(r) > 1 ? _mock_var0(Float64.(r)) : 1.0
    K = min(truncation, length(r) - 1)
    FIEGARCHModel{Float64}(p, q, mean(r), log(max(v, 1e-8)), -0.05, 0.1,
                           fill(0.3 / q, q), fill(0.5 / p, p), Float64(d0), K,
                           -146.0, 308.0, 328.0, true, 65)
end
function estimate_garch_midas(r, x_lf=Float64[]; K::Int=12, m_freq::Int, rv::Symbol=:realized, span::Symbol=:fixed)
    v = length(r) > 1 ? _mock_var0(Float64.(r)) : 1.0
    nblk = fld(length(r), max(m_freq, 1))
    GarchMidasModel{Float64}(mean(r), 0.05, 0.85, log(max(v, 1e-8)), 0.1, 3.0,
                             0.4, K, m_freq, nblk, rv, span, -145.0, 302.0, 320.0, true, 80)
end

coef(m::IGARCHModel) = vcat(m.mu, m.omega, m.alpha, m.beta)
coef(m::CGARCHModel) = [m.mu, m.omega, m.rho, m.phi, m.alpha, m.beta]
coef(m::APARCHModel) = vcat(m.mu, m.omega, m.alpha, m.gamma, m.beta, m.delta)
coef(m::FIGARCHModel) = vcat(m.mu, m.omega, m.phi, m.beta, m.d)
coef(m::FIEGARCHModel) = vcat(m.mu, m.omega, m.theta, m.gamma, m.phi, m.beta, m.d)
coef(m::GarchMidasModel) = [m.mu, m.alpha, m.beta, m.m_const, m.theta, m.w]

stderror(m::IGARCHModel) = fill(0.02, length(coef(m)))
stderror(m::CGARCHModel) = fill(0.02, length(coef(m)))
stderror(m::APARCHModel) = fill(0.02, length(coef(m)))
stderror(m::FIGARCHModel) = fill(0.02, length(coef(m)))
stderror(m::FIEGARCHModel) = fill(0.02, length(coef(m)))
stderror(m::GarchMidasModel) = fill(0.02, length(coef(m)))

loglikelihood(m::Union{IGARCHModel,CGARCHModel,APARCHModel,FIGARCHModel,FIEGARCHModel,GarchMidasModel}) = m.loglik
persistence(m::IGARCHModel) = 1.0
persistence(m::CGARCHModel) = m.rho
persistence(m::APARCHModel) = sum(m.beta) + sum(m.alpha)
persistence(m::FIGARCHModel) = m.d
persistence(m::FIEGARCHModel) = m.d
persistence(m::GarchMidasModel) = m.alpha + m.beta
unconditional_variance(m::CGARCHModel) = m.omega
component_variances(m::CGARCHModel) =
    (permanent=fill(m.omega, 3), transitory=fill(0.0, 3), total=fill(m.omega, 3))

export IGARCHModel, CGARCHModel, APARCHModel, FIGARCHModel, FIEGARCHModel, GarchMidasModel
export estimate_igarch, estimate_cgarch, estimate_aparch, estimate_figarch,
       estimate_fiegarch, estimate_garch_midas
export component_variances

# ─── C067a: penalized & limited-dependent cross-section regression ──────────
# PenalizedRegModel (lasso/ridge/elastic-net), RobustRegModel, TobitModel — faithful
# to real MEMs 0.7.0 src/reg/{penalized,robust,tobit}. Genuine OLS/ridge fits so T1/T2
# catch shape bugs. `coef(::PenalizedRegModel)=beta` but stderror is DELIBERATELY not
# defined (mirrors the real MethodError → the CLI uses `_penalized_coef_table`).

struct PenalizedRegModel{T<:Real}
    y::Vector{T}
    X::Matrix{T}
    beta::Vector{T}
    beta0::T
    alpha::T
    lambda::T
    active_set::Vector{Int}
    df_star::T
    r2::T
    aic::T
    bic::T
    ebic::T
    lambda_min::T
    lambda_1se::T
    select::Symbol
    varnames::Vector{String}
end

struct RobustRegModel{T<:Real}
    y::Vector{T}
    X::Matrix{T}
    beta::Vector{T}
    vcov_mat::Matrix{T}
    scale::T
    weights::Vector{T}
    residuals::Vector{T}
    fitted::Vector{T}
    psi::Symbol
    method::Symbol
    tuning::T
    robust_r2::T
    varnames::Vector{String}
    converged::Bool
    iterations::Int
end

struct TobitModel{T<:Real}
    y::Vector{T}
    X::Matrix{T}
    beta::Vector{T}
    sigma::T
    vcov_mat::Matrix{T}
    sigma_se::T
    residuals::Vector{T}
    fitted::Vector{T}
    loglik::T
    aic::T
    bic::T
    lower::T
    upper::T
    n_censored_left::Int
    n_censored_right::Int
    dist::Symbol
    varnames::Vector{String}
    method::Symbol
    converged::Bool
end

# C067b: truncated-normal regression (mirror of the real TruncRegModel fields).
struct TruncRegModel{T<:Real}
    y::Vector{T}
    X::Matrix{T}
    beta::Vector{T}
    sigma::T
    vcov_mat::Matrix{T}
    sigma_se::T
    residuals::Vector{T}
    fitted::Vector{T}
    loglik::T
    aic::T
    bic::T
    lower::T
    upper::T
    n_truncated::Int
    dist::Symbol
    varnames::Vector{String}
    method::Symbol
    converged::Bool
end

# C067b: Heckman sample-selection model (mirror of the real HeckmanModel fields).
struct HeckmanModel{T<:Real}
    beta::Vector{T}
    vcov_beta::Matrix{T}
    outcome_names::Vector{String}
    gamma::Vector{T}
    vcov_gamma::Matrix{T}
    select_names::Vector{String}
    rho::T
    sigma::T
    lambda::T
    rho_se::T
    sigma_se::T
    lambda_se::T
    mills::Vector{T}
    method::Symbol
    loglik::T
    aic::T
    bic::T
    n_selected::Int
    n_total::Int
    y::Vector{T}
    X::Matrix{T}
    converged::Bool
end

# Faithful validation + genuine fit so shape/argument bugs surface in T1/T2.
function estimate_elastic_net(y::AbstractVector, X::AbstractMatrix;
                              alpha::Real=1.0, lambda=:cv, select::Symbol=:cv,
                              cv::Symbol=:kfold, nfolds::Int=10, standardize::Bool=true,
                              varnames=nothing, seed::Int=1234, kwargs...)
    n, p = size(X)
    length(y) == n || throw(ArgumentError("y has length $(length(y)); X has $n rows"))
    n > 1 || throw(ArgumentError("need n > 1"))
    (0 <= alpha <= 1) || throw(ArgumentError("alpha must be in [0,1]; got $alpha"))
    select in (:cv, :aic, :bic, :ebic) ||
        throw(ArgumentError("select must be :cv, :aic, :bic, or :ebic; got :$select"))
    yv = Vector{Float64}(y); Xm = Matrix{Float64}(X)
    λ = lambda isa Real ? Float64(lambda) : 0.1
    beta = (Xm'Xm + λ * Matrix{Float64}(I(p))) \ (Xm'yv)
    beta0 = mean(yv) - sum(vec(mean(Xm; dims=1)) .* beta)
    fitted = beta0 .+ Xm * beta
    resid = yv .- fitted
    ssr = sum(abs2, resid); tss = max(sum(abs2, yv .- mean(yv)), eps())
    r2 = 1.0 - ssr / tss
    vn = varnames === nothing ? ["x$j" for j in 1:p] : Vector{String}(varnames)
    PenalizedRegModel{Float64}(yv, Xm, beta, beta0, Float64(alpha), λ,
                               findall(!=(0.0), beta), Float64(count(!=(0.0), beta)),
                               r2, -120.0, -100.0, -95.0, λ, 2λ, select, vn)
end
# Explicit kwargs (not a `; kwargs...` absorber) — keeps the mock-surface budget flat.
estimate_lasso(y, X; lambda=:cv, select::Symbol=:cv, varnames=nothing) =
    estimate_elastic_net(y, X; alpha=1.0, lambda=lambda, select=select, varnames=varnames)
estimate_ridge(y, X; lambda=:cv, select::Symbol=:cv, varnames=nothing) =
    estimate_elastic_net(y, X; alpha=0.0, lambda=lambda, select=select, varnames=varnames)

function estimate_robust(y::AbstractVector, X::AbstractMatrix;
                         psi::Symbol=:huber, method::Symbol=:m, maxiter::Int=50,
                         tol::Real=1e-6, varnames=nothing, kwargs...)
    n = length(y); p = size(X, 2)
    size(X, 1) == n || throw(ArgumentError("X must have $n rows (got $(size(X, 1)))"))
    n > p || throw(ArgumentError("Need n > p (n=$n, p=$p)"))
    method in (:m, :mm) || throw(ArgumentError("method must be :m or :mm; got :$method"))
    psi in (:huber, :bisquare) ||
        throw(ArgumentError("psi must be :huber or :bisquare; got :$psi"))
    yv = Vector{Float64}(y); Xm = Matrix{Float64}(X)
    beta = Xm \ yv
    fitted = Xm * beta; resid = yv .- fitted
    s2 = sum(abs2, resid) / max(n - p, 1)
    vcov_mat = s2 .* ((Xm'Xm) \ Matrix{Float64}(I(p)))
    tss = max(sum(abs2, yv .- mean(yv)), eps())
    vn = varnames === nothing ? ["x$j" for j in 1:p] : Vector{String}(varnames)
    RobustRegModel{Float64}(yv, Xm, beta, vcov_mat, sqrt(max(s2, 0.0)),
                            ones(Float64, n), resid, fitted, psi, method,
                            psi === :huber ? 1.345 : 4.685,
                            1.0 - sum(abs2, resid) / tss, vn, true, 8)
end

function estimate_tobit(y::AbstractVector, X::AbstractMatrix;
                        lower::Real=0.0, upper::Real=Inf, dist::Symbol=:normal,
                        varnames=nothing, kwargs...)
    n = length(y); k = size(X, 2)
    size(X, 1) == n || throw(ArgumentError("X must have $n rows (got $(size(X, 1)))"))
    n > k || throw(ArgumentError("Need n > k (n=$n, k=$k)"))
    lower < upper || throw(ArgumentError("lower ($lower) must be < upper ($upper)"))
    dist in (:normal, :logistic, :extreme_value) ||
        throw(ArgumentError("dist must be :normal, :logistic, or :extreme_value; got :$dist"))
    yv = Vector{Float64}(y); Xm = Matrix{Float64}(X)
    beta = Xm \ yv
    fitted = Xm * beta; resid = yv .- fitted
    s2 = sum(abs2, resid) / max(n - k, 1); sigma = sqrt(max(s2, eps()))
    vcov_mat = s2 .* ((Xm'Xm) \ Matrix{Float64}(I(k)))
    nL = isfinite(lower) ? count(<=(Float64(lower)), yv) : 0
    nR = isfinite(upper) ? count(>=(Float64(upper)), yv) : 0
    vn = varnames === nothing ? ["x$j" for j in 1:k] : Vector{String}(varnames)
    TobitModel{Float64}(yv, Xm, beta, sigma, vcov_mat, sigma / sqrt(2n), resid, fitted,
                        -110.0, 230.0, 245.0, Float64(lower), Float64(upper),
                        nL, nR, dist, vn, :normal, true)
end

# C067b: truncated regression — validates like real (every y strictly inside (lower,upper)).
function estimate_truncreg(y::AbstractVector, X::AbstractMatrix;
                           lower::Real=0.0, upper::Real=Inf, varnames=nothing,
                           maxiter::Int=1000, tol::Real=1e-10)
    n = length(y); k = size(X, 2)
    size(X, 1) == n || throw(ArgumentError("X must have $n rows (got $(size(X, 1)))"))
    n > k || throw(ArgumentError("Need n > k (n=$n, k=$k)"))
    L = Float64(lower); U = Float64(upper)
    L < U || throw(ArgumentError("lower ($L) must be < upper ($U)"))
    yv = Vector{Float64}(y); Xm = Matrix{Float64}(X)
    all(yi -> L < yi < U, yv) ||
        throw(ArgumentError("truncated regression requires every y strictly inside (lower, upper)"))
    beta = Xm \ yv
    fitted = Xm * beta; resid = yv .- fitted
    s2 = sum(abs2, resid) / max(n - k, 1); sigma = sqrt(max(s2, eps()))
    vcov_mat = s2 .* ((Xm'Xm) \ Matrix{Float64}(I(k)))
    vn = varnames === nothing ? ["x$j" for j in 1:k] : Vector{String}(varnames)
    TruncRegModel{Float64}(yv, Xm, beta, sigma, vcov_mat, sigma / sqrt(2n), resid, fitted,
                           -108.0, 226.0, 241.0, L, U, n, :normal, vn, :truncreg, true)
end

# C067b: Heckman selection — probit-ish selection γ + OLS-on-selected outcome β; validates
# sizes / binary d / enough selected obs like the real two-step estimator.
function estimate_heckman(y::AbstractVector, X::AbstractMatrix, d::AbstractVector,
                          Z::AbstractMatrix; method::Symbol=:twostep,
                          outcome_names=nothing, select_names=nothing,
                          maxiter::Int=1000, tol::Real=1e-10)
    method in (:twostep, :mle) ||
        throw(ArgumentError("method must be :twostep or :mle; got :$method"))
    n = length(y)
    size(X, 1) == n || throw(ArgumentError("X must have $n rows (got $(size(X, 1)))"))
    size(Z, 1) == n || throw(ArgumentError("Z must have $n rows (got $(size(Z, 1)))"))
    length(d) == n || throw(ArgumentError("d must have length $n (got $(length(d)))"))
    k = size(X, 2); p = size(Z, 2)
    dv = Vector{Float64}(float.(d))
    all(v -> v == 0.0 || v == 1.0, dv) ||
        throw(ArgumentError("selection indicator d must be binary (0/1)"))
    sel = findall(==(1.0), dv); n1 = length(sel)
    n1 > k + 1 || throw(ArgumentError("need more selected obs than outcome params (n_sel=$n1, k=$k)"))
    Xm = Matrix{Float64}(X); Zm = Matrix{Float64}(Z); yv = Vector{Float64}(y)
    all(isfinite, yv[sel]) || throw(ArgumentError("y has non-finite values among selected observations"))
    γ = Zm \ dv
    Vγ = ((Zm'Zm) \ Matrix{Float64}(I(p)))
    Xs = Xm[sel, :]; ys = yv[sel]
    β = Xs \ ys
    resid = ys .- Xs * β
    s2 = sum(abs2, resid) / max(n1 - k, 1); σ = sqrt(max(s2, eps()))
    Vβ = s2 .* ((Xs'Xs) \ Matrix{Float64}(I(k)))
    on = outcome_names === nothing ? ["x$j" for j in 1:k] : Vector{String}(outcome_names)
    sn = select_names === nothing ? ["z$j" for j in 1:p] : Vector{String}(select_names)
    ρ = 0.3; λ = ρ * σ
    HeckmanModel{Float64}(β, Vβ, on, γ, Vγ, sn, ρ, σ, λ, 0.1, σ / sqrt(2n1), 0.15,
                          zeros(Float64, n1), method, -150.0, 310.0, 330.0, n1, n, ys, Xs, true)
end

# coef/stderror: PenalizedRegModel exposes only coef (stderror undefined → MethodError,
# mirroring real MEMs). Robust/Tobit/TruncReg expose both (sqrt of the vcov diagonal);
# Heckman's coef/stderror are the OUTCOME equation (mirrors real StatsAPI dispatch).
coef(m::PenalizedRegModel) = m.beta
coef(m::RobustRegModel) = m.beta
coef(m::TobitModel) = m.beta
coef(m::TruncRegModel) = m.beta
coef(m::HeckmanModel) = m.beta
stderror(m::RobustRegModel) = [sqrt(max(m.vcov_mat[i, i], 0.0)) for i in 1:length(m.beta)]
stderror(m::TobitModel) = [sqrt(max(m.vcov_mat[i, i], 0.0)) for i in 1:length(m.beta)]
stderror(m::TruncRegModel) = [sqrt(max(m.vcov_mat[i, i], 0.0)) for i in 1:length(m.beta)]
stderror(m::HeckmanModel) = [sqrt(max(m.vcov_beta[i, i], 0.0)) for i in 1:length(m.beta)]

export PenalizedRegModel, RobustRegModel, TobitModel, TruncRegModel, HeckmanModel
export estimate_lasso, estimate_ridge, estimate_elastic_net, estimate_robust, estimate_tobit
export estimate_truncreg, estimate_heckman

# ─── BVARForecast Type & Forecast Accessors ──────────────────

struct BVARForecast{T<:AbstractFloat}
    forecast::Matrix{T}
    ci_lower::Matrix{T}
    ci_upper::Matrix{T}
    horizon::Int
    conf_level::T
    point_estimate::Symbol
    varnames::Vector{String}
end

point_forecast(f::Union{VARForecast,BVARForecast}) = f.forecast
lower_bound(f::Union{VARForecast,BVARForecast}) = f.ci_lower
upper_bound(f::Union{VARForecast,BVARForecast}) = f.ci_upper
forecast_horizon(f::Union{VARForecast,BVARForecast}) = f.horizon

# long_table — tidy/long view mirroring real MEMs (#346): array-valued results render
# as `horizon | variable | value | lower | upper` (lower/upper missing when ci_method==:none).
function long_table(f::VARForecast)
    H, nv = size(f.forecast)
    vn = length(f.varnames) == nv ? f.varnames : ["y$i" for i in 1:nv]
    has_ci = f.ci_method != :none
    horizon = Int[]; variable = String[]
    value = Float64[]; lower = Union{Missing,Float64}[]; upper = Union{Missing,Float64}[]
    for h in 1:H, v in 1:nv
        push!(horizon, h); push!(variable, vn[v]); push!(value, f.forecast[h, v])
        push!(lower, has_ci ? f.ci_lower[h, v] : missing)
        push!(upper, has_ci ? f.ci_upper[h, v] : missing)
    end
    return DataFrame(; horizon, variable, value, lower, upper)
end

function long_table(irf::ImpulseResponse)
    H = size(irf.values, 1); nv = length(irf.variables); ns = length(irf.shocks)
    has_ci = irf.ci_type != :none && irf.ci_lower !== nothing
    horizon = Int[]; variable = String[]; shock = String[]
    value = Float64[]; lower = Union{Missing,Float64}[]; upper = Union{Missing,Float64}[]
    for h in 1:H, v in 1:nv, s in 1:ns
        push!(horizon, h); push!(variable, irf.variables[v]); push!(shock, irf.shocks[s])
        push!(value, irf.values[h, v, s])
        push!(lower, has_ci ? irf.ci_lower[h, v, s] : missing)
        push!(upper, has_ci ? irf.ci_upper[h, v, s] : missing)
    end
    return DataFrame(; horizon, variable, shock, value, lower, upper)
end

function long_table(f::FEVD)
    nv, ns, H = size(f.proportions)     # (variable, shock, horizon)
    horizon = Int[]; variable = String[]; shock = String[]; value = Float64[]
    for h in 1:H, v in 1:nv, s in 1:ns
        push!(horizon, h); push!(variable, f.variables[v]); push!(shock, f.shocks[s])
        push!(value, f.proportions[v, s, h])
    end
    return DataFrame(; horizon, variable, shock, value)
end

function long_table(irf::BayesianImpulseResponse)
    H = size(irf.point_estimate, 1); nv = length(irf.variables); ns = length(irf.shocks)
    nq = size(irf.quantiles, 4)
    horizon = Int[]; variable = String[]; shock = String[]
    value = Float64[]; lower = Union{Missing,Float64}[]; upper = Union{Missing,Float64}[]
    for h in 1:H, v in 1:nv, s in 1:ns
        push!(horizon, h); push!(variable, irf.variables[v]); push!(shock, irf.shocks[s])
        push!(value, irf.point_estimate[h, v, s])
        push!(lower, nq > 0 ? irf.quantiles[h, v, s, 1] : missing)
        push!(upper, nq > 0 ? irf.quantiles[h, v, s, nq] : missing)
    end
    return DataFrame(; horizon, variable, shock, value, lower, upper)
end

# Shared tidy builder for AbstractForecastResult-style types → horizon|variable|value|
# lower|upper (mirrors real MEMs long_table(::AbstractForecastResult); univariate vectors
# reshape to (h,1)). lo/hi === nothing ⇒ missing bands.
function _mock_fc_lt(pf, lo, hi, varnames::Vector{String})
    pfm = pf isa AbstractVector ? reshape(pf, :, 1) : pf
    H, nv = size(pfm)
    vn = length(varnames) == nv ? varnames : ["y$i" for i in 1:nv]
    _m(x) = x === nothing ? nothing : (x isa AbstractVector ? reshape(x, :, 1) : x)
    lom = _m(lo); him = _m(hi)
    horizon = Int[]; variable = String[]; value = Float64[]
    lower = Union{Missing,Float64}[]; upper = Union{Missing,Float64}[]
    for h in 1:H, v in 1:nv
        push!(horizon, h); push!(variable, vn[v]); push!(value, Float64(pfm[h, v]))
        push!(lower, lom === nothing ? missing : Float64(lom[h, v]))
        push!(upper, him === nothing ? missing : Float64(him[h, v]))
    end
    return DataFrame(; horizon, variable, value, lower, upper)
end
long_table(f::BVARForecast)       = _mock_fc_lt(f.forecast, f.ci_lower, f.ci_upper, f.varnames)
long_table(f::LPForecast)         = _mock_fc_lt(f.forecast, f.ci_lower, f.ci_upper, String[])

# Coefficient-bearing models expose a tidy coef table via Tables.jl in real MEMs
# (`DataFrame(model)` → equation|term|estimate|std_error|stat|p_value|ci_lower|ci_upper,
# C051 #346). Tables isn't a test dep, so the mock extends DataFrames.DataFrame directly.
function _mock_coef_df_base(term, est::Vector{Float64})
    ne = length(est); se = fill(0.1, ne)
    DataFrames.DataFrame(term=term, estimate=est, std_error=se, stat=est ./ se,
        p_value=fill(0.5, ne), ci_lower=est .- 0.2, ci_upper=est .+ 0.2)
end
function DataFrames.DataFrame(m::VARModel)
    ncoef, neq = size(m.B)
    terms = vcat(["const"], ["$(m.varnames[v]).L$l" for l in 1:m.p for v in 1:length(m.varnames)])
    length(terms) == ncoef || (terms = ["term$i" for i in 1:ncoef])
    equation = String[]; term = String[]; est = Float64[]
    for j in 1:neq, i in 1:ncoef
        push!(equation, m.varnames[j]); push!(term, terms[i]); push!(est, Float64(m.B[i, j]))
    end
    df = _mock_coef_df_base(term, est)
    DataFrames.insertcols!(df, 1, :equation => equation)
    return df
end
# NB: the Union-typed single-equation/panel/ordered coef table and the multinomial coef
# table (DataFrame(::Union{RegModel,...}) / DataFrame(::MultinomialLogitModel)) live
# further down, after RegModel/PanelRegModel/OrderedLogitModel/MultinomialLogitModel etc.
# are actually defined — see "single-equation coefficient models" below estimate_mlogit.
long_table(f::VolatilityForecast) = _mock_fc_lt(f.forecast, f.ci_lower, f.ci_upper, String[])
long_table(f::ARIMAForecast)      = _mock_fc_lt(f.forecast, f.ci_lower, f.ci_upper, String[])
long_table(f::VECMForecast)       = _mock_fc_lt(f.levels, f.ci_lower, f.ci_upper, String[])
long_table(f::FactorForecast)     = _mock_fc_lt(f.observables, f.observables_lower, f.observables_upper, String[])
export long_table

# BVAR forecast dispatch — returns BVARForecast
function forecast(post::BVARPosterior, h::Int; ci_method=:none, quantiles=[0.16, 0.5, 0.84], conf_level=0.95)
    n = post.n
    fc = ones(h, n) * 0.1
    pe = ci_method isa Symbol ? ci_method : :mean
    BVARForecast{Float64}(fc, fc .- 0.5, fc .+ 0.5, h, Float64(conf_level), pe,
                           ["var$i" for i in 1:n])
end

export BVARForecast, point_forecast, lower_bound, upper_bound, forecast_horizon

# ─── DID & Event Study LP Types & Functions ─────────────────

struct DIDResult{T<:Real}
    att::Vector{T}; se::Vector{T}; ci_lower::Vector{T}; ci_upper::Vector{T}
    event_times::Vector{Int}; reference_period::Int
    group_time_att::Union{Matrix{T}, Nothing}; cohorts::Union{Vector{Int}, Nothing}
    overall_att::T; overall_se::T
    n_obs::Int; n_groups::Int; n_treated::Int; n_control::Int
    method::Symbol; outcome_var::String; treatment_var::String
    control_group::Symbol; cluster::Symbol; conf_level::T
end

struct EventStudyLP{T<:Real}
    coefficients::Vector{T}; se::Vector{T}; ci_lower::Vector{T}; ci_upper::Vector{T}
    event_times::Vector{Int}; reference_period::Int
    B::Vector{Matrix{T}}; residuals_per_h::Vector{Matrix{T}}
    vcov::Vector{Matrix{T}}; T_eff::Vector{Int}
    outcome_var::String; treatment_var::String
    n_obs::Int; n_groups::Int; lags::Int; leads::Int; horizon::Int
    clean_controls::Bool; cluster::Symbol; conf_level::T
    data::PanelData{T}
end

struct LPDiDResult{T<:AbstractFloat}
    coefficients::Vector{T}
    se::Vector{T}
    ci_lower::Vector{T}
    ci_upper::Vector{T}
    event_times::Vector{Int}
    reference_period::Int
    nobs_per_horizon::Vector{Int}
    pooled_post::Union{NamedTuple,Nothing}
    pooled_pre::Union{NamedTuple,Nothing}
    vcov::Vector
    outcome_var::String
    treatment_var::String
    T_obs::Int
    n_groups::Int
    specification::Symbol
    pmd::Union{Nothing,Symbol,Int}
    reweight::Bool
    nocomp::Bool
    ylags::Int
    dylags::Int
    pre_window::Int
    post_window::Int
    cluster::Symbol
    conf_level::T
    data::PanelData{T}
end

struct BaconDecomposition{T<:Real}
    estimates::Vector{T}; weights::Vector{T}
    comparison_type::Vector{Symbol}; cohort_i::Vector{Int}; cohort_j::Vector{Int}
    overall_att::T
end

struct PretrendTestResult{T<:Real}
    statistic::T; pvalue::T; df::Int
    pre_coefficients::Vector{T}; pre_se::Vector{T}; test_type::Symbol
end

struct NegativeWeightResult{T<:Real}
    has_negative_weights::Bool; n_negative::Int; total_negative_weight::T
    weights::Vector{T}; cohort_time_pairs::Vector{Tuple{Int,Int}}
end

struct HonestDiDResult{T<:Real}
    Mbar::T
    robust_ci_lower::Vector{T}; robust_ci_upper::Vector{T}
    original_ci_lower::Vector{T}; original_ci_upper::Vector{T}
    breakdown_value::T; post_event_times::Vector{Int}; post_att::Vector{T}
    conf_level::T
end

# ─── DID Mock Functions ─────────────────────────────────────

function estimate_did(pd::PanelData{T}, outcome, treatment;
        method=:twfe, leads=0, horizon=5, covariates=String[],
        control_group=:never_treated, cluster=:unit,
        conf_level=0.95, n_boot=200, base_period=:varying) where T
    et = collect(-leads:horizon)
    n_et = length(et)
    att = fill(T(0.5), n_et)
    se = fill(T(0.1), n_et)
    ci_lo = att .- T(1.96) .* se
    ci_hi = att .+ T(1.96) .* se
    gt_att = method in (:callaway_santanna, :cs) ? ones(T, 3, n_et) * T(0.4) : nothing
    cohorts = method in (:callaway_santanna, :cs) ? [5, 10, 15] : nothing
    DIDResult{T}(att, se, ci_lo, ci_hi, et, -1, gt_att, cohorts,
        T(0.45), T(0.08), pd.T_obs, pd.n_groups,
        div(pd.n_groups, 2), pd.n_groups - div(pd.n_groups, 2),
        method, String(outcome), String(treatment),
        control_group, cluster, T(conf_level))
end

function estimate_event_study_lp(pd::PanelData{T}, outcome, treatment, H::Int;
        leads=3, lags=4, covariates=String[], cluster=:unit, conf_level=0.95) where T
    et = collect(-leads:H)
    n_et = length(et)
    coefs = fill(T(0.3), n_et)
    se = fill(T(0.1), n_et)
    n_h = leads + H + 1
    B_mats = [ones(T, pd.n_vars, pd.n_vars) * T(0.1) for _ in 1:n_h]
    resid = [randn(T, div(pd.T_obs, pd.n_groups), pd.n_vars) for _ in 1:n_h]
    vcov_mats = [Matrix{T}(I(pd.n_vars)) * T(0.01) for _ in 1:n_h]
    t_eff = fill(div(pd.T_obs, pd.n_groups) - lags, n_h)
    EventStudyLP{T}(coefs, se, coefs .- T(1.96) .* se, coefs .+ T(1.96) .* se,
        et, -1, B_mats, resid, vcov_mats, t_eff,
        String(outcome), String(treatment),
        pd.T_obs, pd.n_groups, lags, leads, H, false, cluster, T(conf_level), pd)
end

function estimate_lp_did(pd::PanelData{T}, outcome, treatment, H::Int;
        pre_window=3, post_window=H, ylags=0, dylags=0,
        covariates=String[], nonabsorbing=nothing, notyet=false,
        nevertreated=false, firsttreat=false, oneoff=false,
        pmd=nothing, reweight=false, nocomp=false,
        cluster=:unit, conf_level=0.95,
        only_pooled=false, only_event=false,
        post_pooled=nothing, pre_pooled=nothing) where T
    nt = pre_window + post_window + 1
    et = collect(-pre_window:post_window)
    c = fill(T(0.3), nt); se = fill(T(0.1), nt)
    pp = (coef=T(0.5), se=T(0.1), ci_lower=T(0.3), ci_upper=T(0.7), nobs=100)
    spec = oneoff ? :oneoff : (isnothing(nonabsorbing) ? :absorbing : :nonabsorbing)
    LPDiDResult{T}(c, se, c .- T(1.96) .* se, c .+ T(1.96) .* se,
        et, -1, fill(100, nt), pp, pp, Matrix{T}[],
        String(outcome), String(treatment), pd.T_obs, pd.n_groups,
        spec, pmd, reweight, nocomp, ylags, dylags, pre_window, post_window,
        cluster, T(conf_level), pd)
end

function bacon_decomposition(pd::PanelData{T}, outcome, treatment) where T
    BaconDecomposition{T}(
        [T(0.6), T(0.4), T(0.3)],
        [T(0.5), T(0.3), T(0.2)],
        [:treated_vs_untreated, :earlier_vs_later, :later_vs_earlier],
        [5, 5, 10], [0, 10, 5],
        T(0.47))
end

function pretrend_test(result::DIDResult{T}) where T
    pre_idx = findall(t -> t < 0, result.event_times)
    PretrendTestResult{T}(T(1.2), T(0.35), length(pre_idx),
        result.att[pre_idx], result.se[pre_idx], :f_test)
end

function pretrend_test(result::EventStudyLP{T}) where T
    pre_idx = findall(t -> t < 0, result.event_times)
    PretrendTestResult{T}(T(0.8), T(0.55), length(pre_idx),
        result.coefficients[pre_idx], result.se[pre_idx], :f_test)
end

function negative_weight_check(pd::PanelData{T}, treatment) where T
    NegativeWeightResult{T}(true, 2, T(-0.15),
        [T(0.4), T(0.3), T(-0.1), T(0.5), T(-0.05), T(-0.05)],
        [(5, 3), (5, 4), (10, 3), (10, 4), (10, 5), (10, 6)])
end

function honest_did(result::DIDResult{T}; Mbar=1.0, conf_level=0.95) where T
    post_idx = findall(t -> t >= 0, result.event_times)
    post_et = result.event_times[post_idx]
    post_att = result.att[post_idx]
    HonestDiDResult{T}(T(Mbar),
        post_att .- T(0.3), post_att .+ T(0.3),
        result.ci_lower[post_idx], result.ci_upper[post_idx],
        T(2.5), post_et, post_att, T(conf_level))
end

function honest_did(result::EventStudyLP{T}; Mbar=1.0, conf_level=0.95) where T
    post_idx = findall(t -> t >= 0, result.event_times)
    post_et = result.event_times[post_idx]
    post_att = result.coefficients[post_idx]
    HonestDiDResult{T}(T(Mbar),
        post_att .- T(0.3), post_att .+ T(0.3),
        result.ci_lower[post_idx], result.ci_upper[post_idx],
        T(2.5), post_et, post_att, T(conf_level))
end

export DIDResult, EventStudyLP, LPDiDResult, BaconDecomposition
export PretrendTestResult, NegativeWeightResult, HonestDiDResult
export estimate_did, estimate_event_study_lp, estimate_lp_did
export bacon_decomposition, pretrend_test, negative_weight_check, honest_did

# ─── FAVAR Types & Functions ─────────────────────────────────

struct FAVARModel{T<:Real}
    Y::Matrix{T}; p::Int; B::Matrix{T}; U::Matrix{T}; Sigma::Matrix{T}
    factors::Matrix{T}; loadings::Matrix{T}; n_factors::Int; n_key::Int
    aic::T; bic::T; loglik::T
    varnames::Vector{String}; panel_varnames::Vector{String}
end

struct BayesianFAVAR{T<:Real}
    B_draws::Array{T,3}
    Sigma_draws::Array{T,3}
    factor_draws::Array{T,3}
    loadings_draws::Array{T,3}
    X_panel::Matrix{T}
    panel_varnames::Vector{String}
    Y_key_indices::Vector{Int}
    n_factors::Int
    n_key::Int
    n::Int
    p::Int
    data::Matrix{T}
    varnames::Vector{String}
end

function estimate_favar(X::Matrix{T}, key_indices::Vector{Int}, r::Int, p::Int;
                        method=:two_step, n_draws=5000, panel_varnames=nothing) where T
    n_obs, n_vars = size(X)
    n_key = length(key_indices)
    n_aug = r + n_key
    Y = X[p+1:end, 1:min(n_aug, n_vars)]
    B = ones(T, n_aug * p + 1, n_aug) * T(0.1)
    U = randn(T, n_obs - p, n_aug)
    Sigma = Matrix{T}(I(n_aug)) * T(0.5)
    factors = randn(T, n_obs, r)
    loadings = randn(T, n_vars, r)
    vnames = ["aug$i" for i in 1:n_aug]
    pvnames = panel_varnames === nothing ? ["var$i" for i in 1:n_vars] : panel_varnames
    if method == :bayesian
        B_draws = ones(T, size(B, 1), size(B, 2), n_draws) * T(0.1)
        Sigma_draws = ones(T, n_aug, n_aug, n_draws) * T(0.5)
        factor_draws = ones(T, n_obs, r, n_draws) * T(0.1)
        loadings_draws = ones(T, n_vars, r, n_draws) * T(0.3)
        return BayesianFAVAR{T}(B_draws, Sigma_draws, factor_draws, loadings_draws,
            X, pvnames, key_indices, r, n_key, n_aug, p, Y, vnames)
    end
    FAVARModel{T}(Y, p, B, U, Sigma, factors, loadings, r, n_key,
                   T(-100.0), T(-95.0), T(-90.0), vnames, pvnames)
end

function to_var(favar::FAVARModel{T}) where T
    n = size(favar.Y, 2)
    VARModel{T}(favar.Y, favar.p, favar.B, favar.U, favar.Sigma,
                favar.aic, favar.bic, T(-92.0))
end

function favar_panel_irf(favar::FAVARModel{T}, irf_result::ImpulseResponse{T}) where T
    N = size(favar.loadings, 1)
    H = irf_result.horizon
    n_shocks = length(irf_result.shocks)
    vals = ones(T, H + 1, N, n_shocks) * T(0.05)
    ImpulseResponse(vals, nothing, nothing, H,
        favar.panel_varnames, irf_result.shocks, :favar_panel)
end

function favar_panel_forecast(favar::FAVARModel{T}, fc::VARForecast{T}) where T
    N = size(favar.loadings, 1)
    h = fc.horizon
    panel_fc = ones(T, h, N) * T(0.1)
    VARForecast{T}(panel_fc, panel_fc .- T(0.5), panel_fc .+ T(0.5),
                    h, :none, T(0.95), favar.panel_varnames)
end

# FAVAR dispatches for irf/fevd/hd — delegate to VAR internals
function irf(favar::FAVARModel{T}, horizon::Int; kwargs...) where T
    var_model = to_var(favar)
    irf(var_model, horizon; kwargs...)
end
function fevd(favar::FAVARModel{T}, horizon::Int; kwargs...) where T
    var_model = to_var(favar)
    fevd(var_model, horizon; kwargs...)
end
function historical_decomposition(favar::FAVARModel{T}, horizon::Int; kwargs...) where T
    var_model = to_var(favar)
    historical_decomposition(var_model, horizon; kwargs...)
end
function forecast(favar::FAVARModel{T}, h::Int; kwargs...) where T
    var_model = to_var(favar)
    forecast(var_model, h; kwargs...)
end

export FAVARModel, BayesianFAVAR, estimate_favar, favar_panel_irf, favar_panel_forecast

# ─── Structural DFM Types & Functions ────────────────────────

struct StructuralDFM{T<:Real}
    gdfm::GeneralizedDynamicFactorModel{T}
    factor_var::VARModel{T}
    B0::Matrix{T}; Q::Matrix{T}
    identification::Symbol
    structural_irf::Array{T,3}
    loadings_td::Matrix{T}
    p_var::Int; shock_names::Vector{String}
end

function estimate_structural_dfm(X::Matrix{T}, q::Int;
        identification=:cholesky, p=1, H=40, sign_check=nothing,
        max_draws=1000, standardize=true, bandwidth=0, kernel=:bartlett) where T
    n_obs, n_vars = size(X)
    gdfm = estimate_gdfm(X, q; standardize=standardize, bandwidth=bandwidth, kernel=kernel)
    factor_Y = randn(T, n_obs - p, q)
    B_fvar = ones(T, q * p + 1, q) * T(0.1)
    U_fvar = randn(T, n_obs - p, q)
    Sigma_fvar = Matrix{T}(I(q)) * T(0.5)
    fvar = VARModel{T}(factor_Y, p, B_fvar, U_fvar, Sigma_fvar, T(-50.0), T(-48.0), T(-45.0))
    B0 = Matrix{T}(I(q))
    Q_mat = Matrix{T}(I(q))
    loadings_td = randn(T, n_vars, q)
    s_irf = ones(T, H + 1, n_vars, q) * T(0.05)
    snames = ["structural_shock_$i" for i in 1:q]
    StructuralDFM{T}(gdfm, fvar, B0, Q_mat, identification, s_irf, loadings_td, p, snames)
end

function irf(sdfm::StructuralDFM{T}, horizon::Int; kwargs...) where T
    n_vars = size(sdfm.loadings_td, 1)
    q = size(sdfm.B0, 1)
    h = min(horizon, size(sdfm.structural_irf, 1) - 1)
    vals = sdfm.structural_irf[1:h+1, :, :]
    vnames = ["var$i" for i in 1:n_vars]
    ImpulseResponse(vals, nothing, nothing, h, vnames, sdfm.shock_names, :structural_dfm)
end

function fevd(sdfm::StructuralDFM{T}, horizon::Int; kwargs...) where T
    q = size(sdfm.B0, 1)
    props = ones(T, q, q, horizon) / T(q)
    FEVD(props, props)
end

export StructuralDFM, estimate_structural_dfm

# ─── Bayesian DSGE Types & Functions ─────────────────────────

struct BayesianDSGE{T<:Real}
    theta_draws::Matrix{T}
    log_posterior::Vector{T}
    param_names::Vector{String}
    log_marginal_likelihood::T
    method::Symbol
    acceptance_rate::T
    ess_history::Vector{T}
    spec::DSGESpec{T}
    solution::DSGESolution{T}
end

# theta0 accepts a positional Vector OR a name→value Dict/NamedTuple (MEMs #136).
function estimate_dsge_bayes(spec::DSGESpec{T},
        data::Matrix, theta0::Union{AbstractVector,AbstractDict,NamedTuple};
        priors=Dict(), method=:smc, observables=Symbol[],
        n_smc=5000, n_particles=500, n_mh_steps=1,
        n_draws=10000, burnin=5000, ess_target=0.5,
        measurement_error=nothing, solver=:gensys,
        solver_kwargs=NamedTuple(), delayed_acceptance=false,
        n_screen=200, rng=nothing, solver_obj=nothing) where T
    theta0v = theta0 isa AbstractDict ? collect(values(theta0)) :
              theta0 isa NamedTuple ? collect(theta0) : collect(theta0)
    np = length(theta0v)
    draws = randn(T, n_draws, np) .* T(0.01) .+ Float64.(theta0v)'
    log_post = fill(T(-100.0), n_draws)
    pnames = ["param_$i" for i in 1:np]
    ess_hist = fill(T(n_smc * 0.8), 20)
    sol = solve(spec; method=:gensys)
    BayesianDSGE{T}(draws, log_post, pnames, T(-500.0 + np), method, T(0.25), ess_hist, spec, sol)
end

export BayesianDSGE, estimate_dsge_bayes

# ─── Structural Break Test Types & Functions ─────────────────

struct AndrewsResult{T<:AbstractFloat}
    statistic::T; pvalue::T; break_index::Int; break_fraction::T
    test_type::Symbol; critical_values::Dict{Int,T}
    stat_sequence::Vector{T}; trimming::T; nobs::Int; n_params::Int
end

struct BaiPerronResult{T<:AbstractFloat}
    n_breaks::Int; break_dates::Vector{Int}; break_cis::Vector{Tuple{Int,Int}}
    regime_coefs::Vector{Vector{T}}; regime_ses::Vector{Vector{T}}
    supf_stats::Vector{T}; supf_pvalues::Vector{T}
    sequential_stats::Vector{T}; sequential_pvalues::Vector{T}
    bic_values::Vector{T}; lwz_values::Vector{T}
    trimming::T; nobs::Int
end

function andrews_test(y::AbstractVector{T}, X::AbstractMatrix;
        test=:supwald, trimming=0.15) where T
    n = length(y)
    n_params = size(X, 2)
    bp = div(n, 2)
    seq = fill(T(5.0), n - 2 * round(Int, n * trimming))
    seq[div(length(seq), 2)] = T(12.0)
    cvs = Dict(1 => T(8.85), 5 => T(7.04), 10 => T(6.28))
    AndrewsResult{T}(T(12.0), T(0.02), bp, T(bp / n),
        test, cvs, seq, T(trimming), n, n_params)
end

function bai_perron_test(y::AbstractVector{T}, X::AbstractMatrix;
        max_breaks=5, trimming=0.15, criterion=:bic) where T
    n = length(y)
    k = size(X, 2)
    BaiPerronResult{T}(
        1, [div(n, 2)], [(div(n, 2) - 5, div(n, 2) + 5)],
        [ones(T, k) * T(2.0), ones(T, k) * T(5.0)],
        [ones(T, k) * T(0.3), ones(T, k) * T(0.4)],
        [T(15.0)], [T(0.01)], [T(12.0)], [T(0.03)],
        fill(T(-100.0), max_breaks + 1), fill(T(-98.0), max_breaks + 1),
        T(trimming), n)
end

export AndrewsResult, BaiPerronResult, andrews_test, bai_perron_test

# ─── Panel Unit Root Test Types & Functions ──────────────────

struct PANICResult{T<:AbstractFloat}
    factor_adf_stats::Vector{T}; factor_adf_pvalues::Vector{T}
    pooled_statistic::T; pooled_pvalue::T
    individual_stats::Vector{T}; individual_pvalues::Vector{T}
    n_factors::Int; method::Symbol; nobs::Int; n_units::Int
end

struct PesaranCIPSResult{T<:AbstractFloat}
    cips_statistic::T
    pvalue::T
    individual_cadf_stats::Vector{T}
    critical_values::Dict{Int,T}
    lags::Int
    deterministic::Symbol
    nobs::Int
    n_units::Int
end

struct MoonPerronResult{T<:AbstractFloat}
    t_a_statistic::T; t_b_statistic::T; pvalue_a::T; pvalue_b::T
    n_factors::Int; nobs::Int; n_units::Int
end

struct FactorBreakResult{T<:AbstractFloat}
    statistic::T
    pvalue::T
    break_date::Int
    method::Symbol
    n_factors::Int
    nobs::Int
    n_vars::Int
end

function panic_test(X::AbstractMatrix{T}; r=:auto, method=:pooled) where T
    n_obs, n_units = size(X)
    n_r = r == :auto ? 2 : r
    PANICResult{T}(
        fill(T(-3.0), n_r), fill(T(0.01), n_r),
        T(-5.0), T(0.001),
        fill(T(-2.5), n_units), fill(T(0.05), n_units),
        n_r, method, n_obs, n_units)
end
function panic_test(pd::PanelData{T}; r=:auto, method=:pooled) where T
    X = hcat([pd.data[:, i] for i in 1:pd.n_vars]...)
    panic_test(X; r=r, method=method)
end

function pesaran_cips_test(X::AbstractMatrix{T}; lags=:auto, deterministic=:constant) where T
    n_obs, n_units = size(X)
    p = lags == :auto ? max(1, round(Int, n_obs^(1/3))) : lags
    cvs = Dict(1 => T(-2.16), 5 => T(-2.04), 10 => T(-1.97))
    PesaranCIPSResult{T}(T(-2.5), T(0.01), fill(T(-2.3), n_units),
        cvs, p, deterministic, n_obs, n_units)
end
function pesaran_cips_test(pd::PanelData{T}; lags=:auto, deterministic=:constant) where T
    X = hcat([pd.data[:, i] for i in 1:pd.n_vars]...)
    pesaran_cips_test(X; lags=lags, deterministic=deterministic)
end

function moon_perron_test(X::AbstractMatrix{T}; r=:auto) where T
    n_obs, n_units = size(X)
    n_r = r == :auto ? 2 : r
    MoonPerronResult{T}(T(-3.5), T(-4.0), T(0.001), T(0.0005), n_r, n_obs, n_units)
end
function moon_perron_test(pd::PanelData{T}; r=:auto) where T
    X = hcat([pd.data[:, i] for i in 1:pd.n_vars]...)
    moon_perron_test(X; r=r)
end

function factor_break_test(X::AbstractMatrix{T}, r::Int; method=:breitung_eickmeier) where T
    n_obs, n_units = size(X)
    FactorBreakResult{T}(T(8.5), T(0.03), div(n_obs, 2), method, r, n_obs, n_units)
end
function factor_break_test(pd::PanelData{T}, r::Int; method=:breitung_eickmeier) where T
    X = hcat([pd.data[:, i] for i in 1:pd.n_vars]...)
    factor_break_test(X, r; method=method)
end

function panel_unit_root_summary(X; tests=[:panic, :cips, :moon_perron])
    println("Panel unit root summary ($(length(tests)) tests)")
end

export PANICResult, PesaranCIPSResult, MoonPerronResult, FactorBreakResult
export panic_test, pesaran_cips_test, moon_perron_test, factor_break_test
export panel_unit_root_summary

# ─── C069/C070: randomness/nonlinearity + panel cointegration tests ────
# NamedTuple returns (no result structs) with the exact field names the real
# MEMs result types expose. Kwargs are enumerated (no `; kwargs...` catch-all) to
# stay within the check_mock_surface absorber budget. Minimal real-like validation
# so T1/T2 catch shape/arity bugs.

# Lo–MacKinlay / Chow–Denning variance-ratio test (real fields: q, vr, z, z_star,
# z_pvalue, z_star_pvalue, cd_stat, cd_pvalue, cd_star_stat, cd_star_pvalue, ...).
function variance_ratio_test(y; q=[2, 4, 8, 16], method=:lomackinlay, robust=true,
                             bootstrap=0, boot_weights=:rademacher, seed=1234)
    method in (:lomackinlay, :wright) ||
        throw(ArgumentError("method must be :lomackinlay or :wright, got :$method"))
    yv = float.(collect(y))
    nlev = length(yv)
    nlev >= 4 || throw(ArgumentError("need at least 4 level observations, got $nlev"))
    qvec = sort(unique(Int.(collect(q))))
    all(qi -> qi >= 2, qvec) || throw(ArgumentError("every q must be ≥ 2"))
    maximum(qvec) < nlev - 1 ||
        throw(ArgumentError("every q must be < number of returns ($(nlev - 1))"))
    nq = length(qvec)
    return (q=qvec, vr=fill(0.92, nq), z=fill(-0.9, nq), z_star=fill(-0.8, nq),
            z_pvalue=fill(0.37, nq), z_star_pvalue=fill(0.42, nq),
            cd_stat=1.55, cd_pvalue=0.34, cd_star_stat=1.42, cd_star_pvalue=0.41,
            method=method, robust=robust, nobs=nlev)
end

# BDS iid/nonlinearity test — statistic/pvalue are (n_dims × n_eps) matrices.
function bds_test(y; m=2:6, eps_frac=0.7, bootstrap=0, seed=1234)
    yv = float.(collect(y))
    n = length(yv)
    ms = sort(unique(filter(mm -> mm >= 1, collect(Int, m))))
    isempty(ms) && throw(ArgumentError("no valid embedding dimension in m=$m"))
    nm = length(ms)
    stat = reshape(Float64[1.4 + 0.1 * i for i in 1:nm], nm, 1)
    pval = reshape(fill(0.22, nm), nm, 1)
    return (m=ms, statistic=stat, pvalue=pval, nobs=n)
end

# Hadri panel stationarity test (H0: all units stationary).
function hadri_test(X; deterministic=:constant, hetero=true, cs_demean=false)
    deterministic in (:constant, :trend) ||
        throw(ArgumentError("Hadri deterministic must be :constant or :trend, got :$deterministic"))
    T_obs, N = size(X)
    T_obs >= 10 || throw(ArgumentError("Time dimension T=$T_obs too small for Hadri"))
    N >= 2 || throw(ArgumentError("Hadri needs at least N=2 panel units, got N=$N"))
    return (statistic=1.35, pvalue=0.11, n_units=N, nobs=T_obs,
            deterministic=deterministic, hetero=hetero)
end

# Panel cointegration trio (H0: no cointegration). All three expose the uniform
# names/statistics/pvalues/n_units/n_regressors/nobs output triple.
_panel_coint_meta(pd, xs) = (n_units=pd.n_groups, n_regressors=length(xs),
                             nobs=pd.n_groups == 0 ? pd.T_obs : pd.T_obs ÷ pd.n_groups)

function pedroni_test(pd::PanelData, y::Symbol, xs::Symbol...; trend=:constant,
                      lags=:auto, adf_lags=2)
    isempty(xs) && throw(ArgumentError("pedroni_test needs at least one regressor"))
    m = _panel_coint_meta(pd, xs)
    names = ["panel-v", "panel-rho", "panel-pp", "panel-adf", "group-rho", "group-pp", "group-adf"]
    return (names=names, statistics=[2.1, -1.9, -2.0, -2.2, -1.6, -1.9, -2.1],
            pvalues=[0.02, 0.04, 0.03, 0.02, 0.06, 0.04, 0.03],
            n_units=m.n_units, n_regressors=m.n_regressors, nobs=m.nobs)
end

function kao_test(pd::PanelData, y::Symbol, xs::Symbol...; lags=:auto, kernel_lags=:auto)
    isempty(xs) && throw(ArgumentError("kao_test needs at least one regressor"))
    m = _panel_coint_meta(pd, xs)
    names = ["DFrho", "DFt", "DFrho_star", "DFt_star", "ADF"]
    return (names=names, statistics=[-2.3, -2.1, -2.4, -2.2, -2.0],
            pvalues=[0.02, 0.03, 0.02, 0.03, 0.04],
            n_units=m.n_units, n_regressors=m.n_regressors, nobs=m.nobs)
end

function westerlund_test(pd::PanelData, y::Symbol, xs::Symbol...; trend=:constant,
                         lags=1, leads=0, lrwindow=2, bootstrap=0, seed=20240716)
    isempty(xs) && throw(ArgumentError("westerlund_test needs at least one regressor"))
    length(xs) <= 6 || throw(ArgumentError("Westerlund test supports at most 6 regressors"))
    m = _panel_coint_meta(pd, xs)
    names = ["Gt", "Ga", "Pt", "Pa"]
    return (names=names, statistics=[-2.5, -8.0, -3.0, -9.5],
            pvalues=[0.02, 0.03, 0.02, 0.03],
            n_units=m.n_units, n_regressors=m.n_regressors, nobs=m.nobs)
end

export variance_ratio_test, bds_test, hadri_test
export pedroni_test, kao_test, westerlund_test

# ─── Cross-Sectional Regression Types & Functions ──────────────────

struct RegModel{T<:Real}
    y::Vector{T}
    X::Matrix{T}
    beta::Vector{T}
    vcov_mat::Matrix{T}
    residuals::Vector{T}
    fitted::Vector{T}
    ssr::T
    tss::T
    r2::T
    adj_r2::T
    f_stat::T
    f_pval::T
    loglik::T
    aic::T
    bic::T
    varnames::Vector{String}
    method::Symbol
    cov_type::Symbol
    weights::Union{Vector{T},Nothing}
    Z::Union{Matrix{T},Nothing}
    endogenous::Union{Vector{Int},Nothing}
    first_stage_f::Union{T,Nothing}
    sargan_stat::Union{T,Nothing}
    sargan_pval::Union{T,Nothing}
    cragg_donald_f::Union{T,Nothing}
    kleibergen_paap_f::Union{T,Nothing}
    stock_yogo_10pct::Union{T,Nothing}
end

struct LogitModel{T<:Real}
    y::Vector{T}
    X::Matrix{T}
    beta::Vector{T}
    vcov_mat::Matrix{T}
    residuals::Vector{T}
    fitted::Vector{T}
    loglik::T
    loglik_null::T
    pseudo_r2::T
    aic::T
    bic::T
    varnames::Vector{String}
    converged::Bool
    iterations::Int
    cov_type::Symbol
end

struct ProbitModel{T<:Real}
    y::Vector{T}
    X::Matrix{T}
    beta::Vector{T}
    vcov_mat::Matrix{T}
    residuals::Vector{T}
    fitted::Vector{T}
    loglik::T
    loglik_null::T
    pseudo_r2::T
    aic::T
    bic::T
    varnames::Vector{String}
    converged::Bool
    iterations::Int
    cov_type::Symbol
end

struct MarginalEffects{T<:Real}
    effects::Vector{T}; se::Vector{T}; z_stat::Vector{T}; p_values::Vector{T}
    ci_lower::Vector{T}; ci_upper::Vector{T}; varnames::Vector{String}
    type::Symbol; conf_level::T
end

# StatsAPI dispatches for RegModel
coef(m::RegModel) = m.beta
vcov(m::RegModel) = m.vcov_mat
residuals(m::RegModel) = m.residuals
predict(m::RegModel) = m.fitted
stderror(m::RegModel) = [sqrt(m.var_beta[i,i]) for i in 1:size(m.var_beta, 1)]
nobs(m::RegModel) = m.nobs
loglikelihood(m::RegModel) = m.loglik
aic(m::RegModel) = m.aic
bic(m::RegModel) = m.bic
r2(m::RegModel) = m.r2
confint(m::RegModel; level=0.95) = hcat(m.beta .- 1.96 .* stderror(m), m.beta .+ 1.96 .* stderror(m))

# StatsAPI dispatches for LogitModel
coef(m::LogitModel) = m.beta
vcov(m::LogitModel) = m.vcov_mat
residuals(m::LogitModel) = m.residuals
predict(m::LogitModel) = m.fitted
stderror(m::LogitModel) = [sqrt(m.var_beta[i,i]) for i in 1:size(m.var_beta, 1)]
nobs(m::LogitModel) = m.nobs
loglikelihood(m::LogitModel) = m.loglik
aic(m::LogitModel) = m.aic
bic(m::LogitModel) = m.bic
r2(m::LogitModel) = m.pseudo_r2
confint(m::LogitModel; level=0.95) = hcat(m.beta .- 1.96 .* stderror(m), m.beta .+ 1.96 .* stderror(m))

# StatsAPI dispatches for ProbitModel
coef(m::ProbitModel) = m.beta
vcov(m::ProbitModel) = m.vcov_mat
residuals(m::ProbitModel) = m.residuals
predict(m::ProbitModel) = m.fitted
stderror(m::ProbitModel) = [sqrt(m.var_beta[i,i]) for i in 1:size(m.var_beta, 1)]
nobs(m::ProbitModel) = m.nobs
loglikelihood(m::ProbitModel) = m.loglik
aic(m::ProbitModel) = m.aic
bic(m::ProbitModel) = m.bic
r2(m::ProbitModel) = m.pseudo_r2
confint(m::ProbitModel; level=0.95) = hcat(m.beta .- 1.96 .* stderror(m), m.beta .+ 1.96 .* stderror(m))

# Mock functions

function estimate_reg(y::AbstractVector{T}, X::AbstractMatrix{T};
                      cov_type=:hc1, weights=nothing, varnames=nothing,
                      clusters=nothing) where T
    n, k = size(X)
    beta = ones(T, k) * T(0.5)
    vcov_mat = Matrix{T}(I(k)) * T(0.01)
    fitted_vals = X * beta
    resids = y .- fitted_vals
    ssr = sum(resids .^ 2)
    tss = sum((y .- mean(y)) .^ 2)
    r2_val = one(T) - ssr / tss
    adj_r2_val = one(T) - (one(T) - r2_val) * (n - 1) / (n - k)
    f_val = T(25.0)
    f_p = T(0.001)
    ll = T(-100.0)
    aic_val = T(210.0)
    bic_val = T(220.0)
    vnames = varnames === nothing ? ["x$i" for i in 1:k] : varnames
    RegModel{T}(y, X, beta, vcov_mat, resids, fitted_vals, ssr, tss,
                r2_val, adj_r2_val, f_val, f_p, ll, aic_val, bic_val,
                vnames, :ols, cov_type, weights, nothing, nothing,
                nothing, nothing, nothing, nothing, nothing, nothing)
end

function estimate_iv(y::AbstractVector{T}, X::AbstractMatrix{T}, Z::AbstractMatrix{T};
                     endogenous=Int[], cov_type=:hc1, varnames=nothing) where T
    n, k = size(X)
    beta = ones(T, k) * T(0.5)
    vcov_mat = Matrix{T}(I(k)) * T(0.01)
    fitted_vals = X * beta
    resids = y .- fitted_vals
    ssr = sum(resids .^ 2)
    tss = sum((y .- mean(y)) .^ 2)
    r2_val = one(T) - ssr / tss
    adj_r2_val = one(T) - (one(T) - r2_val) * (n - 1) / (n - k)
    f_val = T(20.0)
    f_p = T(0.002)
    ll = T(-105.0)
    aic_val = T(220.0)
    bic_val = T(230.0)
    vnames = varnames === nothing ? ["x$i" for i in 1:k] : varnames
    first_f = T(15.0)
    sargan_s = T(2.5)
    sargan_p = T(0.30)
    RegModel{T}(y, X, beta, vcov_mat, resids, fitted_vals, ssr, tss,
                r2_val, adj_r2_val, f_val, f_p, ll, aic_val, bic_val,
                vnames, :iv, cov_type, nothing, Z, endogenous,
                first_f, sargan_s, sargan_p, T(15.0), T(14.0), T(7.0))
end

function _build_logit_probit(::Type{M}, y::AbstractVector{T}, X::AbstractMatrix{T};
                             cov_type=:ols, varnames=nothing, clusters=nothing,
                             maxiter=100, tol=1e-8) where {T, M}
    n, k = size(X)
    beta = ones(T, k) * T(0.3)
    vcov_mat = Matrix{T}(I(k)) * T(0.02)
    fitted_vals = ones(T, n) * T(0.5)
    resids = y .- fitted_vals
    ll = T(-80.0)
    ll_null = T(-100.0)
    pseudo = one(T) - ll / ll_null
    aic_val = T(170.0)
    bic_val = T(180.0)
    vnames = varnames === nothing ? ["x$i" for i in 1:k] : varnames
    M{T}(y, X, beta, vcov_mat, resids, fitted_vals, ll, ll_null, pseudo,
          aic_val, bic_val, vnames, true, 5, cov_type)
end

function estimate_logit(y::AbstractVector{T}, X::AbstractMatrix{T};
                        cov_type=:ols, varnames=nothing, clusters=nothing,
                        maxiter=100, tol=1e-8) where T
    _build_logit_probit(LogitModel, y, X; cov_type=cov_type, varnames=varnames,
                        clusters=clusters, maxiter=maxiter, tol=tol)
end

function estimate_probit(y::AbstractVector{T}, X::AbstractMatrix{T};
                         cov_type=:ols, varnames=nothing, clusters=nothing,
                         maxiter=100, tol=1e-8) where T
    _build_logit_probit(ProbitModel, y, X; cov_type=cov_type, varnames=varnames,
                        clusters=clusters, maxiter=maxiter, tol=tol)
end

function marginal_effects(m::Union{LogitModel{T},ProbitModel{T}};
                          type=:ame, at=nothing, conf_level=0.95) where T
    k = length(m.beta)
    effects = ones(T, k) * T(0.1)
    se = ones(T, k) * T(0.02)
    z = effects ./ se
    pvals = ones(T, k) * T(0.001)
    z_crit = T(1.96)
    ci_lo = effects .- z_crit .* se
    ci_hi = effects .+ z_crit .* se
    MarginalEffects{T}(effects, se, z, pvals, ci_lo, ci_hi, m.varnames, type, conf_level)
end

function odds_ratio(m::LogitModel{T}; conf_level=0.95) where T
    or = exp.(m.beta)
    se = stderror(m)
    z_crit = T(1.96)
    ci_lo = exp.(m.beta .- z_crit .* se)
    ci_hi = exp.(m.beta .+ z_crit .* se)
    (odds_ratio=or, ci_lower=ci_lo, ci_upper=ci_hi, varnames=m.varnames)
end

function vif(m::RegModel{T}) where T
    k = length(m.beta)
    # Return escalating VIF values so tests can trigger different warning branches
    # k=2: [2.5, 2.5], k=3: [2.5, 2.5, 7.0], k>=4: [2.5, 2.5, 7.0, 12.0, ...]
    vals = fill(T(2.5), k)
    if k >= 3
        vals[3] = T(7.0)  # moderate multicollinearity
    end
    if k >= 4
        vals[4] = T(12.0)  # severe multicollinearity
    end
    vals
end

function classification_table(m::Union{LogitModel,ProbitModel}; threshold=0.5)
    Dict("accuracy" => 0.85, "precision" => 0.80, "recall" => 0.75,
         "f1" => 0.77, "true_positive" => 30, "true_negative" => 55,
         "false_positive" => 8, "false_negative" => 10, "threshold" => threshold)
end

export RegModel, LogitModel, ProbitModel, MarginalEffects
export estimate_reg, estimate_iv, estimate_logit, estimate_probit
export marginal_effects, odds_ratio, vif, classification_table
export vcov, confint, r2

# ─── Advanced Unit Root Test Types & Functions ─────────────────

struct FourierADFResult{T<:AbstractFloat}
    statistic::T; pvalue::T; frequency::Int; f_statistic::T; f_pvalue::T
    lags::Int; regression::Symbol
    critical_values::Dict{Int,T}; f_critical_values::Dict{Int,T}; nobs::Int
end

struct FourierKPSSResult{T<:AbstractFloat}
    statistic::T; pvalue::T; frequency::Int; f_statistic::T; f_pvalue::T
    regression::Symbol; critical_values::Dict{Int,T}; f_critical_values::Dict{Int,T}
    bandwidth::Int; nobs::Int
end

struct DFGLSResult{T<:AbstractFloat}
    statistic::T
    pvalue::T
    pt_statistic::T
    pt_pvalue::T
    MZa::T
    MZt::T
    MSB::T
    MPT::T
    lags::Int
    regression::Symbol
    critical_values::Dict{Int,T}
    pt_critical_values::Dict{Int,T}
    mgls_critical_values::Dict{Symbol,Dict{Int,T}}
    nobs::Int
end

struct LMUnitRootResult{T<:AbstractFloat}
    statistic::T
    pvalue::T
    breaks::Int
    break_dates::Union{Nothing,Vector{Int}}
    break_fractions::Union{Nothing,Vector{T}}
    lags::Int
    regression::Symbol
    critical_values::Dict{Int,T}
    nobs::Int
end

struct ADF2BreakResult{T<:AbstractFloat}
    statistic::T
    pvalue::T
    break1::Int
    break2::Int
    break1_fraction::T
    break2_fraction::T
    lags::Int
    model::Symbol
    critical_values::Dict{Int,T}
    nobs::Int
end

struct GregoryHansenResult{T<:AbstractFloat}
    adf_statistic::T
    adf_pvalue::T
    zt_statistic::T
    zt_pvalue::T
    za_statistic::T
    za_pvalue::T
    adf_break::Int
    zt_break::Int
    za_break::Int
    model::Symbol
    n_regressors::Int
    adf_critical_values::Dict{Int,T}
    za_critical_values::Dict{Int,T}
    nobs::Int
end

function fourier_adf_test(y::AbstractVector{T};
        regression=:constant, fmax=3, lags=:aic,
        max_lags=nothing, trim=0.15) where T
    n = length(y)
    p = lags == :aic ? max(1, round(Int, n^(1/3))) : lags
    freq = min(fmax, 3)
    cvs = Dict(1 => T(-4.82), 5 => T(-4.25), 10 => T(-3.96))
    f_cvs = Dict(1 => T(6.93), 5 => T(4.68), 10 => T(3.85))
    FourierADFResult{T}(T(-4.5), T(0.02), freq, T(8.5), T(0.005),
        p, regression, cvs, f_cvs, n)
end

function fourier_kpss_test(y::AbstractVector{T};
        regression=:constant, fmax=3, bandwidth=nothing) where T
    n = length(y)
    bw = isnothing(bandwidth) ? max(1, round(Int, n^(1/4))) : bandwidth
    freq = min(fmax, 3)
    cvs = Dict(1 => T(0.739), 5 => T(0.463), 10 => T(0.347))
    f_cvs = Dict(1 => T(6.93), 5 => T(4.68), 10 => T(3.85))
    FourierKPSSResult{T}(T(0.35), T(0.10), freq, T(5.2), T(0.01),
        regression, cvs, f_cvs, bw, n)
end

function dfgls_test(y::AbstractVector{T};
        regression=:constant, lags=:aic, max_lags=nothing) where T
    n = length(y)
    p = lags == :aic ? max(1, round(Int, n^(1/3))) : lags
    cvs = Dict(1 => T(-3.48), 5 => T(-2.89), 10 => T(-2.57))
    pt_cvs = Dict(1 => T(4.5), 5 => T(3.2), 10 => T(2.5))
    mgls_cvs = Dict(:MZa => cvs, :MZt => cvs, :MSB => cvs, :MPT => cvs)
    DFGLSResult{T}(T(-3.2), T(0.02), T(4.5), T(0.05),
        T(-15.0), T(-2.7), T(0.18), T(3.5),
        p, regression, cvs, pt_cvs, mgls_cvs, n)
end

function lm_unitroot_test(y::AbstractVector{T};
        breaks=0, regression=:level, lags=:aic,
        max_lags=nothing, trim=0.15) where T
    n = length(y)
    p = lags == :aic ? max(1, round(Int, n^(1/3))) : lags
    cvs = Dict(1 => T(-4.24), 5 => T(-3.57), 10 => T(-3.21))
    bi = breaks > 0 ? [div(n, i + 1) for i in 1:breaks] : nothing
    bf = breaks > 0 ? [T(1.0 / (i + 1)) for i in 1:breaks] : nothing
    LMUnitRootResult{T}(T(-3.8), T(0.03), breaks, bi, bf, p, regression, cvs, n)
end

function adf_2break_test(y::AbstractVector{T};
        model=:level, lags=:aic, max_lags=nothing, trim=0.10) where T
    n = length(y)
    p = lags == :aic ? max(1, round(Int, n^(1/3))) : lags
    b1 = div(n, 3)
    b2 = div(2n, 3)
    cvs = Dict(1 => T(-5.65), 5 => T(-5.13), 10 => T(-4.82))
    ADF2BreakResult{T}(T(-5.3), T(0.03), b1, b2, T(b1 / n), T(b2 / n),
        p, model, cvs, n)
end

function gregory_hansen_test(Y::AbstractMatrix{T};
        model=:C, lags=:aic, max_lags=nothing, trim=0.15) where T
    n = size(Y, 1)
    bp = div(n, 2)
    cvs = Dict(1 => T(-5.13), 5 => T(-4.61), 10 => T(-4.34))
    GregoryHansenResult{T}(T(-4.8), T(0.03), T(-4.5), T(0.04), T(-35.0), T(0.02),
        bp, bp + 2, bp - 1, model, 1, cvs, cvs, n)
end

export FourierADFResult, FourierKPSSResult, DFGLSResult
export LMUnitRootResult, ADF2BreakResult, GregoryHansenResult
export fourier_adf_test, fourier_kpss_test, dfgls_test
export lm_unitroot_test, adf_2break_test, gregory_hansen_test

# ─── Bayesian DSGE Enhancements ────────────────────────────

struct BayesianDSGESimulation{T<:AbstractFloat}
    quantiles::Array{T,3}
    point_estimate::Matrix{T}
    all_paths::Array{T,3}
    variables::Vector{String}
    quantile_levels::Vector{T}
end

# irf dispatch on BayesianDSGE
function irf(result::BayesianDSGE{T}, horizon::Int;
        n_draws=200, quantiles=[0.05, 0.16, 0.84, 0.95],
        solver=:gensys, solver_kwargs=NamedTuple(), rng=nothing) where T
    nv = length(result.param_names)
    ns = max(1, nv)
    q = Array{T,4}(undef, horizon + 1, nv, ns, length(quantiles))
    fill!(q, T(0.1))
    m = zeros(T, horizon + 1, nv, ns)
    BayesianImpulseResponse(m, q, T.(quantiles))
end

# fevd dispatch on BayesianDSGE
function fevd(result::BayesianDSGE{T}, horizon::Int;
        n_draws=200, quantiles=[0.05, 0.16, 0.84, 0.95],
        solver=:gensys, solver_kwargs=NamedTuple(), rng=nothing) where T
    nv = length(result.param_names)
    ns = max(1, nv)
    q = Array{T,4}(undef, horizon, nv, ns, length(quantiles))
    fill!(q, T(1.0 / ns))
    m = fill(T(1.0 / ns), horizon, nv, ns)
    BayesianFEVD(m, q, T.(quantiles))
end

# simulate dispatch on BayesianDSGE
function simulate(result::BayesianDSGE{T}, T_periods::Int;
        n_draws=200, quantiles=[0.05, 0.16, 0.84, 0.95],
        solver=:gensys, solver_kwargs=NamedTuple(), rng=nothing) where T
    nv = length(result.param_names)
    nq = length(quantiles)
    q = randn(T, T_periods, nv, nq)
    pe = randn(T, T_periods, nv)
    ap = randn(T, n_draws, T_periods, nv)
    BayesianDSGESimulation{T}(q, pe, ap, String.(result.param_names), T.(quantiles))
end

function posterior_summary(result::BayesianDSGE{T}) where T
    Dict(p => Dict(:mean => T(0.5), :median => T(0.49), :std => T(0.1),
        :q05 => T(0.3), :q95 => T(0.7)) for p in result.param_names)
end

function bayes_factor(r1::BayesianDSGE, r2::BayesianDSGE)
    # Match real MEMs: return the LOG Bayes factor (logML₁ − logML₂), positive favors M1.
    r1.log_marginal_likelihood - r2.log_marginal_likelihood
end

function prior_posterior_table(result::BayesianDSGE{T}) where T
    [(param=p, prior_mean=T(0.5), prior_std=T(0.2),
      post_mean=T(0.5), post_std=T(0.1), post_q05=T(0.3), post_q95=T(0.7))
     for p in result.param_names]
end

function posterior_predictive(result::BayesianDSGE{T}, n_sim::Int;
        T_periods=100, rng=nothing) where T
    nv = length(result.param_names)
    randn(T, n_sim, T_periods, nv)
end

export BayesianDSGESimulation
export posterior_summary, bayes_factor, prior_posterior_table, posterior_predictive

# ─── GPL Notice Functions ────────────────────────────────────

function warranty()
    println("THERE IS NO WARRANTY FOR THE PROGRAM (mock)")
    nothing
end

function conditions()
    println("You may convey verbatim copies of the Program (mock)")
    nothing
end

export warranty, conditions

# ─── DSGE Historical Decomposition (v0.4.0) ──────────────────

struct KalmanSmootherResult{T<:Real}
    smoothed_states::Matrix{T}
    smoothed_covariances::Array{T,3}
    smoothed_shocks::Matrix{T}
    filtered_states::Matrix{T}
    filtered_covariances::Array{T,3}
    predicted_states::Matrix{T}
    predicted_covariances::Array{T,3}
    log_likelihood::T
end

function dsge_smoother(sol::DSGESolution, data::AbstractMatrix,
                       observables::Vector{Symbol}; kwargs...)
    T_obs, _ = size(data)
    n_states = sol.spec.n_endog
    n_shocks = sol.spec.n_exog
    KalmanSmootherResult{Float64}(
        randn(T_obs, n_states), randn(T_obs, n_states, n_states),
        randn(T_obs, n_shocks), randn(T_obs, n_states), randn(T_obs, n_states, n_states),
        randn(T_obs, n_states), randn(T_obs, n_states, n_states), -100.0)
end

function historical_decomposition(sol::DSGESolution{T}, data::AbstractMatrix,
        observables::Vector{Symbol}; states::Symbol=:observables,
        measurement_error=nothing) where {T}
    T_obs = size(data, 1)
    n_obs = length(observables)
    n_shocks = sol.spec.n_exog
    n_vars = states == :all ? sol.spec.n_endog : n_obs
    varnames_hd = states == :all ? sol.spec.varnames : [string(s) for s in observables]
    shock_names = string.(sol.spec.exog)
    HistoricalDecomposition{T}(
        randn(T_obs, n_vars, n_shocks), randn(T_obs, n_vars), randn(T_obs, n_vars),
        randn(T_obs, n_shocks), T_obs, varnames_hd, shock_names, :dsge_linear)
end

struct BayesianDSGEHistoricalDecomposition{T<:Real}
    quantiles::Array{T,4}
    point_estimate::Array{T,3}
    initial_quantiles::Array{T,3}
    initial_point_estimate::Matrix{T}
    shocks_point_estimate::Matrix{T}
    actual::Matrix{T}
    T_eff::Int
    variables::Vector{String}
    shock_names::Vector{String}
    quantile_levels::Vector{T}
    method::Symbol
end

function historical_decomposition(bd::BayesianDSGE{T}, data::AbstractMatrix,
        observables::Vector{Symbol}; mode_only::Bool=false, n_draws::Int=200,
        quantiles::Vector{<:Real}=T[0.16, 0.5, 0.84],
        measurement_error=nothing, states::Symbol=:observables) where {T}
    T_obs = size(data, 1)
    n_obs = length(observables)
    n_shocks = bd.spec.n_exog
    n_q = length(quantiles)
    varnames_bd = [string(s) for s in observables]
    shock_names = string.(bd.spec.exog)
    BayesianDSGEHistoricalDecomposition{T}(
        randn(T_obs, n_obs, n_shocks, n_q), randn(T_obs, n_obs, n_shocks),
        randn(T_obs, n_obs, n_q), randn(T_obs, n_obs), randn(T_obs, n_shocks),
        randn(T_obs, n_obs), T_obs, varnames_bd, shock_names, T.(quantiles), :dsge_bayes)
end

contribution(hd::BayesianDSGEHistoricalDecomposition, var::Int, shock::Int) = hd.point_estimate[:, var, shock]
total_shock_contribution(hd::HistoricalDecomposition, var::Int) = dropdims(sum(hd.contributions[:, var, :]; dims=2); dims=2)
verify_decomposition(hd::BayesianDSGEHistoricalDecomposition) = _MOCK_FLAGS[:verify_decomposition]

function dsge_particle_smoother(args...; kwargs...)
    nothing
end

export KalmanSmootherResult, BayesianDSGEHistoricalDecomposition
export dsge_smoother, dsge_particle_smoother
export total_shock_contribution

# ─── Spectral Analysis Types & Functions (v0.4.0) ────────────

struct ACFResult{T<:AbstractFloat}
    lags::Vector{Int}
    acf::Vector{T}
    pacf::Vector{T}
    ci::T
    ccf::Union{Nothing,Vector{T}}
    q_stats::Vector{T}
    q_pvalues::Vector{T}
    nobs::Int
end

struct SpectralDensityResult{T<:AbstractFloat}
    freq::Vector{T}
    density::Vector{T}
    ci_lower::Vector{T}
    ci_upper::Vector{T}
    method::Symbol
    bandwidth::T
    nobs::Int
end

struct CrossSpectrumResult{T<:AbstractFloat}
    freq::Vector{T}
    co_spectrum::Vector{T}
    quad_spectrum::Vector{T}
    coherence::Vector{T}
    phase::Vector{T}
    gain::Vector{T}
    nobs::Int
end

struct TransferFunctionResult{T<:AbstractFloat}
    freq::Vector{T}
    gain::Vector{T}
    phase::Vector{T}
    filter::Symbol
end

struct FisherTestResult{T<:AbstractFloat}
    statistic::T
    pvalue::T
    peak_freq::T
    nobs::Int
end

struct BartlettWhiteNoiseResult{T<:AbstractFloat}
    statistic::T
    pvalue::T
    nobs::Int
end

struct BoxPierceResult{T<:AbstractFloat}
    statistic::T
    pvalue::T
    df::Int
    lags::Int
    nobs::Int
end

struct DurbinWatsonResult{T<:AbstractFloat}
    statistic::T
    pvalue::T
    nobs::Int
end

function acf(y::AbstractVector{T}; lags::Int=20, maxlag::Union{Int,Nothing}=nothing,
             conf_level::Real=0.95, varname::String="y") where T
    n = length(y)
    nlags = isnothing(maxlag) ? lags : maxlag
    acf_vals = [T(0.9)^k for k in 0:nlags]
    pacf_vals = [k == 0 ? T(1.0) : T(0.9) * T(0.5)^(k-1) for k in 0:nlags]
    ci = T(1.96) / sqrt(n)
    q_stats = [T(k+1) * T(0.1) for k in 0:nlags]
    q_pvals = [T(0.05) for _ in 0:nlags]
    lags_vec = collect(0:nlags)
    ACFResult{T}(lags_vec, acf_vals, pacf_vals, ci, nothing, q_stats, q_pvals, n)
end

function pacf(y::AbstractVector{T}; lags::Int=20, maxlag::Union{Int,Nothing}=nothing,
              conf_level::Real=0.95, varname::String="y") where T
    acf(y; lags=lags, maxlag=maxlag, conf_level=conf_level, varname=varname)
end

struct CCFResult{T<:AbstractFloat}
    ccf::Vector{T}
    lags::Vector{Int}
    conf_level::T
    ci_band::T
    varnames::Tuple{String,String}
    nobs::Int
end

function ccf(y1::AbstractVector{T}, y2::AbstractVector{T}; lags::Int=20,
             maxlag::Union{Int,Nothing}=nothing, conf_level::Real=0.95,
             var1::String="y1", var2::String="y2") where T
    n = length(y1)
    nlags = isnothing(maxlag) ? lags : maxlag
    ccf_vals = [T(0.5) * T(0.8)^abs(k) for k in -nlags:nlags]
    ci = T(1.96) / sqrt(n)
    lags_vec = collect(-nlags:nlags)
    CCFResult{T}(ccf_vals, lags_vec, T(conf_level), ci, (var1, var2), n)
end

function periodogram(y::AbstractVector{T}; varname::String="y") where T
    n = length(y)
    freqs = [T(k) / n for k in 1:div(n, 2)]
    spec = abs2.(randn(T, length(freqs))) .+ T(0.01)
    log_spec = log.(spec)
    SpectralDensityResult{T}(freqs, spec, fill(T(0.0), length(freqs)), fill(T(0.0), length(freqs)), :periodogram, T(0.0), n)
end

function spectral_density(y::AbstractVector{T}; method::Symbol=:welch, bandwidth=nothing,
                          kernel::Symbol=:bartlett, varname::String="y") where T
    n = length(y)
    freqs = [T(k) / n for k in 1:div(n, 2)]
    bw = isnothing(bandwidth) ? T(sqrt(n)) : T(bandwidth)
    dens = abs2.(randn(T, length(freqs))) .+ T(0.01)
    SpectralDensityResult{T}(freqs, dens, dens .* T(0.5), dens .* T(1.5), method, bw, n)
end

function cross_spectrum(y1::AbstractVector{T}, y2::AbstractVector{T};
                        bandwidth=nothing, kernel::Symbol=:bartlett,
                        var1::String="y1", var2::String="y2") where T
    n = length(y1)
    freqs = [T(k) / n for k in 1:div(n, 2)]
    nf = length(freqs)
    cs = randn(Complex{T}, nf)
    coh = abs.(cs) ./ (abs.(cs) .+ T(0.1))
    ph = angle.(cs)
    gain = abs.(cs)
    CrossSpectrumResult{T}(freqs, real.(cs), imag.(cs), coh, ph, gain, n)
end

function transfer_function(input::AbstractVector{T}, output::AbstractVector{T};
                           bandwidth=nothing, kernel::Symbol=:bartlett,
                           var_input::String="input", var_output::String="output") where T
    n = length(input)
    freqs = [T(k) / n for k in 1:div(n, 2)]
    nf = length(freqs)
    gain = abs.(randn(T, nf)) .+ T(0.5)
    phase = randn(T, nf)
    coherence = rand(T, nf) .* T(0.8) .+ T(0.1)
    TransferFunctionResult{T}(freqs, gain, phase, :empirical)
end

function transfer_function(filter_name::Symbol; lambda::Real=1600.0, nobs::Int=200,
                           kwargs...)
    n = nobs
    freqs = [Float64(k) / n for k in 1:div(n, 2)]
    nf = length(freqs)
    gain = abs.(randn(nf)) .+ 0.5
    phase = randn(nf)
    TransferFunctionResult{Float64}(freqs, gain, phase, filter_name)
end

function fisher_test(y::AbstractVector{T}) where T
    n = length(y)
    FisherTestResult{T}(T(8.5), T(0.05), T(0.1), n)
end

function bartlett_white_noise_test(y::AbstractVector{T}; lags::Int=20) where T
    n = length(y)
    BartlettWhiteNoiseResult{T}(T(12.0), T(0.15), n)
end

function box_pierce_test(y::AbstractVector{T}; lags::Int=20, ljung_box::Bool=true) where T
    n = length(y)
    BoxPierceResult{T}(T(25.0), T(0.10), lags, lags, n)
end

function durbin_watson_test(residuals::AbstractVector{T}) where T
    n = length(residuals)
    DurbinWatsonResult{T}(T(2.0), T(0.5), n)
end

# Field aliases for spectral handler compat (legacy mock names → real fields)
function Base.getproperty(r::SpectralDensityResult, s::Symbol)
    s === :spectrum && return getfield(r, :density)
    s === :frequencies && return getfield(r, :freq)
    s === :log_spectrum && return log.(max.(getfield(r, :density), eps(eltype(getfield(r, :density)))))
    s === :kernel && return :none
    s === :varname && return "y"
    return getfield(r, s)
end
function Base.getproperty(r::CrossSpectrumResult, s::Symbol)
    s === :frequencies && return getfield(r, :freq)
    s === :cross_spectrum && return complex.(getfield(r, :co_spectrum), getfield(r, :quad_spectrum))
    s === :var1 && return "y1"
    s === :var2 && return "y2"
    return getfield(r, s)
end
function Base.getproperty(r::TransferFunctionResult, s::Symbol)
    s === :frequencies && return getfield(r, :freq)
    s === :coherence && return ones(eltype(getfield(r, :gain)), length(getfield(r, :gain)))
    s === :var_input && return string(getfield(r, :filter))
    s === :var_output && return "output"
    s === :nobs && return length(getfield(r, :freq)) * 2
    return getfield(r, s)
end
function Base.getproperty(r::ACFResult, s::Symbol)
    s === :ci_band && return getfield(r, :ci)
    s === :conf_level && return 0.95
    s === :varname && return "y"
    return getfield(r, s)
end
function Base.getproperty(r::FisherTestResult, s::Symbol)
    s === :dominant_frequency && return getfield(r, :peak_freq)
    s === :periodogram_values && return Float64[]
    s === :frequencies && return Float64[]
    return getfield(r, s)
end
function Base.getproperty(r::BartlettWhiteNoiseResult, s::Symbol)
    s === :lags_tested && return 0
    s === :individual_stats && return Float64[]
    s === :individual_pvalues && return Float64[]
    return getfield(r, s)
end
function Base.getproperty(r::BoxPierceResult, s::Symbol)
    s === :ljung_box && return true
    return getfield(r, s)
end
function Base.getproperty(r::DurbinWatsonResult, s::Symbol)
    s === :decision && return :inconclusive
    s === :lower_bound && return 1.5
    s === :upper_bound && return 2.5
    return getfield(r, s)
end
function Base.getproperty(r::DFGLSResult, s::Symbol)
    s === :tau_statistic && return getfield(r, :statistic)
    s === :mgls_statistics && return Dict(:MZa => getfield(r, :MZa), :MZt => getfield(r, :MZt),
                                          :MSB => getfield(r, :MSB), :MPT => getfield(r, :MPT))
    return getfield(r, s)
end
function Base.getproperty(r::LMUnitRootResult, s::Symbol)
    s === :break_indices && return getfield(r, :break_dates)
    return getfield(r, s)
end
function Base.getproperty(r::ADF2BreakResult, s::Symbol)
    s === :break_index1 && return getfield(r, :break1)
    s === :break_index2 && return getfield(r, :break2)
    s === :break_fraction1 && return getfield(r, :break1_fraction)
    s === :break_fraction2 && return getfield(r, :break2_fraction)
    return getfield(r, s)
end
function Base.getproperty(r::GregoryHansenResult, s::Symbol)
    s === :adf_break_index && return getfield(r, :adf_break)
    s === :zt_break_index && return getfield(r, :zt_break)
    s === :za_break_index && return getfield(r, :za_break)
    s === :critical_values && return getfield(r, :adf_critical_values)
    return getfield(r, s)
end

export ACFResult, SpectralDensityResult, CrossSpectrumResult, TransferFunctionResult
export FisherTestResult, BartlettWhiteNoiseResult, BoxPierceResult, DurbinWatsonResult
export ACFResult, CCFResult
export acf, pacf, ccf, periodogram, spectral_density, cross_spectrum, transfer_function
export fisher_test, bartlett_white_noise_test, box_pierce_test, durbin_watson_test

# ─── Panel Regression Types & Functions (v0.4.0) ─────────────

struct PanelRegModel{T<:Real}
    beta::Vector{T}
    vcov_mat::Matrix{T}
    residuals::Vector{T}
    fitted::Vector{T}
    y::Vector{T}
    X::Matrix{T}
    r2_within::T
    r2_between::T
    r2_overall::T
    sigma_u::T
    sigma_e::T
    rho::T
    theta::T
    f_stat::T
    f_pval::T
    loglik::T
    aic::T
    bic::T
    varnames::Vector{String}
    method::Symbol
    twoway::Bool
    cov_type::Symbol
    n_obs::Int
    n_groups::Int
    n_periods_avg::T
    group_effects::Union{Nothing,Vector{T}}
    data::PanelData{T}
    dynamic_diagnostics::Union{Nothing,NamedTuple}
end

struct PanelIVModel{T<:Real}
    beta::Vector{T}
    vcov_mat::Matrix{T}
    residuals::Vector{T}
    fitted::Vector{T}
    y::Vector{T}
    X::Matrix{T}
    Z::Matrix{T}
    r2_within::T
    r2_between::T
    r2_overall::T
    sigma_u::T
    sigma_e::T
    rho::T
    first_stage_f::T
    sargan_stat::T
    sargan_pval::T
    cragg_donald_f::T
    kleibergen_paap_f::T
    stock_yogo_10pct::T
    varnames::Vector{String}
    endog_names::Vector{String}
    instrument_names::Vector{String}
    method::Symbol
    cov_type::Symbol
    n_obs::Int
    n_groups::Int
    data::PanelData{T}
end

struct PanelLogitModel{T<:Real}
    beta::Vector{T}
    vcov_mat::Matrix{T}
    y::Vector{T}
    X::Matrix{T}
    fitted::Vector{T}
    loglik::T
    loglik_null::T
    pseudo_r2::T
    aic::T
    bic::T
    sigma_u::T
    rho::T
    varnames::Vector{String}
    method::Symbol
    cov_type::Symbol
    converged::Bool
    iterations::Int
    n_obs::Int
    n_groups::Int
    data::PanelData{T}
end

struct PanelProbitModel{T<:Real}
    beta::Vector{T}
    vcov_mat::Matrix{T}
    y::Vector{T}
    X::Matrix{T}
    fitted::Vector{T}
    loglik::T
    loglik_null::T
    pseudo_r2::T
    aic::T
    bic::T
    sigma_u::T
    rho::T
    varnames::Vector{String}
    method::Symbol
    cov_type::Symbol
    converged::Bool
    iterations::Int
    n_obs::Int
    n_groups::Int
    data::PanelData{T}
end

struct PanelTestResult{T<:Real}
    test_name::String
    statistic::T
    pvalue::T
    df::Union{Int,Tuple{Int,Int},Nothing}
    description::String
end

# StatsAPI dispatches for panel regression types
coef(m::PanelRegModel) = m.beta
coef(m::PanelIVModel) = m.beta
coef(m::PanelLogitModel) = m.beta
coef(m::PanelProbitModel) = m.beta
vcov(m::PanelRegModel) = m.vcov_mat
vcov(m::PanelIVModel) = m.vcov_mat
vcov(m::PanelLogitModel) = m.vcov_mat
vcov(m::PanelProbitModel) = m.vcov_mat
residuals(m::PanelRegModel) = m.residuals
residuals(m::PanelIVModel) = m.residuals
residuals(m::PanelLogitModel) = m.residuals
residuals(m::PanelProbitModel) = m.residuals
predict(m::PanelRegModel) = m.fitted
predict(m::PanelIVModel) = m.fitted
predict(m::PanelLogitModel) = m.fitted
predict(m::PanelProbitModel) = m.fitted
stderror(m::PanelRegModel) = [sqrt(m.vcov_mat[i,i]) for i in 1:size(m.vcov_mat,1)]
stderror(m::PanelIVModel) = [sqrt(m.vcov_mat[i,i]) for i in 1:size(m.vcov_mat,1)]
stderror(m::PanelLogitModel) = [sqrt(m.vcov_mat[i,i]) for i in 1:size(m.vcov_mat,1)]
stderror(m::PanelProbitModel) = [sqrt(m.vcov_mat[i,i]) for i in 1:size(m.vcov_mat,1)]
nobs(m::PanelRegModel) = m.nobs
nobs(m::PanelIVModel) = m.nobs
nobs(m::PanelLogitModel) = m.nobs
nobs(m::PanelProbitModel) = m.nobs
loglikelihood(m::PanelRegModel) = m.loglik
loglikelihood(m::PanelLogitModel) = m.loglik
loglikelihood(m::PanelProbitModel) = m.loglik
aic(m::PanelRegModel) = m.aic
aic(m::PanelLogitModel) = m.aic
aic(m::PanelProbitModel) = m.aic
bic(m::PanelRegModel) = m.bic
bic(m::PanelLogitModel) = m.bic
bic(m::PanelProbitModel) = m.bic
r2(m::PanelRegModel) = m.within_r2
r2(m::PanelLogitModel) = m.pseudo_r2
r2(m::PanelProbitModel) = m.pseudo_r2
confint(m::PanelRegModel; level=0.95) = hcat(m.beta .- 1.96 .* stderror(m), m.beta .+ 1.96 .* stderror(m))
confint(m::PanelIVModel; level=0.95) = hcat(m.beta .- 1.96 .* stderror(m), m.beta .+ 1.96 .* stderror(m))
confint(m::PanelLogitModel; level=0.95) = hcat(m.beta .- 1.96 .* stderror(m), m.beta .+ 1.96 .* stderror(m))
confint(m::PanelProbitModel; level=0.95) = hcat(m.beta .- 1.96 .* stderror(m), m.beta .+ 1.96 .* stderror(m))

function estimate_xtreg(pd::PanelData{T}, outcome, covariates;
        model=:fe, twoway=false, fe=:twoway, cov_type=:cluster, clusters=nothing,
        varnames=nothing) where T
    n, k = pd.T_obs, length(covariates) + 1
    beta = ones(T, k) * T(0.5)
    vcov_mat = Matrix{T}(I(k)) * T(0.01)
    y = pd.data[:, 1]
    X = ones(T, n, k)
    fitted_vals = X * beta
    resids = y .- fitted_vals
    vnames = varnames === nothing ? ["const"; string.(covariates)] : varnames
    meth = model isa Symbol ? model : :fe
    PanelRegModel{T}(beta, vcov_mat, resids, fitted_vals, y, X,
        T(0.35), T(0.25), T(0.30), T(0.5), T(1.0), T(0.2), T(0.5),
        T(20.0), T(0.001), T(-200.0), T(410.0), T(420.0),
        vnames, meth, Bool(twoway), cov_type, n, pd.n_groups, T(n / max(pd.n_groups, 1)),
        nothing, pd, nothing)
end

function estimate_xtiv(pd::PanelData{T}, outcome, covariates, endog=Symbol[];
        instruments=Symbol[], model=:fe, fe=:twoway, cov_type=:cluster, clusters=nothing, varnames=nothing) where T
    n, k = pd.T_obs, length(covariates) + 1
    kz = max(1, length(instruments) + 1)
    beta = ones(T, k) * T(0.5)
    vcov_mat = Matrix{T}(I(k)) * T(0.01)
    y = pd.data[:, 1]
    X = ones(T, n, k)
    Z = ones(T, n, kz)
    fitted_vals = X * beta
    resids = y .- fitted_vals
    vnames = varnames === nothing ? ["const"; string.(covariates)] : varnames
    endog_names = string.(endog)
    inst_names = string.(instruments)
    PanelIVModel{T}(beta, vcov_mat, resids, fitted_vals, y, X, Z,
        T(0.30), T(0.20), T(0.25), T(0.5), T(1.0), T(0.2),
        T(12.0), T(2.5), T(0.30), T(10.0), T(9.0), T(7.0),
        vnames, endog_names, inst_names, model isa Symbol ? model : :fe, cov_type,
        n, pd.n_groups, pd)
end

function estimate_xtlogit(pd::PanelData{T}, outcome, covariates;
        model=:pooled, fe=:fe, cov_type=:cluster, clusters=nothing, varnames=nothing,
        maxiter=100, tol=1e-8) where T
    n, k = pd.T_obs, length(covariates) + 1
    beta = ones(T, k) * T(0.3)
    vcov_mat = Matrix{T}(I(k)) * T(0.02)
    y = pd.data[:, 1]
    X = ones(T, n, k)
    fitted_vals = ones(T, n) * T(0.5)
    vnames = varnames === nothing ? ["const"; string.(covariates)] : varnames
    PanelLogitModel{T}(beta, vcov_mat, y, X, fitted_vals,
        T(-80.0), T(-100.0), T(0.20), T(170.0), T(180.0),
        T(0.5), T(0.2), vnames, model isa Symbol ? model : :pooled, cov_type,
        true, 10, n, pd.n_groups, pd)
end

function estimate_xtprobit(pd::PanelData{T}, outcome, covariates;
        model=:pooled, fe=:re, cov_type=:cluster, clusters=nothing, varnames=nothing,
        maxiter=100, tol=1e-8) where T
    n, k = pd.T_obs, length(covariates) + 1
    beta = ones(T, k) * T(0.3)
    vcov_mat = Matrix{T}(I(k)) * T(0.02)
    y = pd.data[:, 1]
    X = ones(T, n, k)
    fitted_vals = ones(T, n) * T(0.5)
    vnames = varnames === nothing ? ["const"; string.(covariates)] : varnames
    PanelProbitModel{T}(beta, vcov_mat, y, X, fitted_vals,
        T(-80.0), T(-100.0), T(0.20), T(170.0), T(180.0),
        T(0.5), T(0.2), vnames, model isa Symbol ? model : :pooled, cov_type,
        true, 10, n, pd.n_groups, pd)
end

function hausman_test(fe_model::PanelRegModel{T}, re_model::PanelRegModel{T}) where T
    k = length(fe_model.beta)
    PanelTestResult{T}("Hausman", T(10.0), T(0.01), k, "FE vs RE")
end

function breusch_pagan_test(model::PanelRegModel{T}) where T
    PanelTestResult{T}("Breusch-Pagan LM", T(45.0), T(0.001), 1, "LM test for random effects")
end

function f_test_fe(model::PanelRegModel{T}) where T
    df2 = model.n_obs - model.n_groups - length(model.beta)
    PanelTestResult{T}("F-test for FE", T(12.0), T(0.001), (model.n_groups - 1, df2), "joint FE significance")
end

function pesaran_cd_test(model::Union{PanelRegModel{T},PanelLogitModel{T},PanelProbitModel{T}}) where T
    PanelTestResult{T}("Pesaran CD", T(3.5), T(0.001), 0, "cross-sectional dependence")
end

function wooldridge_ar_test(model::PanelRegModel{T}) where T
    PanelTestResult{T}("Wooldridge AR(1)", T(5.2), T(0.02), 1, "serial correlation in panel")
end

function modified_wald_test(model::PanelRegModel{T}) where T
    PanelTestResult{T}("Modified Wald", T(28.0), T(0.005), model.n_groups, "groupwise heteroskedasticity")
end

export PanelRegModel, PanelIVModel, PanelLogitModel, PanelProbitModel, PanelTestResult
export estimate_xtreg, estimate_xtiv, estimate_xtlogit, estimate_xtprobit
export hausman_test, breusch_pagan_test, f_test_fe, pesaran_cd_test
export wooldridge_ar_test, modified_wald_test

# ─── Ordered/Multinomial & Data Utilities (v0.4.0) ───────────

struct OrderedLogitModel{T<:Real}
    y::Vector{T}
    X::Matrix{T}
    beta::Vector{T}
    cutpoints::Vector{T}
    vcov_mat::Matrix{T}
    fitted::Matrix{T}
    loglik::T
    loglik_null::T
    pseudo_r2::T
    aic::T
    bic::T
    varnames::Vector{String}
    categories::Vector{Int}
    converged::Bool
    iterations::Int
    cov_type::Symbol
end

struct OrderedProbitModel{T<:Real}
    y::Vector{T}
    X::Matrix{T}
    beta::Vector{T}
    cutpoints::Vector{T}
    vcov_mat::Matrix{T}
    fitted::Matrix{T}
    loglik::T
    loglik_null::T
    pseudo_r2::T
    aic::T
    bic::T
    varnames::Vector{String}
    categories::Vector{Int}
    converged::Bool
    iterations::Int
    cov_type::Symbol
end

struct MultinomialLogitModel{T<:Real}
    y::Vector{T}
    X::Matrix{T}
    beta::Matrix{T}
    vcov_mat::Array{T,3}
    fitted::Matrix{T}
    loglik::T
    loglik_null::T
    pseudo_r2::T
    aic::T
    bic::T
    varnames::Vector{String}
    categories::Vector{Int}
    converged::Bool
    iterations::Int
    cov_type::Symbol
end

# StatsAPI dispatches for ordered/multinomial models
coef(m::OrderedLogitModel) = vcat(m.beta, m.cutpoints)
coef(m::OrderedProbitModel) = vcat(m.beta, m.cutpoints)
coef(m::MultinomialLogitModel) = vec(m.beta)
vcov(m::OrderedLogitModel) = m.vcov_mat
vcov(m::OrderedProbitModel) = m.vcov_mat
vcov(m::MultinomialLogitModel) = m.vcov_mat[:, :, 1]
residuals(m::OrderedLogitModel) = m.y .- m.fitted[:, 1]
residuals(m::OrderedProbitModel) = m.y .- m.fitted[:, 1]
residuals(m::MultinomialLogitModel) = m.y .- m.fitted[:, 1]
predict(m::OrderedLogitModel) = m.fitted[:, 1]
predict(m::OrderedProbitModel) = m.fitted[:, 1]
predict(m::MultinomialLogitModel) = m.fitted[:, 1]

# Compat aliases for handlers still using legacy field names
function Base.getproperty(m::Union{OrderedLogitModel,OrderedProbitModel}, s::Symbol)
    s === :thresholds && return getfield(m, :cutpoints)
    s === :n_categories && return length(getfield(m, :categories))
    s === :var_beta && return getfield(m, :vcov_mat)
    s === :nobs && return length(getfield(m, :y))
    s === :residuals && return getfield(m, :y) .- getfield(m, :fitted)[:, 1]
    return getfield(m, s)
end
function Base.getproperty(m::MultinomialLogitModel, s::Symbol)
    s === :n_categories && return length(getfield(m, :categories))
    s === :base_category && return first(getfield(m, :categories))
    s === :var_beta && return getfield(m, :vcov_mat)
    s === :nobs && return length(getfield(m, :y))
    s === :residuals && return getfield(m, :y) .- getfield(m, :fitted)[:, 1]
    return getfield(m, s)
end
stderror(m::OrderedLogitModel) = [sqrt(m.vcov_mat[i,i]) for i in 1:size(m.vcov_mat,1)]
stderror(m::OrderedProbitModel) = [sqrt(m.vcov_mat[i,i]) for i in 1:size(m.vcov_mat,1)]
stderror(m::MultinomialLogitModel) = vcat([[sqrt(m.vcov_mat[i,i,c]) for i in 1:size(m.vcov_mat,1)] for c in 1:size(m.vcov_mat,3)]...)
nobs(m::OrderedLogitModel) = length(m.y)
nobs(m::OrderedProbitModel) = length(m.y)
nobs(m::MultinomialLogitModel) = length(m.y)
loglikelihood(m::OrderedLogitModel) = m.loglik
loglikelihood(m::OrderedProbitModel) = m.loglik
loglikelihood(m::MultinomialLogitModel) = m.loglik
aic(m::OrderedLogitModel) = m.aic
aic(m::OrderedProbitModel) = m.aic
aic(m::MultinomialLogitModel) = m.aic
bic(m::OrderedLogitModel) = m.bic
bic(m::OrderedProbitModel) = m.bic
bic(m::MultinomialLogitModel) = m.bic
r2(m::OrderedLogitModel) = m.pseudo_r2
r2(m::OrderedProbitModel) = m.pseudo_r2
r2(m::MultinomialLogitModel) = m.pseudo_r2

function _build_ordered(::Type{M}, y::AbstractVector{T}, X::AbstractMatrix{T};
        n_categories::Int=3, cov_type::Symbol=:hc1, varnames=nothing,
        maxiter::Int=100, tol::Real=1e-8) where {T, M}
    n, k = size(X)
    beta = ones(T, k) * T(0.3)
    cutpoints = [T(c) * T(0.5) for c in 1:(n_categories - 1)]
    nb = k + length(cutpoints)
    vcov_mat = Matrix{T}(I(nb)) * T(0.02)
    fitted_mat = ones(T, n, n_categories) / n_categories
    ll = T(-80.0); ll_null = T(-100.0)
    pseudo = one(T) - ll / ll_null
    vnames = varnames === nothing ? ["x$i" for i in 1:k] : varnames
    cats = collect(1:n_categories)
    M{T}(y, X, beta, cutpoints, vcov_mat, fitted_mat, ll, ll_null, pseudo,
         T(170.0), T(180.0), vnames, cats, true, 15, cov_type)
end

function estimate_ologit(y::AbstractVector{T}, X::AbstractMatrix{T};
        n_categories::Int=3, cov_type::Symbol=:hc1, varnames=nothing, clusters=nothing,
        maxiter::Int=100, tol::Real=1e-8) where T
    _build_ordered(OrderedLogitModel, y, X; n_categories=n_categories,
                   cov_type=cov_type, varnames=varnames, maxiter=maxiter, tol=tol)
end

function estimate_oprobit(y::AbstractVector{T}, X::AbstractMatrix{T};
        n_categories::Int=3, cov_type::Symbol=:hc1, varnames=nothing, clusters=nothing,
        maxiter::Int=100, tol::Real=1e-8) where T
    _build_ordered(OrderedProbitModel, y, X; n_categories=n_categories,
                   cov_type=cov_type, varnames=varnames, maxiter=maxiter, tol=tol)
end

function estimate_mlogit(y::AbstractVector{T}, X::AbstractMatrix{T};
        n_categories::Int=3, base_category::Int=1, cov_type::Symbol=:hc1,
        varnames=nothing, maxiter::Int=100, tol::Real=1e-8) where T
    n, k = size(X)
    nc = n_categories
    beta = ones(T, k, nc) * T(0.3)
    beta[:, base_category] .= T(0.0)
    vcov_mat = zeros(T, k, k, nc)
    for c in 1:nc
        vcov_mat[:, :, c] = Matrix{T}(I(k)) * T(0.02)
    end
    fitted_mat = ones(T, n, nc) / nc
    ll = T(-90.0); ll_null = T(-110.0)
    pseudo = one(T) - ll / ll_null
    vnames = varnames === nothing ? ["x$i" for i in 1:k] : varnames
    cats = collect(1:nc)
    MultinomialLogitModel{T}(y, X, beta, vcov_mat, fitted_mat, ll, ll_null, pseudo,
        T(190.0), T(200.0), vnames, cats, true, 20, cov_type)
end

# Single-equation coefficient models → 7-col base (term first, no equation). Placed here
# (not with the other DataFrame(model) methods near VARModel) because RegModel/PanelReg*/
# OrderedLogit*/MultinomialLogitModel aren't defined until this point in the file.
function DataFrames.DataFrame(m::Union{RegModel,LogitModel,ProbitModel,
                                       PanelRegModel,PanelIVModel,PanelLogitModel,PanelProbitModel,
                                       OrderedLogitModel,OrderedProbitModel})
    b = Float64.(m.beta)
    terms = length(b) <= 1 ? ["x1"] : vcat(["_cons"], ["x$i" for i in 1:length(b)-1])
    _mock_coef_df_base(terms, b)
end
# Multinomial logit → tidy coef table keyed by alternative (real MEMs merges `alternative`).
function DataFrames.DataFrame(m::MultinomialLogitModel)
    B = m.beta                      # n_terms × (n_alt - 1)
    nterms, nalt = size(B)
    terms0 = nterms <= 1 ? ["x1"] : vcat(["_cons"], ["x$i" for i in 1:nterms-1])
    alt = String[]; term = String[]; est = Float64[]
    for j in 1:nalt, i in 1:nterms
        push!(alt, "alt$(j + 1)"); push!(term, terms0[i]); push!(est, Float64(B[i, j]))
    end
    df = _mock_coef_df_base(term, est)
    DataFrames.insertcols!(df, 1, :alternative => alt)
    return df
end

function marginal_effects(m::Union{OrderedLogitModel{T},OrderedProbitModel{T}};
        type=:ame, at=nothing, conf_level=0.95) where T
    k = length(m.beta)
    nc = length(m.categories)
    effects = ones(T, k, nc) * T(0.1)
    MarginalEffects{T}(vec(effects), fill(T(0.02), k*nc), fill(T(5.0), k*nc),
        fill(T(0.001), k*nc), vec(effects) .- T(0.04), vec(effects) .+ T(0.04),
        m.varnames, type, T(conf_level))
end

function marginal_effects(m::MultinomialLogitModel{T};
        type=:ame, at=nothing, conf_level=0.95) where T
    k = size(m.beta, 1)
    nc = length(m.categories)
    effects = ones(T, k, nc) * T(0.1)
    MarginalEffects{T}(vec(effects), fill(T(0.02), k*nc), fill(T(5.0), k*nc),
        fill(T(0.001), k*nc), vec(effects) .- T(0.04), vec(effects) .+ T(0.04),
        m.varnames, type, T(conf_level))
end

function brant_test(m::Union{OrderedLogitModel{T},OrderedProbitModel{T}}) where T
    k = length(m.beta)
    nc = length(m.categories)
    PanelTestResult{T}("Brant", T(5.0), T(0.25), k * (nc - 2),
        "proportional odds test")
end

function hausman_iia(m::MultinomialLogitModel{T}; omit_category::Int=2) where T
    k = size(m.beta, 1)
    PanelTestResult{T}("Hausman IIA", T(3.5), T(0.48), k, "IIA test")
end

function dropna(ts; vars=nothing, cols=nothing)
    ts
end

function keeprows(ts, indices::AbstractVector)
    ts
end

# Compat field aliases (handlers may still use legacy names)
function Base.getproperty(m::PanelRegModel, s::Symbol)
    s === :nobs && return getfield(m, :n_obs)
    s === :within_r2 && return getfield(m, :r2_within)
    s === :between_r2 && return getfield(m, :r2_between)
    s === :overall_r2 && return getfield(m, :r2_overall)
    s === :f_pvalue && return getfield(m, :f_pval)
    s === :var_beta && return getfield(m, :vcov_mat)
    s === :fe_type && return getfield(m, :method)
    s === :panel && return getfield(m, :data)
    s === :dof_resid && return getfield(m, :n_obs) - length(getfield(m, :beta))
    s === :rank && return length(getfield(m, :beta))
    s === :clusters && return nothing
    return getfield(m, s)
end
function Base.getproperty(m::PanelIVModel, s::Symbol)
    s === :nobs && return getfield(m, :n_obs)
    s === :within_r2 && return getfield(m, :r2_within)
    s === :overall_r2 && return getfield(m, :r2_overall)
    s === :f_pvalue && return getfield(m, :f_stat)  # no f_pval on real IV; expose f_stat
    s === :var_beta && return getfield(m, :vcov_mat)
    s === :fe_type && return getfield(m, :method)
    s === :panel && return getfield(m, :data)
    s === :dof_resid && return getfield(m, :n_obs) - length(getfield(m, :beta))
    s === :rank && return length(getfield(m, :beta))
    s === :clusters && return nothing
    return getfield(m, s)
end
function Base.getproperty(m::Union{PanelLogitModel,PanelProbitModel}, s::Symbol)
    s === :nobs && return getfield(m, :n_obs)
    s === :var_beta && return getfield(m, :vcov_mat)
    s === :fe_type && return getfield(m, :method)
    s === :panel && return getfield(m, :data)
    s === :residuals && return getfield(m, :y) .- getfield(m, :fitted)
    return getfield(m, s)
end
function Base.getproperty(m::RegModel, s::Symbol)
    s === :var_beta && return getfield(m, :vcov_mat)
    s === :f_pvalue && return getfield(m, :f_pval)
    s === :nobs && return length(getfield(m, :y))
    s === :rank && return length(getfield(m, :beta))
    s === :dof_resid && return length(getfield(m, :y)) - length(getfield(m, :beta))
    s === :clusters && return nothing
    return getfield(m, s)
end
function Base.getproperty(m::Union{LogitModel,ProbitModel}, s::Symbol)
    s === :var_beta && return getfield(m, :vcov_mat)
    s === :nobs && return length(getfield(m, :y))
    return getfield(m, s)
end
function Base.getproperty(m::BayesianImpulseResponse, s::Symbol)
    s === :mean && return getfield(m, :point_estimate)
    return getfield(m, s)
end
function Base.getproperty(m::BayesianFEVD, s::Symbol)
    s === :mean && return getfield(m, :point_estimate)
    return getfield(m, s)
end
function Base.getproperty(m::BayesianHistoricalDecomposition, s::Symbol)
    s === :mean && return getfield(m, :point_estimate)
    s === :initial_mean && return getfield(m, :initial_point_estimate)
    s === :shocks_mean && return getfield(m, :shocks_point_estimate)
    return getfield(m, s)
end
function Base.getproperty(m::LPDiDResult, s::Symbol)
    s === :se_vec && return getfield(m, :se)
    s === :nobs_h && return getfield(m, :nobs_per_horizon)
    s === :pooled_post_result && return getfield(m, :pooled_post)
    s === :pooled_pre_result && return getfield(m, :pooled_pre)
    s === :vcov_all && return getfield(m, :vcov)
    s === :outcome_name && return getfield(m, :outcome_var)
    s === :treatment_name && return getfield(m, :treatment_var)
    s === :spec_type && return getfield(m, :specification)
    s === :pd && return getfield(m, :data)
    return getfield(m, s)
end
function Base.getproperty(m::BVARForecast, s::Symbol)
    s === :ci_method && return getfield(m, :point_estimate)
    return getfield(m, s)
end
function Base.getproperty(m::BayesianFAVAR, s::Symbol)
    s === :Y && return getfield(m, :data)
    s === :factors && return dropdims(mean(getfield(m, :factor_draws); dims=3); dims=3)
    s === :loadings && return dropdims(mean(getfield(m, :loadings_draws); dims=3); dims=3)
    s === :n_draws && return size(getfield(m, :B_draws), 3)
    return getfield(m, s)
end
function Base.getproperty(m::PesaranCIPSResult, s::Symbol)
    s === :cips && return getfield(m, :cips_statistic)
    s === :individual_cadf && return getfield(m, :individual_cadf_stats)
    return getfield(m, s)
end
function Base.getproperty(m::FactorBreakResult, s::Symbol)
    s === :r && return getfield(m, :n_factors)
    s === :n_units && return getfield(m, :n_vars)
    return getfield(m, s)
end
function Base.getproperty(m::GeneralizedDynamicFactorModel, s::Symbol)
    s === :loadings && return dropdims(mean(getfield(m, :loadings_spectral); dims=3); dims=3)
    return getfield(m, s)
end
function Base.getproperty(m::Union{ARModel,MAModel,ARMAModel,ARIMAModel}, s::Symbol)
    s === :aic_val && return getfield(m, :aic)
    s === :bic_val && return getfield(m, :bic)
    s === :ll && return getfield(m, :loglik)
    s === :sigma && return sqrt(getfield(m, :sigma2))
    s === :coefficients && begin
        if m isa ARModel
            return getfield(m, :phi)
        elseif m isa MAModel
            return getfield(m, :theta)
        elseif m isa ARMAModel
            return vcat(getfield(m, :phi), getfield(m, :theta))
        else
            return vcat(getfield(m, :phi), getfield(m, :theta))
        end
    end
    return getfield(m, s)
end

# --- C039 Phase-4 surface mocks (MEMs 0.6.7 fields ⊆ real) ---
struct HADSGESpec{T<:AbstractFloat}
    aggregate_spec::Any
    individual::Any
    income::Any
    grid::Any
    aggregation::Any
    het_params::Dict{Symbol,T}
    n_assets::Int
    n_income::Int
    model::Symbol
end

struct HASteadyState{T<:AbstractFloat}
    policies::Any
    distribution::Any
    value_fn::Any
    prices::Dict{Symbol,T}
    aggregates::Dict{Symbol,T}
    grid::Any
    income::Any
    converged::Bool
    iterations::Int
    euler_error::T
    excess_demand::T
end

struct HADSGESolution{T<:AbstractFloat}
    steady_state::HASteadyState{T}
    linear_solution::Any
    method::Symbol
    spec::HADSGESpec{T}
    reduction_basis::Any
    n_full_states::Int
    n_reduced::Int
    explained_variance::T
    jacobians::Any
    C_obs::Matrix{T}
    D_obs::Matrix{T}
end

struct BlanchardOLG{T<:AbstractFloat}
    alpha::T
    beta::T
    delta::T
    gamma::T
    Z::T
    b::T
end

struct BlanchardOLGSteadyState{T<:AbstractFloat}
    k::T
    C::T
    r::T
    w::T
    H::T
    mpc::T
    b::T
    converged::Bool
end

struct BlanchardOLGSolution{T<:AbstractFloat}
    ss::BlanchardOLGSteadyState{T}
    M::Matrix{T}
    eigenvalues::Vector{ComplexF64}
    stable_eig::T
    policy_slope::T
    determinate::Bool
end

# Continuous-time HA (C041)
struct CTPoissonIncome{T<:AbstractFloat}
    z::Vector{T}
    lambda::Vector{T}
end

struct CTAiyagari{T<:AbstractFloat}
    alpha::T
    rho::T
    sigma::T
    delta::T
    Z::T
    income::CTPoissonIncome{T}
    a_min::T
    a_max::T
    I::Int
end

function CTAiyagari(; alpha::Real=0.36, rho::Real=0.05, sigma::Real=2.0, delta::Real=0.05,
                      Z::Real=1.0, z::AbstractVector=[0.1, 0.2],
                      lambda::AbstractVector=[0.5, 0.5],
                      a_min::Real=0.0, a_max::Real=30.0, I::Int=500)
    T = Float64
    inc = CTPoissonIncome{T}(collect(T, z), collect(T, lambda))
    CTAiyagari{T}(T(alpha), T(rho), T(sigma), T(delta), T(Z), inc, T(a_min), T(a_max), I)
end

struct CTSteadyState{T<:AbstractFloat}
    r::T
    w::T
    K::T
    L::T
    a::Vector{T}
    g::Matrix{T}
    v::Matrix{T}
    c::Matrix{T}
    s::Matrix{T}
    A::Any
    converged::Bool
end

struct CTTransition{T<:AbstractFloat}
    t::Vector{T}
    Z::Vector{T}
    K::Vector{T}
    r::Vector{T}
    w::Vector{T}
    C::Vector{T}
    converged::Bool
    iterations::Int
end

struct CTTwoAsset{T<:AbstractFloat}
    sigma::T
    rho::T
    r_a::T
    r_b::T
    chi::T
    w::T
    income::Any
    b_max::T
    a_max::T
    Ib::Int
    Ia::Int
end

function CTTwoAsset(; sigma::Real=2.0, rho::Real=0.06, r_a::Real=0.05, r_b::Real=0.02,
                      chi::Real=0.03, w::Real=1.0, b_max::Real=40.0, a_max::Real=70.0,
                      Ib::Int=40, Ia::Int=25)
    T = Float64
    CTTwoAsset{T}(T(sigma), T(rho), T(r_a), T(r_b), T(chi), T(w), nothing,
                  T(b_max), T(a_max), Ib, Ia)
end

struct CTTwoAssetSolution{T<:AbstractFloat}
    b::Vector{T}
    a::Vector{T}
    V::Array{T,3}
    c::Array{T,3}
    d::Array{T,3}
    sb::Array{T,3}
    sa::Array{T,3}
    g::Array{T,3}
    B::T
    A::T
    gen::Any
    hjb_converged::Bool
end

struct X13FilterResult{T<:AbstractFloat}
    trend::Vector{T}
    seasonal::Vector{T}
    irregular::Vector{T}
    adjusted::Vector{T}
    original::Vector{T}
    method::Symbol
    arima_order::NTuple{N,Int} where N
    frequency::Int
    transform::Symbol
    sigma2::T
    aic::T
    n_outliers::Int
    T_obs::Int
end

struct IOData{T}
    Z::Matrix{T}
    Y::Matrix{T}
    va::Matrix{T}
    x::Vector{T}
    sectors::Vector{String}
    regions::Vector{String}
    fd_cats::Vector{String}
    va_cats::Vector{String}
    extensions::Dict{String,Any}
    unit::String
    year::Int
    source::String
    meta::Dict{String,Any}
end

const _HA_EXAMPLE_NAMES = (:krusell_smith, :one_asset_hank, :two_asset_hank, :huggett)

function load_ha_example(name::Symbol)
    name in _HA_EXAMPLE_NAMES || error(
        "Unknown HA-DSGE example: :$name. Available: :krusell_smith, :one_asset_hank, :two_asset_hank, :huggett")
    HADSGESpec{Float64}(nothing, nothing, nothing, nothing, nothing,
                        Dict{Symbol,Float64}(:alpha => 0.36, :delta => 0.025),
                        50, 2, name)
end
load_ha_example(name::String) = load_ha_example(Symbol(replace(name, "-" => "_")))

struct KrusellSmithSolution{T<:AbstractFloat}
    steady_state::HASteadyState{T}
    plm_coefficients::Vector{T}
    r_squared::T
    spec::HADSGESpec{T}
    converged::Bool
    iterations::Int
end

function _mock_ha_ss(spec::HADSGESpec{T}) where T
    HASteadyState{T}(
        Dict{Symbol,Any}(:savings => ones(T, 10, 2) * T(0.5)),
        ones(T, 10, 2) ./ 20,
        ones(T, 10, 2),
        Dict{Symbol,T}(:r => T(0.01), :w => T(1.0)),
        Dict{Symbol,T}(:K => T(10.0), :Y => T(1.0), :excess_demand => T(0.0)),
        nothing, nothing, true, 10, T(1e-6), T(0.0))
end

function compute_steady_state(spec::HADSGESpec{T};
        K_init=nothing, r_bounds=nothing, max_iter::Int=100, tol=1e-8,
        verbose::Bool=false, price_fn=nothing, clearing=nothing) where T
    _mock_ha_ss(spec)
end

function solve(spec::HADSGESpec{T}; method::Symbol=:ssj, ss=nothing,
               n_reduced::Int=10, T_horizon::Int=300,
               T_sim::Int=11000, T_burn::Int=1000, max_outer::Int=20) where T
    ss0 = ss === nothing ? _mock_ha_ss(spec) : ss
    if method === :krusell_smith
        return KrusellSmithSolution{T}(ss0, T[0.1, 0.9, 0.05], T(0.99), spec, true, 5)
    end
    method in (:ssj, :reiter) || error(
        "Unknown HA-DSGE method: :$method. Use :ssj, :reiter, or :krusell_smith.")
    n_red = n_reduced
    n_sys = max(n_red + 1, 2)
    endog = [Symbol("x_$i") for i in 1:n_sys]
    dummy_dsge = DSGESpec{T}(endog, [:epsilon], Symbol[], Dict{Symbol,T}(),
                             n_sys, 1, 0, string.(endog), zeros(T, n_sys), false)
    G1 = Matrix{T}(I, n_sys, n_sys) * T(0.5)
    impact = ones(T, n_sys, 1) * T(0.1)
    lin = LinearDSGE{T}(Matrix{T}(I, n_sys, n_sys), G1, zeros(T, n_sys), impact,
                         zeros(T, n_sys, 0), dummy_dsge)
    dsol = DSGESolution{T}(G1, impact, zeros(T, n_sys), [1, 1], method,
                            Complex{T}[T(0.5) + 0im], dummy_dsge, lin)
    n_full = 20
    U = ones(T, n_full, min(n_red, n_full)) ./ T(n_full)
    C_obs = method === :ssj ? ones(T, 1, n_sys) : Matrix{T}(I, n_sys, n_sys)
    D_obs = method === :ssj ? ones(T, 1, 1) * T(0.1) : zeros(T, n_sys, 1)
    HADSGESolution{T}(ss0, dsol, method, spec, U, n_full, n_red, T(0.95),
                      nothing, C_obs, D_obs)
end

function irf(sol::HADSGESolution{T}, horizon::Int; ci_type::Symbol=:none) where T
    n_out = size(sol.C_obs, 1)
    vals = ones(T, horizon, n_out, 1) * T(0.05)
    vars = ["y$i" for i in 1:n_out]
    ImpulseResponse(vals, nothing, nothing, horizon, vars, ["epsilon"], ci_type)
end

function fevd(sol::HADSGESolution{T}, horizon::Int) where T
    n_out = size(sol.C_obs, 1)
    props = ones(T, n_out, 1, horizon)
    FEVD(copy(props), props, ["y$i" for i in 1:n_out], ["epsilon"])
end

function simulate(sol::HADSGESolution{T}, T_periods::Int;
                  shock_draws=nothing, rng=Random.default_rng()) where T
    n_out = size(sol.C_obs, 1)
    ones(T, T_periods, n_out) * T(0.01)
end

function distribution_irf(sol::HADSGESolution{T}, horizon::Int;
                          shock_index::Int=1, shock_size::Real=1.0) where T
    sol.method === :ssj && error(
        "distribution IRFs are unavailable for method=:ssj; use method=:reiter.")
    zeros(T, 10, 2, horizon)
end

function inequality_irf(sol::HADSGESolution{T}, horizon::Int;
                        shock_index::Int=1, shock_size::Real=1.0) where T
    Dict{Symbol,Vector{T}}(
        :gini => fill(T(0.4), horizon),
        :p10 => fill(T(0.1), horizon),
        :p25 => fill(T(0.2), horizon),
        :p50 => fill(T(0.5), horizon),
        :p75 => fill(T(0.8), horizon),
        :p90 => fill(T(1.5), horizon),
    )
end

function inequality_irf(ss::HASteadyState{T}; T_periods::Int=50) where T
    Dict{Symbol,Vector{T}}(
        :gini => fill(T(0.4), T_periods),
        :p10 => fill(T(0.1), T_periods),
        :p25 => fill(T(0.2), T_periods),
        :p50 => fill(T(0.5), T_periods),
        :p75 => fill(T(0.8), T_periods),
        :p90 => fill(T(1.5), T_periods),
    )
end

function simulate_panel(ss::HASteadyState{T};
                        N_agents::Int=1000, T_periods::Int=100,
                        rng=Random.default_rng()) where T
    ones(T, N_agents, T_periods) .* T(1.0) .+ randn(rng, T, N_agents, T_periods) .* T(0.1)
end

# HA Bayesian estimation (C048; un-deferred after MEMs#228). Returns BayesianDSGE with
# RWMH method — mirrors the real HADSGESpec dispatch surface.
function estimate_dsge_bayes(spec::HADSGESpec{T}, data::AbstractMatrix, theta0;
        priors=Dict(), observables=Symbol[], n_draws::Int=5000, burnin::Int=1000,
        measurement_error=nothing, ha_method::Symbol=:ssj,
        ha_kwargs=NamedTuple(), proposal_scale=0.01, adapt_interval::Int=100,
        rng=nothing) where {T<:AbstractFloat}
    np = length(theta0)
    n_kept = max(n_draws - burnin, 1)
    tv = T.(collect(theta0))
    draws = randn(T, n_kept, np) .* T(0.01) .+ reshape(tv, 1, np)
    log_post = fill(T(-100.0), n_kept)
    pnames = isempty(priors) ? ["param_$i" for i in 1:np] :
             sort!([String(k) for k in keys(priors)])
    ess_hist = fill(T(0.8), 10)
    dspec = DSGESpec()
    sol = solve(dspec; method=:gensys)
    BayesianDSGE{T}(draws, log_post, pnames, T(-450.0 + np), :rwmh, T(0.30),
                    ess_hist, dspec, sol)
end

function x13_filter(y::AbstractVector{T};
                    frequency::Int=12,
                    method::Symbol=:seats,
                    start::Tuple{Int,Int}=(1,1),
                    transform::Symbol=:auto,
                    model::Symbol=:auto,
                    trading_day::Bool=false,
                    easter::Bool=false,
                    easter_window::Int=8,
                    outliers::Bool=true,
                    critical_value::Float64=0.0) where {T<:AbstractFloat}
    n = length(y)
    n < 3 * frequency && throw(ArgumentError(
        "x13_filter requires at least 3 × frequency = $(3 * frequency) observations, got $n"))
    frequency ∉ (4, 12) && throw(ArgumentError(
        "x13_filter supports frequency 4 (quarterly) or 12 (monthly), got $frequency"))
    method ∉ (:seats, :x11) && throw(ArgumentError(
        "method must be :seats or :x11, got :$method"))
    z = Float64.(y)
    seas = [0.5 * sin(2π * t / frequency) for t in 1:n]
    trend = [z[t] - seas[t] for t in 1:n]
    irr = zeros(n)
    adj = z .- seas
    X13FilterResult{Float64}(trend, seas, irr, adj, z, method, (0,1,1,0,1,1),
                             frequency, transform === :auto ? :none : transform,
                             1.0, 0.0, outliers ? 1 : 0, n)
end
x13_filter(y::AbstractVector; frequency::Int=12, method::Symbol=:seats,
           transform::Symbol=:auto, trading_day::Bool=false, easter::Bool=false,
           outliers::Bool=true, critical_value::Float64=0.0) =
    x13_filter(Float64.(y); frequency=frequency, method=method, transform=transform,
               trading_day=trading_day, easter=easter, outliers=outliers,
               critical_value=critical_value)

# ── Input-Output analysis mock (C049) ─────────────────────────
# Faithful re-implementation of the MEMs io module (real formulas) so handler
# unit tests catch table-shaping bugs. `IOData` is defined above (~L4423).

struct IOExtension{T}
    F::Matrix{T}
    F_Y::Matrix{T}
    S::Matrix{T}
    stressors::Vector{String}
    unit::Vector{String}
end

struct IOMetaData
    source::String
    version::String
    history::Vector{String}
    files::Vector{Pair{String,String}}
end

struct LeontiefModel{T}
    A::Matrix{T}
    L::Matrix{T}
    x::Vector{T}
    io::IOData{T}
end

struct GhoshModel{T}
    B::Matrix{T}
    G::Matrix{T}
    x::Vector{T}
    io::IOData{T}
end

struct IOMultipliers
    values::Vector{Float64}
    kind::Symbol
    type::Symbol
    sectors::Vector{String}
end

struct LinkageResult
    backward::Vector{Float64}
    forward::Vector{Float64}
    Ui::Vector{Float64}
    Uj::Vector{Float64}
    classification::Vector{Symbol}
    sectors::Vector{String}
end

struct SDAResult
    effects::Dict{Symbol,Vector{Float64}}
    total::Vector{Float64}
    residual::Vector{Float64}
    method::Symbol
end

struct ExtractionResult
    total_loss::Float64
    sector_loss::Vector{Float64}
    extracted::Vector{Int}
end

struct FootprintResult
    total::Matrix{Float64}
    by_sector::Matrix{Float64}
    stressors::Vector{String}
    name::String
end

struct BaqaeeFarhiResult
    domar::Vector{Float64}
    first_order::Vector{Float64}
    second_order::Matrix{Float64}
    influence::Vector{Float64}
    upstreamness::Vector{Float64}
    downstreamness::Vector{Float64}
    sectors::Vector{String}
end

struct IOSourceTable
    rows::Vector{Tuple{Symbol,NamedTuple}}
end

_io_invdiag(x::AbstractVector{T}) where {T} =
    T[xi == zero(T) ? zero(T) : one(T) / xi for xi in x]

technical_coefficients(io::IOData) = io.Z * Diagonal(_io_invdiag(io.x))
function leontief_inverse(io::IOData{T}) where {T}
    A = technical_coefficients(io); Matrix{T}(inv(I - A))
end
allocation_coefficients(io::IOData) = Diagonal(_io_invdiag(io.x)) * io.Z
function ghosh_inverse(io::IOData{T}) where {T}
    B = allocation_coefficients(io); Matrix{T}(inv(I - B))
end
function leontief(io::IOData{T}) where {T}
    A = technical_coefficients(io); LeontiefModel{T}(A, Matrix{T}(inv(I - A)), copy(io.x), io)
end
function ghosh(io::IOData{T}) where {T}
    B = allocation_coefficients(io); GhoshModel{T}(B, Matrix{T}(inv(I - B)), copy(io.x), io)
end

function _io_household(io::IOData, kind::Symbol)
    invx = _io_invdiag(io.x)
    if kind == :output
        return ones(length(io.x))
    elseif kind == :income
        return vec(sum(io.va, dims=1)) .* invx
    elseif kind == :employment
        haskey(io.extensions, "employment") ||
            throw(ArgumentError("no 'employment' extension; add one with add_extension!"))
        return vec(sum(io.extensions["employment"].F, dims=1)) .* invx
    else
        throw(ArgumentError("kind must be :output, :income, or :employment"))
    end
end

function _io_closed_leontief(io::IOData)
    A = technical_coefficients(io); n = size(A, 1); invx = _io_invdiag(io.x)
    hinc = vec(io.va[1, :]) .* invx
    y = vec(sum(io.Y, dims=2)); hc = y ./ max(sum(y), eps())
    Abar = [A hc; reshape(collect(float.(hinc)), 1, n) 0.0]
    Matrix{Float64}(inv(I - Abar))
end

function multipliers(io::IOData; kind::Symbol=:output, type::Symbol=:I)
    L = leontief_inverse(io); h = _io_household(io, kind)
    if type == :I
        vals = kind == :output ? vec(sum(L, dims=1)) : vec(L' * h)
    elseif type == :II
        n = length(io.x); L2 = _io_closed_leontief(io)
        vals = kind == :output ? vec(sum(view(L2, 1:n, 1:n), dims=1)) :
               kind == :income ? collect(view(L2, n + 1, 1:n)) :
               vec(transpose(view(L2, 1:n, 1:n)) * h)
    else
        throw(ArgumentError("type must be :I or :II"))
    end
    IOMultipliers(vals, kind, type, copy(io.sectors))
end

_io_classify(ui, uj) = ui > 1 && uj > 1 ? :key : ui > 1 && uj <= 1 ? :backward :
                       ui <= 1 && uj > 1 ? :forward : :weak

function linkages(io::IOData; forward::Symbol=:ghosh)
    L = leontief_inverse(io); n = size(L, 1)
    backward = vec(sum(L, dims=1))
    fwd = forward == :ghosh ? vec(sum(ghosh_inverse(io), dims=2)) :
          forward == :leontief ? vec(sum(L, dims=2)) :
          throw(ArgumentError("forward must be :ghosh or :leontief"))
    Ui = backward ./ (sum(backward) / n); Uj = fwd ./ (sum(fwd) / n)
    LinkageResult(backward, fwd, Ui, Uj,
                  [_io_classify(Ui[i], Uj[i]) for i in 1:n], copy(io.sectors))
end
rasmussen(io::IOData) = linkages(io)
key_sectors(io::IOData) = linkages(io).classification

function sda(io0::IOData, io1::IOData; method::Symbol=:additive,
            factors::Symbol=:LY, average::Symbol=:two_polar)
    L0 = leontief_inverse(io0); L1 = leontief_inverse(io1)
    y0 = vec(sum(io0.Y, dims=2)); y1 = vec(sum(io1.Y, dims=2))
    ΔL = L1 - L0; Δy = y1 - y0
    if method == :additive
        L_eff = 0.5 .* (ΔL * y0 .+ ΔL * y1); Y_eff = 0.5 .* (L1 * Δy .+ L0 * Δy)
        total = L1 * y1 .- L0 * y0
        return SDAResult(Dict(:L => L_eff, :Y => Y_eff), total,
                         total .- (L_eff .+ Y_eff), :additive)
    elseif method == :multiplicative
        x0 = L0 * y0; x1 = L1 * y1; ratio = x1 ./ max.(x0, eps())
        L_eff = (L1 * y0) ./ max.(x0, eps()); Y_eff = ratio ./ max.(L_eff, eps())
        return SDAResult(Dict(:L => L_eff, :Y => Y_eff), ratio,
                         ratio .- (L_eff .* Y_eff), :multiplicative)
    else
        throw(ArgumentError("method must be :additive or :multiplicative"))
    end
end

_io_sector_idx(io::IOData, s::Integer) = [Int(s)]
_io_sector_idx(io::IOData, s::AbstractVector{<:Integer}) = collect(Int, s)
function _io_sector_idx(io::IOData, s::AbstractString)
    idx = findfirst(==(s), io.sectors)
    idx === nothing && throw(ArgumentError("sector '$s' not found")); [idx]
end
_io_sector_idx(io::IOData, s::AbstractVector{<:AbstractString}) =
    reduce(vcat, _io_sector_idx.(Ref(io), s))

function hypothetical_extraction(io::IOData, sectors)
    idx = _io_sector_idx(io, sectors); A = technical_coefficients(io)
    y = vec(sum(io.Y, dims=2)); x_base = (I - A) \ y
    Ae = copy(A); Ae[idx, :] .= 0.0; Ae[:, idx] .= 0.0
    ye = copy(y); ye[idx] .= 0.0; x_red = (I - Ae) \ ye
    loss = x_base .- x_red
    ExtractionResult(sum(loss), loss, idx)
end

function add_extension!(io::IOData{T}, name::AbstractString, F::AbstractMatrix;
                        stressors, unit, F_Y=nothing) where {T}
    Fm = Matrix{T}(F); S = Fm * Diagonal(_io_invdiag(io.x))
    FYm = F_Y === nothing ? zeros(T, size(Fm, 1), size(io.Y, 2)) : Matrix{T}(F_Y)
    io.extensions[String(name)] =
        IOExtension{T}(Fm, FYm, S, collect(String.(stressors)), collect(String.(unit)))
    io
end
_io_ext(io, name) = haskey(io.extensions, name) ? io.extensions[name] :
    throw(ArgumentError("no extension '$name'"))
intensities(io::IOData, name::AbstractString) = _io_ext(io, name).S
emission_multipliers(io::IOData, name::AbstractString) =
    _io_ext(io, name).S * leontief_inverse(io)
function footprint(io::IOData, name::AbstractString)
    ext = _io_ext(io, name); L = leontief_inverse(io); M = ext.S * L
    total = M * io.Y .+ ext.F_Y; y = vec(sum(io.Y, dims=2))
    FootprintResult(total, M .* reshape(y, 1, :), ext.stressors, String(name))
end

domar_weights(io::IOData) = io.x ./ sum(io.va)
function baqaee_farhi(io::IOData; theta=nothing, sigma=nothing)
    λ = domar_weights(io); L = leontief_inverse(io)
    y = vec(sum(io.Y, dims=2)); β = y ./ sum(y)
    n = length(λ)
    BaqaeeFarhiResult(λ, copy(λ), zeros(n, n), vec(L' * β),
                      vec(sum(L, dims=2)), vec(sum(L, dims=1)), copy(io.sectors))
end

const _IO_SOURCES = Dict{Symbol,NamedTuple}(
    :oecd => (name="OECD ICIO", needs_credentials=false, versions=["v2016","v2018","v2021","v2023"], note="ICIO tables."),
    :wiod => (name="WIOD 2013", needs_credentials=false, versions=["2013"], note="World IO Database."),
    :exiobase3 => (name="EXIOBASE 3", needs_credentials=false, versions=["3.8.2"], note="Zenodo-hosted."),
    :eora26 => (name="EORA26", needs_credentials=true, versions=["26"], note="Requires worldmrio.com account."),
    :gloria => (name="GLORIA", needs_credentials=false, versions=["053"], note="Fixed URL set."),
)
list_io_sources() = IOSourceTable([(k, _IO_SOURCES[k]) for k in sort(collect(keys(_IO_SOURCES)))])

# Per-source downloaders mirror the REAL restricted signatures (sources.jl): only
# exiobase3 accepts `system`; eora26 accepts neither `system` nor `verify`. This
# lets T1/T2 catch a handler that over-forwards kwargs (real download_io relays
# extras verbatim → MethodError), instead of the mock silently swallowing them.
_io_dl_meta(name, ver, key) = IOMetaData(name, ver, ["mock download of :$key"],
    Pair{String,String}["https://example.org/$(key)_1.zip" => "$(key)_1.zip",
                        "https://example.org/$(key)_2.zip" => "$(key)_2.zip"])
download_oecd(folder; version="v2023", years=nothing, overwrite_existing::Bool=false, verify::Bool=true) =
    _io_dl_meta("OECD ICIO", version, :oecd)
download_wiod(folder; years=nothing, overwrite_existing::Bool=false, verify::Bool=true) =
    _io_dl_meta("WIOD 2013", "2013", :wiod)
download_exiobase3(folder; years=nothing, system::AbstractString="pxp",
                   overwrite_existing::Bool=false, verify::Bool=true) =
    _io_dl_meta("EXIOBASE3", "3.8.2", :exiobase3)
download_eora26(folder; email, password, years=nothing, overwrite_existing::Bool=false) =
    _io_dl_meta("EORA26", "26", :eora26)
download_gloria(folder; years=nothing, overwrite_existing::Bool=false, verify::Bool=true) =
    _io_dl_meta("GLORIA", "053", :gloria)

function download_io(source::Symbol; storage_folder, years=nothing,
                     overwrite_existing::Bool=false, version=nothing,
                     email=nothing, password=nothing, kwargs...)
    if source == :oecd
        download_oecd(storage_folder; version=something(version, "v2023"), years=years,
                      overwrite_existing=overwrite_existing, kwargs...)
    elseif source == :wiod
        download_wiod(storage_folder; years=years, overwrite_existing=overwrite_existing, kwargs...)
    elseif source == :exiobase3
        download_exiobase3(storage_folder; years=years, overwrite_existing=overwrite_existing, kwargs...)
    elseif source == :eora26
        download_eora26(storage_folder; email=something(email, ""), password=something(password, ""),
                        years=years, overwrite_existing=overwrite_existing, kwargs...)
    elseif source == :gloria
        download_gloria(storage_folder; years=years, overwrite_existing=overwrite_existing, kwargs...)
    else
        throw(ArgumentError("unknown source :$source; see list_io_sources()"))
    end
end

# Miller & Blair (2009) 2-sector fixture — mirrors data/wiot.toml.
function _mock_wiot()
    Z = [150.0 500.0; 200.0 100.0]; Y = reshape([350.0, 1700.0], 2, 1)
    va = [300.0 1000.0; 350.0 400.0]
    x = vec(sum(Z, dims=2)) .+ vec(sum(Y, dims=2))
    exts = Dict{String,Any}()
    io = IOData{Float64}(Z, Y, va, x, ["Agriculture","Manufacturing"], ["total"],
                         ["final_demand"], ["compensation","other_va"], exts,
                         "millions", 2009,
                         "Miller, R.E. & Blair, P.D. (2009) Input-Output Analysis, 2nd ed., Table 2.3",
                         Dict{String,Any}())
    add_extension!(io, "employment", reshape([30.0, 40.0], 1, 2);
                   stressors=["jobs"], unit=["thousand persons"])
    add_extension!(io, "CO2", reshape([100.0, 300.0], 1, 2);
                   stressors=["CO2"], unit=["kt"])
    io
end

# Mirrors the real parse_io CSV path (parse.jl): reads the file and slices
# raw[1:n_sectors, ...], so an oversized n_sectors raises BoundsError just like
# real _parse_csv_io — keeps the handler's error-mapping honest under T1/T2.
function parse_io(path::AbstractString; source::Symbol=:csv, year=nothing,
                  n_sectors::Int=2, n_fd::Int=1, sectors=String[], delim::AbstractChar=',')
    ext = lowercase(splitext(path)[2])
    ext in (".csv", ".tsv", ".txt") ||
        throw(ArgumentError("unsupported file type '$ext' for parse_io"))
    rows = Vector{Float64}[]
    for l in eachline(path)
        s = strip(l)
        isempty(s) && continue
        push!(rows, [parse(Float64, t) for t in split(s, delim)])
    end
    raw = permutedims(reduce(hcat, rows))            # nrow × ncol
    Z = raw[1:n_sectors, 1:n_sectors]                # BoundsError if n_sectors too large
    Y = raw[1:n_sectors, n_sectors+1:n_sectors+n_fd]
    x = vec(sum(Z, dims=2)) .+ vec(sum(Y, dims=2))
    va = reshape(x .- vec(sum(Z, dims=1)), 1, n_sectors)
    secs = isempty(sectors) ? ["sector$i" for i in 1:n_sectors] : collect(String.(sectors))
    IOData{Float64}(Matrix{Float64}(Z), Matrix{Float64}(Y), Matrix{Float64}(va), x,
                    secs, ["total"], ["fd$j" for j in 1:n_fd], ["va1"],
                    Dict{String,Any}(), "", year === nothing ? 0 : Int(year),
                    string(source), Dict{String,Any}())
end

function BlanchardOLG(; alpha::Real=0.36, beta::Real=0.96, delta::Real=0.08,
                        gamma::Real=0.98, Z::Real=1.0, b::Real=0.0)
    T = Float64
    BlanchardOLG{T}(T(alpha), T(beta), T(delta), T(gamma), T(Z), T(b))
end

function blanchard_steady_state(m::BlanchardOLG{T}; tol::Real=1e-10, max_iter::Int=200) where T
    BlanchardOLGSteadyState{T}(T(5.0), T(1.2), T(0.04), T(1.0), T(10.0),
                               one(T) - m.beta * m.gamma, m.b, true)
end

function blanchard_solve(m::BlanchardOLG{T},
                          ss::BlanchardOLGSteadyState{T}=blanchard_steady_state(m)) where T
    BlanchardOLGSolution{T}(ss, Matrix{T}(I, 2, 2), ComplexF64[0.5, 1.2],
                            T(0.85), T(0.16), true)
end

function blanchard_transition(m::BlanchardOLG{T}, sol::BlanchardOLGSolution{T}, k0::Real;
                               H::Int=50) where T
    kpath = [T(k0) + (sol.ss.k - T(k0)) * (one(T) - sol.stable_eig^t) for t in 0:H]
    Cpath = [sol.ss.C + sol.policy_slope * (k - sol.ss.k) for k in kpath]
    rpath = fill(sol.ss.r, H + 1)
    wpath = fill(sol.ss.w, H + 1)
    return (k=kpath, C=Cpath, r=rpath, w=wpath)
end

function ct_steady_state(m::CTAiyagari{T}; r_bounds=nothing, max_iter::Int=100,
                          tol::Real=1e-6, hjb_max_iter::Int=100, hjb_tol::Real=1e-6,
                          Delta::Real=1000.0) where T
    a = collect(range(m.a_min, m.a_max; length=m.I))
    g = ones(T, m.I, 2) ./ T(2 * m.I)
    v = ones(T, m.I, 2)
    c = ones(T, m.I, 2) * T(0.5)
    s = zeros(T, m.I, 2)
    CTSteadyState{T}(T(0.04), T(1.0), T(3.0), T(1.0), a, g, v, c, s, nothing, true)
end

function ct_mit_shock(m::CTAiyagari{T}, ss0::CTSteadyState{T}, Z_path::AbstractVector;
                       dt::Real=0.25, max_iter::Int=300, tol::Real=1e-6,
                       relax::Real=0.3) where T
    N = length(Z_path)
    t = collect(T, 0:N-1) .* T(dt)
    Z = collect(T, Z_path)
    K = fill(ss0.K, N); K[1] = ss0.K * T(0.98)
    for i in 2:N
        K[i] = ss0.K + (K[1] - ss0.K) * T(0.9)^(i - 1)
    end
    r = fill(ss0.r, N); w = fill(ss0.w, N); C = fill(ss0.K * ss0.r + ss0.w, N)
    CTTransition{T}(t, Z, K, r, w, C, true, 5)
end

function ct_two_asset_solve(m::CTTwoAsset{T}; max_iter::Int=200, tol::Real=1e-6,
                             Delta::Real=1000.0) where T
    b = collect(range(zero(T), m.b_max; length=m.Ib))
    a = collect(range(zero(T), m.a_max; length=m.Ia))
    V = ones(T, m.Ib, m.Ia, 2)
    c = ones(T, m.Ib, m.Ia, 2) * T(0.5)
    d = zeros(T, m.Ib, m.Ia, 2)
    sb = zeros(T, m.Ib, m.Ia, 2)
    sa = zeros(T, m.Ib, m.Ia, 2)
    g = ones(T, m.Ib, m.Ia, 2) ./ T(2 * m.Ib * m.Ia)
    CTTwoAssetSolution{T}(b, a, V, c, d, sb, sa, g, T(1.0), T(5.0), nothing, true)
end

export OrderedLogitModel, OrderedProbitModel, MultinomialLogitModel
export estimate_ologit, estimate_oprobit, estimate_mlogit
export brant_test, hausman_iia, dropna, keeprows

export HADSGESpec, HASteadyState, HADSGESolution, KrusellSmithSolution
export CTAiyagari, CTSteadyState, CTTransition, CTTwoAsset, CTTwoAssetSolution, CTPoissonIncome
export BlanchardOLG, BlanchardOLGSteadyState, BlanchardOLGSolution
export X13FilterResult, IOData
export load_ha_example, compute_steady_state, distribution_irf, inequality_irf, simulate_panel
export ct_steady_state, ct_mit_shock, ct_two_asset_solve
export x13_filter, parse_io, blanchard_steady_state, blanchard_solve, blanchard_transition
# Input-Output analysis (C049)
export IOExtension, IOMetaData, LeontiefModel, GhoshModel, IOMultipliers, LinkageResult
export SDAResult, ExtractionResult, FootprintResult, BaqaeeFarhiResult, IOSourceTable
export technical_coefficients, leontief_inverse, allocation_coefficients, ghosh_inverse
export leontief, ghosh, multipliers, linkages, rasmussen, key_sectors
export sda, hypothetical_extraction, add_extension!, intensities, emission_multipliers, footprint
export domar_weights, baqaee_farhi, list_io_sources, download_io
export download_oecd, download_wiod, download_exiobase3, download_eora26, download_gloria

end # module
