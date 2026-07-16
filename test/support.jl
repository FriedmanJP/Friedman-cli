# Shared test helpers (TS-1). Included by runtests / test_commands / test_e2e.

using Test
using CSV, DataFrames, JSON3, PrettyTables, TOML
using Random

# ─── Test Helpers ───────────────────────────────────────────────

"""Create a temp CSV file with synthetic multivariate data."""
function _make_csv(dir; T=100, n=3, colnames=nothing)
    cols = isnothing(colnames) ? ["var$i" for i in 1:n] : colnames
    data = Dict{String,Vector{Float64}}()
    for (i, name) in enumerate(cols)
        data[name] = randn(T) .+ Float64(i)
    end
    path = joinpath(dir, "data.csv")
    CSV.write(path, DataFrame(data))
    return path
end

"""Create a temp instruments CSV file."""
function _make_instruments_csv(dir; T=100, n_inst=2)
    data = Dict{String,Vector{Float64}}()
    for i in 1:n_inst
        data["z$i"] = randn(T)
    end
    path = joinpath(dir, "instruments.csv")
    CSV.write(path, DataFrame(data))
    return path
end

"""Capture stdout (and stderr) from a function call, returning the string.

After P1-2, status prose goes to stderr; tests that assert on status text
need both streams. Data remains on stdout; merging keeps assertions stable.
"""
function _capture(f)
    path, io = mktemp()
    try
        redirect_stdio(f; stdout=io, stderr=io)
        close(io)
        return read(path, String)
    finally
        try; close(io); catch; end
        try; rm(path; force=true); catch; end
    end
end

"""Capture stdout and stderr separately as a NamedTuple `(out, err)`."""
function _capture_all(f)
    outp, outio = mktemp()
    errp, errio = mktemp()
    try
        redirect_stdio(f; stdout=outio, stderr=errio)
        close(outio); close(errio)
        return (out=read(outp, String), err=read(errp, String))
    finally
        try; close(outio); catch; end
        try; close(errio); catch; end
        try; rm(outp; force=true); catch; end
        try; rm(errp; force=true); catch; end
    end
end

"""Dispatch via a minimal Entry built from register_* (mock-bound)."""
function _dispatch_via_app(args::Vector{String})
    root_cmds = Dict{String,Union{NodeCommand,LeafCommand}}(
        "estimate" => register_estimate_commands!(),
        "test"     => register_test_commands!(),
        "irf"      => register_irf_commands!(),
        "fevd"     => register_fevd_commands!(),
        "hd"       => register_hd_commands!(),
        "forecast"  => register_forecast_commands!(),
        "predict"   => register_predict_commands!(),
        "residuals" => register_residuals_commands!(),
        "filter"    => register_filter_commands!(),
        "data"      => register_data_commands!(),
        "nowcast"   => register_nowcast_commands!(),
        "dsge"      => register_dsge_commands!(),
        "did"       => register_did_commands!(),
        "spectral"  => register_spectral_commands!(),
    )
    root = NodeCommand("friedman", root_cmds, "test tree")
    entry = Entry("friedman", root; version=v"0.4.3")
    return dispatch(entry, args)
end

"""Create a temp CSV file with synthetic panel data (group + time columns)."""
function _make_panel_csv(dir; G=5, T_per=20, n=3, colnames=nothing)
    cols = isnothing(colnames) ? ["var$i" for i in 1:n] : colnames
    rows = G * T_per
    data = Dict{String,Vector}()
    data["group"] = repeat(1:G, inner=T_per)
    data["time"] = repeat(1:T_per, outer=G)
    for (i, name) in enumerate(cols)
        data[name] = randn(rows) .+ Float64(i)
    end
    path = joinpath(dir, "panel.csv")
    CSV.write(path, DataFrame(data))
    return path
end

"""Create a TOML config for prior settings."""
function _make_prior_config(dir; optimize=false)
    path = joinpath(dir, "prior.toml")
    open(path, "w") do io
        write(io, """
        [prior]
        type = "minnesota"
        [prior.hyperparameters]
        lambda1 = 0.2
        lambda2 = 0.5
        lambda3 = 1.0
        lambda4 = 100000.0
        [prior.optimization]
        enabled = $optimize
        """)
    end
    return path
end

"""Create a TOML config for sign identification."""
function _make_sign_config(dir)
    path = joinpath(dir, "sign.toml")
    open(path, "w") do io
        write(io, """
        [identification]
        method = "sign"
        [identification.sign_matrix]
        matrix = [[1, -1, 1], [0, 1, -1], [0, 0, 1]]
        horizons = [0, 1, 2]
        """)
    end
    return path
end

"""Create a TOML config for narrative identification."""
function _make_narrative_config(dir)
    path = joinpath(dir, "narrative.toml")
    open(path, "w") do io
        write(io, """
        [identification]
        method = "narrative"
        [identification.sign_matrix]
        matrix = [[1, -1, 1], [0, 1, -1], [0, 0, 1]]
        horizons = [0]
        [identification.narrative]
        shock_index = 1
        periods = [10, 15]
        signs = [1, -1]
        """)
    end
    return path
end

"""Create a TOML config for Arias identification."""
function _make_arias_config(dir)
    path = joinpath(dir, "arias.toml")
    open(path, "w") do io
        write(io, """
        [[identification.zero_restrictions]]
        var = 1
        shock = 1
        horizon = 0
        [[identification.sign_restrictions]]
        var = 2
        shock = 1
        sign = "positive"
        horizon = 0
        """)
    end
    return path
end

"""Create a TOML config for Uhlig identification."""
function _make_uhlig_config(dir)
    path = joinpath(dir, "uhlig.toml")
    open(path, "w") do io
        write(io, """
        [[identification.zero_restrictions]]
        var = 1
        shock = 1
        horizon = 0
        [[identification.sign_restrictions]]
        var = 2
        shock = 1
        sign = "positive"
        horizon = 0
        [identification.uhlig]
        n_starts = 50
        n_refine = 10
        """)
    end
    return path
end

"""Create a TOML config for GMM."""
function _make_gmm_config(dir; colnames=["var1","var2","var3"])
    path = joinpath(dir, "gmm.toml")
    open(path, "w") do io
        write(io, """
        [gmm]
        moment_conditions = ["$(colnames[1])", "$(colnames[2])"]
        instruments = ["lag_$(colnames[1])", "lag_$(colnames[2])"]
        weighting = "twostep"
        """)
    end
    return path
end

"""Create a TOML config for nongaussian smooth_transition."""
function _make_ng_smooth_config(dir; transition_var="var2")
    path = joinpath(dir, "ng_smooth.toml")
    open(path, "w") do io
        write(io, """
        [nongaussian]
        method = "smooth_transition"
        transition_variable = "$transition_var"
        """)
    end
    return path
end

"""Create a TOML config for nongaussian external volatility."""
function _make_ng_external_config(dir; regime_var="var3")
    path = joinpath(dir, "ng_external.toml")
    open(path, "w") do io
        write(io, """
        [nongaussian]
        method = "external"
        regime_variable = "$regime_var"
        """)
    end
    return path
end

# ─── Tests ─────────────────────────────────────────────────────


"""Compare golden envelope JSON loosely (filled in C022)."""
function _golden_compare(actual_json::AbstractString, golden_path::AbstractString)
    if !isfile(golden_path)
        @warn "golden missing" golden_path
        return false
    end
    return strip(actual_json) == strip(read(golden_path, String))
end
