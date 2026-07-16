# Known-DGP synthetic data generators for integration tests (TS-6 / C031)

using Random
using LinearAlgebra
using Statistics
using CSV
using DataFrames

"""Write a DataFrame to a temp CSV and return the path."""
function write_csv(df::DataFrame; prefix="dgp")
    path = tempname() * "_$(prefix).csv"
    CSV.write(path, df)
    return path
end

"""AR(1): y_t = φ y_{t-1} + ε_t with φ=0.7 (default)."""
function dgp_ar1(; T::Int=200, φ::Float64=0.7, σ::Float64=1.0, seed::Int=42)
    rng = MersenneTwister(seed)
    y = zeros(T)
    for t in 2:T
        y[t] = φ * y[t-1] + σ * randn(rng)
    end
    return write_csv(DataFrame(y=y); prefix="ar1")
end

"""Stable VAR(2) with 3 variables."""
function dgp_var2(; T::Int=200, seed::Int=42)
    rng = MersenneTwister(seed)
    n = 3
    # Companion-stable lag coeffs (small)
    A1 = [0.4 0.1 0.0;
          0.1 0.3 0.05;
          0.0 0.05 0.35]
    A2 = [0.1 0.0 0.0;
          0.0 0.1 0.0;
          0.0 0.0 0.1]
    Y = zeros(T, n)
    ε = randn(rng, T, n)
    for t in 3:T
        Y[t, :] = A1 * Y[t-1, :] + A2 * Y[t-2, :] + ε[t, :]
    end
    return write_csv(DataFrame(y1=Y[:,1], y2=Y[:,2], y3=Y[:,3]); prefix="var2")
end

"""Cointegrated pair: x_t random walk, y_t = β x_t + stationary."""
function dgp_coint(; T::Int=250, β::Float64=1.0, seed::Int=42)
    rng = MersenneTwister(seed)
    x = cumsum(randn(rng, T))
    y = β .* x .+ randn(rng, T)
    return write_csv(DataFrame(x=x, y=y); prefix="coint")
end

"""GARCH(1,1)-like returns (univariate)."""
function dgp_garch(; T::Int=500, seed::Int=42)
    rng = MersenneTwister(seed)
    ω, α, β = 0.05, 0.1, 0.85
    r = zeros(T)
    σ2 = ones(T)
    for t in 2:T
        σ2[t] = ω + α * r[t-1]^2 + β * σ2[t-1]
        r[t] = sqrt(σ2[t]) * randn(rng)
    end
    return write_csv(DataFrame(r=r); prefix="garch")
end

"""Binary logit DGP: P(y=1|x) = Λ(β'x)."""
function dgp_logit(; T::Int=400, seed::Int=42)
    rng = MersenneTwister(seed)
    x1 = randn(rng, T)
    x2 = randn(rng, T)
    η = -0.5 .+ 1.2 .* x1 .- 0.8 .* x2
    p = 1.0 ./ (1.0 .+ exp.(-η))
    y = [rand(rng) < p[t] ? 1.0 : 0.0 for t in 1:T]
    return write_csv(DataFrame(y=y, x1=x1, x2=x2); prefix="logit")
end

"""Cross-section for OLS: y = 1 + 2 x + e."""
function dgp_reg(; T::Int=200, seed::Int=42)
    rng = MersenneTwister(seed)
    x = randn(rng, T)
    y = 1.0 .+ 2.0 .* x .+ 0.5 .* randn(rng, T)
    return write_csv(DataFrame(y=y, x=x); prefix="reg")
end

"""Stationary series for unit-root tests (should reject unit root)."""
function dgp_stationary(; T::Int=200, seed::Int=42)
    return dgp_ar1(; T=T, φ=0.5, seed=seed)
end

"""HP-filterable series (trend + cycle)."""
function dgp_trend_cycle(; T::Int=200, seed::Int=42)
    rng = MersenneTwister(seed)
    t = 1:T
    trend = 0.01 .* t
    cycle = sin.(2π .* t ./ 20) .+ 0.3 .* randn(rng, T)
    y = trend .+ cycle
    return write_csv(DataFrame(y=y); prefix="tc")
end
