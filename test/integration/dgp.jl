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

"""ARFIMA(0,d,0) long-memory series via the truncated (1-L)^{-d} MA(∞) filter.
ψ_0 = 1, ψ_k = ψ_{k-1}·(k-1+d)/k; y_t = Σ_{k=0}^{t-1} ψ_k ε_{t-k}. d≈0.3 → persistent
but stationary long memory."""
function dgp_fracdiff(; T::Int=400, d::Float64=0.3, σ::Float64=1.0, seed::Int=42)
    rng = MersenneTwister(seed)
    ε = σ .* randn(rng, T)
    ψ = zeros(T)
    ψ[1] = 1.0
    for k in 2:T
        ψ[k] = ψ[k-1] * ((k - 2) + d) / (k - 1)
    end
    y = zeros(T)
    for t in 1:T
        s = 0.0
        @inbounds for k in 1:t
            s += ψ[k] * ε[t - k + 1]
        end
        y[t] = s
    end
    return write_csv(DataFrame(y=y); prefix="fracdiff")
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

"""Balanced DiD / Panel-VAR panel: `N` units × `T` periods, columns id/time/y/d.
Half the units are treated from `treat_start` (a 0/1 post indicator `d`), the
rest never-treated; parallel pre-trends + a `att` treatment effect on `y`."""
function dgp_did_panel(; N::Int=40, T::Int=10, treat_start::Int=6,
                        att::Float64=2.0, seed::Int=7)
    rng = MersenneTwister(seed)
    id = Int[]; time = Int[]; y = Float64[]; d = Int[]
    for i in 1:N
        treated = i <= N ÷ 2
        ufe = randn(rng)
        for t in 1:T
            di = (treated && t >= treat_start) ? 1 : 0
            push!(id, i); push!(time, t)
            push!(y, ufe + 0.1 * t + att * di + 0.3 * randn(rng))
            push!(d, di)
        end
    end
    return write_csv(DataFrame(id=id, time=time, y=y, d=d); prefix="did")
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

"""Correlated multivariate GARCH(1,1)-like returns (`n` series × `T` obs). Each series
follows its own GARCH recursion; innovations share a common standard-normal factor so the
conditional correlation is non-trivial (drives CCC/DCC/BEKK)."""
function dgp_mgarch(; T::Int=300, n::Int=2, seed::Int=42)
    rng = MersenneTwister(seed)
    ω, α, β = 0.05, 0.08, 0.9
    R = zeros(T, n)
    σ2 = ones(T, n)
    for t in 2:T
        z_common = randn(rng)
        for j in 1:n
            σ2[t, j] = ω + α * R[t-1, j]^2 + β * σ2[t-1, j]
            z = 0.5 * z_common + sqrt(0.75) * randn(rng)
            R[t, j] = sqrt(σ2[t, j]) * z
        end
    end
    df = DataFrame([Symbol("r$j") => R[:, j] for j in 1:n])
    return write_csv(df; prefix="mgarch")
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

"""Cross-section DGP for penalized/robust/tobit (C067a): p regressors with a sparse
true β (only the first three coefficients nonzero → a lasso/elastic-net should shrink the
rest). Returns `(csv_clean, csv_censored, β)`:
* `csv_clean` — columns `y, x1..xp` (clean linear `y`), for lasso/ridge/elastic-net/robust;
* `csv_censored` — columns `yc, x1..xp`, where `yc = max(y - shift, 0)` (default shift 0
  ⇒ ≈50% left-censored, which Tobit recovers well), for Tobit.
Each CSV holds ONLY its target + the regressors (never both targets) so the shared
`_load_reg_data` loader picks exactly `x1..xp` as X. True β is `[-1.0, 0.8, -0.6, 0, 0, ...]`."""
function dgp_penalized(; T::Int=300, p::Int=5, seed::Int=42, censor_shift::Float64=0.0)
    rng = MersenneTwister(seed)
    X = randn(rng, T, p)
    β = zeros(p)
    for j in 1:min(3, p)
        β[j] = (-1.0)^j * (1.0 - 0.2 * (j - 1))   # -1.0, 0.8, -0.6, then 0, 0, ...
    end
    y = X * β .+ 0.3 .* randn(rng, T)
    yc = max.(y .- censor_shift, 0.0)              # left-censored at 0
    df_clean = DataFrame(y=y)
    df_cens  = DataFrame(yc=yc)
    for j in 1:p
        df_clean[!, "x$j"] = X[:, j]
        df_cens[!, "x$j"]  = X[:, j]
    end
    return write_csv(df_clean; prefix="penalized"), write_csv(df_cens; prefix="tobit"), β
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
