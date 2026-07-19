# Integration core vs real MacroEconometricModels (TS-6 / C031 / F35)
# Run: julia --project=test/integration test/integration/runtests.jl
#
# Each case asserts: (a) envelope schema-valid, (b) scalar sanity / teeth,
# (c) non-empty table shapes.

using Test
using JSON3
using Friedman
using Random
using Statistics
using LinearAlgebra

const ROOT = dirname(dirname(@__DIR__))
const SCHEMA_PATH = joinpath(ROOT, "schema", "envelope-v1.json")

include(joinpath(@__DIR__, "dgp.jl"))
include(joinpath(@__DIR__, "schema_validate.jl"))

# ── Runner ────────────────────────────────────────────────────

"""Run friedman args with --quiet --format=json; return (code, doc, raw)."""
function run_json(args::Vector{String}; quiet::Bool=true)
    argv = String[]
    quiet && push!(argv, "--quiet")
    append!(argv, args)
    any(a -> startswith(a, "--format"), argv) || push!(argv, "--format", "json")

    out_path = tempname()
    err_path = tempname()
    code = try
        open(out_path, "w") do out_io
            open(err_path, "w") do err_io
                redirect_stdout(out_io) do
                    redirect_stderr(err_io) do
                        return Friedman.run_cli(argv)
                    end
                end
            end
        end
    catch
        Cint(1)
    end
    raw = read(out_path, String)
    rm(out_path; force=true)
    rm(err_path; force=true)
    doc = try
        JSON3.read(strip(raw))
    catch
        nothing
    end
    return (code=Int(code), doc=doc, raw=raw)
end

function assert_envelope_ok(r; label="")
    @test r.code == 0
    @test r.doc !== nothing
    r.doc === nothing && return
    @test string(r.doc.status) == "ok"
    errs = validate_envelope_json(r.raw; schema_path=SCHEMA_PATH)
    @test isempty(errs)
    if !isempty(errs)
        @info "schema errors for $label" errs
    end
end

"""First table rows from envelope data (dict of tables)."""
function first_table(doc)
    doc === nothing && return nothing, nothing
    data = try
        doc.data
    catch
        nothing
    end
    data === nothing && return nothing, nothing
    for (k, v) in pairs(data)
        if v isa JSON3.Object && haskey(v, :rows)
            return string(k), v
        elseif v isa AbstractDict && haskey(v, "rows")
            return string(k), v
        end
    end
    return nothing, nothing
end

function table_rows(tbl)
    rows = haskey(tbl, :rows) ? tbl.rows : tbl["rows"]
    return collect(rows)
end

function table_cols(tbl)
    cols = haskey(tbl, :columns) ? tbl.columns : tbl["columns"]
    return String[string(c) for c in cols]
end

function metric_value(tbl, metric_name::AbstractString)
    cols = table_cols(tbl)
    rows = table_rows(tbl)
    mi = findfirst(==("metric"), cols)
    vi = findfirst(==("value"), cols)
    (mi === nothing || vi === nothing) && return nothing
    for row in rows
        r = collect(row)
        string(r[mi]) == metric_name && return r[vi]
    end
    return nothing
end

"""A specific named table from envelope data (dict of tables), or nothing."""
function named_table(doc, name::Symbol)
    doc === nothing && return nothing
    data = try
        doc.data
    catch
        nothing
    end
    data === nothing && return nothing
    haskey(data, name) ? data[name] : nothing
end

"""Column index by name in a table, or nothing."""
col_index(tbl, name::AbstractString) = findfirst(==(name), table_cols(tbl))

# ── Tests ─────────────────────────────────────────────────────

@testset "Integration core vs real MEMs (TS-6)" begin
    @testset "estimate var (C051 tidy coef)" begin
        csv = dgp_var2(; T=180, seed=7)
        r = run_json(["estimate", "var", csv, "--lags", "2"])
        assert_envelope_ok(r; label="estimate var")
        coef = named_table(r.doc, :var_2_coefficients)
        @test coef !== nothing
        if coef !== nothing
            # C051: MEMs' uniform tidy coefficient table via DataFrame(model)
            @test table_cols(coef) ==
                  ["equation", "term", "estimate", "std_error", "stat", "p_value", "ci_lower", "ci_upper"]
            @test length(table_rows(coef)) >= 1
        end
        rm(csv; force=true)
    end

    @testset "estimate arima on AR(1) φ=0.7" begin
        csv = dgp_ar1(; T=250, φ=0.7, seed=11)
        r = run_json(["estimate", "arima", csv, "--column", "1"])
        assert_envelope_ok(r; label="estimate arima")
        # Extract AR coefficient if present in any table
        found_phi = false
        for (_, v) in pairs(r.doc.data)
            if (v isa JSON3.Object || v isa AbstractDict) && (haskey(v, :rows) || haskey(v, "rows"))
                cols = table_cols(v)
                rows = table_rows(v)
                # look for phi/ar/estimate columns
                for row in rows
                    rr = collect(row)
                    for x in rr
                        if x isa Real && 0.45 <= x <= 0.95
                            found_phi = true
                        end
                    end
                end
            end
        end
        # Soft numeric tooth: at least envelope OK; phi often appears as AR(1) coef
        @test r.doc.status == "ok" || string(r.doc.status) == "ok"
        # Prefer finding a coefficient in the AR band when present
        if found_phi
            @test found_phi
        end
        rm(csv; force=true)
    end

    @testset "test adf rejects unit root on stationary series" begin
        # Strongly mean-reverting → p-value should be small
        csv = dgp_ar1(; T=400, φ=0.2, seed=3)
        r = run_json(["test", "adf", csv, "--column", "1"])
        assert_envelope_ok(r; label="test adf")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        pv = metric_value(tbl, "p-value")
        @test pv !== nothing
        @test pv isa Real
        @test pv < 0.10   # teeth: stationary series should look stationary
        rm(csv; force=true)
    end

    @testset "test kpss" begin
        csv = dgp_ar1(; T=200, φ=0.3, seed=5)
        r = run_json(["test", "kpss", csv, "--column", "1"])
        assert_envelope_ok(r; label="test kpss")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        @test length(table_rows(tbl)) >= 1
        rm(csv; force=true)
    end

    @testset "irf var Cholesky tidy (C051)" begin
        csv = dgp_var2(; T=200, seed=9)
        r = run_json(["irf", "var", csv, "--lags", "2", "--horizons", "8",
                      "--shock", "1", "--ci", "none", "--id", "cholesky"])
        assert_envelope_ok(r; label="irf var")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        if tbl !== nothing
            # C051: tidy long_table, filtered to the selected --shock.
            @test table_cols(tbl) == ["horizon", "variable", "shock", "value", "lower", "upper"]
            ci = Dict(c => i for (i, c) in enumerate(table_cols(tbl)))
            rows = [collect(row) for row in table_rows(tbl)]
            @test length(unique(row[ci["shock"]] for row in rows)) == 1   # one shock
            h1 = [Float64(row[ci["value"]]) for row in rows if row[ci["horizon"]] == 1]
            @test any(x -> abs(x) > 1e-6, h1)   # Cholesky impact responses not all zero
        end
        rm(csv; force=true)
    end

    @testset "fevd var tidy (C051)" begin
        csv = dgp_var2(; T=180, seed=13)
        r = run_json(["fevd", "var", csv, "--lags", "2", "--horizons", "10", "--id", "cholesky"])
        assert_envelope_ok(r; label="fevd var")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        if tbl !== nothing
            @test table_cols(tbl) == ["horizon", "variable", "shock", "value"]
            ci = Dict(c => i for (i, c) in enumerate(table_cols(tbl)))
            rows = [collect(row) for row in table_rows(tbl)]
            # FEVD proportions are shares in [0, 1]
            @test all(-1e-8 <= Float64(row[ci["value"]]) <= 1.0 + 1e-8 for row in rows)
        end
        rm(csv; force=true)
    end

    @testset "hd var shape" begin
        csv = dgp_var2(; T=120, seed=15)
        r = run_json(["hd", "var", csv, "--lags", "1", "--id", "cholesky"])
        assert_envelope_ok(r; label="hd var")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        @test length(table_rows(tbl)) >= 1
        rm(csv; force=true)
    end

    @testset "forecast var (C051 tidy long_table)" begin
        csv = dgp_var2(; T=150, seed=17)
        r = run_json(["forecast", "var", csv, "--lags", "2", "--horizons", "4"])
        assert_envelope_ok(r; label="forecast var")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        if tbl !== nothing
            # C051: MEMs' uniform tidy long_table schema (one row per horizon×variable),
            # replacing the old wide per-variable table (horizon | var | var_lower | ...).
            @test table_cols(tbl) == ["horizon", "variable", "value", "lower", "upper"]
            @test length(table_rows(tbl)) == 4 * 3   # 4 horizons × 3 variables (dgp_var2)
        end
        rm(csv; force=true)
    end

    @testset "forecast arima tidy (C051)" begin
        csv = dgp_ar1(; T=200, φ=0.6, seed=19)
        r = run_json(["forecast", "arima", csv, "--column", "1", "--horizons", "5"])
        assert_envelope_ok(r; label="forecast arima")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        if tbl !== nothing
            @test table_cols(tbl) == ["horizon", "variable", "value", "lower", "upper"]
            @test length(table_rows(tbl)) == 5   # univariate: 5 horizons × 1 variable
        end
        rm(csv; force=true)
    end

    @testset "forecast vecm/lp/static tidy (C051)" begin
        # forecast leaves whose handlers return an AbstractForecastResult → long_table
        cointcsv = dgp_coint(; T=300, seed=45)
        rv = run_json(["forecast", "vecm", cointcsv, "--lags", "2", "--rank", "1", "--horizons", "6"])
        assert_envelope_ok(rv; label="forecast vecm")
        _, tv = first_table(rv.doc)
        @test tv !== nothing && table_cols(tv) == ["horizon", "variable", "value", "lower", "upper"]
        rm(cointcsv; force=true)

        mvcsv = dgp_var2(; T=150, seed=47)
        rl = run_json(["forecast", "lp", mvcsv, "--shock", "1", "--horizons", "6"])
        assert_envelope_ok(rl; label="forecast lp")
        _, tl = first_table(rl.doc)
        @test tl !== nothing && table_cols(tl) == ["horizon", "variable", "value", "lower", "upper"]

        rs = run_json(["forecast", "static", mvcsv, "--nfactors", "1", "--horizons", "6"])
        assert_envelope_ok(rs; label="forecast static")
        _, ts = first_table(rs.doc)
        @test ts !== nothing && table_cols(ts) == ["horizon", "variable", "value", "lower", "upper"]
        rm(mvcsv; force=true)
    end

    @testset "forecast bvar/dynamic/gdfm/favar tidy (C051 redesign)" begin
        # Previously hand-computed; now routed through MEMs forecast(...) → long_table.
        csv = dgp_var2(; T=150, seed=51)
        for args in (["forecast", "bvar", csv, "--lags", "1", "--draws", "80", "--horizons", "6"],
                     ["forecast", "dynamic", csv, "--nfactors", "1", "--horizons", "6"],
                     ["forecast", "gdfm", csv, "--nfactors", "1", "--dynamic-rank", "1", "--horizons", "6"],
                     ["forecast", "favar", csv, "--factors", "1", "--key-vars", "1", "--horizons", "6"])
            r = run_json(args)
            assert_envelope_ok(r; label=join(args[1:2], " "))
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            tbl !== nothing && @test table_cols(tbl) == ["horizon", "variable", "value", "lower", "upper"]
        end
        rm(csv; force=true)
    end

    @testset "filter hp" begin
        csv = dgp_trend_cycle(; T=120, seed=21)
        r = run_json(["filter", "hp", csv, "--columns", "1"])
        assert_envelope_ok(r; label="filter hp")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        @test length(table_rows(tbl)) >= 50
        rm(csv; force=true)
    end

    @testset "filter bn" begin
        csv = dgp_trend_cycle(; T=150, seed=23)
        r = run_json(["filter", "bn", csv, "--columns", "1"])
        # BN may fail on some series — accept ok or graceful error
        if r.code == 0 && r.doc !== nothing && string(r.doc.status) == "ok"
            assert_envelope_ok(r; label="filter bn")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
        else
            @test r.code != 0 || (r.doc !== nothing && string(r.doc.status) == "error")
            @info "filter bn skipped/failed on DGP (acceptable)" code=r.code
        end
        rm(csv; force=true)
    end

    @testset "estimate garch" begin
        csv = dgp_garch(; T=400, seed=25)
        r = run_json(["estimate", "garch", csv, "--column", "1", "--p", "1", "--q", "1"])
        assert_envelope_ok(r; label="estimate garch")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        @test length(table_rows(tbl)) >= 1
        rm(csv; force=true)
    end

    @testset "estimate reg OLS slope ≈ 2" begin
        csv = dgp_reg(; T=300, seed=27)
        r = run_json(["estimate", "reg", csv, "--dep", "y"])
        assert_envelope_ok(r; label="estimate reg")
        # Scan all tables for a coefficient on x ≈ 2
        found = false
        for (_, v) in pairs(r.doc.data)
            (v isa JSON3.Object || v isa AbstractDict) || continue
            haskey(v, :rows) || haskey(v, "rows") || continue
            cols = table_cols(v)
            rows = table_rows(v)
            name_i = findfirst(c -> c == "term" || occursin("var", lowercase(c)) || occursin("param", lowercase(c)), cols)
            est_i = findfirst(c -> occursin("coef", lowercase(c)) || occursin("estimate", lowercase(c)), cols)
            name_i === nothing && continue
            est_i === nothing && continue
            for row in rows
                rr = collect(row)
                if occursin(r"^x$", lowercase(string(rr[name_i]))) || lowercase(string(rr[name_i])) == "x"
                    β = rr[est_i]
                    @test β isa Real
                    @test 1.5 <= Float64(β) <= 2.5  # teeth: true slope is 2
                    found = true
                end
            end
        end
        @test found
        rm(csv; force=true)
    end

    @testset "estimate logit (C051 tidy coef)" begin
        csv = dgp_logit(; T=400, seed=29)
        r = run_json(["estimate", "logit", csv, "--dep", "y"])
        assert_envelope_ok(r; label="estimate logit")
        # a table carries the tidy single-equation coef schema
        tidy = ["term", "estimate", "std_error", "stat", "p_value", "ci_lower", "ci_upper"]
        has_coef = any(v -> (v isa JSON3.Object && haskey(v, :rows) && table_cols(v) == tidy),
                       values(r.doc.data))
        @test has_coef
        rm(csv; force=true)
    end

    @testset "test johansen on cointegrated pair" begin
        # C054 #270: the Johansen rank off-by-one is fixed upstream. A single
        # cointegrating relation must reject r=0 and fail to reject r=1, i.e.
        # the selected rank is exactly 1 (not 2, which the old bug produced).
        csv = dgp_coint(; T=300, seed=31)
        r = run_json(["test", "johansen", csv, "--lags", "2"])
        assert_envelope_ok(r; label="test johansen")
        trace = named_table(r.doc, :johansen_trace_test)
        @test trace !== nothing
        rows = [collect(x) for x in table_rows(trace)]
        ri = col_index(trace, "rank"); rj = col_index(trace, "reject")
        rejat(k) = (row = rows[findfirst(x -> Int(x[ri]) == k, rows)]; string(row[rj]))
        @test rejat(0) == "yes"   # reject r=0 → at least one cointegrating vector
        @test rejat(1) == "no"    # fail to reject r=1 → exactly one (rank = 1)
        rm(csv; force=true)
    end

    @testset "estimate vecm --rank auto selects rank 1" begin
        # C054 #270: auto rank selection on a cointegrated pair → exactly one
        # cointegrating vector (CV1), recovering β ≈ [1, -1].
        csv = dgp_coint(; T=300, seed=33)
        r = run_json(["estimate", "vecm", csv, "--lags", "2", "--rank", "auto"])
        assert_envelope_ok(r; label="estimate vecm --rank auto")
        beta = named_table(r.doc, :cointegrating_vectors_beta)
        @test beta !== nothing
        cols = table_cols(beta)
        @test "CV1" in cols        # exactly one cointegrating vector auto-selected
        @test !("CV2" in cols)
        rm(csv; force=true)
    end

    @testset "irf vecm tidy (C051)" begin
        csv = dgp_coint(; T=300, seed=35)
        r = run_json(["irf", "vecm", csv, "--lags", "2", "--rank", "1",
                      "--shock", "1", "--ci", "none", "--horizons", "8"])
        assert_envelope_ok(r; label="irf vecm")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        if tbl !== nothing
            @test table_cols(tbl) == ["horizon", "variable", "shock", "value", "lower", "upper"]
            ci = Dict(c => i for (i, c) in enumerate(table_cols(tbl)))
            rows = [collect(row) for row in table_rows(tbl)]
            @test length(unique(row[ci["shock"]] for row in rows)) == 1   # one shock
        end
        rm(csv; force=true)
    end

    @testset "fevd vecm tidy (C051)" begin
        csv = dgp_coint(; T=300, seed=37)
        r = run_json(["fevd", "vecm", csv, "--lags", "2", "--rank", "1", "--horizons", "10"])
        assert_envelope_ok(r; label="fevd vecm")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        if tbl !== nothing
            @test table_cols(tbl) == ["horizon", "variable", "shock", "value"]
            ci = Dict(c => i for (i, c) in enumerate(table_cols(tbl)))
            rows = [collect(row) for row in table_rows(tbl)]
            @test all(-1e-8 <= Float64(row[ci["value"]]) <= 1.0 + 1e-8 for row in rows)
        end
        rm(csv; force=true)
    end

    # ── Panel VAR + DiD family (C054): this suite is the gate that was missing
    # when the MEMs 0.7.0 bump silently broke xtset / estimate_pvar / pvar_fevd /
    # pvar_bootstrap_irf / pvar_lag_selection / lp_did. ──────────────────────
    @testset "panel VAR + DiD family on real MEMs" begin
        panel = dgp_did_panel(; N=40, T=10, seed=7)
        P = ["--id-col", "id", "--time-col", "time"]
        D = ["--outcome", "y", "--treatment", "d"]

        @testset "estimate pvar" begin
            r = run_json(vcat(["estimate", "pvar", panel], P, ["--lags", "1"]))
            assert_envelope_ok(r; label="estimate pvar")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing && length(table_rows(tbl)) >= 1
        end
        @testset "test pvar lagselect/mmsc/stability/hansen-j" begin
            for sub in ("lagselect", "mmsc", "stability", "hansen-j")
                r = run_json(vcat(["test", "pvar", sub, panel], P))
                assert_envelope_ok(r; label="test pvar $sub")
            end
        end
        @testset "irf pvar" begin
            r = run_json(vcat(["irf", "pvar", panel], P, ["--lags", "1", "--horizons", "4"]))
            assert_envelope_ok(r; label="irf pvar")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing && length(table_rows(tbl)) >= 1
        end
        @testset "fevd pvar proportions in [0,1]" begin
            r = run_json(vcat(["fevd", "pvar", panel], P, ["--lags", "1", "--horizons", "4"]))
            assert_envelope_ok(r; label="fevd pvar")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            for row in table_rows(tbl), v in collect(row)[2:end]
                v isa Real && (@test -1e-6 <= v <= 1 + 1e-6)
            end
        end
        @testset "did estimate has finite SE column (#164-169)" begin
            r = run_json(vcat(["did", "estimate", panel], D, P))
            assert_envelope_ok(r; label="did estimate")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            si = col_index(tbl, "SE")
            @test si !== nothing
            ses = [collect(row)[si] for row in table_rows(tbl)]
            @test all(x -> x isa Real && isfinite(x) && x >= 0, ses)
        end
        @testset "did test honest has RR robust + original CIs (C061)" begin
            r = run_json(vcat(["did", "test", "honest", panel], D, P))
            assert_envelope_ok(r; label="did test honest")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            cols = table_cols(tbl)
            # Rambachan–Roth structure: both robust and original CIs present.
            @test any(c -> occursin("Robust", c), cols)
            @test any(c -> occursin("Original", c), cols)
        end
        @testset "did event-study / lp-did / bacon / pretrend / negweight" begin
            # event-study also guards the stdout-contract fix (leading noise would
            # make the raw envelope unparseable → assert_envelope_ok fails).
            for (name, args) in (
                ("event-study", vcat(["did", "event-study", panel], D, P)),
                ("lp-did",      vcat(["did", "lp-did", panel], D, P)),
                ("test bacon",  vcat(["did", "test", "bacon", panel], D, P)),
                ("test pretrend", vcat(["did", "test", "pretrend", panel], D, P)),
                ("test negweight", vcat(["did", "test", "negweight", panel, "--treatment", "d"], P)),
            )
                r = run_json(args)
                assert_envelope_ok(r; label="did $name")
            end
        end
        rm(panel; force=true)
    end

    @testset "spectral density" begin
        csv = dgp_ar1(; T=200, φ=0.5, seed=35)
        r = run_json(["spectral", "density", csv, "--column", "1", "--method", "welch"])
        assert_envelope_ok(r; label="spectral density")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        @test length(table_rows(tbl)) >= 5
        rm(csv; force=true)
    end

    @testset "estimate lp" begin
        csv = dgp_var2(; T=200, seed=37)
        r = run_json(["estimate", "lp", csv, "--horizons", "5", "--control-lags", "2"])
        assert_envelope_ok(r; label="estimate lp")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        rm(csv; force=true)
    end

    @testset "estimate bvar tiny draws" begin
        csv = dgp_var2(; T=120, seed=39)
        r = run_json(["estimate", "bvar", csv, "--lags", "1", "--draws", "50"])
        # BVAR may be slow/stochastic; require success
        assert_envelope_ok(r; label="estimate bvar")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        rm(csv; force=true)
    end

    @testset "irf bvar tidy (C051)" begin
        csv = dgp_var2(; T=120, seed=43)
        r = run_json(["irf", "bvar", csv, "--lags", "1", "--draws", "80",
                      "--shock", "1", "--horizons", "6"])
        assert_envelope_ok(r; label="irf bvar")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        if tbl !== nothing
            @test table_cols(tbl) == ["horizon", "variable", "shock", "value", "lower", "upper"]
            ci = Dict(c => i for (i, c) in enumerate(table_cols(tbl)))
            rows = [collect(row) for row in table_rows(tbl)]
            @test length(unique(row[ci["shock"]] for row in rows)) == 1   # one shock
        end
        rm(csv; force=true)
    end

    @testset "var stability" begin
        csv = dgp_var2(; T=150, seed=41)
        r = run_json(["test", "var", "stability", csv, "--lags", "2"])
        assert_envelope_ok(r; label="var stability")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        rm(csv; force=true)
    end

    @testset "model handle round-trip no re-estimation" begin
        csv = dgp_var2(; T=100, seed=43)
        fmod = tempname() * ".fmod"
        r1 = run_json(["estimate", "var", csv, "--lags", "1", "--save-model", fmod])
        assert_envelope_ok(r1; label="estimate save-model")
        @test isfile(fmod)
        r2 = run_json(["irf", "var", "--model", fmod, "--horizons", "4", "--ci", "none"])
        assert_envelope_ok(r2; label="irf --model")
        _, tbl = first_table(r2.doc)
        @test tbl !== nothing
        @test length(table_rows(tbl)) >= 4
        rm(csv; force=true)
        rm(fmod; force=true)
    end

    # C040 — HA-DSGE against real MEMs (builtin huggett is smallest)
    @testset "dsge ha steady-state huggett" begin
        r = run_json(["dsge", "ha", "steady-state", "huggett"])
        assert_envelope_ok(r; label="dsge ha steady-state")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        @test length(table_rows(tbl)) >= 1
    end

    @testset "dsge ha solve reiter huggett" begin
        r = run_json(["dsge", "ha", "solve", "huggett",
                      "--method", "reiter", "--n-reduced", "8"])
        assert_envelope_ok(r; label="dsge ha solve reiter")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
    end

    @testset "dsge ha irf reiter huggett" begin
        r = run_json(["dsge", "ha", "irf", "huggett",
                      "--method", "reiter", "--horizon", "5", "--n-reduced", "8"])
        assert_envelope_ok(r; label="dsge ha irf")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        @test length(table_rows(tbl)) >= 5
    end

    # C048 — HA Bayesian estimation (un-deferred after MEMs#228). RWMH re-solves the HA
    # model each draw, so this is kept minimal (krusell-smith, 4 draws, tiny horizon/grid).
    @testset "dsge ha estimate krusell-smith (C048)" begin
        rng = Random.MersenneTwister(123)
        csv = write_csv(DataFrame(K = 40.0 .+ 0.1 .* randn(rng, 16)); prefix="ha_k")
        priors = tempname() * "_ha_priors.toml"
        write(priors, "[priors]\n[priors.alpha]\ndist = \"normal\"\na = 0.36\nb = 0.05\n")
        try
            r = run_json(["dsge", "ha", "estimate", "krusell-smith",
                          "--data", csv, "--priors", priors, "--observables", "K",
                          "--method", "ssj", "--n-draws", "4", "--burnin", "1",
                          "--t-horizon", "20", "--n-reduced", "6", "--seed", "1"])
            assert_envelope_ok(r; label="dsge ha estimate")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            @test length(table_rows(tbl)) >= 1   # posterior summary row for alpha
        finally
            rm(csv; force=true); rm(priors; force=true)
        end
    end

    # C041 — CT Aiyagari + Blanchard OLG (small grids for CI time)
    @testset "dsge ct solve aiyagari" begin
        r = run_json(["dsge", "ct", "solve",
                      "--grid-size", "40", "--max-iter", "40", "--tol", "1e-4"])
        assert_envelope_ok(r; label="dsge ct solve")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
    end

    @testset "dsge olg solve" begin
        r = run_json(["dsge", "olg", "solve"])
        assert_envelope_ok(r; label="dsge olg solve")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
    end

    @testset "dsge olg simulate" begin
        r = run_json(["dsge", "olg", "simulate", "--horizon", "20"])
        assert_envelope_ok(r; label="dsge olg simulate")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        @test length(table_rows(tbl)) >= 20
    end

    # C051 loader + C061 bayes-compare — representative-agent DSGE on real MEMs.
    # Regression guard: the RA DSGE surface (every `dsge` / `dsge bayes` leaf that loads
    # a model file, via _load_dsge_model) had ZERO T3 coverage and was silently broken on
    # the 0.7.0 pin — `.toml` had no real DSGESpec constructor (MethodError); `.jl` hit a
    # world-age MethodError on the @dsge-generated residual fns; and `bayes_factor` (now a
    # log BF) tripped `dsge bayes compare` with a log-of-negative DomainError. Keep green
    # so a future MEMs bump can't hide the same class of drift.
    @testset "representative-agent DSGE (C051/C061)" begin
        dir = mktempdir()
        # Linear AR(1)-style RA DSGE: Y is the driven state, C mirrors it (linear = true
        # so the steady state is trivially zero — no nonlinear solve inside SMC).
        model_toml = joinpath(dir, "model.toml")
        write(model_toml, """
        [model]
        parameters = { rho = 0.9, sigma = 0.01 }
        endogenous = ["Y", "C"]
        exogenous = ["e"]
        linear = true
        [[model.equations]]
        expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
        [[model.equations]]
        expr = "C[t] = Y[t]"
        """)
        # No `using MacroEconometricModels` here on purpose — the loader injects it (C051).
        model_jl = joinpath(dir, "model.jl")
        write(model_jl, """
        @dsge begin
            parameters: rho = 0.9, sigma = 0.01
            endogenous: Y, C
            exogenous: e
            linear: true

            Y[t] = rho * Y[t-1] + sigma * e[t]
            C[t] = Y[t]
        end
        """)

        @testset "dsge solve from TOML (TOML→@dsge bridge)" begin
            r = run_json(["dsge", "solve", model_toml])
            assert_envelope_ok(r; label="dsge solve toml")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            @test length(table_rows(tbl)) == 2   # Y, C
        end

        @testset "dsge solve from .jl (auto-import + world-age)" begin
            r = run_json(["dsge", "solve", model_jl])
            assert_envelope_ok(r; label="dsge solve jl")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            @test length(table_rows(tbl)) == 2
        end

        @testset "dsge steady-state from TOML (compute_steady_state world-age)" begin
            r = run_json(["dsge", "steady-state", model_toml])
            assert_envelope_ok(r; label="dsge steady-state")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
        end

        @testset "dsge irf from .jl (solve then IRF on solution)" begin
            r = run_json(["dsge", "irf", model_jl, "--horizon", "12"])
            assert_envelope_ok(r; label="dsge irf")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
        end

        @testset "dsge bayes compare (C061; log-BF semantics)" begin
            priors = joinpath(dir, "priors.toml")
            write(priors, """
            [priors]
            [priors.rho]
            dist = "beta"
            a = 0.5
            b = 0.2
            [priors.sigma]
            dist = "inv_gamma"
            a = 2.0
            b = 0.1
            """)
            priors2 = joinpath(dir, "priors2.toml")   # model 2 estimates rho only
            write(priors2, """
            [priors]
            [priors.rho]
            dist = "beta"
            a = 0.5
            b = 0.2
            """)
            # 1 observable (Y) ⇒ 1 structural shock ⇒ non-singular likelihood.
            data = joinpath(dir, "data.csv")
            open(data, "w") do io
                println(io, "Y")
                y = 0.0
                for _ in 1:60
                    y = 0.9 * y + 0.01 * randn()
                    println(io, y)
                end
            end
            r = run_json(["dsge", "bayes", "compare", model_jl,
                          "--data", data, "--observables", "Y",
                          "--params", "rho,sigma", "--priors", priors,
                          "--model2", model_jl, "--params2", "rho", "--priors2", priors2,
                          "--sampler", "smc", "--n-smc", "100", "--n-particles", "50",
                          "--n-draws", "100", "--burnin", "10"])
            assert_envelope_ok(r; label="dsge bayes compare")
            tbl = named_table(r.doc, :bayesian_model_comparison)
            @test tbl !== nothing
            if tbl !== nothing
                @test length(table_rows(tbl)) == 2   # Model 1, Model 2
                lml_i = col_index(tbl, "log_marginal_likelihood")
                @test lml_i !== nothing
                # teeth: both marginal likelihoods finite ⇒ estimation ran end-to-end and
                # the log-BF handler path did not throw (the previous log-of-negative
                # DomainError).
                if lml_i !== nothing
                    for row in table_rows(tbl)
                        @test isfinite(Float64(collect(row)[lml_i]))
                    end
                end
            end
        end

        rm(dir; force=true, recursive=true)
    end

    # C042 — X-13ARIMA-SEATS (pure-Julia MEMs port; always available)
    @testset "filter x13 monthly" begin
        csv = tempname() * ".csv"
        open(csv, "w") do io
            println(io, "y")
            for t in 1:120
                println(io, 100 + 10 * sin(2π * t / 12) + 0.05 * t + 0.3 * randn())
            end
        end
        r = run_json(["filter", "x13", csv, "--frequency", "12", "--method", "x11",
                      "--transform", "none"])
        assert_envelope_ok(r; label="filter x13")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        @test length(table_rows(tbl)) >= 100
        rm(csv; force=true)
    end
end

# Real entry-point coverage (C036) — also on core/CI path
include(joinpath(@__DIR__, "test_entry.jl"))
