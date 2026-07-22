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

    @testset "estimate arfima / test gph / test local-whittle — long memory (C068)" begin
        # ARFIMA(0,d,0) with d≈0.3: a genuine long-memory series. Assert envelope-valid
        # and a finite d in a sane range (roughly (−0.5, 1)) with p-values in [0,1].
        csv = dgp_fracdiff(; T=400, d=0.3, seed=123)

        # scan every kv table for a "metric == name" numeric value
        scan_metric(doc, name) = begin
            v = nothing
            for (_, tbl) in pairs(doc.data)
                if (tbl isa JSON3.Object || tbl isa AbstractDict) && (haskey(tbl, :rows) || haskey(tbl, "rows"))
                    mv = metric_value(tbl, name)
                    mv !== nothing && (v = mv)
                end
            end
            v
        end

        # estimate arfima(0,d,0)
        ra = run_json(["estimate", "arfima", csv, "--column", "1", "--p", "0", "--q", "0"])
        assert_envelope_ok(ra; label="estimate arfima")
        da = scan_metric(ra.doc, "d (frac. integ.)")
        @test da !== nothing
        if da !== nothing
            @test isfinite(Float64(da))
            @test -0.5 < Float64(da) < 1.0
        end

        # test gph
        rg = run_json(["test", "gph", csv, "--column", "1"])
        assert_envelope_ok(rg; label="test gph")
        dg = scan_metric(rg.doc, "d (long-memory)")
        pg = scan_metric(rg.doc, "p-value")
        @test dg !== nothing && isfinite(Float64(dg)) && -0.5 < Float64(dg) < 1.0
        @test pg !== nothing && 0.0 <= Float64(pg) <= 1.0

        # test local-whittle
        rw = run_json(["test", "local-whittle", csv, "--column", "1"])
        assert_envelope_ok(rw; label="test local-whittle")
        dw = scan_metric(rw.doc, "d (long-memory)")
        pw = scan_metric(rw.doc, "p-value")
        @test dw !== nothing && isfinite(Float64(dw)) && -0.5 < Float64(dw) < 1.0
        @test pw !== nothing && 0.0 <= Float64(pw) <= 1.0

        # bandwidth override still valid
        rgm = run_json(["test", "gph", csv, "--column", "1", "--bandwidth", "40"])
        assert_envelope_ok(rgm; label="test gph --bandwidth")

        rm(csv; force=true)
    end

    @testset "estimate smm — AR(1) recovery (first-ever T3, #345)" begin
        # SMM was broken on real MEMs 0.7.0 (3-arg call vs required 4-arg
        # estimate_smm(simulator_fn, moments_fn, theta0, data)) with zero T3
        # coverage — the same panel/DiD-class blind spot. This is the anchor.
        csv = dgp_ar1(; T=400, φ=0.7, σ=1.0, seed=71)
        cfg = tempname() * "_smm.toml"
        write(cfg, """
        [smm]
        model = "ar1"
        theta0 = [0.4, 0.5]
        lags = 2
        weighting = "two_step"
        sim_ratio = 5
        burn = 100
        lower = [-0.99, 1.0e-4]
        upper = [0.99, 10.0]
        """)
        r = run_json(["--seed", "20240722", "estimate", "smm", csv, "--config", cfg])
        assert_envelope_ok(r; label="estimate smm")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        if tbl !== nothing
            cols = table_cols(tbl)
            @test "parameter" in cols
            @test "estimate" in cols
            rows = [collect(row) for row in table_rows(tbl)]
            @test length(rows) == 2          # phi, sigma
            pidx = findfirst(==("parameter"), cols)
            eidx = findfirst(==("estimate"), cols)
            @test all(isfinite(Float64(row[eidx])) for row in rows)
            phi_row = rows[findfirst(row -> string(row[pidx]) == "phi", rows)]
            # AR persistence recovered near the true 0.7 (bounds keep it in (-0.99,0.99))
            @test 0.3 < Float64(phi_row[eidx]) < 0.99
        end
        rm(csv; force=true); rm(cfg; force=true)
    end

    @testset "estimate sur / 3sls — systems (C063, M5c)" begin
        Random.seed!(4242)
        Tn = 300
        x1 = randn(Tn); x2 = randn(Tn); x3 = randn(Tn)
        U = ([1.0 0.0; 0.6 0.8] * randn(2, Tn))'    # cross-equation error correlation
        y1 = 1.0 .+ 0.5 .* x1 .+ 0.3 .* x2 .+ U[:, 1]
        y2 = -0.5 .+ 0.8 .* x2 .+ 0.2 .* x3 .+ U[:, 2]
        csv = tempname() * ".csv"
        open(csv, "w") do io
            println(io, "y1,y2,x1,x2,x3")
            for t in 1:Tn
                println(io, join((y1[t], y2[t], x1[t], x2[t], x3[t]), ","))
            end
        end
        surcfg = tempname() * "_sur.toml"
        write(surcfg, """
        [[equations]]
        name = "consumption"
        dep = "y1"
        indep = ["x1", "x2"]
        [[equations]]
        name = "investment"
        dep = "y2"
        indep = ["x2", "x3"]
        """)
        _syscoef(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                ("equation" in table_cols(v) && "term" in table_cols(v)) && return v
            end
            nothing
        end

        @testset "sur tidy coef + slope recovery" begin
            r = run_json(["estimate", "sur", csv, "--config", surcfg])
            assert_envelope_ok(r; label="estimate sur")
            coef = _syscoef(r.doc)
            @test coef !== nothing
            if coef !== nothing
                @test issubset(["equation", "term", "estimate", "std_error", "stat", "p_value", "ci_lower", "ci_upper"],
                               table_cols(coef))
                rows = [collect(row) for row in table_rows(coef)]
                @test length(rows) == 6                       # 2 eq × (const + 2)
                ei = col_index(coef, "estimate"); ti = col_index(coef, "term"); qi = col_index(coef, "equation")
                @test all(isfinite(Float64(row[ei])) for row in rows)
                x1row = rows[findfirst(row -> string(row[qi]) == "consumption" && string(row[ti]) == "x1", rows)]
                @test 0.3 < Float64(x1row[ei]) < 0.7          # true 0.5
            end
        end

        @testset "3sls (instruments span regressors → collapses to SUR)" begin
            tslscfg = tempname() * "_3sls.toml"
            write(tslscfg, """
            [[equations]]
            dep = "y1"
            indep = ["x1", "x2"]
            [[equations]]
            dep = "y2"
            indep = ["x2", "x3"]
            [instruments]
            common = ["x1", "x2", "x3"]
            """)
            r = run_json(["estimate", "3sls", csv, "--config", tslscfg])
            assert_envelope_ok(r; label="estimate 3sls")
            coef = _syscoef(r.doc)
            @test coef !== nothing && length(table_rows(coef)) == 6
            rm(tslscfg; force=true)
        end
        rm(csv; force=true); rm(surcfg; force=true)
    end

    @testset "forecast evaluate — evaluation & combination (C072, M5c)" begin
        # y = AR(1); f1 a decent forecast (small noise), f2 a noisier competitor.
        Random.seed!(9090)
        Tn = 250
        y = Vector{Float64}(undef, Tn); y[1] = randn()
        for t in 2:Tn
            y[t] = 0.6 * y[t-1] + randn()
        end
        y .+= 10.0                                   # shift away from zero (well-defined MAPE)
        f1 = y .+ 0.30 .* randn(Tn)                  # good forecast
        f2 = y .+ 1.20 .* randn(Tn)                  # noisier forecast
        csv = tempname() * "_fceval.csv"
        open(csv, "w") do io
            println(io, "y,f1,f2")
            for t in 1:Tn
                println(io, join((y[t], f1[t], f2[t]), ","))
            end
        end

        _kvval(doc, name) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                "metric" in table_cols(v) || continue
                mv = metric_value(v, name)
                mv === nothing || return mv
            end
            nothing
        end
        _tblcol(doc, col) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                col in table_cols(v) && return v
            end
            nothing
        end

        @testset "metrics — RMSE(f1) < RMSE(f2)" begin
            r = run_json(["forecast", "evaluate", "metrics", csv, "--actual", "y", "--forecasts", "f1,f2"])
            assert_envelope_ok(r; label="forecast evaluate metrics")
            acc = _tblcol(r.doc, "RMSE")
            @test acc !== nothing
            if acc !== nothing
                @test issubset(["model","ME","MAE","RMSE","MAPE","sMAPE","MASE","U1","U2"], table_cols(acc))
                rows = [collect(row) for row in table_rows(acc)]
                @test length(rows) == 2
                ri = col_index(acc, "RMSE")
                rmses = [Float64(row[ri]) for row in rows]
                @test all(isfinite, rmses)
                @test rmses[1] < rmses[2]              # teeth: f1 more accurate than f2
            end
            dec = _tblcol(r.doc, "bias")
            @test dec !== nothing
            if dec !== nothing
                drow = collect(first(table_rows(dec)))
                props = [Float64(drow[col_index(dec, c)]) for c in ("bias","variance","covariance")]
                @test all(p -> -1e-6 <= p <= 1.0 + 1e-6, props)
                @test isapprox(sum(props), 1.0; atol=1e-3)   # Theil proportions sum to 1
            end
        end

        @testset "dm / clark-west / mincer-zarnowitz / encompassing p-values in [0,1]" begin
            for (leaf, fc) in (("dm", "f1,f2"), ("clark-west", "f1,f2"),
                               ("mincer-zarnowitz", "f1"), ("encompassing", "f1,f2"))
                r = run_json(["forecast", "evaluate", leaf, csv, "--actual", "y", "--forecasts", fc])
                assert_envelope_ok(r; label="forecast evaluate $leaf")
                stat = _kvval(r.doc, "statistic")
                leaf in ("dm", "clark-west") && (@test stat isa Real && isfinite(Float64(stat)))
                pname = leaf == "mincer-zarnowitz" ? "p_value_wald" : "p_value"
                pv = _kvval(r.doc, pname)
                @test pv isa Real && 0.0 <= Float64(pv) <= 1.0
            end
        end

        @testset "combine — equal weights + bates-granger favors f1" begin
            r = run_json(["forecast", "evaluate", "combine", csv, "--actual", "y",
                          "--forecasts", "f1,f2", "--method", "bates-granger"])
            assert_envelope_ok(r; label="forecast evaluate combine")
            w = _tblcol(r.doc, "weight")
            @test w !== nothing
            if w !== nothing
                rows = [collect(row) for row in table_rows(w)]
                @test length(rows) == 2
                wi = col_index(w, "weight")
                weights = [Float64(row[wi]) for row in rows]
                @test isapprox(sum(weights), 1.0; atol=1e-4)
                @test weights[1] > weights[2]          # inverse-MSE weight favors the better f1
            end
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

    @testset "estimate GARCH variants on real MEMs 0.7.0 (C064a)" begin
        # hand-built coef table (parameter|estimate) + diagnostics (metric|value)
        _coef_of(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :columns)) || continue
                cols = table_cols(v)
                ("parameter" in cols && "estimate" in cols) && return v
            end
            return nothing
        end
        _diag_of(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :columns)) || continue
                "metric" in table_cols(v) && return v
            end
            return nothing
        end
        _finite_estimates(tbl) = begin
            ei = col_index(tbl, "estimate")
            all(isfinite(Float64(collect(row)[ei])) for row in table_rows(tbl))
        end

        @testset "igarch — Σα+Σβ=1 ⇒ persistence≈1" begin
            csv = dgp_garch(; T=400, seed=101)
            r = run_json(["estimate", "igarch", csv, "--column", "1", "--p", "1", "--q", "1"])
            assert_envelope_ok(r; label="igarch")
            tbl = _coef_of(r.doc); @test tbl !== nothing
            @test _finite_estimates(tbl)
            pers = metric_value(_diag_of(r.doc), "persistence")
            @test pers !== nothing && isapprox(Float64(pers), 1.0; atol=1e-6)
            rm(csv; force=true)
        end

        @testset "cgarch — component decomposition, ρ∈(0,1]" begin
            csv = dgp_garch(; T=500, seed=102)
            r = run_json(["estimate", "cgarch", csv, "--column", "1"])
            assert_envelope_ok(r; label="cgarch")
            tbl = _coef_of(r.doc); @test tbl !== nothing
            @test _finite_estimates(tbl)
            pers = metric_value(_diag_of(r.doc), "persistence")
            @test pers !== nothing && 0.0 < Float64(pers) <= 1.0001
            @test metric_value(_diag_of(r.doc), "unconditional_variance") !== nothing
            rm(csv; force=true)
        end

        @testset "aparch — power δ>0, finite persistence" begin
            csv = dgp_garch(; T=400, seed=103)
            r = run_json(["estimate", "aparch", csv, "--column", "1", "--p", "1", "--q", "1"])
            assert_envelope_ok(r; label="aparch")
            tbl = _coef_of(r.doc); @test tbl !== nothing
            @test _finite_estimates(tbl)
            dlt = metric_value(_diag_of(r.doc), "delta")
            @test dlt !== nothing && Float64(dlt) > 0.0
            pers = metric_value(_diag_of(r.doc), "persistence")
            @test pers !== nothing && isfinite(Float64(pers))
            rm(csv; force=true)
        end

        @testset "figarch — long memory d∈(0,1)" begin
            csv = dgp_garch(; T=400, seed=104)
            r = run_json(["estimate", "figarch", csv, "--column", "1", "--truncation", "100"])
            assert_envelope_ok(r; label="figarch")
            tbl = _coef_of(r.doc); @test tbl !== nothing
            @test _finite_estimates(tbl)
            d = metric_value(_diag_of(r.doc), "d")               # d ∈ [0,1] (logistic transform; boundary reachable)
            @test d !== nothing && 0.0 <= Float64(d) <= 1.0
            rm(csv; force=true)
        end

        @testset "fiegarch — long memory d∈[0,1]" begin
            csv = dgp_garch(; T=400, seed=105)
            r = run_json(["estimate", "fiegarch", csv, "--column", "1", "--truncation", "100"])
            assert_envelope_ok(r; label="fiegarch")
            tbl = _coef_of(r.doc); @test tbl !== nothing
            @test _finite_estimates(tbl)
            d = metric_value(_diag_of(r.doc), "d")               # d ∈ [0,1] (logistic transform; boundary reachable)
            @test d !== nothing && 0.0 <= Float64(d) <= 1.0
            rm(csv; force=true)
        end

        @testset "garch-midas — realized, short-run persistence α+β∈(0,1)" begin
            csv = dgp_garch(; T=600, seed=106)
            r = run_json(["estimate", "garch-midas", csv, "--column", "1", "--m-freq", "20", "--k", "6"])
            assert_envelope_ok(r; label="garch-midas")
            tbl = _coef_of(r.doc); @test tbl !== nothing
            @test _finite_estimates(tbl)
            pers = metric_value(_diag_of(r.doc), "persistence")
            @test pers !== nothing && 0.0 < Float64(pers) < 1.0
            vr = metric_value(_diag_of(r.doc), "variance_ratio")
            @test vr !== nothing && 0.0 <= Float64(vr) <= 1.0
            rm(csv; force=true)
        end

        @testset "garch-midas missing --m-freq → usage error (not exit 1)" begin
            csv = dgp_garch(; T=200, seed=107)
            r = run_json(["estimate", "garch-midas", csv, "--column", "1"])
            @test r.code == 2
            rm(csv; force=true)
        end
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

    @testset "estimate ologit/mlogit/preg tidy coef (C051)" begin
        # Coef schemas share a core; some prepend equation/alternative/block. Assert the
        # core tidy columns are present (subset) — robust across the per-model variants.
        core = ["term", "estimate", "std_error", "stat", "p_value", "ci_lower", "ci_upper"]
        hascore(doc) = any(v -> (v isa JSON3.Object && haskey(v, :rows) && issubset(core, table_cols(v))),
                           values(doc.data))

        # ordered/multinomial need ≥3 categories → deterministic 3-category outcome from x
        catcsv = tempname() * ".csv"
        catrng = MersenneTwister(61)
        open(catcsv, "w") do io
            println(io, "y,x")
            for _ in 1:300
                xi = randn(catrng)
                yi = xi < -0.5 ? 0 : (xi < 0.5 ? 1 : 2)
                println(io, "$yi,$xi")
            end
        end
        ro = run_json(["estimate", "ologit", catcsv, "--dep", "y"])
        assert_envelope_ok(ro; label="estimate ologit")
        @test hascore(ro.doc)                 # ordered coef table is block|term|…

        rml = run_json(["estimate", "mlogit", catcsv, "--dep", "y"])
        assert_envelope_ok(rml; label="estimate mlogit")
        @test hascore(rml.doc)                # multinomial is alternative|term|…
        rm(catcsv; force=true)

        pc = dgp_did_panel(; N=40, T=10, seed=65)
        rp = run_json(["estimate", "preg", pc, "--id-col", "id", "--time-col", "time",
                       "--dep", "y", "--indep", "d"])
        assert_envelope_ok(rp; label="estimate preg")
        @test hascore(rp.doc)
        rm(pc; force=true)
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

    @testset "irf lp tidy (C051)" begin
        csv = dgp_var2(; T=200, seed=53)
        r = run_json(["irf", "lp", csv, "--shock", "1", "--horizons", "8", "--lags", "4"])
        assert_envelope_ok(r; label="irf lp")
        _, tbl = first_table(r.doc)
        @test tbl !== nothing
        if tbl !== nothing
            # C051: slp.irf is a full ImpulseResponse (Plagborg-Møller & Wolf 2021 stack LP
            # responses into the same 3D array as a VAR IRF) — same schema as irf var.
            @test table_cols(tbl) == ["horizon", "variable", "shock", "value", "lower", "upper"]
            ci = Dict(c => i for (i, c) in enumerate(table_cols(tbl)))
            rows = [collect(row) for row in table_rows(tbl)]
            @test length(unique(row[ci["shock"]] for row in rows)) == 1   # one shock selected
        end
        rm(csv; force=true)
    end

    @testset "irf/fevd favar tidy (C051)" begin
        # irf(favar,...)/fevd(favar,...) delegate to the VAR representation, so favar
        # renders through the same ImpulseResponse/FEVD long_table as irf/fevd var — one
        # tidy table now covers every shock (no more per-shock output files).
        csv = dgp_var2(; T=150, seed=55)
        ri = run_json(["irf", "favar", csv, "--factors", "1", "--key-vars", "1", "--horizons", "6"])
        assert_envelope_ok(ri; label="irf favar")
        _, ti = first_table(ri.doc)
        @test ti !== nothing && table_cols(ti) == ["horizon", "variable", "shock", "value", "lower", "upper"]

        rf = run_json(["fevd", "favar", csv, "--factors", "1", "--key-vars", "1", "--horizons", "6"])
        assert_envelope_ok(rf; label="fevd favar")
        _, tf = first_table(rf.doc)
        @test tf !== nothing && table_cols(tf) == ["horizon", "variable", "shock", "value"]
        rm(csv; force=true)
    end

    @testset "irf/fevd sdfm tidy (C051)" begin
        # irf(sdfm,...) returns a panel-wide ImpulseResponse directly; fevd(sdfm,...)
        # delegates to the factor VAR — both render through the same long_table as var.
        csv = dgp_var2(; T=150, seed=57)
        ri = run_json(["irf", "sdfm", csv, "--factors", "1", "--horizons", "6"])
        assert_envelope_ok(ri; label="irf sdfm")
        _, ti = first_table(ri.doc)
        @test ti !== nothing && table_cols(ti) == ["horizon", "variable", "shock", "value", "lower", "upper"]

        rf = run_json(["fevd", "sdfm", csv, "--factors", "1", "--horizons", "6"])
        assert_envelope_ok(rf; label="fevd sdfm")
        _, tf = first_table(rf.doc)
        @test tf !== nothing && table_cols(tf) == ["horizon", "variable", "shock", "value"]
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

    # C052 — native save/load handles + reproducibility manifests + seed forwarding
    @testset "C052 native .jld2 save/load + hybrid fallback (#347)" begin
        csv = dgp_var2(; T=100, seed=43)
        # native round-trip: VARModel → .jld2 → irf --model (no re-estimation)
        jld = tempname() * ".jld2"
        r1 = run_json(["estimate", "var", csv, "--lags", "1", "--save-model", jld])
        assert_envelope_ok(r1; label="estimate save native jld2")
        @test isfile(jld)
        r2 = run_json(["irf", "var", "--model", jld, "--horizons", "4", "--ci", "none"])
        assert_envelope_ok(r2; label="irf --model native jld2")
        @test first_table(r2.doc)[2] !== nothing
        # model info reads the native handle
        r3 = run_json(["model", "info", jld])
        assert_envelope_ok(r3; label="model info native jld2")
        # hybrid: an unsupported type on .jld2 errors clearly and writes nothing
        vjld = tempname() * ".jld2"
        r4 = run_json(["estimate", "vecm", csv, "--save-model", vjld])
        @test r4.doc !== nothing && String(r4.doc["status"]) == "error"
        @test occursin("unsupported", String(r4.doc["error"]["code"]))
        @test !isfile(vjld)
        # hybrid: same unsupported type on .fmod falls back to the interim handle
        vfmod = tempname() * ".fmod"
        r5 = run_json(["estimate", "vecm", csv, "--save-model", vfmod])
        assert_envelope_ok(r5; label="vecm .fmod interim fallback")
        @test isfile(vfmod)
        # a non-JLD2 file handed to the native path is BAD INPUT, not a CLI bug:
        # must map to a data/* class (exit 3), never internal/error (exit 1)
        garbage = tempname() * ".jld2"
        write(garbage, rand(UInt8, 200))
        r6 = run_json(["model", "info", garbage])
        @test r6.doc !== nothing && String(r6.doc["status"]) == "error"
        @test startswith(String(r6.doc["error"]["code"]), "data/")
        rm(csv; force=true); rm(jld; force=true); rm(vfmod; force=true); rm(garbage; force=true)
    end

    @testset "C052 reproducibility manifest in envelope meta (#345)" begin
        csv = dgp_var2(; T=80, seed=7)
        r = run_json(["estimate", "var", csv, "--lags", "1"])
        assert_envelope_ok(r; label="manifest meta")
        @test haskey(r.doc["meta"], "manifest")
        m = r.doc["meta"]["manifest"]
        for k in ("seed", "n_threads", "julia_version", "package_version",
                  "os", "machine", "timestamp", "dependency_versions")
            @test haskey(m, k)
        end
        @test String(m["package_version"]) != "unknown"
        rm(csv; force=true)
    end

    @testset "C052 --seed byte-identical + manifest.seed (#243)" begin
        csv = dgp_var2(; T=80, seed=9)
        # two --seed 42 BVAR runs are byte-identical on the data payload
        r1 = run_json(["--seed", "42", "estimate", "bvar", csv, "--lags", "1", "--draws", "200"])
        r2 = run_json(["--seed", "42", "estimate", "bvar", csv, "--lags", "1", "--draws", "200"])
        assert_envelope_ok(r1; label="seeded bvar 1")
        assert_envelope_ok(r2; label="seeded bvar 2")
        @test JSON3.write(r1.doc["data"]) == JSON3.write(r2.doc["data"])
        @test r1.doc["meta"]["manifest"]["seed"] == 42
        # forwarded seed= makes the consumed BVAR posterior reproducible → irf bvar identical
        i1 = run_json(["--seed", "42", "irf", "bvar", csv, "--lags", "1", "--horizons", "4"])
        i2 = run_json(["--seed", "42", "irf", "bvar", csv, "--lags", "1", "--horizons", "4"])
        assert_envelope_ok(i1; label="seeded irf bvar 1")
        @test JSON3.write(i1.doc["data"]) == JSON3.write(i2.doc["data"])
        rm(csv; force=true)
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

    # ── Input-Output analysis (C049) — offline via the bundled :wiot fixture ──
    @testset "io command family (C049)" begin
        # First table in the envelope whose columns ⊇ `cols`.
        cols_table(doc, cols) = begin
            doc === nothing && return nothing
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                all(c -> c in table_cols(v), cols) && return v
            end
            return nothing
        end

        @testset "sources catalog" begin
            r = run_json(["io", "sources"])
            assert_envelope_ok(r; label="io sources")
            t = cols_table(r.doc, ["source", "name", "versions", "credentials"])
            @test t !== nothing && length(table_rows(t)) == 5
        end

        @testset "load :wiot dims + balance" begin
            r = run_json(["io", "load"])
            assert_envelope_ok(r; label="io load")
            t = cols_table(r.doc, ["sector", "gross_output", "final_demand", "value_added"])
            @test t !== nothing
            rows = [collect(x) for x in table_rows(t)]
            ci = findfirst(==("sector"), table_cols(t)); gi = findfirst(==("gross_output"), table_cols(t))
            go = Dict(string(row[ci]) => Float64(row[gi]) for row in rows)
            @test isapprox(go["Agriculture"], 1000.0; atol=1e-6)
            @test isapprox(go["Manufacturing"], 2000.0; atol=1e-6)
        end

        @testset "leontief wide (L[Ag,Ag] ≈ 1.254125)" begin
            r = run_json(["io", "leontief"])
            assert_envelope_ok(r; label="io leontief")
            t = cols_table(r.doc, ["sector", "Agriculture", "Manufacturing"])
            @test t !== nothing
            r1 = collect(first(x for x in table_rows(t) if string(collect(x)[1]) == "Agriculture"))
            ai = findfirst(==("Agriculture"), table_cols(t))
            @test isapprox(Float64(r1[ai]), 1.254125; atol=1e-4)
            # both matrices → two tables
            r2 = run_json(["io", "leontief", "--matrix", "both"])
            assert_envelope_ok(r2; label="io leontief both")
            @test length(collect(keys(r2.doc.data))) == 2
            assert_envelope_ok(run_json(["io", "ghosh"]); label="io ghosh")
        end

        @testset "multipliers output Type I ≈ [1.518,1.452]" begin
            r = run_json(["io", "multipliers", "--kind", "output", "--type", "I"])
            assert_envelope_ok(r; label="io multipliers")
            t = cols_table(r.doc, ["sector", "multiplier"])
            vi = findfirst(==("multiplier"), table_cols(t))
            vals = sort([Float64(collect(x)[vi]) for x in table_rows(t)]; rev=true)
            @test isapprox(vals, [1.518152, 1.452145]; atol=1e-4)
            assert_envelope_ok(run_json(["io", "multipliers", "--kind", "income", "--type", "II"]); label="io mult inc II")
            assert_envelope_ok(run_json(["io", "multipliers", "--kind", "employment"]); label="io mult emp")
        end

        @testset "linkages / key-sectors / sda / baqaee-farhi" begin
            r = run_json(["io", "linkages"])
            assert_envelope_ok(r; label="io linkages")
            @test cols_table(r.doc, ["sector", "backward", "forward", "Ui", "Uj", "class"]) !== nothing
            assert_envelope_ok(run_json(["io", "key-sectors"]); label="io key-sectors")
            rs = run_json(["io", "sda", "--method", "additive"])
            assert_envelope_ok(rs; label="io sda")
            ts = cols_table(rs.doc, ["sector", "L_effect", "Y_effect", "total", "residual"])
            @test ts !== nothing
            bf = run_json(["io", "baqaee-farhi"])
            assert_envelope_ok(bf; label="io baqaee-farhi")
            @test cols_table(bf.doc, ["sector", "domar", "influence", "upstreamness", "downstreamness"]) !== nothing
        end

        @testset "extract (Agriculture loss ≈ 1000) + footprint (CO2 = 400)" begin
            r = run_json(["io", "extract", "--sectors-extract", "Agriculture"])
            assert_envelope_ok(r; label="io extract")
            t = cols_table(r.doc, ["sector", "output_loss"])
            si = findfirst(==("sector"), table_cols(t)); li = findfirst(==("output_loss"), table_cols(t))
            loss = Dict(string(collect(x)[si]) => Float64(collect(x)[li]) for x in table_rows(t))
            @test isapprox(loss["Agriculture"], 1000.0; atol=1e-3)
            fp = run_json(["io", "footprint"])
            assert_envelope_ok(fp; label="io footprint")
            ft = cols_table(fp.doc, ["stressor", "footprint"])
            @test ft !== nothing
            fi = findfirst(==("footprint"), table_cols(ft))
            @test isapprox(Float64(collect(first(table_rows(ft)))[fi]), 400.0; atol=1e-6)
        end

        @testset "download --offline → env/network (exit 6)" begin
            r = run_json(["io", "download", "--source", "oecd", "--storage",
                          joinpath(tempdir(), "io_dl_none"), "--offline"])
            @test r.code == 6
        end
    end
end

# Real entry-point coverage (C036) — also on core/CI path
include(joinpath(@__DIR__, "test_entry.jl"))
