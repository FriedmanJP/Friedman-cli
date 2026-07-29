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

"""ARDL / error-correction DGP with a stable long-run relationship (C062b):
`x_t` is a stationary AR(0.5); `y_t = c + φ y_{t-1} + β₀ x_t + β₁ x_{t-1} + e_t` (φ=0.5).
The long-run multiplier is `θ = (β₀+β₁)/(1−φ)` — used to check ARDL long-run recovery
(loose) and that the PSS bounds test returns a valid decision symbol."""
function dgp_ardl(; T::Int=300, φ::Float64=0.5, β0::Float64=1.0, β1::Float64=0.5,
                   c::Float64=0.2, seed::Int=42)
    rng = MersenneTwister(seed)
    x = zeros(T)
    for t in 2:T
        x[t] = 0.5 * x[t-1] + randn(rng)
    end
    y = zeros(T)
    for t in 2:T
        y[t] = c + φ * y[t-1] + β0 * x[t] + β1 * x[t-1] + 0.5 * randn(rng)
    end
    θ = (β0 + β1) / (1 - φ)
    return write_csv(DataFrame(y=y, x=x); prefix="ardl"), θ
end

"""NARDL / asymmetric-adjustment DGP (C062b): `x_t` is a random walk whose positive and
negative increments load on `y` with DIFFERENT long-run coefficients, so the long-run
symmetry test should reject and the +/- dynamic multipliers should diverge. Set `sym=true`
for a symmetric control DGP (equal loadings → fail to reject symmetry)."""
function dgp_nardl(; T::Int=300, φ::Float64=0.5, θpos::Float64=1.0, θneg::Float64=-0.3,
                    seed::Int=42, sym::Bool=false)
    rng = MersenneTwister(seed)
    tp = θpos; tn = sym ? θpos : θneg
    dx = randn(rng, T)
    x = cumsum(dx)
    xpos = zeros(T); xneg = zeros(T)
    for t in 2:T
        xpos[t] = xpos[t-1] + max(dx[t], 0.0)
        xneg[t] = xneg[t-1] + min(dx[t], 0.0)
    end
    # error-correction toward θ⁺·x⁺ + θ⁻·x⁻
    y = zeros(T)
    for t in 2:T
        lr = tp * xpos[t] + tn * xneg[t]
        y[t] = y[t-1] + (1 - φ) * (lr - y[t-1]) + 0.4 * randn(rng)
    end
    return write_csv(DataFrame(y=y, x=x); prefix=sym ? "nardl_sym" : "nardl_asym"), tp, tn
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

"""Cross-section IV DGP (C067b): one endogenous regressor instrumented by two strong
excluded instruments, plus a `const` and one exogenous control. Columns `y, const, x2,
x_endog, z1, z2`. Structural: y = 1 + 2·x_endog + 0.8·x2 + u; first stage x_endog =
0.7·z1 + 0.5·z2 + 0.6·u + noise (so x_endog is endogenous but z1,z2 are STRONG → the
weak-instrument test should NOT flag it). True β on x_endog is 2.0."""
function dgp_iv(; T::Int=300, seed::Int=42, inst_strength::Float64=0.7)
    rng = MersenneTwister(seed)
    z1 = randn(rng, T); z2 = randn(rng, T); x2 = randn(rng, T)
    u = randn(rng, T)
    x_endog = inst_strength .* z1 .+ 0.5 .* z2 .+ 0.6 .* u .+ 0.3 .* randn(rng, T)
    y = 1.0 .+ 2.0 .* x_endog .+ 0.8 .* x2 .+ u
    # `const` is a Julia keyword → build with string-keyed columns (a data column named
    # "const" is fine at the CSV/CLI layer; only the Julia constructor keyword is reserved).
    df = DataFrame("y" => y, "const" => fill(1.0, T), "x2" => x2,
                   "x_endog" => x_endog, "z1" => z1, "z2" => z2)
    return write_csv(df; prefix="iv")
end

"""Cross-section Heckman sample-selection DGP (C067b). Latent outcome y* = 1 + 0.8·x1 + ε,
selection d = 1{ 0.3 + 0.5·x1 + 1.0·z1 + ν > 0 } with corr(ε, ν)=ρ; y observed only when
d=1. `z1` is the exclusion restriction (drives selection, not the outcome). Columns
`y, d, const, x1, z1` — y for the non-selected rows is set to 0 (unobserved; the estimator
uses only d==1 rows). True outcome slope on x1 is 0.8."""
function dgp_heckman(; T::Int=800, seed::Int=42, ρ::Float64=0.5)
    rng = MersenneTwister(seed)
    x1 = randn(rng, T); z1 = randn(rng, T)
    e1 = randn(rng, T)
    ν = ρ .* e1 .+ sqrt(1 - ρ^2) .* randn(rng, T)   # corr(e1, ν) = ρ
    ystar = 1.0 .+ 0.8 .* x1 .+ e1
    d = Float64.(0.3 .+ 0.5 .* x1 .+ 1.0 .* z1 .+ ν .> 0.0)
    y = [d[t] == 1.0 ? ystar[t] : 0.0 for t in 1:T]
    df = DataFrame("y" => y, "d" => d, "const" => fill(1.0, T), "x1" => x1, "z1" => z1)
    return write_csv(df; prefix="heckman")
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

# ── C069/C070: variance-ratio / BDS / Hadri / panel-cointegration DGPs ──

"""Pure random walk y_t = y_{t-1} + ε_t — the variance-ratio H0 (VR ≈ 1)."""
function dgp_random_walk(; T::Int=600, seed::Int=42)
    rng = MersenneTwister(seed)
    return write_csv(DataFrame(y=cumsum(randn(rng, T))); prefix="rw")
end

"""iid white noise y_t = ε_t — the BDS H0 (iid)."""
function dgp_iid(; T::Int=400, seed::Int=42)
    rng = MersenneTwister(seed)
    return write_csv(DataFrame(y=randn(rng, T)); prefix="iid")
end

"""Wide T×N panel matrix (columns = units) for the Hadri panel-stationarity test
(H0: all units stationary). `unit_root=false` ⇒ each column a stationary AR(1);
`unit_root=true` ⇒ each column an independent random walk."""
function dgp_panel_matrix(; N::Int=10, T::Int=80, unit_root::Bool=false,
                           φ::Float64=0.5, seed::Int=42)
    rng = MersenneTwister(seed)
    df = DataFrame()
    for j in 1:N
        e = randn(rng, T)
        if unit_root
            df[!, "u$j"] = cumsum(e)
        else
            col = zeros(T)
            for t in 2:T
                col[t] = φ * col[t-1] + e[t]
            end
            df[!, "u$j"] = col
        end
    end
    return write_csv(df; prefix=unit_root ? "hadri_i1" : "hadri_i0")
end

"""Long-format cointegrated panel (columns id/time/y/x): per unit i, x_it is a
unit-specific I(1) random walk and y_it = β·x_it + stationary error, so y and x are
cointegrated within each unit → the Pedroni/Kao/Westerlund tests should reject
no-cointegration."""
function dgp_coint_panel(; N::Int=10, T::Int=50, β::Float64=1.0, seed::Int=42)
    rng = MersenneTwister(seed)
    id = Int[]; time = Int[]; y = Float64[]; x = Float64[]
    for i in 1:N
        xi = cumsum(randn(rng, T))            # unit-specific I(1) regressor
        yi = β .* xi .+ 0.5 .* randn(rng, T)  # cointegrated with x (stationary resid)
        for t in 1:T
            push!(id, i); push!(time, t)
            push!(y, yi[t]); push!(x, xi[t])
        end
    end
    return write_csv(DataFrame(id=id, time=time, y=y, x=x); prefix="cpanel")
end

# Heterogeneous-panel ARDL error-correction system with a COMMON long-run θ:
#   Δy_it = φ_i (y_{i,t-1} − θ x_{i,t-1}) + β_i Δx_it + ε_it,
# φ_i ∈ [−0.6,−0.3] (heterogeneous EC speed), β_i heterogeneous short-run, x_it a random walk.
# Used by the PMG T3: the pooled long-run θ should be recovered (loose) across units.
function dgp_pmg(; N::Int=10, T::Int=60, θ::Float64=1.0, seed::Int=42)
    rng = MersenneTwister(seed)
    id = Int[]; time = Int[]; y = Float64[]; x = Float64[]
    for i in 1:N
        φi = -(0.3 + 0.3 * rand(rng))       # heterogeneous, error-correcting (negative)
        βi = 0.4 + 0.6 * rand(rng)          # heterogeneous short-run impact
        xi = zeros(T); yi = zeros(T)
        xi[1] = randn(rng); yi[1] = θ * xi[1] + 0.3 * randn(rng)
        for t in 2:T
            dx = 0.3 * randn(rng)
            xi[t] = xi[t-1] + dx
            ec = yi[t-1] - θ * xi[t-1]
            yi[t] = yi[t-1] + φi * ec + βi * dx + 0.15 * randn(rng)
        end
        for t in 1:T
            push!(id, i); push!(time, t); push!(y, yi[t]); push!(x, xi[t])
        end
    end
    return write_csv(DataFrame(id=id, time=time, y=y, x=x); prefix="pmgpanel")
end

"""Mixed-frequency MIDAS DGP (C062d): a high-frequency indicator `x_hf` (AR(0.5), length
`m*Tlf`) drives a low-frequency target `y = a + b·Σ_k w_k x_{HF-lag k} + e` through a known
exp-Almon weight curve (θ=(θ₁,θ₂), decaying, sums to 1). Returns `(lf_csv, hf_csv, b)`: the LF
target CSV (column `gdp`), the HF indicator CSV (column `ip`, exactly `m` obs per LF period), and
the true HF loading `b`. Used to check `estimate midas` recovers a positive, finite HF loading
and a sensible R² (loose — restricted MIDAS NLS is noisy)."""
function dgp_midas(; Tlf::Int=120, m::Int=3, K::Int=6, a::Float64=1.0, b::Float64=2.0,
                    θ1::Float64=0.3, θ2::Float64=-0.08, seed::Int=42)
    rng = MersenneTwister(seed)
    lenhf = m * Tlf
    x = zeros(lenhf)
    for h in 2:lenhf
        x[h] = 0.5 * x[h-1] + randn(rng)          # AR(0.5) high-frequency indicator
    end
    # known exp-Almon weight curve over K most-recent HF lags (sums to 1)
    kk = collect(1.0:K)
    z = θ1 .* kk .+ θ2 .* (kk .^ 2); z .-= maximum(z)
    w = exp.(z); w ./= sum(w)
    y = zeros(Tlf)
    for t in 1:Tlf
        hi = lenhf - (Tlf - t) * m                # most-recent HF obs in LF period t
        lo = hi - K + 1
        s = lo >= 1 ? sum(w[k] * x[hi-(k-1)] for k in 1:K) : 0.0
        y[t] = a + b * s + 0.3 * randn(rng)
    end
    lf = write_csv(DataFrame(gdp=y); prefix="midas_lf")
    hf = write_csv(DataFrame(ip=x); prefix="midas_hf")
    return lf, hf, b
end

"""Genuine two-regime SETAR: yₜ = 0.6 yₜ₋₁ + εₜ if yₜ₋₁ ≤ 0, else -0.5 yₜ₋₁ + εₜ. The
sign flip of the AR coefficient at the threshold 0 makes this self-exciting series clearly
nonlinear → both regimes are populated, γ̂ lands near 0, and the Hansen (1996) linearity
test rejects linearity (loose bootstrap direction)."""
function dgp_setar(; n::Int=400, seed::Int=42)
    rng = MersenneTwister(seed)
    y = zeros(n)
    for t in 2:n
        y[t] = (y[t-1] <= 0 ? 0.6 * y[t-1] : -0.5 * y[t-1]) + randn(rng)
    end
    return write_csv(DataFrame(y=y); prefix="setar")
end

"""Genuine self-exciting LSTAR: yₜ = (1−Gₜ)·0.8 yₜ₋₁ + Gₜ·(−0.4 yₜ₋₁) + εₜ, where the
logistic weight Gₜ = 1/(1+exp(−5·yₜ₋₁)) switches smoothly in yₜ₋₁. The strong asymmetry
(0.8 vs −0.4) makes the series clearly nonlinear → the STAR LM3 test rejects linearity and
`estimate star` recovers a nonzero γ̂ with lm3_pvalue < 0.10 (loose direction only)."""
function dgp_star(; n::Int=400, seed::Int=42)
    rng = MersenneTwister(seed)
    burn = 100
    total = n + burn
    yy = zeros(total)
    for t in 2:total
        G = 1.0 / (1.0 + exp(-5.0 * yy[t-1]))
        yy[t] = (1 - G) * (0.8 * yy[t-1]) + G * (-0.4 * yy[t-1]) + randn(rng)
    end
    return write_csv(DataFrame(y=yy[(burn+1):total]); prefix="star")
end

"""Genuine 2-regime mean-switching series: a latent 2-state Markov chain (sticky, stay
probability 0.95) drives the level μ ∈ {−3, 3} with a common AR(1) φ = 0.5 and unit-variance
Gaussian noise, `(yₜ − μ_{sₜ}) = 0.5·(y_{t−1} − μ_{s_{t−1}}) + εₜ`. The wide, well-separated
means make the two regimes recoverable → `estimate ms-ar` converges to an ordered `mu` with a
row-stochastic P, and `estimate ms` (intercept-only on the same series) recovers two distinct
regime means. Loose/direction-only teeth (EM is noisy)."""
function dgp_msar(; n::Int=500, seed::Int=42)
    rng = MersenneTwister(seed)
    mus = (-3.0, 3.0)
    s = 1
    y = zeros(n)
    prev_mu = mus[s]
    y[1] = prev_mu + randn(rng)
    for t in 2:n
        rand(rng) < 0.05 && (s = 3 - s)         # sticky 2-state chain (stay prob 0.95)
        mu = mus[s]
        y[t] = mu + 0.5 * (y[t-1] - prev_mu) + randn(rng)
        prev_mu = mu
    end
    return write_csv(DataFrame(y=y); prefix="msar")
end

# ── C069 (remainder): seasonal / bubble / non-cointegrated DGPs ──────────────

"""Quarterly series with a SEASONAL UNIT ROOT: the seasonal differences accumulate
(`y_t = y_{t-4} + ε_t`), so HEGY should fail to reject a unit root at the seasonal
frequencies. `deterministic=true` instead gives fixed quarterly dummies around a
stationary AR(1), where the seasonal roots ARE rejected."""
function dgp_seasonal(; T::Int=240, deterministic::Bool=false, seed::Int=42)
    rng = MersenneTwister(seed)
    y = zeros(T)
    if deterministic
        dummies = [2.0, -1.0, 0.5, -1.5]
        for t in 2:T
            y[t] = 0.4 * y[t-1] + dummies[mod1(t, 4)] + randn(rng)
        end
    else
        for t in 5:T
            y[t] = y[t-4] + randn(rng)      # seasonal random walk
        end
    end
    return write_csv(DataFrame(y=y); prefix="seasonal")
end

"""Series with an explosive episode in the middle: a random walk that switches to
`y_t = 1.06 y_{t-1} + ε_t` for a stretch, then reverts. SADF/GSADF should reject the
unit-root null; a pure random walk (`dgp_random_walk`) should not."""
function dgp_bubble(; T::Int=300, start::Int=150, stop::Int=210, δ::Float64=1.06,
                    seed::Int=42)
    rng = MersenneTwister(seed)
    y = zeros(T)
    for t in 2:T
        y[t] = (start <= t <= stop ? δ * y[t-1] : y[t-1]) + randn(rng)
    end
    return write_csv(DataFrame(y=y); prefix="bubble")
end

"""Two INDEPENDENT random walks — the residual-cointegration H0 (no cointegration).
The mirror of `dgp_coint`, which is genuinely cointegrated."""
function dgp_no_coint(; T::Int=250, seed::Int=42)
    rng = MersenneTwister(seed)
    return write_csv(DataFrame(x=cumsum(randn(rng, T)), y=cumsum(randn(rng, T)));
                     prefix="nocoint")
end
