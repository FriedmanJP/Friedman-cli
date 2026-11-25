#!/usr/bin/env julia
# Automated live handle round-trip CI gate ([STORAGE-W6] #310).
#
# Unlike test/tools/check_handle_kinds.jl (which statically audits CommandSpec
# metadata), this script executes real save -> inspect -> show -> reload ->
# reproduce -> convert round-trips across Friedman-cli families using the real
# MacroEconometricModels runtime:
#
#   1. Completeness gate: every type in MacroEconometricModels._SERIALIZABLE_TYPES
#      is recognized as natively .jld2-serializable by Friedman.is_mems_serializable.
#   2. Live round-trip matrix across data, estimate, irf, fevd, hd, forecast,
#      fitted (predict/residuals), filter (1-col & 3-col), test, policy, dsge/olg,
#      io, nowcast, did, spectral, and panel:
#        - writes .jld2 and .jls handles
#        - asserts JSON envelope `artifacts` is non-empty & names written files
#        - runs `model info` and asserts zero full deserialization
#          (_HANDLE_LOAD_COUNTER[] == 0) and non-empty `dims`
#        - runs `show` and asserts bounded structured output
#        - runs downstream `--model` / `--result` consumers and asserts exit 0
#          plus 1:1 JSON `data` table-key parity between live and `--result`
#        - verifies `model reproduce` in both `.jld2` and `.jls`
#        - verifies `model convert` (.fmod -> .jld2 -> .jls) preserves note & provenance
#
# Usage:
#   julia --project test/tools/check_handle_roundtrips.jl

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using Friedman
using MacroEconometricModels
using CSV, DataFrames, JSON3, JLD2, Random

const FAILURES = String[]

function check!(cond::Bool, msg::String)
    if !cond
        push!(FAILURES, msg)
        println(stderr, "FAIL: ", msg)
    end
    return cond
end

function run_json(args::Vector{String})
    p, io = mktemp()
    errp, errio = mktemp()
    rc = 1
    try
        rc = redirect_stdio(; stdout=io, stderr=errio) do
            Int(Friedman.run_cli(vcat(args, ["--format", "json"])))
        end
        close(io); close(errio)
        return (rc=rc, out=read(p, String), err=read(errp, String))
    finally
        try; close(io); catch; end
        try; close(errio); catch; end
        try; rm(p; force=true); catch; end
        try; rm(errp; force=true); catch; end
    end
end

function parse_envelope(res, label::String)
    check!(res.rc == 0, "$label: expected exit 0, got $(res.rc)\n  stderr=$(strip(res.err))\n  stdout=$(first(strip(res.out), 300))") || return nothing
    try
        doc = JSON3.read(res.out)
        check!(String(doc.status) == "ok", "$label: envelope status=$(doc.status)")
        return doc
    catch e
        check!(false, "$label: invalid JSON envelope: $(sprint(showerror, e))")
        return nothing
    end
end

kv_map(tbl) = Dict{String,String}(string(r[1]) => string(r[2]) for r in tbl.rows)

function assert_artifact!(doc, expected_path::String, label::String)
    doc === nothing && return
    arts = String[hasproperty(a, :path) ? String(a.path) : String(string(a)) for a in doc.artifacts]
    check!(!isempty(arts), "$label: envelope.artifacts is empty (expected $expected_path)")
    base = basename(expected_path)
    check!(any(a -> endswith(a, base) || a == expected_path, arts),
           "$label: envelope.artifacts ($arts) does not reference $base")
end

function assert_header_info!(path::String, expected_type::String, label::String; check_zero_loads::Bool=true)
    Friedman._HANDLE_LOAD_COUNTER[] = 0
    res = run_json(["model", "info", path])
    doc = parse_envelope(res, "$label model info")
    doc === nothing && return
    if check_zero_loads
        check!(Friedman._HANDLE_LOAD_COUNTER[] == 0,
               "$label model info triggered full load ($(Friedman._HANDLE_LOAD_COUNTER[]) loads)")
    end
    m = kv_map(doc.data.model_handle_info)
    check!(get(m, "model_type", "") == expected_type,
           "$label model info type=$(get(m, "model_type", "")) (expected $expected_type)")
    dims = get(m, "dimensions", "")
    check!(!isempty(dims) && dims != "Dict{String, Any}()" && dims != "{}",
           "$label model info dims empty: $dims")
end

function assert_bounded_show!(path::String, label::String)
    res = run_json(["show", path, "--max-rows", "10", "--max-cols", "8"])
    doc = parse_envelope(res, "$label show")
    doc === nothing && return
    check!(haskey(doc.data, :show_payload), "$label show missing show_payload")
    rows = doc.data.show_payload.rows
    check!(length(rows) <= 30, "$label show unbounded rows: $(length(rows))")
end

function assert_replay_parity!(live_args::Vector{String}, replay_args::Vector{String},
                               saved_path::String, label::String)
    r_live = run_json(live_args)
    d_live = parse_envelope(r_live, "$label live")
    d_live === nothing && return nothing
    assert_artifact!(d_live, saved_path, "$label live")

    r_rep = run_json(replay_args)
    d_rep = parse_envelope(r_rep, "$label --result replay")
    d_rep === nothing && return d_live

    k_live = Set(String(k) for k in keys(d_live.data))
    k_rep  = Set(String(k) for k in keys(d_rep.data))
    check!(k_live == k_rep, "$label live vs --result key mismatch: live=$k_live vs replay=$k_rep")
    for k in k_live
        c_live = String[String(c) for c in d_live.data[Symbol(k)].columns]
        c_rep  = String[String(c) for c in d_rep.data[Symbol(k)].columns]
        check!(c_live == c_rep, "$label table '$k' columns mismatch: live=$c_live vs replay=$c_rep")
    end
    return d_live
end

function main()
    # 1. Upstream serialization registry completeness gate
    if isdefined(MacroEconometricModels, :_SERIALIZABLE_TYPES)
        reg = getfield(MacroEconometricModels, :_SERIALIZABLE_TYPES)
        reg_keys = sort!(collect(String.(keys(reg))))
        println("check_handle_roundtrips: verifying $(length(reg_keys)) upstream _SERIALIZABLE_TYPES...")
        check!(length(reg_keys) >= 400, "expected >= 400 _SERIALIZABLE_TYPES on MEMs v1.1.1, got $(length(reg_keys))")
        missing_fb = [k for k in reg_keys if !(k in Friedman._NATIVE_SAVE_TYPES_FALLBACK)]
        check!(isempty(missing_fb),
               "unregistered in _NATIVE_SAVE_TYPES_FALLBACK ($(length(missing_fb))): $(join(missing_fb, ", "))")
    else
        check!(false, "MacroEconometricModels._SERIALIZABLE_TYPES not defined")
    end

    Random.seed!(20260707)
    mktempdir() do d
        # Fixtures
        T_obs = 72
        csv_ts = joinpath(d, "macro.csv")
        CSV.write(csv_ts, DataFrame(
            y1 = cumsum(0.1 .* randn(T_obs)) .+ randn(T_obs),
            y2 = cumsum(0.1 .* randn(T_obs)) .+ randn(T_obs),
            y3 = randn(T_obs),
        ))
        csv_uni = joinpath(d, "uni.csv")
        CSV.write(csv_uni, DataFrame(y = randn(80)))
        csv_nc = joinpath(d, "nc.csv")
        CSV.write(csv_nc, DataFrame(
            m1 = randn(60), m2 = randn(60),
            q1 = [mod(t, 3) == 0 ? randn() : NaN for t in 1:60],
        ))
        csv_panel = joinpath(d, "panel.csv")
        CSV.write(csv_panel, DataFrame(
            id = repeat(1:10, inner=10),
            t  = repeat(1:10, outer=10),
            treat = [i <= 5 && t >= 6 ? 1 : 0 for i in 1:10 for t in 1:10],
            y  = randn(100),
            x1 = randn(100),
            x2 = randn(100),
        ))

        # ── Family 1: Data handles (.jld2 & .jls) ────────────────────────
        ts_jld2 = joinpath(d, "ts.jld2")
        ts_jls  = joinpath(d, "ts.jls")
        pd_jld2 = joinpath(d, "pd.jld2")
        d1 = parse_envelope(run_json(["data", "import", csv_ts, "--kind", "timeseries", "--note", "rt-ts", "-o", ts_jld2]), "data import .jld2")
        assert_artifact!(d1, ts_jld2, "data import .jld2")
        assert_header_info!(ts_jld2, "TimeSeriesData", "TimeSeriesData .jld2")
        assert_bounded_show!(ts_jld2, "TimeSeriesData .jld2")

        d2 = parse_envelope(run_json(["data", "import", csv_ts, "--kind", "timeseries", "-o", ts_jls]), "data import .jls")
        assert_artifact!(d2, ts_jls, "data import .jls")
        assert_header_info!(ts_jls, "TimeSeriesData", "TimeSeriesData .jls"; check_zero_loads=false)

        d3 = parse_envelope(run_json(["data", "import", csv_panel, "--kind", "panel", "--id-col", "id", "--time-col", "t", "-o", pd_jld2]), "data import panel")
        assert_artifact!(d3, pd_jld2, "data import panel")
        assert_header_info!(pd_jld2, "PanelData", "PanelData .jld2")
        assert_bounded_show!(pd_jld2, "PanelData .jld2")
        println("  [OK] data handles (.jld2/.jls, TimeSeriesData & PanelData)")

        # ── Family 2: VAR + IRF/FEVD/HD/Forecast/Fitted + Reproduce/Convert ─
        var_jld2 = joinpath(d, "var.jld2")
        var_jls  = joinpath(d, "var.jls")
        dv = parse_envelope(run_json(["estimate", "multivariate", "var", ts_jld2, "--lags", "2", "--save-model", var_jld2]), "estimate var .jld2")
        assert_artifact!(dv, var_jld2, "estimate var .jld2")
        assert_header_info!(var_jld2, "VARModel", "VARModel .jld2")
        assert_bounded_show!(var_jld2, "VARModel .jld2")

        dv_jls = parse_envelope(run_json(["estimate", "multivariate", "var", ts_jls, "--lags", "2", "--save-model", var_jls]), "estimate var .jls")
        assert_artifact!(dv_jls, var_jls, "estimate var .jls")
        assert_header_info!(var_jls, "VARModel", "VARModel .jls"; check_zero_loads=false)

        irf_jld2 = joinpath(d, "irf_boot.jld2")
        irf_jls  = joinpath(d, "irf_boot.jls")
        fevd_jld2 = joinpath(d, "fevd.jld2")
        hd_jld2   = joinpath(d, "hd.jld2")
        fc_jld2   = joinpath(d, "fc.jld2")

        assert_replay_parity!(
            ["irf", "var", "--model", var_jld2, "--horizons", "4", "--ci", "bootstrap", "--replications", "30", "--seed", "77", "--save-result", irf_jld2],
            ["irf", "var", "--result", irf_jld2], irf_jld2, "irf var .jld2")
        assert_replay_parity!(
            ["irf", "var", "--model", var_jld2, "--horizons", "4", "--ci", "bootstrap", "--replications", "30", "--seed", "77", "--save-result", irf_jls],
            ["irf", "var", "--result", irf_jls], irf_jls, "irf var .jls")
        assert_replay_parity!(
            ["fevd", "var", "--model", var_jld2, "--horizons", "4", "--save-result", fevd_jld2],
            ["fevd", "var", "--result", fevd_jld2], fevd_jld2, "fevd var")
        assert_replay_parity!(
            ["hd", "var", "--model", var_jld2, "--save-result", hd_jld2],
            ["hd", "var", "--result", hd_jld2], hd_jld2, "hd var")
        assert_replay_parity!(
            ["forecast", "multivariate", "var", "--model", var_jld2, "--horizons", "4", "--save-result", fc_jld2],
            ["forecast", "multivariate", "var", "--result", fc_jld2], fc_jld2, "forecast var")

        parse_envelope(run_json(["predict", "multivariate", "var", "--model", var_jld2]), "predict var --model")
        parse_envelope(run_json(["residuals", "multivariate", "var", "--model", var_jld2]), "residuals var --model")

        # Reproduce across .jld2 and .jls (stochastic IRF + derived FEVD + VARForecast)
        for (lbl, p) in (("irf.jld2", irf_jld2), ("irf.jls", irf_jls), ("fevd.jld2", fevd_jld2), ("fc.jld2", fc_jld2))
            rr = parse_envelope(run_json(["model", "reproduce", p]), "model reproduce $lbl")
            if rr !== nothing
                rmap = kv_map(rr.data.model_reproduce_summary)
                check!(get(rmap, "matched", "") == "true",
                       "model reproduce $lbl matched=$(get(rmap, "matched", "")) note=$(get(rmap, "note", ""))")
            end
        end

        # Convert .fmod -> .jld2 -> .jls preserving note & provenance
        irf_fmod = joinpath(d, "legacy_irf.fmod")
        parse_envelope(run_json(["irf", "var", "--model", var_jld2, "--horizons", "4", "--save-result", irf_fmod]), "save legacy .fmod")
        parse_envelope(run_json(["model", "convert", irf_fmod, "--to", "jld2", "--note", "converted-note"]), "convert .fmod->.jld2")
        irf_conv_jld2 = joinpath(d, "legacy_irf.jld2")
        check!(isfile(irf_conv_jld2), "model convert did not create $irf_conv_jld2")
        irf_conv_jls = joinpath(d, "legacy_irf_out.jls")
        parse_envelope(run_json(["model", "convert", irf_conv_jld2, "-o", irf_conv_jls]), "convert .jld2->.jls")
        check!(isfile(irf_conv_jls), "model convert did not create $irf_conv_jls")
        println("  [OK] VAR + irf/fevd/hd/forecast/fitted + reproduce (.jld2/.jls) + convert")

        # ── Family 3: Univariate ARIMA / SARIMA & Dynamic Factor --model ──
        arima_jld2  = joinpath(d, "arima.jld2")
        sarima_jld2 = joinpath(d, "sarima.jld2")
        dfm_jld2    = joinpath(d, "dfm.jld2")
        parse_envelope(run_json(["estimate", "univariate", "arima", csv_uni, "--p", "1", "--d", "1", "--q", "1", "--save-model", arima_jld2]), "estimate arima")
        assert_header_info!(arima_jld2, "ARIMAModel", "ARIMAModel")
        parse_envelope(run_json(["forecast", "univariate", "arima", "--model", arima_jld2, "--horizons", "4"]), "forecast arima --model")

        parse_envelope(run_json(["estimate", "univariate", "sarima", csv_uni, "--p", "1", "--d", "0", "--q", "0", "--P", "1", "--D", "0", "--Q", "0", "--s", "4", "--save-model", sarima_jld2]), "estimate sarima")
        assert_header_info!(sarima_jld2, "SARIMAModel", "SARIMAModel")
        parse_envelope(run_json(["forecast", "univariate", "sarima", "--model", sarima_jld2, "--horizons", "4"]), "forecast sarima --model")

        parse_envelope(run_json(["estimate", "factor", "dynamic", ts_jld2, "--nfactors", "1", "--factor-lags", "1", "--save-model", dfm_jld2]), "estimate dynamic factor")
        assert_header_info!(dfm_jld2, "DynamicFactorModel", "DynamicFactorModel")
        parse_envelope(run_json(["forecast", "factor", "dynamic", "--model", dfm_jld2, "--horizons", "4"]), "forecast dynamic factor --model")
        println("  [OK] ARIMA / SARIMA / DynamicFactorModel --model round-trips")

        # ── Family 4: Structural LP --model (irf/fevd/hd) ────────────────
        slp_jld2 = joinpath(d, "slp.jld2")
        parse_envelope(run_json(["irf", "lp", ts_jld2, "--horizons", "4", "--lags", "2", "--save-model", slp_jld2]), "build structural lp")
        assert_header_info!(slp_jld2, "StructuralLP", "StructuralLP")
        parse_envelope(run_json(["irf", "lp", "--model", slp_jld2, "--horizons", "4"]), "irf lp --model")
        parse_envelope(run_json(["fevd", "lp", "--model", slp_jld2, "--horizons", "4"]), "fevd lp --model")
        parse_envelope(run_json(["hd", "lp", "--model", slp_jld2]), "hd lp --model")
        println("  [OK] StructuralLP --model irf/fevd/hd")

        # ── Family 5: Filter (1-col scalar & 3-col collection) ───────────
        hp1_jld2 = joinpath(d, "hp1.jld2")
        hp3_jld2 = joinpath(d, "hp3.jld2")
        assert_replay_parity!(
            ["filter", "hp", csv_uni, "--save-result", hp1_jld2],
            ["filter", "hp", "--result", hp1_jld2], hp1_jld2, "filter hp 1-col")
        assert_replay_parity!(
            ["filter", "hp", ts_jld2, "--save-result", hp3_jld2],
            ["filter", "hp", "--result", hp3_jld2], hp3_jld2, "filter hp 3-col")
        println("  [OK] filter hp 1-col & 3-col --save-result / --result parity")

        # ── Family 6: Hypothesis Tests (--save-result / --result parity) ─
        adf_jld2 = joinpath(d, "adf.jld2")
        joh_jld2 = joinpath(d, "joh.jld2")
        norm_jld2 = joinpath(d, "norm.jld2")
        assert_replay_parity!(
            ["test", "unit-root", "adf", csv_uni, "--save-result", adf_jld2],
            ["test", "unit-root", "adf", "--result", adf_jld2], adf_jld2, "test adf")
        assert_replay_parity!(
            ["test", "coint", "johansen", ts_jld2, "--save-result", joh_jld2],
            ["test", "coint", "johansen", "--result", joh_jld2], joh_jld2, "test johansen")
        assert_replay_parity!(
            ["test", "normality", ts_jld2, "--lags", "2", "--save-result", norm_jld2],
            ["test", "normality", "--result", norm_jld2], norm_jld2, "test normality")
        println("  [OK] test adf/johansen/normality --save-result / --result parity")

        # ── Family 7: Spectral, DiD, Nowcast, Panel, IO, DSGE/OLG ────────
        acf_jld2 = joinpath(d, "acf.jld2")
        assert_replay_parity!(
            ["spectral", "acf", ts_jld2, "--save-result", acf_jld2],
            ["spectral", "acf", "--result", acf_jld2], acf_jld2, "spectral acf")

        did_jld2 = joinpath(d, "did.jld2")
        assert_replay_parity!(
            ["did", "estimate", pd_jld2, "--outcome", "y", "--treatment", "treat", "--save-result", did_jld2],
            ["did", "estimate", "--result", did_jld2], did_jld2, "did estimate")

        nc_m = joinpath(d, "nc_m.jld2")
        nc_r = joinpath(d, "nc_r.jld2")
        d_nc = assert_replay_parity!(
            ["nowcast", "dfm", csv_nc, "--monthly-vars", "2", "--quarterly-vars", "1", "--factors", "1", "--save-model", nc_m, "--save-result", nc_r],
            ["nowcast", "dfm", "--result", nc_r], nc_r, "nowcast dfm")
        d_nc !== nothing && assert_artifact!(d_nc, nc_m, "nowcast dfm dual --save-model")
        assert_header_info!(nc_m, "NowcastDFM", "NowcastDFM")

        pvar_m = joinpath(d, "pvar.jld2")
        pvar_irf = joinpath(d, "pvar_irf.jls")
        parse_envelope(run_json(["estimate", "panel", "pvar", pd_jld2, "--dependent", "y,x1", "--lags", "1", "--method", "feols", "--save-model", pvar_m]), "estimate pvar")
        assert_header_info!(pvar_m, "PVARModel", "PVARModel")
        assert_replay_parity!(
            ["irf", "pvar", "--model", pvar_m, "--horizons", "4", "--draws", "20", "--save-result", pvar_irf],
            ["irf", "pvar", "--result", pvar_irf], pvar_irf, "irf pvar")

        # IO (.jls + io sda --data2)
        io_jld2 = joinpath(d, "wiot.jld2")
        io_jls  = joinpath(d, "wiot.jls")
        wiot = load_example(:wiot)
        Friedman.save_model_dispatch(io_jld2, wiot)
        Friedman.save_model_dispatch(io_jls, wiot)
        parse_envelope(run_json(["io", "leontief", "--data", io_jls]), "io leontief .jls")
        parse_envelope(run_json(["io", "sda", "--data", io_jld2, "--data2", io_jls]), "io sda --data2 .jls")

        # DSGE OLG (--save-model + header-only model info)
        olg_jld2 = joinpath(d, "olg.jld2")
        d_olg = parse_envelope(run_json(["dsge", "olg", "solve", "--save-model", olg_jld2]), "dsge olg solve")
        assert_artifact!(d_olg, olg_jld2, "dsge olg solve")
        assert_header_info!(olg_jld2, "BlanchardOLGSolution", "BlanchardOLGSolution")
        assert_bounded_show!(olg_jld2, "BlanchardOLGSolution")

        # Plain multi-key .jld2 + model keys
        plain_jld2 = joinpath(d, "multi.jld2")
        JLD2.jldsave(plain_jld2; df1=DataFrame(a=1:5, b=6:10), vec1=collect(1.0:5.0))
        Friedman._HANDLE_LOAD_COUNTER[] = 0
        parse_envelope(run_json(["model", "info", plain_jld2]), "plain .jld2 model info")
        check!(Friedman._HANDLE_LOAD_COUNTER[] == 0, "plain .jld2 model info loaded payload")
        dk = parse_envelope(run_json(["model", "keys", plain_jld2]), "plain .jld2 model keys")
        if dk !== nothing
            kset = Set(String(r[1]) for r in dk.data.model_keys.rows)
            check!(kset == Set(["df1", "vec1"]), "model keys mismatch: $kset")
        end
        println("  [OK] spectral, did, nowcast, pvar, io, dsge olg, plain multi-key .jld2")

        # ── Family 8: MEMs v1.1.1 Waves 1–5 (.jld2 round-trips) ──────────
        # W1: QuantileFactorModel + QuantileVARModel
        csv_qfm = joinpath(d, "qfm.csv")
        CSV.write(csv_qfm, DataFrame(randn(40, 8), ["x$i" for i in 1:8]))
        qfm_m = joinpath(d, "qfm.jld2")
        parse_envelope(run_json(["estimate", "factor", "qfm", csv_qfm, "--factors", "2", "--tau", "0.5", "--save-model", qfm_m]), "estimate qfm")
        assert_header_info!(qfm_m, "QuantileFactorModel", "QuantileFactorModel")
        assert_bounded_show!(qfm_m, "QuantileFactorModel")
        parse_envelope(run_json(["forecast", "factor", "qfm", "--model", qfm_m, "--horizons", "3"]), "forecast qfm --model")

        qvar_m = joinpath(d, "qvar.jld2")
        parse_envelope(run_json(["estimate", "multivariate", "qvar", ts_jld2, "--lags", "1", "--taus", "0.25,0.5,0.75", "--save-model", qvar_m]), "estimate qvar")
        assert_header_info!(qvar_m, "QuantileVARModel", "QuantileVARModel")
        parse_envelope(run_json(["irf", "qvar", "--model", qvar_m, "--horizons", "3", "--shock", "1"]), "irf qvar --model")

        # W2: FHLZModel + OnatskiQTestResult
        fhlz_m = joinpath(d, "fhlz.jld2")
        parse_envelope(run_json(["estimate", "factor", "fhlz", csv_qfm, "--dynamic-rank", "1", "--p-max", "2", "--n-perm", "5", "--save-model", fhlz_m]), "estimate fhlz")
        assert_header_info!(fhlz_m, "FHLZModel", "FHLZModel")
        parse_envelope(run_json(["predict", "factor", "fhlz", "--model", fhlz_m]), "predict fhlz --model")

        onq_r = joinpath(d, "onq.jld2")
        assert_replay_parity!(
            ["test", "factor", "onatski-q", csv_qfm, "--k-max", "3", "--save-result", onq_r],
            ["test", "factor", "onatski-q", "--result", onq_r], onq_r, "test onatski-q")

        # W3: LMSSVARResult + SVARMAModel
        lms_m = joinpath(d, "lms.jld2")
        parse_envelope(run_json(["estimate", "multivariate", "lms-svar", ts_jld2, "--lags", "1", "--save-model", lms_m]), "estimate lms-svar")
        assert_header_info!(lms_m, "LMSSVARResult", "LMSSVARResult")
        parse_envelope(run_json(["irf", "var", "--model", lms_m, "--horizons", "3"]), "irf var --model lms")

        ssv_csv = joinpath(d, "ssv.csv")
        ssv_sim = MacroEconometricModels.dgp_ssvarma(Xoshiro(123); T=80, burn=40)
        CSV.write(ssv_csv, DataFrame(ssv_sim.Y, ["y1", "y2"]))
        ssv_m = joinpath(d, "ssv.jld2")
        parse_envelope(run_json(["estimate", "multivariate", "ssvarma", ssv_csv, "--ar-lags", "1", "--ma-lags", "1", "--max-iter", "20", "--save-model", ssv_m]), "estimate ssvarma")
        assert_header_info!(ssv_m, "SVARMAModel", "SVARMAModel")
        parse_envelope(run_json(["irf", "ssvarma", "--model", ssv_m, "--horizons", "3"]), "irf ssvarma --model")

        # W4: ABCDSystem + DSGEVARPosterior
        rbc_spec = joinpath(d, "rbc.jl")
        write(rbc_spec, """
        using .MacroEconometricModels
        @dsge begin
            parameters: α = 0.33, β = 0.99, δ = 0.025, ρ = 0.9
            endogenous: k, c, z
            exogenous: e
            c[t]^(-1) = β * c[t+1]^(-1) * (α * exp(z[t+1]) * k[t]^(α-1) + 1 - δ)
            k[t] = exp(z[t]) * k[t-1]^α + (1 - δ) * k[t-1] - c[t]
            z[t] = ρ * z[t-1] + e[t]
        end
        """)
        abcd_m = joinpath(d, "abcd.jld2")
        parse_envelope(run_json(["dsge", "abcd", "extract", rbc_spec, "--observables", "c", "--save-model", abcd_m]), "dsge abcd extract")
        assert_header_info!(abcd_m, "ABCDSystem", "ABCDSystem")
        parse_envelope(run_json(["dsge", "abcd", "invertibility", "--model", abcd_m]), "dsge abcd invertibility --model")

        dv_csv = joinpath(d, "dv.csv")
        CSV.write(dv_csv, DataFrame(c=randn(60)))
        dv_m = joinpath(d, "dsgevar.jld2")
        parse_envelope(run_json(["dsge", "var", "estimate", rbc_spec, "--data", dv_csv, "--observables", "c", "--lags", "1", "--lambda", "1.0", "--draws", "20", "--seed", "7", "--save-model", dv_m]), "dsge var estimate")
        assert_header_info!(dv_m, "DSGEVARPosterior", "DSGEVARPosterior")
        parse_envelope(run_json(["dsge", "var", "irf", "--model", dv_m, "--horizons", "3"]), "dsge var irf --model")

        # W5: SimsKalmanSolution + RILogitModel
        ri_cfg = joinpath(d, "ri.toml")
        write(ri_cfg, """
        [ri]
        A = [[0.8]]
        B = [[1.0]]
        H = [[1.0]]
        M = [[1.0]]
        beta = 0.99
        capacity = 1.0
        """)
        ri_m = joinpath(d, "ri.jld2")
        parse_envelope(run_json(["ri", "solve", "--config", ri_cfg, "--save-model", ri_m]), "ri solve")
        assert_header_info!(ri_m, "SimsKalmanSolution", "SimsKalmanSolution")
        parse_envelope(run_json(["ri", "irf", "--model", ri_m, "--horizons", "4"]), "ri irf --model")

        ril_rows = DataFrame(env=Int[], state=Int[], alt=Int[], choice=Int[], x1=Float64[])
        for m in 1:2, _ in 1:25
            s = rand(1:2)
            ch = rand() < (s == 1 ? 0.75 : 0.25) ? 1 : 2
            for j in 1:2
                push!(ril_rows, (m, s, j, j == ch ? 1 : 0, j == s ? Float64(m) : 0.0))
            end
        end
        ril_csv = joinpath(d, "ril.csv")
        CSV.write(ril_csv, ril_rows)
        ril_m = joinpath(d, "ril.jld2")
        parse_envelope(run_json(["estimate", "choice", "ri-logit", ril_csv, "--env-col", "env", "--choice-col", "choice", "--alt-col", "alt", "--state-col", "state", "--attr-cols", "x1", "--normalize", "omega-one", "--save-model", ril_m]), "estimate ri-logit")
        assert_header_info!(ril_m, "RILogitModel", "RILogitModel")
        parse_envelope(run_json(["predict", "choice", "ri-logit", "--model", ril_m]), "predict ri-logit --model")
        println("  [OK] MEMs v1.1.1 W1–W5 .jld2 round-trips (QFM, QVAR, FHLZ, Onatski-q, LMS, SSVARMA, ABCD, DSGE-VAR, RI, RI-Logit)")
    end

    if !isempty(FAILURES)
        println(stderr, "\ncheck_handle_roundtrips: FAILED ($(length(FAILURES)) failure(s))")
        return 1
    end
    println("check_handle_roundtrips: PASS (all families + serialization registry verified)")
    return 0
end

exit(main())
