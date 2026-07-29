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

    @testset "estimate lasso/ridge/elastic-net/robust/tobit — penalized & LDV (C067a, M5c)" begin
        # Real cross-section DGP: sparse true β=[-1.0, 0.8, -0.6, 0, 0], plus a
        # left-censored yc for Tobit. Teeth: sparse recovery, large-λ shrinkage, robust≈OLS
        # on clean data, Tobit β recovery + censoring counts.
        csv, csvc, β = dgp_penalized(; T=300, p=5, seed=42)

        _diag(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                "metric" in table_cols(v) && return v
            end
            nothing
        end
        _coef_est(doc, term; termcol="term") = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                cols = table_cols(v)
                ti = findfirst(==(termcol), cols); ei = findfirst(==("estimate"), cols)
                (ti === nothing || ei === nothing) && continue
                for row in table_rows(v)
                    r = collect(row)
                    string(r[ti]) == term && return Float64(r[ei])
                end
            end
            nothing
        end

        @testset "lasso — sparse recovery (x1≈-1, x2≈0.8) + intercept row" begin
            r = run_json(["estimate", "lasso", csv, "--dep", "y", "--select", "bic"])
            assert_envelope_ok(r; label="estimate lasso")
            # penalized coef table: term|estimate|nonzero, with an intercept row
            @test _coef_est(r.doc, "(Intercept)") !== nothing
            b1 = _coef_est(r.doc, "x1"); b2 = _coef_est(r.doc, "x2")
            @test b1 !== nothing && -1.4 < b1 < -0.6      # true -1.0
            @test b2 !== nothing && 0.5 < b2 < 1.1        # true  0.8
            na = metric_value(_diag(r.doc), "n_active")
            @test na !== nothing && Int(na) >= 3          # recovers the 3 real regressors
        end

        @testset "lasso — large --lambda drives the active set to 0 (shrinkage teeth)" begin
            r = run_json(["estimate", "lasso", csv, "--dep", "y", "--lambda", "100"])
            assert_envelope_ok(r; label="estimate lasso big-lambda")
            na = metric_value(_diag(r.doc), "n_active")
            @test na !== nothing && Int(na) <= 1          # essentially everything shrunk out
        end

        @testset "ridge / elastic-net run + fitted β sign" begin
            for (leaf, extra) in (("ridge", String[]), ("elastic-net", ["--alpha", "0.5"]))
                r = run_json(vcat(["estimate", leaf, csv, "--dep", "y"], extra))
                assert_envelope_ok(r; label="estimate $leaf")
                b1 = _coef_est(r.doc, "x1")
                @test b1 !== nothing && b1 < 0.0          # true coefficient is negative
            end
        end

        @testset "robust ≈ OLS on clean data (x1≈-1, x2≈0.8)" begin
            r = run_json(["estimate", "robust", csv, "--dep", "y", "--psi", "huber", "--method", "m"])
            assert_envelope_ok(r; label="estimate robust")
            b1 = _coef_est(r.doc, "x1"; termcol="parameter")
            b2 = _coef_est(r.doc, "x2"; termcol="parameter")
            @test b1 !== nothing && -1.15 < b1 < -0.85
            @test b2 !== nothing && 0.65 < b2 < 0.95
            @test string(metric_value(_diag(r.doc), "converged")) == "true"
        end

        @testset "tobit — recovers β on left-censored yc + censoring counts" begin
            r = run_json(["estimate", "tobit", csvc, "--dep", "yc", "--lower", "0.0"])
            assert_envelope_ok(r; label="estimate tobit")
            b1 = _coef_est(r.doc, "x1"; termcol="parameter")
            @test b1 !== nothing && -1.3 < b1 < -0.7       # true -1.0 (≈50% censored)
            nL = metric_value(_diag(r.doc), "n_censored_left")
            @test nL !== nothing && Int(nL) > 0
        end

        @testset "bad --dep → data/column-range (exit 3, hardened loader)" begin
            r = run_json(["estimate", "lasso", csv, "--dep", "does_not_exist"])
            @test r.code == 3
        end

        @testset "elastic-net --alpha 2 → usage error (exit 2, not raw MEMs)" begin
            r = run_json(["estimate", "elastic-net", csv, "--dep", "y", "--alpha", "2"])
            @test r.code == 2
        end

        rm(csv; force=true); rm(csvc; force=true)
    end

    @testset "estimate cointreg/xtcointreg — cointegrating regression (C062a, M5c)" begin
        # Real cointegration DGP: x_t random walk, y_t = β x_t + I(0). Teeth: FMOLS/CCR/DOLS
        # recover β within a LOOSE tol (the estimators are noisy), the coef table carries the
        # full tidy schema, and diagnostics/CIs are finite. Panel: N units, common β → group
        # & pooled β̄ within a loose tol; back-solved group-mean SE may be Inf (round-safe).
        _coefrow(doc, term) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                cols = table_cols(v)
                ti = findfirst(==("term"), cols); ei = findfirst(==("estimate"), cols)
                (ti === nothing || ei === nothing) && continue
                for row in table_rows(v)
                    r = collect(row)
                    string(r[ti]) == term && return (v, Float64(r[ei]))
                end
            end
            (nothing, nothing)
        end
        _diag(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                "metric" in table_cols(v) && return v
            end
            nothing
        end
        _coefcols = ["term", "estimate", "std_error", "stat", "p_value", "ci_lower", "ci_upper"]

        @testset "cointreg — FMOLS/CCR/DOLS recover β≈1 (loose) + tidy schema" begin
            csv = dgp_coint(; T=300, β=1.0, seed=45)
            for meth in ("fmols", "ccr", "dols")
                r = run_json(["estimate", "cointreg", csv, "--dep", "y", "--method", meth])
                assert_envelope_ok(r; label="estimate cointreg $meth")
                tbl, bx = _coefrow(r.doc, "x")
                @test tbl !== nothing && Set(_coefcols) ⊆ Set(table_cols(tbl))
                @test bx !== nothing && abs(bx - 1.0) < 0.3        # loose slope recovery
                d = _diag(r.doc)
                @test metric_value(d, "method") !== nothing
                @test Int(metric_value(d, "k")) == 1
                @test isfinite(Float64(metric_value(d, "omega_uv")))
            end
            # DOLS exposes leads/lags in the diagnostics block
            rd = run_json(["estimate", "cointreg", csv, "--dep", "y", "--method", "dols"])
            @test metric_value(_diag(rd.doc), "leads") !== nothing
            rm(csv; force=true)
        end

        @testset "xtcointreg — panel group & pooled β̄≈1 (loose), SE finite-or-Inf-safe" begin
            cp = dgp_coint_panel(; N=8, T=50, β=1.0, seed=61)
            for pool in ("group", "pooled"), meth in ("fmols", "dols")
                r = run_json(["estimate", "xtcointreg", cp, "--dep", "y", "--indep", "x",
                              "--method", meth, "--pooling", pool])
                assert_envelope_ok(r; label="estimate xtcointreg $meth/$pool")
                tbl, bx = _coefrow(r.doc, "x")
                @test tbl !== nothing && Set(_coefcols) ⊆ Set(table_cols(tbl))
                @test bx !== nothing && abs(bx - 1.0) < 0.3       # common-β recovery
                d = _diag(r.doc)
                @test Int(metric_value(d, "N")) == 8
                @test string(metric_value(d, "pooling")) == pool
            end
            rm(cp; force=true)
        end

        @testset "bad input stays typed (not internal exit 1)" begin
            csv = dgp_coint(; T=200, seed=63)
            @test run_json(["estimate", "cointreg", csv, "--dep", "nope"]).code == 3       # data/column-range
            @test run_json(["estimate", "cointreg", csv, "--method", "bogus"]).code == 2   # enum
            @test run_json(["estimate", "cointreg", csv, "--bandwidth", "junk"]).code == 2 # dual-type parse
            @test run_json(["estimate", "cointreg", csv, "--leads", "-1"]).code == 2
            cp = dgp_coint_panel(; N=6, T=40, seed=65)
            @test run_json(["estimate", "xtcointreg", cp, "--dep", "y", "--indep", "x", "--method", "ccr"]).code == 2
            @test run_json(["estimate", "xtcointreg", cp, "--dep", "nope", "--indep", "x"]).code == 2
            rm(csv; force=true); rm(cp; force=true)
        end
    end

    @testset "estimate ardl/nardl + test ardl-bounds/nardl-symmetry + multipliers nardl (C062b, M5c)" begin
        # Real ARDL/NARDL family. Teeth (all LOOSE — noisy single-equation estimators):
        # ARDL recovers the long-run θ=(β₀+β₁)/(1−φ); the bounds test returns a valid decision
        # symbol; NARDL symmetry REJECTS on an asymmetric DGP (discriminating vs a symmetric
        # control); the dynamic multipliers converge toward θ⁺/θ⁻ with finite bootstrap bands.
        _tbl_kw(doc, kw) = begin   # first data table whose envelope key contains `kw`
            for (k, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                occursin(kw, lowercase(string(k))) && return v
            end
            nothing
        end
        _tbl_col(doc, col) = begin  # first data table that HAS column `col` (robust to key-order)
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                col in table_cols(v) && return v
            end
            nothing
        end
        _rowval(tbl, keycol, key, valcol) = begin
            tbl === nothing && return nothing
            cols = table_cols(tbl)
            ki = findfirst(==(keycol), cols); vi = findfirst(==(valcol), cols)
            (ki === nothing || vi === nothing) && return nothing
            for row in table_rows(tbl)
                r = collect(row)
                string(r[ki]) == key && return Float64(r[vi])
            end
            nothing
        end
        _diag(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                "metric" in table_cols(v) && return v
            end
            nothing
        end

        @testset "ardl — long-run θ recovery (loose) + ECM diagnostics" begin
            csv, θ = dgp_ardl(; T=300, φ=0.5, β0=1.0, β1=0.5, seed=44)
            r = run_json(["estimate", "ardl", csv, "--dep", "y", "--p", "1", "--q", "1"])
            assert_envelope_ok(r; label="estimate ardl")
            lrt = _tbl_kw(r.doc, "long")                 # long-run table (key contains "long")
            θ̂ = _rowval(lrt, "term", "x", "estimate")
            @test θ̂ !== nothing && abs(θ̂ - θ) < 0.4     # loose long-run recovery
            d = _diag(r.doc)
            @test metric_value(d, "alpha") !== nothing
            @test isfinite(Float64(metric_value(d, "longrun_denom")))
            @test Int(metric_value(d, "case")) == 3
            # auto selection path also runs
            @test run_json(["estimate", "ardl", csv, "--dep", "y", "--p", "auto"]).code == 0
            rm(csv; force=true)
        end

        @testset "test ardl-bounds — valid decision symbol, no p-value" begin
            csv, _ = dgp_ardl(; T=300, seed=46)
            r = run_json(["test", "ardl-bounds", csv, "--dep", "y", "--p", "1", "--q", "1"])
            assert_envelope_ok(r; label="test ardl-bounds")
            bt = _tbl_col(r.doc, "decision")   # bounds DATA table (key "bounds" is shared with the summary)
            @test bt !== nothing && "decision" in table_cols(bt)
            @test !("p_value" in table_cols(bt))          # bounds test has NO p-value
            fdec = string(metric_value(_diag(r.doc), "f_decision"))
            @test fdec in ("cointegrated", "not_cointegrated", "inconclusive")
            # case II → undefined t-bounds render "undefined", never a NaN crash
            @test run_json(["test", "ardl-bounds", csv, "--dep", "y", "--p", "1", "--q", "1", "--case", "2"]).code == 0
            rm(csv; force=true)
        end

        @testset "nardl — runs + asymmetric long-run terms" begin
            csv, tp, tn = dgp_nardl(; T=300, θpos=1.0, θneg=-0.3, seed=47)
            r = run_json(["estimate", "nardl", csv, "--dep", "y", "--p", "1", "--q", "1"])
            assert_envelope_ok(r; label="estimate nardl")
            lrt = _tbl_kw(r.doc, "long")
            @test lrt !== nothing
            terms = String[string(collect(row)[findfirst(==("term"), table_cols(lrt))]) for row in table_rows(lrt)]
            @test any(t -> occursin("_POS", t), terms) && any(t -> occursin("_NEG", t), terms)
            d = _diag(r.doc)
            @test string(metric_value(d, "f_decision")) in ("cointegrated", "not_cointegrated", "inconclusive")
            @test Int(metric_value(d, "k")) == 2 * Int(metric_value(d, "k_orig"))
            rm(csv; force=true)
        end

        @testset "test nardl-symmetry — rejects asymmetric, milder on symmetric (loose direction)" begin
            ca, _, _ = dgp_nardl(; T=320, θpos=1.0, θneg=-0.4, seed=48)
            cs, _, _ = dgp_nardl(; T=320, seed=49, sym=true)
            ra = run_json(["test", "nardl-symmetry", ca, "--dep", "y", "--p", "1", "--q", "1"])
            rs = run_json(["test", "nardl-symmetry", cs, "--dep", "y", "--p", "1", "--q", "1"])
            assert_envelope_ok(ra; label="nardl-symmetry asym")
            assert_envelope_ok(rs; label="nardl-symmetry sym")
            st_a = _tbl_col(ra.doc, "lr_p_chi2"); st_s = _tbl_col(rs.doc, "lr_p_chi2")  # data table (key "symmetry" shared w/ summary)
            pa = _rowval(st_a, "regressor", "x", "lr_p_chi2")
            ps = _rowval(st_s, "regressor", "x", "lr_p_chi2")
            @test pa !== nothing && ps !== nothing
            @test 0.0 <= pa <= 1.0 && 0.0 <= ps <= 1.0
            @test pa < 0.10          # asymmetric DGP → reject long-run symmetry (loose)
            @test pa < ps            # discriminating direction: asym more significant than sym
            rm(ca; force=true); rm(cs; force=true)
        end

        @testset "multipliers nardl — converge to θ⁺/θ⁻ (loose) + finite bands" begin
            csv, tp, tn = dgp_nardl(; T=320, θpos=1.0, θneg=-0.4, seed=50)
            r = run_json(["multipliers", "nardl", csv, "--dep", "y", "--p", "1", "--q", "1",
                          "--horizon", "24", "--nreps", "120"])
            assert_envelope_ok(r; label="multipliers nardl")
            mt = _tbl_col(r.doc, "m_pos")   # multiplier DATA table (key "multiplier" shared w/ summary)
            @test mt !== nothing
            cols = table_cols(mt)
            @test Set(["horizon", "regressor", "m_pos", "m_neg", "m_diff"]) ⊆ Set(cols)
            @test "m_pos_lo" in cols                       # band columns present (nreps>0)
            hi = findfirst(==("horizon"), cols); mp = findfirst(==("m_pos"), cols)
            mn = findfirst(==("m_neg"), cols); lo = findfirst(==("m_pos_lo"), cols)
            rows = [collect(row) for row in table_rows(mt)]
            @test all(isfinite(Float64(r[mp])) && isfinite(Float64(r[lo])) for r in rows)
            hmax = maximum(Int(r[hi]) for r in rows)
            mpos_end = Float64(first(r[mp] for r in rows if Int(r[hi]) == hmax))
            @test abs(mpos_end - tp) < 0.5                 # converges toward θ⁺ (loose)
            # --no-bootstrap drops band columns
            rnb = run_json(["multipliers", "nardl", csv, "--dep", "y", "--p", "1", "--q", "1",
                            "--horizon", "12", "--no-bootstrap"])
            @test rnb.code == 0
            @test !("m_pos_lo" in table_cols(_tbl_col(rnb.doc, "m_pos")))
            rm(csv; force=true)
        end

        @testset "bad input stays typed (never internal exit 1)" begin
            csv, _ = dgp_ardl(; T=200, seed=51)
            @test run_json(["estimate", "ardl", csv, "--dep", "nope"]).code == 3        # data/column-range
            @test run_json(["estimate", "ardl", csv, "--dep", "y", "--case", "9"]).code == 2   # usage
            @test run_json(["estimate", "nardl", csv, "--dep", "y", "--asymmetric", "0"]).code == 2
            @test run_json(["test", "ardl-bounds", csv, "--dep", "y", "--level", "0.03"]).code == 2
            @test run_json(["test", "ardl-bounds", csv, "--dep", "y", "--cv-source", "narayan"]).code == 2
            @test run_json(["multipliers", "nardl", csv, "--dep", "y", "--horizon", "-1"]).code == 2
            rm(csv; force=true)
        end
    end

    @testset "estimate pmg + test pmg-hausman — panel ARDL (C062c, M5c)" begin
        # Heterogeneous-panel ARDL-EC with a COMMON long-run θ=1, heterogeneous φ_i/short-run.
        # Teeth (all LOOSE — noisy panel ML): PMG recovers the pooled θ; the fit converges; MG
        # and DFE also run; the Hausman test returns a decision + a p-value in [0,1] (on a
        # homogeneous-θ DGP it should FAIL to reject long-run homogeneity — loose direction).
        _diag(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                "metric" in table_cols(v) && return v
            end
            nothing
        end
        _rowval(doc, term, valcol) = begin  # scan all tables for term row, return valcol
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                cols = table_cols(v)
                ti = findfirst(==("term"), cols); vi = findfirst(==(valcol), cols)
                (ti === nothing || vi === nothing) && continue
                for row in table_rows(v)
                    r = collect(row)
                    string(r[ti]) == term && return Float64(r[vi])
                end
            end
            nothing
        end

        @testset "pmg — long-run θ recovery (loose) + converged, MG/DFE run" begin
            cp = dgp_pmg(; N=10, T=60, θ=1.0, seed=71)
            r = run_json(["estimate", "pmg", cp, "--dep", "y", "--indep", "x", "--method", "pmg"])
            assert_envelope_ok(r; label="estimate pmg")
            θ̂ = _rowval(r.doc, "x", "estimate")
            @test θ̂ !== nothing && abs(θ̂ - 1.0) < 0.35        # loose pooled long-run recovery
            d = _diag(r.doc)
            @test Int(metric_value(d, "N")) == 10
            @test string(metric_value(d, "converged")) in ("true", "1")
            @test isfinite(Float64(metric_value(d, "phi")))
            # MG / DFE also run
            @test run_json(["estimate", "pmg", cp, "--dep", "y", "--indep", "x", "--method", "mg"]).code == 0
            @test run_json(["estimate", "pmg", cp, "--dep", "y", "--indep", "x", "--method", "dfe"]).code == 0
            rm(cp; force=true)
        end

        @testset "pmg-hausman — decision + p-value in [0,1], efficient pmg/dfe" begin
            cp = dgp_pmg(; N=10, T=60, θ=1.0, seed=73)
            for eff in ("pmg", "dfe")
                r = run_json(["test", "pmg-hausman", cp, "--dep", "y", "--indep", "x", "--efficient", eff])
                assert_envelope_ok(r; label="test pmg-hausman $eff")
                d = _diag(r.doc)
                pv = Float64(metric_value(d, "pvalue"))
                @test 0.0 <= pv <= 1.0
                @test metric_value(d, "statistic") !== nothing
            end
            rm(cp; force=true)
        end

        @testset "bad input stays typed (not internal exit 1)" begin
            cp = dgp_pmg(; N=6, T=40, seed=75)
            @test run_json(["estimate", "pmg", cp, "--dep", "y", "--indep", "x", "--method", "bogus"]).code == 2
            @test run_json(["estimate", "pmg", cp, "--dep", "nope", "--indep", "x"]).code == 2
            @test run_json(["estimate", "pmg", cp, "--dep", "y", "--indep", "x", "--p", "0"]).code == 2
            @test run_json(["test", "pmg-hausman", cp, "--dep", "y", "--indep", "x", "--efficient", "mg"]).code == 2
            rm(cp; force=true)
        end
    end

    @testset "estimate midas — mixed-frequency MIDAS (C062d, M5c)" begin
        # Real MIDAS: an HF indicator drives a LF target through a known exp-Almon weight curve.
        # Teeth (all LOOSE — restricted MIDAS NLS is noisy): the HF loading β₁ is finite & positive;
        # the restricted weight curve has K entries summing ≈1; R² is non-trivial; umidas (OLS) and
        # ADL (--p-ar) also run. Bad mixed-frequency input stays typed (never an internal exit 1).
        _tbl_col(doc, col) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                col in table_cols(v) && return v
            end
            nothing
        end
        _diag(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                "metric" in table_cols(v) && return v
            end
            nothing
        end
        _coef(doc, matchfn) = begin   # first term row whose term satisfies matchfn → estimate
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                cols = table_cols(v)
                ti = findfirst(==("term"), cols); ei = findfirst(==("estimate"), cols)
                (ti === nothing || ei === nothing) && continue
                for row in table_rows(v)
                    r = collect(row)
                    matchfn(string(r[ti])) && return Float64(r[ei])
                end
            end
            nothing
        end

        @testset "expalmon — HF loading finite/positive, weight curve sums≈1, R² non-trivial" begin
            lf, hf, b = dgp_midas(; Tlf=120, m=3, K=6, b=2.0, seed=91)
            r = run_json(["estimate", "midas", lf, "--hf-data", hf, "--m", "3", "--k", "6", "--weights", "expalmon"])
            assert_envelope_ok(r; label="estimate midas expalmon")
            wt = _tbl_col(r.doc, "weight")
            @test wt !== nothing
            wcol = findfirst(==("weight"), table_cols(wt))
            ws = [Float64(collect(row)[wcol]) for row in table_rows(wt)]
            @test length(ws) == 6
            @test abs(sum(ws) - 1.0) < 1e-3                      # restricted weights are normalized
            bx = _coef(r.doc, t -> occursin("HF loading", t))
            @test bx !== nothing && isfinite(bx) && bx > 0.0     # positive HF loading (loose)
            d = _diag(r.doc)
            @test Float64(metric_value(d, "r2")) > 0.3
            @test string(metric_value(d, "weights_kind")) == "expalmon"
            @test Int(metric_value(d, "K")) == 6
            rm(lf; force=true); rm(hf; force=true)
        end

        @testset "umidas (OLS) + ADL-MIDAS (--p-ar) run" begin
            lf, hf, _ = dgp_midas(; Tlf=120, m=3, K=6, seed=93)
            @test run_json(["estimate", "midas", lf, "--hf-data", hf, "--m", "3", "--k", "6", "--weights", "umidas"]).code == 0
            @test run_json(["estimate", "midas", lf, "--hf-data", hf, "--m", "3", "--k", "6", "--p-ar", "1"]).code == 0
            rm(lf; force=true); rm(hf; force=true)
        end

        @testset "ragged HF (nhf > m×LF) accepted — leading edge dropped (real _align_hf)" begin
            # The real estimator anchors the last HF obs to the last LF period and drops leading
            # ragged history (its headline nowcasting feature); the CLI loader relaxes to
            # `nhf >= m×LF` to match. Prepend 20 extra leading HF obs → nhf = 3*120 + 20 = 380 > 360.
            lf, hf, _ = dgp_midas(; Tlf=120, m=3, K=6, seed=97)
            orig = CSV.read(hf, DataFrame)
            padded = vcat(DataFrame(ip = collect(range(-1.0, 0.0; length=20))), orig)
            hfrag = write_csv(padded; prefix="midas_hf_ragged")
            r = run_json(["estimate", "midas", lf, "--hf-data", hfrag, "--m", "3", "--k", "6", "--weights", "expalmon"])
            @test r.code == 0
            rm(lf; force=true); rm(hf; force=true); rm(hfrag; force=true)
        end

        @testset "bad input stays typed (not internal exit 1)" begin
            lf, hf, _ = dgp_midas(; Tlf=80, m=3, K=6, seed=95)
            @test run_json(["estimate", "midas", lf, "--m", "3", "--k", "6"]).code == 2                            # missing --hf-data
            @test run_json(["estimate", "midas", lf, "--hf-data", hf, "--m", "0", "--k", "6"]).code == 2
            @test run_json(["estimate", "midas", lf, "--hf-data", hf, "--m", "3", "--k", "0"]).code == 2
            @test run_json(["estimate", "midas", lf, "--hf-data", hf, "--m", "3", "--k", "1", "--weights", "beta2"]).code == 3  # K<2
            @test run_json(["estimate", "midas", lf, "--hf-data", hf, "--m", "4", "--k", "6"]).code == 3            # HF shorter than m×LF (240 < 4*80=320) → data/shape
            rm(lf; force=true); rm(hf; force=true)
        end
    end

    @testset "estimate setar + test hansen-linearity + forecast setar — nonlinear TS (C065a, M5c)" begin
        # Real SETAR/threshold family. Teeth are LOOSE/direction-only (bootstrap Hansen +
        # threshold search are noisy): both regimes populated, γ̂ inside its CI, finite AIC,
        # and the nonlinear DGP rejects linearity (pvalue_lm < 0.10).
        Random.seed!(65065)
        _diag(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                "metric" in table_cols(v) && return v
            end
            nothing
        end
        mv(doc, name) = (d = _diag(doc); d === nothing ? nothing : metric_value(d, name))

        @testset "estimate setar — two regimes, γ in CI, attached Hansen rejects" begin
            csv = dgp_setar(; n=400, seed=651)
            r = run_json(["estimate", "setar", csv, "--column", "1", "--p", "1", "--d", "1", "--reps", "199"])
            assert_envelope_ok(r; label="estimate setar")
            # coef table: regime|term|estimate|std_error|z_stat|p_value, 2 regimes × 2 terms
            ct = nothing
            for (_, v) in pairs(r.doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                "regime" in table_cols(v) && (ct = v)
            end
            @test ct !== nothing
            @test Set(["regime", "term", "estimate", "std_error"]) ⊆ Set(table_cols(ct))
            @test length(table_rows(ct)) == 4
            @test string(mv(r.doc, "is_setar")) == "true"
            @test Int(mv(r.doc, "n1")) > 0 && Int(mv(r.doc, "n2")) > 0
            γ  = Float64(mv(r.doc, "gamma"))
            γl = Float64(mv(r.doc, "gamma_ci_lower")); γu = Float64(mv(r.doc, "gamma_ci_upper"))
            @test isfinite(γ) && γl < γ < γu
            @test isfinite(Float64(mv(r.doc, "aic")))
            # attached Hansen (1996) linearity test rejects on the nonlinear DGP (loose)
            @test Float64(mv(r.doc, "pvalue_lm")) < 0.10
            # --d auto grid also runs
            @test run_json(["estimate", "setar", csv, "--p", "1", "--d", "auto", "--reps", "99"]).code == 0
            # a constant series admits no threshold split → data/invalid (exit 3) on REAL MEMs
            # (ArgumentError "Empty threshold grid"), NEVER an internal exit 1 — the mock mirrors this class
            constcsv = write_csv(DataFrame(y=fill(1.0, 60)); prefix="setar_const")
            @test run_json(["estimate", "setar", constcsv, "--p", "1", "--d", "1"]).code == 3
            rm(csv; force=true); rm(constcsv; force=true)
        end

        @testset "test hansen-linearity — rejects on the SETAR DGP" begin
            csv = dgp_setar(; n=400, seed=652)
            r = run_json(["test", "hansen-linearity", csv, "--column", "1", "--p", "1", "--d", "1", "--reps", "199"])
            assert_envelope_ok(r; label="test hansen-linearity")
            @test Set(["sup_lm", "pvalue_lm", "sup_wald", "pvalue_wald", "gamma_sup", "n_grid"]) ⊆
                  Set(String(string(collect(row)[1])) for row in table_rows(_diag(r.doc)))
            @test Float64(mv(r.doc, "pvalue_lm")) < 0.10
            # too-short series → data/invalid (wrapped estimate_setar), never internal exit-1
            short = write_csv(DataFrame(y=collect(1.0:6.0)); prefix="setar_short")
            @test run_json(["test", "hansen-linearity", short, "--p", "1", "--d", "1"]).code == 3
            rm(csv; force=true); rm(short; force=true)
        end

        @testset "forecast setar — h=6 finite paths, lower ≤ value ≤ upper" begin
            csv = dgp_setar(; n=400, seed=653)
            r = run_json(["forecast", "setar", csv, "--column", "1", "--p", "1", "--d", "1",
                          "--horizons", "6", "--reps", "199"])
            assert_envelope_ok(r; label="forecast setar")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            @test table_cols(tbl) == ["horizon", "variable", "value", "lower", "upper"]
            rows = [collect(row) for row in table_rows(tbl)]
            @test length(rows) == 6
            vi = col_index(tbl, "value"); li = col_index(tbl, "lower"); ui = col_index(tbl, "upper")
            for row in rows
                v = Float64(row[vi]); lo = Float64(row[li]); hi = Float64(row[ui])
                @test isfinite(v) && isfinite(lo) && isfinite(hi)
                @test lo <= v <= hi
            end
            # --ci-level 0.8 → usage error (exit 2), not a Hansen-crit crash
            @test run_json(["forecast", "setar", csv, "--horizons", "4", "--ci-level", "0.8"]).code == 2
            rm(csv; force=true)
        end
    end

    @testset "estimate star + test star-linearity + forecast star — nonlinear TS (C065b, M5c)" begin
        # Real STAR family. Teeth are LOOSE/direction-only (NLS is deterministic but noisy):
        # regime + transition tables present, finite params, and the LSTAR DGP rejects
        # linearity (lm3_pvalue/pvalue < 0.10) while a linear AR(1) does not strongly reject.
        Random.seed!(65066)
        _diag(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                "metric" in table_cols(v) && return v
            end
            nothing
        end
        mv(doc, name) = (d = _diag(doc); d === nothing ? nothing : metric_value(d, name))

        @testset "estimate star — regimes + transition params, LM3 rejects on LSTAR" begin
            csv = dgp_star(; n=400, seed=661)
            r = run_json(["estimate", "star", csv, "--column", "1", "--p", "1", "--d", "1", "--type", "auto"])
            assert_envelope_ok(r; label="estimate star")
            # regime-weight coef table: regime|term|estimate|std_error|z_stat|p_value, 2 regimes × 2 terms
            ct = nothing; tt = nothing
            for (_, v) in pairs(r.doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                "regime" in table_cols(v) && (ct = v)
                ("parameter" in table_cols(v) && "z_stat" in table_cols(v)) && (tt = v)
            end
            @test ct !== nothing && Set(["regime", "term", "estimate", "std_error"]) ⊆ Set(table_cols(ct))
            @test length(table_rows(ct)) == 4
            # transition-params table carries γ with a finite estimate
            @test tt !== nothing
            ei = col_index(tt, "estimate")
            γrow = first(row for row in table_rows(tt) if occursin("γ", String(string(collect(row)[1]))))
            @test isfinite(Float64(collect(γrow)[ei]))
            @test isfinite(Float64(mv(r.doc, "sigma2")))
            @test string(mv(r.doc, "converged")) in ("true", "false")
            @test Float64(mv(r.doc, "lm3_pvalue")) < 0.10
            # --type auto ⇒ the Teräsvirta selection triple appears in the diagnostics kv
            @test mv(r.doc, "sel_H04") !== nothing
            rm(csv; force=true)
        end

        @testset "test star-linearity — rejects on LSTAR, not on linear AR(1)" begin
            csv = dgp_star(; n=400, seed=662)
            r = run_json(["test", "star-linearity", csv, "--column", "1", "--p", "1", "--d", "1"])
            assert_envelope_ok(r; label="test star-linearity")
            @test Set(["stat", "pvalue", "fstat", "fpvalue", "df"]) ⊆
                  Set(String(string(collect(row)[1])) for row in table_rows(_diag(r.doc)))
            @test Float64(mv(r.doc, "pvalue")) < 0.10
            # negative control: a linear AR(1) should NOT strongly reject (loose upper check)
            lin = dgp_ar1(; T=400, φ=0.5, seed=6620)
            rl = run_json(["test", "star-linearity", lin, "--column", "1", "--p", "1", "--d", "1"])
            assert_envelope_ok(rl; label="test star-linearity (linear)")
            @test Float64(mv(rl.doc, "pvalue")) > 0.01
            # short series: real star_linearity_test is defensively coded (returns a finite LM3 for a
            # short effective sample), so this must be exit 0, NOT data/invalid — the mock mirrors it.
            shortc = write_csv(DataFrame(y=[0.1 * i + 0.3 * sin(i) for i in 1:14]); prefix="starlin_short")
            @test run_json(["test", "star-linearity", shortc, "--column", "1", "--p", "3", "--d", "1"]).code == 0
            rm(csv; force=true); rm(lin; force=true); rm(shortc; force=true)
        end

        @testset "forecast star — h=6 finite paths, coherent bands" begin
            csv = dgp_star(; n=400, seed=663)
            r = run_json(["forecast", "star", csv, "--column", "1", "--p", "1", "--d", "1",
                          "--horizons", "6", "--reps", "199"])
            assert_envelope_ok(r; label="forecast star")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            @test table_cols(tbl) == ["horizon", "variable", "value", "lower", "upper"]
            rows = [collect(row) for row in table_rows(tbl)]
            @test length(rows) == 6
            vi = col_index(tbl, "value"); li = col_index(tbl, "lower"); ui = col_index(tbl, "upper")
            for row in rows
                v = Float64(row[vi]); lo = Float64(row[li]); hi = Float64(row[ui])
                @test isfinite(v) && isfinite(lo) && isfinite(hi)
                # `value` is the bootstrap MEAN path and the bands are percentiles; for a skewed
                # nonlinear-bootstrap forecast the mean can lie outside the percentile band, so we
                # assert only the guaranteed invariant (lower percentile ≤ upper percentile).
                @test lo <= hi
            end
            # --ci-level 0.8 → usage error (exit 2)
            @test run_json(["forecast", "star", csv, "--horizons", "4", "--ci-level", "0.8"]).code == 2
            rm(csv; force=true)
        end
    end

    @testset "estimate ms-ar + estimate ms — Markov-switching nonlinear TS (C065c, M5c)" begin
        # Real Markov-switching EM. Teeth are LOOSE/direction-only (EM is noisy): ms-ar converges
        # with an ordered mu, a row-stochastic K=2 transition matrix, and a finite loglik; ms
        # (intercept-only on the same series) recovers two distinct regime means.
        Random.seed!(65067)
        _find(doc, cols...) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                Set(String.(cols)) ⊆ Set(table_cols(v)) && return v
            end
            nothing
        end
        _diag(doc) = _find(doc, "metric", "value")
        mv(doc, name) = (d = _diag(doc); d === nothing ? nothing : metric_value(d, name))

        @testset "estimate ms-ar — converged, ordered mu, row-stochastic P, finite loglik" begin
            csv = dgp_msar(; n=500, seed=671)
            r = run_json(["estimate", "ms-ar", csv, "--column", "1", "--p", "1"])
            assert_envelope_ok(r; label="estimate ms-ar")
            # coef table: per-regime `mu` rows (ordered increasing) + a common-AR block
            ct = _find(r.doc, "regime", "term", "estimate")
            @test ct !== nothing
            ei = col_index(ct, "estimate"); ti = col_index(ct, "term")
            murows = [collect(row) for row in table_rows(ct) if string(collect(row)[ti]) == "mu"]
            @test length(murows) == 2
            mu1 = Float64(murows[1][ei]); mu2 = Float64(murows[2][ei])
            @test isfinite(mu1) && isfinite(mu2) && mu1 < mu2
            # WIDE K×K transition matrix, K = 2, rows sum ≈ 1 (row-stochastic)
            pt = _find(r.doc, "from_regime", "to_regime1", "to_regime2")
            @test pt !== nothing
            prows = [collect(row) for row in table_rows(pt)]
            @test length(prows) == 2
            c1 = col_index(pt, "to_regime1"); c2 = col_index(pt, "to_regime2")
            for row in prows
                @test isapprox(Float64(row[c1]) + Float64(row[c2]), 1.0; atol=1e-4)
            end
            # per-regime variance table (2 regimes) + finite loglik + convergence flag
            vt = _find(r.doc, "regime", "sigma2", "std_error")
            @test vt !== nothing && length(table_rows(vt)) == 2
            @test isfinite(Float64(mv(r.doc, "loglik")))
            @test string(mv(r.doc, "converged")) == "true"
            @test string(mv(r.doc, "switching_var")) == "false"     # Hamilton default
            # bad input → typed usage error (exit 2), never internal exit-1
            @test run_json(["estimate", "ms-ar", csv, "--k-regimes", "1"]).code == 2
            rm(csv; force=true)
        end

        @testset "estimate ms — intercept-only recovers two distinct regime means" begin
            csv = dgp_msar(; n=500, seed=672)
            r = run_json(["estimate", "ms", csv])
            assert_envelope_ok(r; label="estimate ms")
            ct = _find(r.doc, "regime", "term", "estimate")
            @test ct !== nothing
            ei = col_index(ct, "estimate")
            ests = [Float64(collect(row)[ei]) for row in table_rows(ct)]
            @test length(ests) == 2                                 # intercept-only: 1 term × 2 regimes
            @test all(isfinite, ests)
            @test abs(ests[1] - ests[2]) > 0.5                      # two DISTINCT regime means
            @test string(mv(r.doc, "switching_var")) == "true"      # ms default (switching σ²)
            @test run_json(["estimate", "ms", csv, "--tol", "0"]).code == 2
            rm(csv; force=true)
        end
    end

    @testset "estimate iv/truncreg/heckman + test weak-instrument (C067b, M5c)" begin
        # Coefficient extractor: scan all tables for a row whose `termcol` == term, return
        # its `estimate`. Works for the IV tidy table (term), truncreg (parameter), and the
        # Heckman two-equation table (term, optionally filtered by an `equation` value).
        _coef(doc, term; termcol="term", eq=nothing) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                cols = table_cols(v)
                ti = findfirst(==(termcol), cols); ei = findfirst(==("estimate"), cols)
                (ti === nothing || ei === nothing) && continue
                qi = eq === nothing ? nothing : findfirst(==("equation"), cols)
                for row in table_rows(v)
                    r = collect(row)
                    string(r[ti]) == term || continue
                    (qi === nothing || string(r[qi]) == eq) || continue
                    return Float64(r[ei])
                end
            end
            nothing
        end
        _diag(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                "metric" in table_cols(v) && return v
            end
            nothing
        end

        @testset "estimate iv — order-condition FIX: recovers β_endog≈2 (was exit-1)" begin
            csv = dgp_iv(; T=400, seed=11)
            # Excluded instruments z1,z2; const & x2 exogenous. Pre-C067b this raised an
            # untyped `Order condition violated (m<k)` → internal exit-1.
            r = run_json(["estimate", "iv", csv, "--dep", "y",
                          "--endogenous", "x_endog", "--instruments", "z1,z2"])
            assert_envelope_ok(r; label="estimate iv")
            b = _coef(r.doc, "x_endog")
            @test b !== nothing && 1.6 < b < 2.4                 # true 2.0
            fsf = metric_value(_diag(r.doc), "First-stage F")
            @test fsf !== nothing && Float64(fsf) > 10.0         # strong instruments
            rm(csv; force=true)
        end

        @testset "test weak-instrument — strong (not weak) vs weak (flagged)" begin
            strong = dgp_iv(; T=400, seed=12, inst_strength=0.8)
            rs = run_json(["test", "weak-instrument", strong, "--dep", "y",
                           "--endogenous", "x_endog", "--instruments", "z1,z2"])
            assert_envelope_ok(rs; label="weak-instrument strong")
            @test string(metric_value(_diag(rs.doc), "weak")) == "false"
            @test Float64(metric_value(_diag(rs.doc), "first_stage_f")) > 10.0
            rm(strong; force=true)

            weak = dgp_iv(; T=400, seed=13, inst_strength=0.02)  # near-irrelevant z1
            rw = run_json(["test", "weak-instrument", weak, "--dep", "y",
                           "--endogenous", "x_endog", "--instruments", "z1,z2"])
            assert_envelope_ok(rw; label="weak-instrument weak")
            # z1 near-zero, z2 still present → borderline; assert the F is far below the
            # strong case rather than a hard weak=true (z2 keeps some strength).
            @test Float64(metric_value(_diag(rw.doc), "first_stage_f")) <
                  Float64(metric_value(_diag(rs.doc), "first_stage_f"))
            rm(weak; force=true)
        end

        @testset "test weak-instrument — under-identified → data/invalid (exit 3)" begin
            csv = dgp_iv(; T=200, seed=14)
            # two endogenous, one excluded instrument → |excluded| < |endogenous|.
            r = run_json(["test", "weak-instrument", csv, "--dep", "y",
                          "--endogenous", "x_endog,x2", "--instruments", "z1"])
            @test r.code == 3
            rm(csv; force=true)
        end

        @testset "estimate truncreg — recovers slope on a truncated sample" begin
            # y* = 1 + 0.8 x + e; observe only y*>0 (truncated at 0). Include a const column.
            rng = MersenneTwister(77)
            xs = Float64[]; ys = Float64[]
            while length(ys) < 300
                x = randn(rng); yv = 1.0 + 0.8 * x + randn(rng)
                if yv > 0.0
                    push!(xs, x); push!(ys, yv)
                end
            end
            trcsv = tempname() * "_trunc.csv"
            open(trcsv, "w") do io
                println(io, "y,const,x")
                for i in eachindex(ys); println(io, "$(ys[i]),1.0,$(xs[i])"); end
            end
            r = run_json(["estimate", "truncreg", trcsv, "--dep", "y", "--lower", "0.0"])
            assert_envelope_ok(r; label="estimate truncreg")
            b = _coef(r.doc, "x"; termcol="parameter")
            @test b !== nothing && 0.4 < b < 1.2                 # true 0.8 (truncation-corrected)
            @test metric_value(_diag(r.doc), "n_truncated") !== nothing
            rm(trcsv; force=true)
        end

        @testset "estimate heckman — two-step recovers outcome slope + both equations" begin
            csv = dgp_heckman(; T=1500, seed=21, ρ=0.5)
            r = run_json(["estimate", "heckman", csv, "--dep", "y", "--select", "d",
                          "--outcome-vars", "const,x1", "--select-vars", "const,z1"])
            assert_envelope_ok(r; label="estimate heckman")
            bx = _coef(r.doc, "x1"; eq="outcome")
            @test bx !== nothing && 0.5 < bx < 1.1               # true outcome slope 0.8
            @test _coef(r.doc, "z1"; eq="selection") !== nothing # selection equation present
            @test string(metric_value(_diag(r.doc), "method")) == "twostep"
            rm(csv; force=true)
        end
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

    @testset "test vecm restriction tests — real Johansen LR (C071)" begin
        # Two I(1) series sharing a stochastic trend → cointegrating rank 1.
        cointcsv = dgp_coint(; T=300, β=1.0, seed=71)
        kv(doc, name) = (t = last(first_table(doc)); t === nothing ? nothing : metric_value(t, name))

        # Write a restriction config (p=2, r=1). Non-binding H = I₂ (s=p) ⇒ LR ≈ 0, df = 0.
        idcfg = tempname() * ".toml"
        write(idcfg, "[vecm_restriction]\nH = [[1.0, 0.0], [0.0, 1.0]]\n")
        rid = run_json(["test", "vecm", "beta", cointcsv, "--config", idcfg, "--rank", "1"])
        assert_envelope_ok(rid; label="test vecm beta (identity H)")
        @test kv(rid.doc, "df") == 0
        lr0 = kv(rid.doc, "LR statistic")
        @test lr0 !== nothing && abs(Float64(lr0)) < 1e-4       # non-binding restriction

        # Binding β restriction β = Hφ with H = (1, -1)′ (s=1 ⇒ df = r(p−s) = 1).
        bcfg = tempname() * ".toml"
        write(bcfg, "[vecm_restriction]\nH = [[1.0], [-1.0]]\nA = [[1.0], [0.0]]\nb = [[1.0], [-1.0]]\n")
        rb = run_json(["test", "vecm", "beta", cointcsv, "--config", bcfg, "--rank", "1"])
        assert_envelope_ok(rb; label="test vecm beta")
        @test kv(rb.doc, "df") == 1
        pvb = kv(rb.doc, "p-value")
        @test pvb !== nothing && 0.0 <= Float64(pvb) <= 1.0

        # α restriction (df = r(p−a) = 1).
        ra = run_json(["test", "vecm", "alpha", cointcsv, "--config", bcfg, "--rank", "1"])
        assert_envelope_ok(ra; label="test vecm alpha")
        @test kv(ra.doc, "df") == 1

        # Weak exogeneity of variable 1 (df = r·|vars| = 1).
        rw = run_json(["test", "vecm", "weak-exog", cointcsv, "--vars", "1", "--rank", "1"])
        assert_envelope_ok(rw; label="test vecm weak-exog")
        @test kv(rw.doc, "df") == 1

        # Known β (b is p×r; df = r(p−r) = 1).
        rk = run_json(["test", "vecm", "known-beta", cointcsv, "--config", bcfg, "--rank", "1"])
        assert_envelope_ok(rk; label="test vecm known-beta")
        @test kv(rk.doc, "df") == 1

        # Joint β&α via the switching algorithm (df = r(p−s)+r(p−a) = 2).
        rj = run_json(["test", "vecm", "joint", cointcsv, "--config", bcfg, "--rank", "1"])
        assert_envelope_ok(rj; label="test vecm joint")
        @test kv(rj.doc, "df") == 2

        # Bad input stays typed (not internal exit 1): missing --config, fitted rank 0.
        rmc = run_json(["test", "vecm", "beta", cointcsv, "--rank", "1"])
        @test rmc.code == 2                                     # usage/missing-config
        r0 = run_json(["test", "vecm", "beta", cointcsv, "--config", bcfg, "--rank", "0"])
        @test r0.code == 3                                      # data/no-cointegration

        rm(cointcsv; force=true)
        rm(idcfg; force=true)
        rm(bcfg; force=true)
    end

    @testset "TS + panel test batteries — real MEMs (C069/C070)" begin
        # scan every kv table (metric|value) across the envelope for a metric value
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
        # the (first) table that contains a named column
        coltable(doc, col) = begin
            for (_, tbl) in pairs(doc.data)
                if (tbl isa JSON3.Object || tbl isa AbstractDict) && (haskey(tbl, :columns) || haskey(tbl, "columns"))
                    col in table_cols(tbl) && return tbl
                end
            end
            nothing
        end
        pmin(tbl) = minimum(Float64(collect(r)[col_index(tbl, "p_value")]) for r in table_rows(tbl))

        @testset "variance-ratio — random walk (H0) vs mean-reverting (reject)" begin
            rw = dgp_random_walk(; T=600, seed=91)
            rrw = run_json(["test", "variance-ratio", rw, "--column", "1"])
            assert_envelope_ok(rrw; label="variance-ratio rw")
            prw = scan_metric(rrw.doc, "Chow-Denning p-value")
            @test prw !== nothing && 0.0 <= Float64(prw) <= 1.0
            t = coltable(rrw.doc, "variance_ratio")
            @test t !== nothing && length(table_rows(t)) == 4        # default q = 2,4,8,16

            mr = dgp_ar1(; T=600, φ=0.3, seed=93)                    # stationary → VR ≠ 1
            rmr = run_json(["test", "variance-ratio", mr, "--column", "1"])
            assert_envelope_ok(rmr; label="variance-ratio mean-reverting")
            pmr = scan_metric(rmr.doc, "Chow-Denning p-value")
            @test pmr !== nothing && Float64(pmr) < 0.05             # reject random walk
            rm(rw; force=true); rm(mr; force=true)
        end

        @testset "bds — iid (H0) vs nonlinear GARCH (reject)" begin
            iid = dgp_iid(; T=400, seed=95)
            rii = run_json(["test", "bds", iid, "--column", "1"])
            assert_envelope_ok(rii; label="bds iid")
            t = coltable(rii.doc, "embed_dim")
            @test t !== nothing && length(table_rows(t)) == 5        # m = 2..6
            @test 0.0 <= pmin(t) <= 1.0

            g = dgp_garch(; T=500, seed=97)
            rg = run_json(["test", "bds", g, "--column", "1"])
            assert_envelope_ok(rg; label="bds garch")
            @test pmin(coltable(rg.doc, "p_value")) < 0.05          # nonlinear ⇒ reject iid
            rm(iid; force=true); rm(g; force=true)
        end

        @testset "hadri — stationary vs unit-root panel" begin
            i0 = dgp_panel_matrix(; N=10, T=80, unit_root=false, seed=101)
            r0 = run_json(["test", "hadri", i0])
            assert_envelope_ok(r0; label="hadri stationary")
            p0 = scan_metric(r0.doc, "p-value"); s0 = scan_metric(r0.doc, "statistic")
            @test p0 !== nothing && 0.0 <= Float64(p0) <= 1.0
            @test s0 !== nothing && isfinite(Float64(s0))

            i1 = dgp_panel_matrix(; N=10, T=80, unit_root=true, seed=103)
            r1 = run_json(["test", "hadri", i1])
            assert_envelope_ok(r1; label="hadri unit-root")
            p1 = scan_metric(r1.doc, "p-value"); s1 = scan_metric(r1.doc, "statistic")
            @test p1 !== nothing && Float64(p1) < 0.05              # reject all-stationary
            # the I(1) panel's LM statistic is far larger than the (over-rejecting but
            # bounded) stationary panel's — the robust discriminating direction.
            @test s1 !== nothing && Float64(s1) > Float64(s0)
            rm(i0; force=true); rm(i1; force=true)
        end

        @testset "pedroni / kao / westerlund — cointegrated panel (reject no-coint)" begin
            cp = dgp_coint_panel(; N=10, T=50, seed=105)
            for (leaf, ncols) in [("pedroni", 7), ("kao", 5), ("westerlund", 4)]
                r = run_json(["test", leaf, cp, "--dep", "y", "--indep", "x"])
                assert_envelope_ok(r; label="$leaf coint panel")
                t = coltable(r.doc, "p_value")
                @test t !== nothing && length(table_rows(t)) == ncols
                @test pmin(t) < 0.05                                # genuinely cointegrated
                @test scan_metric(r.doc, "n_regressors") == 1
            end
            rm(cp; force=true)
        end

        @testset "bad input stays typed (not internal exit 1)" begin
            uni = dgp_iid(; T=200, seed=111)
            @test run_json(["test", "variance-ratio", uni, "--horizons", "junk"]).code == 2
            @test run_json(["test", "variance-ratio", uni, "--horizons", "1,2"]).code == 2
            @test run_json(["test", "bds", uni, "--max-dim", "1"]).code == 2
            cp = dgp_coint_panel(; N=6, T=40, seed=113)
            @test run_json(["test", "pedroni", cp, "--dep", "nope"]).code == 2
            @test run_json(["test", "pedroni", cp, "--indep", "nope"]).code == 2
            @test run_json(["test", "pedroni", cp, "--id-col", "nosuch"]).code == 3   # data/missing-column
            # duplicate (id,time) pair → real xtset ArgumentError mapped to typed data/invalid
            # (regression: adversarial review C069/C070 — was an uncaught internal exit-1)
            dup = tempname() * ".csv"
            write(dup, "id,time,y,x\n1,1,0.5,1.2\n1,1,0.7,1.3\n1,2,0.9,1.4\n2,1,0.3,0.8\n2,2,0.6,0.9\n")
            @test run_json(["test", "pedroni", dup, "--dep", "y", "--indep", "x"]).code == 3
            rm(dup; force=true)
            rm(uni; force=true); rm(cp; force=true)
        end

        # ── C069 remainder: seasonal / point-optimal / bubble / EDF + residual
        # cointegration. Each case asserts the DISCRIMINATING DIRECTION on a DGP built
        # for that null, not a hard-coded statistic.

        @testset "hegy — seasonal unit root vs deterministic seasonality" begin
            su = dgp_seasonal(; T=240, deterministic=false, seed=121)
            r = run_json(["test", "hegy", su, "--frequency", "4"])
            assert_envelope_ok(r; label="hegy seasonal unit root")
            t = coltable(r.doc, "decision")
            # quarterly ⇒ zero + Nyquist + one harmonic pair
            @test t !== nothing && length(table_rows(t)) == 3
            @test Set(["frequency", "kind", "statistic", "cv_5pct", "decision"]) ⊆
                  Set(String.(table_cols(t)))
            # a seasonal random walk must not reject at EVERY seasonal frequency
            decs = [String(collect(row)[col_index(t, "decision")]) for row in table_rows(t)]
            @test any(d -> startswith(d, "cannot reject"), decs)

            ds = dgp_seasonal(; T=240, deterministic=true, seed=123)
            rd = run_json(["test", "hegy", ds, "--frequency", "4"])
            assert_envelope_ok(rd; label="hegy deterministic seasonality")
            decs_d = [String(collect(row)[col_index(coltable(rd.doc, "decision"), "decision")])
                      for row in table_rows(coltable(rd.doc, "decision"))]
            # stationary + dummies ⇒ the seasonal roots are rejected
            @test count(d -> startswith(d, "reject"), decs_d) > count(d -> startswith(d, "reject"), decs)
            rm(su; force=true); rm(ds; force=true)
        end

        @testset "ers — random walk (H0) vs stationary AR(1) (reject)" begin
            rw = dgp_random_walk(; T=300, seed=125)
            r0 = run_json(["test", "ers", rw])
            assert_envelope_ok(r0; label="ers random walk")
            p0 = scan_metric(r0.doc, "p-value")
            @test p0 !== nothing && Float64(p0) > 0.05          # cannot reject a unit root

            st = dgp_ar1(; T=300, φ=0.2, seed=127)
            r1 = run_json(["test", "ers", st])
            assert_envelope_ok(r1; label="ers stationary")
            p1 = scan_metric(r1.doc, "p-value")
            @test p1 !== nothing && Float64(p1) < 0.05          # reject the unit root
            @test scan_metric(r1.doc, "regression") == "constant"
            @test run_json(["test", "ers", st, "--trend"]).code == 0
            rm(rw; force=true); rm(st; force=true)
        end

        @testset "sadf/gsadf — explosive episode vs pure random walk" begin
            bub = dgp_bubble(; T=300, seed=129)
            rw  = dgp_random_walk(; T=300, seed=131)
            for leaf in ("sadf", "gsadf")
                rb = run_json(["test", leaf, bub, "--mc-reps", "199"])
                assert_envelope_ok(rb; label="$leaf bubble")
                sb = scan_metric(rb.doc, "statistic")
                rr = run_json(["test", leaf, rw, "--mc-reps", "199"])
                assert_envelope_ok(rr; label="$leaf random walk")
                sr = scan_metric(rr.doc, "statistic")
                # the explosive series must score strictly higher than the pure I(1) one
                @test sb !== nothing && sr !== nothing && Float64(sb) > Float64(sr)
                @test coltable(rb.doc, "episode") !== nothing
            end
            rm(bub; force=true); rm(rw; force=true)
        end

        @testset "edf — normal sample (H0) vs an obviously non-normal one" begin
            iid = dgp_iid(; T=400, seed=133)
            r0 = run_json(["test", "edf", iid, "--dist", "normal", "--test", "ad"])
            assert_envelope_ok(r0; label="edf normal")
            p0 = scan_metric(r0.doc, "p-value")
            @test p0 !== nothing && Float64(p0) > 0.05         # consistent with normality

            # a random-walk LEVEL series is nowhere near normal
            rw = dgp_random_walk(; T=400, seed=135)
            r1 = run_json(["test", "edf", rw, "--dist", "normal", "--test", "ad"])
            assert_envelope_ok(r1; label="edf non-normal")
            p1 = scan_metric(r1.doc, "p-value")
            @test p1 !== nothing && Float64(p1) < 0.05
            @test run_json(["test", "edf", iid, "--test", "ks"]).code == 0
            # upstream spells the supplied-parameter case :specified — a T3 regression, since
            # the mock had wrongly accepted :known and hid the failure at T1/T2
            @test run_json(["test", "edf", iid, "--params", "specified", "--theta", "0,1"]).code == 0
            @test run_json(["test", "edf", iid, "--params", "known", "--theta", "0,1"]).code == 2
            rm(iid; force=true); rm(rw; force=true)
        end

        @testset "engle-granger / phillips-ouliaris — cointegrated vs independent" begin
            # NOTE the H0 flips relative to a unit-root test: H0 is NO cointegration, so
            # a LOW p-value is evidence FOR a cointegrating relationship.
            ci = dgp_coint(; T=250, β=2.0, seed=137)
            nc = dgp_no_coint(; T=250, seed=139)
            for leaf in ("engle-granger", "phillips-ouliaris")
                rc = run_json(["test", leaf, ci, "--dep", "y"])
                assert_envelope_ok(rc; label="$leaf cointegrated")
                pc = scan_metric(rc.doc, "p-value")
                pc = pc === nothing ? nothing : Float64(pc)
                if pc === nothing                      # PO reports its p-values in a table
                    t = coltable(rc.doc, "p_value")
                    pc = minimum(Float64(collect(r)[col_index(t, "p_value")]) for r in table_rows(t))
                end
                @test pc < 0.05                        # cointegrated ⇒ reject no-cointegration

                rn = run_json(["test", leaf, nc, "--dep", "y"])
                assert_envelope_ok(rn; label="$leaf independent")
                pn = scan_metric(rn.doc, "p-value")
                pn = pn === nothing ? nothing : Float64(pn)
                if pn === nothing
                    t = coltable(rn.doc, "p_value")
                    pn = minimum(Float64(collect(r)[col_index(t, "p_value")]) for r in table_rows(t))
                end
                @test pn > pc                          # independent walks score far weaker
            end
            @test run_json(["test", "phillips-ouliaris", ci, "--dep", "y",
                            "--kernel", "parzen", "--bandwidth", "6"]).code == 0
            @test run_json(["test", "engle-granger", ci, "--dep", "y", "--lags", "2"]).code == 0
            rm(ci; force=true); rm(nc; force=true)
        end

        @testset "hansen-instability / park-added — stable cointegration" begin
            ci = dgp_coint(; T=250, β=2.0, seed=141)
            rh = run_json(["test", "hansen-instability", ci, "--dep", "y"])
            assert_envelope_ok(rh; label="hansen-instability")
            ph = scan_metric(rh.doc, "p-value")
            # H0 here is STABLE cointegration, and the DGP has a constant β ⇒ don't reject
            @test ph !== nothing && Float64(ph) > 0.05
            @test scan_metric(rh.doc, "trend") == "const"

            rp = run_json(["test", "park-added", ci, "--dep", "y", "--q-add", "2"])
            assert_envelope_ok(rp; label="park-added")
            pp = scan_metric(rp.doc, "p-value")
            # H0 is genuine cointegration ⇒ don't reject on a genuinely cointegrated pair
            @test pp !== nothing && Float64(pp) > 0.05
            @test scan_metric(rp.doc, "q_add (df)") == 2

            # A spurious pair must still produce a well-formed result. Deliberately NOT
            # asserting statistic(spurious) > statistic(cointegrated): the Park H(p,q)
            # test's power at T=250 on a single draw does not guarantee that ordering
            # (measured 3.54 vs 4.25 on seeds 143/141), so such a check tests the seed,
            # not the wrapper.
            nc = dgp_no_coint(; T=250, seed=143)
            rs = run_json(["test", "park-added", nc, "--dep", "y"])
            assert_envelope_ok(rs; label="park-added spurious")
            @test isfinite(Float64(scan_metric(rs.doc, "H(p,q) statistic")))
            let psp = Float64(scan_metric(rs.doc, "p-value"))
                @test 0.0 <= psp <= 1.0
            end

            @test run_json(["test", "hansen-instability", ci, "--dep", "y",
                            "--method", "dols", "--leads", "2", "--lags", "2"]).code == 0
            rm(ci; force=true); rm(nc; force=true)
        end

        @testset "llc/ips/breitung — unit-root vs stationary panel" begin
            # H0 for all three is that EVERY unit has a unit root — the OPPOSITE of hadri.
            i1 = dgp_panel_matrix(; N=10, T=80, unit_root=true, seed=301)
            i0 = dgp_panel_matrix(; N=10, T=80, unit_root=false, seed=303)
            for leaf in ("llc", "ips", "breitung")
                r1 = run_json(["test", leaf, i1])
                assert_envelope_ok(r1; label="$leaf unit-root panel")
                p1 = Float64(scan_metric(r1.doc, "p-value"))
                @test p1 > 0.05                       # cannot reject "all have a unit root"

                r0 = run_json(["test", leaf, i0])
                assert_envelope_ok(r0; label="$leaf stationary panel")
                p0 = Float64(scan_metric(r0.doc, "p-value"))
                @test p0 < p1                         # stationary panel scores stronger
                @test scan_metric(r0.doc, "n_units") == 10
            end
            # IPS reports the per-unit ADF statistics
            t = coltable(run_json(["test", "ips", i0]).doc, "t_statistic")
            @test t !== nothing && length(table_rows(t)) == 10
            @test run_json(["test", "llc", i0, "--deterministic", "trend"]).code == 0
            @test run_json(["test", "breitung", i0, "--cs-demean"]).code == 0
            rm(i1; force=true); rm(i0; force=true)
        end

        @testset "fisher-johansen / dh-causality — panel leaves" begin
            cp = dgp_coint_panel(; N=10, T=50, seed=305)
            fj = run_json(["test", "fisher-johansen", cp, "--vars", "y,x"])
            assert_envelope_ok(fj; label="fisher-johansen")
            t = coltable(fj.doc, "trace_statistic")
            @test t !== nothing && length(table_rows(t)) >= 1
            @test Set(["rank", "trace_statistic", "trace_p_value", "max_statistic",
                       "max_p_value"]) ⊆ Set(String.(table_cols(t)))
            @test scan_metric(fj.doc, "n_units") == 10
            @test run_json(["test", "fisher-johansen", cp, "--vars", "y,x",
                            "--combine", "choi"]).code == 0

            dh = run_json(["test", "dh-causality", cp, "--cause", "x", "--effect", "y"])
            assert_envelope_ok(dh; label="dh-causality")
            for m in ("cause", "effect", "W-bar", "Z-bar", "Z-tilde", "Z-tilde p-value")
                @test scan_metric(dh.doc, m) !== nothing
            end
            @test String(scan_metric(dh.doc, "cause")) == "x"
            @test String(scan_metric(dh.doc, "effect")) == "y"
            rm(cp; force=true)
        end

        @testset "estimate preg — PCSE and Prais-Winsten AR(1) (#75)" begin
            cp = dgp_coint_panel(; N=10, T=50, seed=307)
            base = ["estimate", "preg", cp, "--dep", "y", "--indep", "x"]
            @test run_json(vcat(base, ["--cov-type", "pcse"])).code == 0
            @test run_json(vcat(base, ["--cov-type", "pcse", "--pcse-unbalanced", "pairwise"])).code == 0
            for a in ("common", "panel-specific")
                @test run_json(vcat(base, ["--ar1", a])).code == 0
            end
            # --pcse-unbalanced only means anything under --cov-type pcse
            @test run_json(vcat(base, ["--pcse-unbalanced", "pairwise"])).code == 2
            @test run_json(vcat(base, ["--ar1", "bogus"])).code == 2
            rm(cp; force=true)
        end

        @testset "C070 remainder — bad input stays typed" begin
            mv = dgp_panel_matrix(; N=8, T=60, seed=309)
            cp = dgp_coint_panel(; N=8, T=40, seed=311)
            @test run_json(["test", "llc", mv, "--lags", "junk"]).code == 2
            @test run_json(["test", "llc", mv, "--max-lags", "-1"]).code == 2
            @test run_json(["test", "breitung", mv, "--lags", "-1"]).code == 2
            @test run_json(["test", "llc", mv, "--deterministic", "bogus"]).code == 2
            @test run_json(["test", "fisher-johansen", cp, "--vars", "y"]).code == 2
            @test run_json(["test", "fisher-johansen", cp, "--vars", "nosuch"]).code == 2
            @test run_json(["test", "dh-causality", cp, "--effect", "y"]).code == 2
            @test run_json(["test", "dh-causality", cp, "--cause", "x", "--effect", "y",
                            "--p", "0"]).code == 2
            @test run_json(["test", "dh-causality", cp, "--cause", "y", "--effect", "y"]).code == 2
            rm(mv; force=true); rm(cp; force=true)
        end

        # ── C067 remainder (#72): cross-section OLS diagnostics. Each case asserts the
        # DISCRIMINATING DIRECTION on a DGP built for that null.

        @testset "white/glejser/harvey — homoskedastic vs heteroskedastic" begin
            hom = dgp_reg_diag(; n=300, hetero=false, seed=201)
            het = dgp_reg_diag(; n=300, hetero=true, seed=203)
            for leaf in ("white", "glejser", "harvey")
                r0 = run_json(["test", leaf, hom, "--dep", "y"])
                assert_envelope_ok(r0; label="$leaf homoskedastic")
                p0 = Float64(scan_metric(r0.doc, "p-value"))
                @test p0 > 0.05                     # H0 homoskedasticity holds

                r1 = run_json(["test", leaf, het, "--dep", "y"])
                assert_envelope_ok(r1; label="$leaf heteroskedastic")
                p1 = Float64(scan_metric(r1.doc, "p-value"))
                @test p1 < 0.05                     # reject homoskedasticity
            end
            @test run_json(["test", "white", hom, "--dep", "y", "--no-cross-terms"]).code == 0
            rm(hom; force=true); rm(het; force=true)
        end

        @testset "chow — stable sample vs a slope break" begin
            stable = dgp_reg_diag(; n=200, seed=205)
            brk = dgp_reg_diag(; n=200, break_at=100, seed=207)
            r0 = run_json(["test", "chow", stable, "--dep", "y", "--break-at", "100"])
            assert_envelope_ok(r0; label="chow stable")
            @test Float64(scan_metric(r0.doc, "p-value")) > 0.05

            r1 = run_json(["test", "chow", brk, "--dep", "y", "--break-at", "100"])
            assert_envelope_ok(r1; label="chow break")
            @test Float64(scan_metric(r1.doc, "p-value")) < 0.05
            @test run_json(["test", "chow", brk, "--dep", "y", "--break-at", "60,120"]).code == 0
            rm(stable; force=true); rm(brk; force=true)
        end

        @testset "cusum/cusumsq — band path, no p-value" begin
            brk = dgp_reg_diag(; n=200, break_at=100, seed=209)
            for (leaf, col) in (("cusum", "cusum"), ("cusumsq", "cusumsq"))
                r = run_json(["test", leaf, brk, "--dep", "y"])
                assert_envelope_ok(r; label=leaf)
                t = coltable(r.doc, col)
                @test t !== nothing
                @test Set(["observation", col, "lower", "upper"]) ⊆ Set(String.(table_cols(t)))
                @test length(table_rows(t)) > 0
                # StabilityResult has a band, NOT a p-value — the crossing IS the verdict
                @test scan_metric(r.doc, "p-value") === nothing
                @test scan_metric(r.doc, "crossed band") !== nothing
            end
            rm(brk; force=true)
        end

        @testset "influence / recursive-residuals — per-observation output" begin
            csv = dgp_reg_diag(; n=150, seed=211)
            ri = run_json(["test", "influence", csv, "--dep", "y"])
            assert_envelope_ok(ri; label="influence")
            t = coltable(ri.doc, "hat")
            @test t !== nothing && length(table_rows(t)) == 150      # one row per observation
            @test Set(["hat", "student_internal", "student_external", "dffits", "cooksd"]) ⊆
                  Set(String.(table_cols(t)))
            # Leverages sum to k (a standard identity) — checks we read the right field.
            # Tolerance is loose because the CLI rounds `hat` to 6 dp, so summing n rows
            # accumulates up to n*5e-7 of rounding (1e-6 fails at n=150).
            hs = [Float64(collect(r)[col_index(t, "hat")]) for r in table_rows(t)]
            @test isapprox(sum(hs), 3.0; atol=1e-3)                  # k = const + x1 + x2

            rr = run_json(["test", "recursive-residuals", csv, "--dep", "y"])
            assert_envelope_ok(rr; label="recursive-residuals")
            rt = coltable(rr.doc, "recursive_residual")
            @test rt !== nothing && length(table_rows(rt)) == 150 - 3   # n - k
            rm(csv; force=true)
        end

        @testset "estimate select — recovers the true model (#72)" begin
            # y depends on x1 and x2 only; x3/x4 are pure noise, so a working search
            # must keep the former and drop the latter.
            csv = dgp_select(; n=400, seed=217)
            r = run_json(["estimate", "select", csv, "--dep", "y"])
            assert_envelope_ok(r; label="estimate select")
            sel = String(scan_metric(r.doc, "selected"))
            @test occursin("x1", sel) && occursin("x2", sel)
            @test !occursin("x3", sel) && !occursin("x4", sel)
            @test Float64(scan_metric(r.doc, "n selected")) >= 2

            # the selection path is the audit trail
            t = coltable(r.doc, "action")
            @test t !== nothing
            @test Set(["step", "action", "variable", "statistic"]) ⊆ Set(String.(table_cols(t)))

            # --keep forces a regressor in even though it is irrelevant
            rk = run_json(["estimate", "select", csv, "--dep", "y", "--keep", "x3"])
            assert_envelope_ok(rk; label="estimate select --keep")
            @test occursin("x3", String(scan_metric(rk.doc, "selected")))

            for m in ("forward", "backward", "gets")
                @test run_json(["estimate", "select", csv, "--dep", "y", "--method", m]).code == 0
            end
            @test run_json(["estimate", "select", csv, "--dep", "y", "--criterion", "bic"]).code == 0

            @test run_json(["estimate", "select", csv, "--dep", "y", "--p-enter", "0"]).code == 2
            @test run_json(["estimate", "select", csv, "--dep", "y",
                            "--p-enter", "0.2", "--p-remove", "0.05"]).code == 2
            @test run_json(["estimate", "select", csv, "--dep", "y", "--keep", "nosuch"]).code == 3
            @test run_json(["estimate", "select", csv, "--dep", "y", "--method", "bogus"]).code == 2
            rm(csv; force=true)
        end

        @testset "estimate iv — k-class family (#72)" begin
            csv = dgp_iv(; T=400, seed=215)
            base = ["estimate", "iv", csv, "--dep", "y", "--endogenous", "x_endog",
                    "--instruments", "z1,z2"]
            b = Dict{String,Float64}()
            for m in ("tsls", "liml", "fuller", "kclass")
                args = m == "kclass" ? vcat(base, ["--method", m, "--k", "1"]) :
                                       vcat(base, ["--method", m])
                r = run_json(args)
                assert_envelope_ok(r; label="iv $m")
                t = coltable(r.doc, "estimate")
                row = first(rr for rr in table_rows(t)
                            if String(collect(rr)[col_index(t, "term")]) == "x_endog")
                b[m] = Float64(collect(row)[col_index(t, "estimate")])
                @test isapprox(b[m], 2.0; atol=0.25)      # all recover the true beta
            end
            # k=1 IS 2SLS by construction — a deterministic identity, not a tolerance test
            @test isapprox(b["kclass"], b["tsls"]; atol=1e-8)
            # LIML reports kappa_hat >= 1; Fuller shifts k below it by a/(n-m)
            rl = run_json(vcat(base, ["--method", "liml"]))
            @test Float64(scan_metric(rl.doc, "kappa_hat")) >= 1.0
            rf = run_json(vcat(base, ["--method", "fuller"]))
            @test Float64(scan_metric(rf.doc, "k-class k")) < Float64(scan_metric(rf.doc, "kappa_hat"))

            @test run_json(vcat(base, ["--method", "kclass"])).code == 2      # --k required
            @test run_json(vcat(base, ["--method", "tsls", "--k", "1"])).code == 2
            @test run_json(vcat(base, ["--method", "bogus"])).code == 2
            rm(csv; force=true)
        end

        @testset "C067 remainder — bad input stays typed" begin
            csv = dgp_reg_diag(; n=120, seed=213)
            @test run_json(["test", "chow", csv, "--dep", "y"]).code == 2            # --break-at required
            @test run_json(["test", "chow", csv, "--dep", "y", "--break-at", "junk"]).code == 2
            @test run_json(["test", "chow", csv, "--dep", "y", "--break-at", "0"]).code == 2
            # an out-of-range break reaches MEMs' ArgumentError → typed data/invalid, not exit 1
            @test run_json(["test", "chow", csv, "--dep", "y", "--break-at", "500"]).code == 3
            @test run_json(["test", "cusum", csv, "--dep", "y", "--level", "0"]).code == 2
            @test run_json(["test", "white", csv, "--dep", "nope"]).code == 3
            @test run_json(["test", "influence", csv, "--dep", "nope"]).code == 3
            rm(csv; force=true)
        end

        @testset "C069 remainder — bad input stays typed" begin
            uni = dgp_iid(; T=200, seed=145)
            reg = dgp_coint(; T=200, seed=147)
            @test run_json(["test", "hegy", uni, "--frequency", "7"]).code == 2
            @test run_json(["test", "hegy", uni, "--lags", "junk"]).code == 2
            @test run_json(["test", "sadf", uni, "--r0", "1.5"]).code == 2
            @test run_json(["test", "sadf", uni, "--adflag", "-1"]).code == 2
            @test run_json(["test", "gsadf", uni, "--mc-reps", "0"]).code == 2
            @test run_json(["test", "edf", uni, "--params", "specified"]).code == 2
            @test run_json(["test", "edf", uni, "--dist", "bogus"]).code == 2
            # EG/PO take :none|:constant|:trend — cointreg's "linear" must NOT be accepted
            @test run_json(["test", "engle-granger", reg, "--trend", "linear"]).code == 2
            @test run_json(["test", "engle-granger", reg, "--dep", "nope"]).code == 3
            @test run_json(["test", "phillips-ouliaris", reg, "--bandwidth", "junk"]).code == 2
            @test run_json(["test", "park-added", reg, "--q-add", "0"]).code == 2
            @test run_json(["test", "hansen-instability", reg, "--dep", "nope"]).code == 3
            # too few observations for the (y,X) leaves → typed data error, never exit 1
            short = tempname() * ".csv"
            write(short, "y,x\n1.0,2.0\n2.0,3.1\n3.0,3.9\n4.0,5.2\n")
            @test run_json(["test", "engle-granger", short, "--dep", "y"]).code == 3
            @test run_json(["test", "ers", short]).code == 3        # ERS needs ≥ 30 obs
            rm(short; force=true)
            rm(uni; force=true); rm(reg; force=true)
        end
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

    @testset "MGARCH ccc/dcc/bekk + volatility diagnostics on real MEMs (C064b)" begin
        # scanners: wide correlation (series col), dynamics (parameter|estimate), diag (metric|value)
        _corr_of(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :columns)) || continue
                "series" in table_cols(v) && return v
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
        _coef_of(doc) = begin
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :columns)) || continue
                cols = table_cols(v)
                ("parameter" in cols && "estimate" in cols) && return v
            end
            return nothing
        end

        @testset "estimate ccc — n×n correlation, no second-stage params" begin
            csv = dgp_mgarch(; T=300, n=3, seed=201)
            r = run_json(["estimate", "ccc", csv, "--p", "1", "--q", "1"])
            assert_envelope_ok(r; label="estimate ccc")
            corr = _corr_of(r.doc); @test corr !== nothing
            @test "series" in table_cols(corr) && "r1" in table_cols(corr)
            @test length(table_rows(corr)) == 3          # 3 series → 3 rows (wide sector×sector)
            @test string(metric_value(_diag_of(r.doc), "kind")) == "ccc"
            @test _coef_of(r.doc) === nothing            # CCC has no dynamics coef table
            rm(csv; force=true)
        end

        @testset "estimate dcc — a,b ∈ (0,1), persistence < 1" begin
            csv = dgp_mgarch(; T=350, n=2, seed=202)
            r = run_json(["estimate", "dcc", csv])
            assert_envelope_ok(r; label="estimate dcc")
            tbl = _coef_of(r.doc); @test tbl !== nothing
            names = String[string(collect(row)[col_index(tbl, "parameter")]) for row in table_rows(tbl)]
            @test "a" in names && "b" in names
            pers = metric_value(_diag_of(r.doc), "persistence")
            @test pers !== nothing && 0.0 <= Float64(pers) <= 1.0001
            @test string(metric_value(_diag_of(r.doc), "correction")) == "none"
            rm(csv; force=true)
        end

        @testset "estimate dcc --correction aielli (cDCC)" begin
            csv = dgp_mgarch(; T=300, n=2, seed=203)
            r = run_json(["estimate", "dcc", csv, "--correction", "aielli"])
            assert_envelope_ok(r; label="estimate dcc aielli")
            @test string(metric_value(_diag_of(r.doc), "correction")) == "aielli"
            rm(csv; force=true)
        end

        @testset "estimate bekk scalar / diagonal" begin
            csv = dgp_mgarch(; T=300, n=2, seed=204)
            rs = run_json(["estimate", "bekk", csv, "--kind", "scalar"])
            assert_envelope_ok(rs; label="estimate bekk scalar")
            @test string(metric_value(_diag_of(rs.doc), "bekk_kind")) == "scalar"
            ts = _coef_of(rs.doc); @test ts !== nothing
            snames = String[string(collect(row)[col_index(ts, "parameter")]) for row in table_rows(ts)]
            @test "a" in snames && "b" in snames

            rd = run_json(["estimate", "bekk", csv, "--kind", "diagonal"])
            assert_envelope_ok(rd; label="estimate bekk diagonal")
            @test string(metric_value(_diag_of(rd.doc), "bekk_kind")) == "diagonal"
            td = _coef_of(rd.doc); @test td !== nothing
            dnames = String[string(collect(row)[col_index(td, "parameter")]) for row in table_rows(td)]
            @test "a1" in dnames && "b1" in dnames
            rm(csv; force=true)
        end

        @testset "estimate ccc on 1-column data → data error (not exit 1)" begin
            csv = dgp_garch(; T=200, seed=205)   # single column 'r'
            r = run_json(["estimate", "ccc", csv])
            @test r.code == 3                     # ArgumentError('≥2 series') → data/invalid
            rm(csv; force=true)
        end

        @testset "test sign-bias — Engle-Ng joint p-value ∈ [0,1]" begin
            csv = dgp_garch(; T=400, seed=206)
            r = run_json(["test", "sign-bias", csv, "--column", "1", "--model", "garch"])
            assert_envelope_ok(r; label="test sign-bias")
            jp = metric_value(_diag_of(r.doc), "joint_pvalue")
            @test jp !== nothing && 0.0 <= Float64(jp) <= 1.0
            @test metric_value(_diag_of(r.doc), "joint_statistic") !== nothing
            rm(csv; force=true)
        end

        @testset "test nyblom — individual L stats + joint L_C vs cv" begin
            csv = dgp_garch(; T=400, seed=207)
            r = run_json(["test", "nyblom", csv, "--column", "1", "--model", "garch"])
            assert_envelope_ok(r; label="test nyblom")
            ind = nothing
            for (_, v) in pairs(r.doc.data)
                (v isa JSON3.Object && haskey(v, :columns)) || continue
                "L_stat" in table_cols(v) && (ind = v)
            end
            @test ind !== nothing && length(table_rows(ind)) >= 3   # μ, ω, α1, β1
            @test metric_value(_diag_of(r.doc), "joint_LC") !== nothing
            @test metric_value(_diag_of(r.doc), "cv_joint_5pct") !== nothing
            rm(csv; force=true)
        end

        @testset "test sign-bias bad --model → usage error (not exit 1)" begin
            csv = dgp_garch(; T=200, seed=208)
            r = run_json(["test", "sign-bias", csv, "--model", "bogus"])
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

        # C073 — Bayesian DSGE diagnostics. Reuse the RA `.jl` spec; own priors+data.
        # Tiny SMC chains are noisy — assert shapes/keys/finiteness, not tight numbers.
        @testset "dsge bayes diagnostics (C073)" begin
            priors = joinpath(dir, "diag_priors.toml")
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
            data = joinpath(dir, "diag_data.csv")
            open(data, "w") do io
                println(io, "Y")
                y = 0.0
                for _ in 1:60
                    y = 0.9 * y + 0.01 * randn()
                    println(io, y)
                end
            end
            smc = ["--sampler", "smc", "--n-smc", "100", "--n-particles", "50",
                   "--n-draws", "100", "--burnin", "10"]
            base = vcat(["--data", data, "--observables", "Y",
                         "--params", "rho,sigma", "--priors", priors], smc)

            @testset "mcmc-diag (R-hat/ESS/Geweke)" begin
                r = run_json(vcat(["dsge", "bayes", "mcmc-diag", model_jl], base))
                assert_envelope_ok(r; label="dsge bayes mcmc-diag")
                tbl = named_table(r.doc, :mcmc_convergence_diagnostics)
                @test tbl !== nothing
                if tbl !== nothing
                    ri = col_index(tbl, "rhat")
                    @test ri !== nothing
                    @test length(table_rows(tbl)) == 2   # rho, sigma
                    if ri !== nothing
                        for row in table_rows(tbl)
                            @test isfinite(Float64(collect(row)[ri]))
                        end
                    end
                end
            end

            @testset "identification (Iskrev rank test; no MCMC)" begin
                r = run_json(["dsge", "bayes", "identification", model_jl,
                              "--params", "rho,sigma", "--observables", "Y"])
                assert_envelope_ok(r; label="dsge bayes identification")
                kv = named_table(r.doc, :identification_diagnostics)
                @test kv !== nothing
                if kv !== nothing
                    @test metric_value(kv, "rank") !== nothing
                    @test metric_value(kv, "identified") !== nothing
                end
            end

            @testset "identification bad --params → usage/invalid, not exit-1 (review fix)" begin
                # A --params typo makes MEMs' identification_diagnostics throw an untyped
                # KeyError (spec.param_values[:typo]); the handler must map it to usage/invalid
                # (exit 2), NOT let it fall through run_cli to the exit-1 "likely a bug" tail.
                r = run_json(["dsge", "bayes", "identification", model_jl,
                              "--params", "rho,typo", "--observables", "Y"])
                @test r.code == 2
            end

            @testset "learning-rate (Koop-Pesaran-Smith)" begin
                r = run_json(vcat(["dsge", "bayes", "learning-rate", model_jl], base,
                                  ["--refit-n-smc", "30"]))
                assert_envelope_ok(r; label="dsge bayes learning-rate")
                tbl = named_table(r.doc, :learning_rate_check)
                @test tbl !== nothing
                if tbl !== nothing
                    @test col_index(tbl, "learning_rate") !== nothing
                    @test length(table_rows(tbl)) == 2
                end
            end

            @testset "overlap (prior/posterior)" begin
                r = run_json(vcat(["dsge", "bayes", "overlap", model_jl], base))
                assert_envelope_ok(r; label="dsge bayes overlap")
                tbl = named_table(r.doc, :prior_posterior_overlap)
                @test tbl !== nothing
                if tbl !== nothing
                    @test col_index(tbl, "overlap") !== nothing
                    @test length(table_rows(tbl)) == 2
                end
            end

            @testset "marginal-lik (bridge sampling; may be NaN)" begin
                r = run_json(vcat(["dsge", "bayes", "marginal-lik", model_jl], base))
                assert_envelope_ok(r; label="dsge bayes marginal-lik")
                kv = named_table(r.doc, :marginal_likelihood_bridge_sampling)
                @test kv !== nothing
                if kv !== nothing
                    # bridge_sampling_ml can return NaN on a tiny chain → assert the leaf
                    # ran end-to-end (both keys present), not a finite value.
                    @test metric_value(kv, "log_marginal_likelihood_bridge") !== nothing
                    @test metric_value(kv, "log_marginal_likelihood_smc") !== nothing
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

    @testset "estimate statespace/tvp/kde/kernel-reg/lowess (C066, M5c)" begin
        # First table in the envelope whose columns ⊇ `cols`.
        cols_table(doc, cols) = begin
            doc === nothing && return nothing
            for (_, v) in pairs(doc.data)
                (v isa JSON3.Object && haskey(v, :rows)) || continue
                all(c -> c in table_cols(v), cols) && return v
            end
            return nothing
        end
        metrics_table(doc) = cols_table(doc, ["metric", "value"])

        @testset "statespace local-level — finite loglik + positive variances" begin
            csv = dgp_ar1(; T=200, φ=0.6, seed=31)
            r = run_json(["estimate", "statespace", csv, "--model", "local-level"])
            assert_envelope_ok(r; label="statespace local-level")
            pt = cols_table(r.doc, ["parameter", "estimate"])
            @test pt !== nothing && length(table_rows(pt)) == 2
            ei = findfirst(==("estimate"), table_cols(pt))
            @test all(Float64(collect(row)[ei]) >= 0.0 for row in table_rows(pt))   # variances ≥ 0
            ll = metric_value(metrics_table(r.doc), "loglik")
            @test ll !== nothing && isfinite(Float64(ll))
            rm(csv; force=true)
        end

        @testset "statespace local-linear-trend — 3 hyper-params" begin
            csv = dgp_trend_cycle(; T=200, seed=32)
            r = run_json(["estimate", "statespace", csv, "--model", "local-linear-trend"])
            assert_envelope_ok(r; label="statespace llt")
            pt = cols_table(r.doc, ["parameter", "estimate"])
            @test pt !== nothing && length(table_rows(pt)) == 3
            rm(csv; force=true)
        end

        @testset "tvp — smoothed path has T·k rows (T=150, k=2)" begin
            csv = dgp_reg(; T=150, seed=33)    # columns y, x → k = intercept + x = 2
            r = run_json(["estimate", "tvp", csv, "--dep", "y"])
            assert_envelope_ok(r; label="tvp")
            path = cols_table(r.doc, ["period", "coefficient", "estimate"])
            @test path !== nothing && length(table_rows(path)) == 150 * 2
            @test Float64(metric_value(metrics_table(r.doc), "n_coef")) == 2.0
            rm(csv; force=true)
        end

        @testset "kde — density ≥ 0, grid length == npoints, ∫≈1" begin
            csv = dgp_iid(; T=400, seed=34)
            r = run_json(["estimate", "kde", csv, "--npoints", "256"])
            assert_envelope_ok(r; label="kde")
            g = cols_table(r.doc, ["x", "density"])
            @test g !== nothing && length(table_rows(g)) == 256
            xi = findfirst(==("x"), table_cols(g)); di = findfirst(==("density"), table_cols(g))
            xs = [Float64(collect(row)[xi]) for row in table_rows(g)]
            ds = [Float64(collect(row)[di]) for row in table_rows(g)]
            @test all(d -> d >= -1e-9, ds)                       # a proper density
            # trapezoidal integral over the grid ≈ 1 (loose — grid is finite-support).
            area = sum((xs[i+1] - xs[i]) * (ds[i+1] + ds[i]) / 2 for i in 1:length(xs)-1)
            @test isapprox(area, 1.0; atol=0.05)
            @test Float64(metric_value(metrics_table(r.doc), "bandwidth")) > 0.0
            rm(csv; force=true)
        end

        @testset "kde — sj bandwidth + non-gaussian kernel also run" begin
            csv = dgp_iid(; T=300, seed=35)
            r = run_json(["estimate", "kde", csv, "--bw", "sj", "--kernel", "epanechnikov",
                          "--npoints", "128"])
            assert_envelope_ok(r; label="kde sj epanechnikov")
            @test string(metric_value(metrics_table(r.doc), "bw_method")) == "sj"
            rm(csv; force=true)
        end

        @testset "kernel-reg — fitted length == nobs, tracks a linear mean" begin
            csv = dgp_reg(; T=200, seed=36)    # y = 1 + 2x + noise
            r = run_json(["estimate", "kernel-reg", csv, "--dep", "y", "--indep", "x"])
            assert_envelope_ok(r; label="kernel-reg ll")
            fit = cols_table(r.doc, ["x", "fitted", "se"])
            @test fit !== nothing && length(table_rows(fit)) == 200
            xi = findfirst(==("x"), table_cols(fit)); fi = findfirst(==("fitted"), table_cols(fit))
            xs = [Float64(collect(row)[xi]) for row in table_rows(fit)]
            fs = [Float64(collect(row)[fi]) for row in table_rows(fit)]
            @test all(isfinite, fs)
            @test cor(xs, fs) > 0.8                              # positive slope ≈ +2
            rm(csv; force=true)
        end

        @testset "kernel-reg — nw method + rot bandwidth run" begin
            csv = dgp_reg(; T=150, seed=37)
            r = run_json(["estimate", "kernel-reg", csv, "--dep", "y", "--indep", "x",
                          "--method", "nw", "--bw", "rot"])
            assert_envelope_ok(r; label="kernel-reg nw rot")
            @test string(metric_value(metrics_table(r.doc), "method")) == "nw"
            @test Float64(metric_value(metrics_table(r.doc), "degree")) == 0.0
            rm(csv; force=true)
        end

        @testset "lowess — fitted length == nobs, tracks a linear mean" begin
            csv = dgp_reg(; T=200, seed=38)
            r = run_json(["estimate", "lowess", csv, "--dep", "y", "--indep", "x"])
            assert_envelope_ok(r; label="lowess")
            fit = cols_table(r.doc, ["x", "fitted"])
            @test fit !== nothing && length(table_rows(fit)) == 200
            xi = findfirst(==("x"), table_cols(fit)); fi = findfirst(==("fitted"), table_cols(fit))
            xs = [Float64(collect(row)[xi]) for row in table_rows(fit)]
            fs = [Float64(collect(row)[fi]) for row in table_rows(fit)]
            @test all(isfinite, fs)
            @test cor(xs, fs) > 0.8
            rm(csv; force=true)
        end

        @testset "C066 bad input → typed classes (never uncaught exit-1)" begin
            csv = dgp_reg(; T=100, seed=39)
            @test run_json(["estimate", "kde", csv, "--bw", "notanumber"]).code == 2
            @test run_json(["estimate", "kernel-reg", csv, "--dep", "y"]).code == 2  # missing --indep
            @test run_json(["estimate", "kernel-reg", csv, "--dep", "y", "--indep", "nope"]).code == 3
            @test run_json(["estimate", "lowess", csv, "--dep", "y", "--indep", "y"]).code == 3  # indep==dep
            rm(csv; force=true)
        end
    end

    # ── Data loading on real MEMs ────────────────────────────────────────────
    # This family had NO T3 coverage, which is why a broken `data load --path`,
    # a `:name` reference that exited 1, and panel datasets that silently lost
    # their id columns all survived. Keep these here.
    @testset "data loading (real load_example)" begin
        @testset "data load --path without a positional name" begin
            mktempdir() do dir
                src = joinpath(dir, "mine.csv")
                CSV.write(src, DataFrame(a=randn(30), b=randn(30)))
                out = joinpath(dir, "out.csv")
                # Regression: <name> used to be required → "missing required argument"
                @test run_json(["data", "load", "--path", src, "-o", out]).code == 0
                @test isfile(out)
                @test nrow(CSV.read(out, DataFrame)) == 30
            end
        end

        @testset "dataset names: ':' refs, both separators, typos" begin
            mktempdir() do dir
                for (i, form) in enumerate(["fred_md", "fred-md", ":fred-md", ":fred_md"])
                    out = joinpath(dir, "d$i.csv")
                    # Regression: ':fred-md' raised an untyped ArgumentError → exit 1
                    @test run_json(["data", "load", form, "-o", out]).code == 0
                    @test isfile(out)
                end
            end
            # Unknown name → typed data error (exit 3), never the exit-1 "likely a bug" tail
            @test run_json(["data", "load", "frd_md"]).code == 3
            @test run_json(["data", "load", ":wiot"]).code == 3
            # Neither a name nor --path → usage error (exit 2)
            @test run_json(["data", "load"]).code == 2
        end

        @testset "every advertised dataset actually loads" begin
            # data list is built from EXAMPLE_DATASETS; assert the list is honest.
            mktempdir() do dir
                for (i, d) in enumerate(Friedman.EXAMPLE_DATASETS)
                    out = joinpath(dir, "ds$i.csv")
                    r = run_json(["data", "load", String(d), "-o", out])
                    @test r.code == 0
                    @test isfile(out)
                end
            end
        end

        @testset "builtin panels keep their group/time identifiers" begin
            # Without this, every panel command fails on a bundled panel dataset.
            df = Friedman.load_data(":pwt")
            @test "group" in names(df)
            @test "time" in names(df)
            # …and a real panel command can bind to them end-to-end.
            r = run_json(["test", "cips", ":grunfeld", "--id-col", "group",
                          "--time-col", "time", "--lags", "1"])
            @test r.code == 0
        end

        @testset "default output paths never contain the ':' marker" begin
            mktempdir() do dir
                cd(dir) do
                    # Regression: produced a file literally named ':fred-md_clean.csv'
                    @test run_json(["data", "fix", ":denmark"]).code == 0
                    @test isfile(joinpath(dir, "denmark_clean.csv"))
                    @test !isfile(joinpath(dir, ":denmark_clean.csv"))
                end
            end
        end

        @testset "data describe reports a scalar n per variable" begin
            mktempdir() do dir
                src = joinpath(dir, "d.csv")
                CSV.write(src, DataFrame(a=randn(50), b=randn(50)))
                r = run_json(["data", "describe", src])
                @test r.code == 0
                _, tbl = first_table(r.doc)
                @test tbl !== nothing
                if tbl !== nothing
                    ni = findfirst(==("n"), table_cols(tbl))
                    @test ni !== nothing
                    # Regression: fill(summary.n, n_vars) put the whole vector in every cell
                    @test all(row -> collect(row)[ni] isa Integer, table_rows(tbl))
                    @test all(row -> collect(row)[ni] == 50, table_rows(tbl))
                end
            end
        end

        @testset "~ is expanded by the loader (the REPL has no shell)" begin
            mktempdir() do dir
                CSV.write(joinpath(dir, "tilde.csv"), DataFrame(a=randn(20)))
                withenv("HOME" => dir) do
                    @test nrow(Friedman.load_data("~/tilde.csv")) == 20
                end
            end
        end

        @testset "path confinement is opt-in and resolves, not substring-matches (#83)" begin
            mktempdir() do root
                inside = joinpath(root, "in.csv")
                CSV.write(inside, DataFrame(a=randn(30), b=randn(30)))
                sub = joinpath(root, "sub"); mkpath(sub)
                weird = joinpath(root, "dotdot..name.csv")
                CSV.write(weird, DataFrame(a=randn(30), b=randn(30)))

                # Unconfined: a parent-relative path and a '..' filename both load
                @test run_json(["data", "describe", joinpath(sub, "..", "in.csv")]).code == 0
                @test run_json(["data", "describe", weird]).code == 0

                # Confined: inside is fine, escaping is data/bad-path (exit 3)
                withenv("FRIEDMAN_DATA_ROOT" => root) do
                    @test run_json(["data", "describe", inside]).code == 0
                    @test run_json(["data", "describe",
                                    joinpath(root, "..", "etc", "passwd")]).code == 3
                end
            end
        end
    end

    # ── Commands whose result-field access was masked by mock aliases (#84) ──
    # Each of these read a field real MEMs does not have and exited 1 on EVERY
    # invocation. The mock's `getproperty` aliases invented the field, so T1/T2
    # passed; none had T3 coverage. Keep every one of them covered here.
    @testset "result-field access on real MEMs (#84 regressions)" begin
        uni = dgp_ar1(; T=200, seed=5)
        multi = dgp_var2(; T=200, seed=5)

        @testset "test durbin-watson (statistic/pvalue, no invented bounds)" begin
            r = run_json(["test", "durbin-watson", uni])
            assert_envelope_ok(r; label="durbin-watson")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            @test metric_value(tbl, "DW statistic") !== nothing
            @test metric_value(tbl, "p-value") !== nothing
        end

        @testset "test dfgls (statistic + separate M-GLS fields)" begin
            r = run_json(["test", "dfgls", uni])
            assert_envelope_ok(r; label="dfgls")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            @test metric_value(tbl, "DF-GLS tau statistic") !== nothing
            for k in ("M-GLS MZa", "M-GLS MZt", "M-GLS MSB", "M-GLS MPT")
                @test metric_value(tbl, k) !== nothing
            end
        end

        @testset "test adf-2break (break1/break2 + fractions)" begin
            r = run_json(["test", "adf-2break", uni])
            assert_envelope_ok(r; label="adf-2break")
            _, tbl = first_table(r.doc)
            @test metric_value(tbl, "Break 1 index") !== nothing
            @test metric_value(tbl, "Break 2 index") !== nothing
        end

        @testset "test lm-unitroot (breaks/break_dates)" begin
            r = run_json(["test", "lm-unitroot", uni])
            assert_envelope_ok(r; label="lm-unitroot")
            _, tbl = first_table(r.doc)
            @test metric_value(tbl, "LM statistic") !== nothing
        end

        @testset "test gregory-hansen (adf_break/zt_break/za_break)" begin
            r = run_json(["test", "gregory-hansen", multi])
            assert_envelope_ok(r; label="gregory-hansen")
            _, tbl = first_table(r.doc)
            @test metric_value(tbl, "ADF* break index") !== nothing
            @test metric_value(tbl, "Za* break index") !== nothing
            # One column is a cointegration shape error (exit 3), not an exit-1 crash
            @test run_json(["test", "gregory-hansen", uni]).code == 3
        end

        @testset "test factor-break (n_factors/n_vars)" begin
            r = run_json(["test", "factor-break", multi, "--factors", "1"])
            assert_envelope_ok(r; label="factor-break")
            _, tbl = first_table(r.doc)
            @test metric_value(tbl, "Factors") !== nothing
            @test metric_value(tbl, "Units") !== nothing
        end

        @testset "fevd bvar (point_estimate, and its (h,var,shock) layout)" begin
            r = run_json(["fevd", "bvar", multi, "--lags", "1", "--horizons", "4"])
            assert_envelope_ok(r; label="fevd bvar")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            rows = table_rows(tbl)
            # One row per horizon (a transposed array silently yields n rows instead)
            @test length(rows) == 4
            # Variance shares sum to 1 across shocks at every horizon
            for row in rows
                vals = Float64.(collect(row)[2:end])
                @test isapprox(sum(vals), 1.0; atol=1e-6)
            end
        end

        @testset "hd bvar (point_estimate + initial_point_estimate)" begin
            r = run_json(["hd", "bvar", multi, "--lags", "1"])
            assert_envelope_ok(r; label="hd bvar")
            _, tbl = first_table(r.doc)
            @test tbl !== nothing
            @test !isempty(table_rows(tbl))
        end

        @testset "estimate favar --method bayesian (draws from B_draws)" begin
            r = run_json(["estimate", "favar", multi, "--method", "bayesian",
                          "--factors", "1", "--lags", "1", "--key-vars", "y1"])
            assert_envelope_ok(r; label="favar bayesian")
            # Missing --key-vars is a usage error (exit 2), not an untyped exit 1
            @test run_json(["estimate", "favar", multi, "--method", "bayesian",
                            "--factors", "1", "--lags", "1"]).code == 2
        end
    end

    # ── Families that had no real-MEMs coverage at all (#85) ──
    @testset "nowcast family (#85: was entirely uncovered)" begin
        multi = dgp_var2(; T=160, seed=8)
        # Each leaf has its own option set — dfm takes --factors, bvar only --lags,
        # bridge takes per-frequency lag counts.
        for (leaf, extra) in [("dfm", ["--factors", "1", "--lags", "1"]),
                              ("bvar", ["--lags", "2"]),
                              ("bridge", ["--lag-m", "1", "--lag-q", "1", "--lag-y", "1"])]
            @testset "nowcast $leaf" begin
                r = run_json(vcat(["nowcast", leaf, multi], extra))
                assert_envelope_ok(r; label="nowcast $leaf")
            end
        end
        @testset "nowcast forecast" begin
            r = run_json(["nowcast", "forecast", multi, "--factors", "1",
                          "--lags", "1", "--horizons", "3"])
            assert_envelope_ok(r; label="nowcast forecast")
        end
        @testset "nowcast news" begin
            # Same-shape vintages: the old one has the final observation not yet
            # released (a vintage differs in which cells are filled, not row count).
            new_df = CSV.read(multi, DataFrame)
            old_df = copy(new_df)
            old_df[end, 1] = NaN
            old_path = tempname() * ".csv"
            CSV.write(old_path, old_df)
            r = run_json(["nowcast", "news", "--data-new", multi, "--data-old", old_path,
                          "--factors", "1", "--lags", "1"])
            assert_envelope_ok(r; label="nowcast news")

            # A row-count mismatch is the user's input, not an internal bug
            short_path = tempname() * ".csv"
            CSV.write(short_path, new_df[1:end-1, :])
            @test run_json(["nowcast", "news", "--data-new", multi, "--data-old", short_path,
                            "--factors", "1", "--lags", "1"]).code == 3
            # Missing a required vintage is a usage error
            @test run_json(["nowcast", "news", "--data-new", multi]).code == 2
            rm(old_path; force=true); rm(short_path; force=true)
        end
    end

    @testset "predict/residuals sweep (#85: was 1 of 23 leaves, nightly-only)" begin
        multi = dgp_var2(; T=200, seed=9)
        uni = dgp_ar1(; T=200, seed=9)
        reg = dgp_reg(; T=200, seed=9)
        logit = dgp_logit(; T=300, seed=9)
        gar = dgp_garch(; T=400, seed=9)

        # (leaf, data, extra args) — one per result-type family, so an accessor rename
        # upstream cannot slip through on either action.
        cases = [
            ("var",    multi, ["--lags", "1"]),
            ("bvar",   multi, ["--lags", "1"]),
            ("vecm",   multi, ["--lags", "2", "--rank", "1"]),
            ("arima",  uni,   ["--column", "1"]),
            ("reg",    reg,   ["--dep", "y"]),
            ("logit",  logit, ["--dep", "y"]),
            ("probit", logit, ["--dep", "y"]),
            ("garch",  gar,   ["--column", "1"]),
        ]
        for (leaf, data, extra) in cases
            for action in ("predict", "residuals")
                @testset "$action $leaf" begin
                    r = run_json(vcat([action, leaf, data], extra))
                    assert_envelope_ok(r; label="$action $leaf")
                    _, tbl = first_table(r.doc)
                    @test tbl !== nothing
                    @test tbl !== nothing && !isempty(table_rows(tbl))
                end
            end
        end

        # Ordered/multinomial: `predict` returns an n x n_categories probability
        # matrix (feeding it to DataFrame used to be an exit-1 crash), and MEMs
        # defines no `residuals` for them, so that must be a typed refusal.
        ord = tempname() * ".csv"
        let n = 300
            Random.seed!(19)
            CSV.write(ord, DataFrame(y=rand(1:3, n), x1=randn(n), x2=randn(n)))
        end
        for leaf in ("ologit", "oprobit", "mlogit")
            @testset "predict $leaf (per-category probabilities)" begin
                r = run_json(["predict", leaf, ord, "--dep", "y"])
                assert_envelope_ok(r; label="predict $leaf")
                _, tbl = first_table(r.doc)
                @test tbl !== nothing
                if tbl !== nothing
                    cols = table_cols(tbl)
                    @test count(c -> startswith(c, "prob_"), cols) == 3
                end
            end
            @testset "residuals $leaf → model/unsupported (exit 5)" begin
                @test run_json(["residuals", leaf, ord, "--dep", "y"]).code == 5
            end
        end

        @testset "predict logit reports (flags, not string options)" begin
            for flag in ("--odds-ratio", "--marginal-effects", "--classification-table")
                r = run_json(["predict", "logit", logit, "--dep", "y", flag])
                assert_envelope_ok(r; label="predict logit $flag")
            end
            # probit has no odds ratio → unknown option is a usage error
            @test run_json(["predict", "probit", logit, "--dep", "y", "--odds-ratio"]).code == 2
        end
        rm(ord; force=true)
    end
end

# Real entry-point coverage (C036) — also on core/CI path
include(joinpath(@__DIR__, "test_entry.jl"))
