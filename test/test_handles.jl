@testset "typed-handles registry fields" begin
    s = CommandSpec(path=["estimate", "var"], summary="x",
                    args=[ArgSpec(name="data")],
                    handler=wrap_legacy((; kwargs...) -> nothing))
    @test s.data_kinds == Symbol[]
    @test s.model_types == Symbol[]
    @test s.result_types == Symbol[]
    @test MODEL_OPTION.handle === true
    @test SAVE_MODEL_OPTION.handle === false
    tagged = with_data_kinds([s], [:timeseries, :csv])
    @test tagged[1].data_kinds == [:timeseries, :csv]
    @test tagged[1].path == s.path
    @test tagged[1].handler === s.handler
    copied = with_options([s], [MODEL_OPTION])
    @test copied[1].data_kinds == s.data_kinds
    @test any(o -> o.name == "model" && o.handle, copied[1].options)
end

@testset "typed-handles stem resolution" begin
    mktempdir() do dir
        csv = joinpath(dir, "macro.csv")
        jld = joinpath(dir, "macro.jld2")
        CSV.write(csv, DataFrame(y1=randn(12), y2=randn(12)))
        ts = TimeSeriesData(df_to_matrix(CSV.read(csv, DataFrame));
                            varnames=["y1", "y2"])
        save_model_dispatch(jld, ts)

        @test resolve_stem(joinpath(dir, "macro"); slot=:data) == jld
        @test resolve_stem(csv; slot=:data) == csv
        @test resolve_stem(jld; slot=:data) == jld
        @test resolve_save_path(joinpath(dir, "out")) == joinpath(dir, "out.jld2")
        @test resolve_save_path(joinpath(dir, "out.csv")) == joinpath(dir, "out.csv")
        @test resolve_save_path("model://m1") == "model://m1"

        loaded = resolve_data(joinpath(dir, "macro"))
        @test loaded isa TimeSeriesData
        @test _data_kind_of(loaded) === :timeseries

        rm(jld)
        @test resolve_stem(joinpath(dir, "macro"); slot=:data) == csv
        df = resolve_data(joinpath(dir, "macro"))
        @test df isa DataFrame

        err = try
            resolve_stem(joinpath(dir, "nope"); slot=:data)
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "data/file-not-found"
    end
end

@testset "typed-handles wrap_legacy data/wrong-kind" begin
    mktempdir() do dir
        csv = joinpath(dir, "p.csv")
        CSV.write(csv, DataFrame(group=repeat(1:2, inner=4),
                                 time=repeat(1:4, outer=2),
                                 y=randn(8), x=randn(8)))
        pd = xtset(CSV.read(csv, DataFrame), :group, :time)
        h = joinpath(dir, "panel.jld2")
        save_model_dispatch(h, pd)

        saw = Ref{String}("")
        handler = wrap_legacy((; data::String="", format="table", output="") -> (saw[] = data; nothing))
        spec = CommandSpec(path=["estimate", "var"], summary="x",
                           args=[ArgSpec(name="data", required=false, default="")],
                           options=[OptionSpec(name="format", default="table"),
                                    OptionSpec(name="output", default="")],
                           handler=handler,
                           data_kinds=[:timeseries, :csv])
        leaf = to_leaf(spec)
        err = try
            leaf.handler(; data=joinpath(dir, "panel"), format="json", output="")
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "data/wrong-kind"
        @test occursin("PanelData", err.message)

        # CSV still legal
        handler2 = wrap_legacy((; data::String="", format="table", output="") -> (saw[] = data; "ok"))
        spec2 = _copy_spec(spec; handler=handler2)
        leaf2 = to_leaf(spec2)
        @test leaf2.handler(; data=csv, format="json", output="") == "ok"
        @test saw[] == csv
    end
end

@testset "data import" begin
    node = register_data_commands!()
    @test haskey(node.subcmds, "import")
    mktempdir() do dir
        csv = joinpath(dir, "macro.csv")
        CSV.write(csv, DataFrame(y1=randn(10), y2=randn(10)))
        err = try
            _capture() do
                _data_import(; data=csv, kind="", output=joinpath(dir, "macro"))
            end
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "usage/invalid"
        @test occursin("--kind", err.message)

        _capture() do
            _data_import(; data=csv, kind="timeseries", frequency="quarterly",
                         output=joinpath(dir, "macro"))
        end
        @test isfile(joinpath(dir, "macro.jld2"))
        obj = load_model_dispatch(joinpath(dir, "macro.jld2"))
        @test obj isa TimeSeriesData
        @test varnames(obj) == ["y1", "y2"]

        dated = joinpath(dir, "dated.csv")
        CSV.write(dated, DataFrame(dates=1990:1999, y1=randn(10), y2=randn(10)))
        _capture() do
            _data_import(; data=dated, kind="timeseries", dates="dates",
                         output=joinpath(dir, "dated"))
        end
        dated_obj = load_model_dispatch(joinpath(dir, "dated.jld2"))
        @test dated_obj isa TimeSeriesData
        @test varnames(dated_obj) == ["y1", "y2"]

        miss = joinpath(dir, "miss.csv")
        CSV.write(miss, DataFrame(y1=[1.0, missing, 3.0], y2=[1.0, 2.0, 3.0]))
        err = try
            _capture() do
                _data_import(; data=miss, kind="timeseries",
                             output=joinpath(dir, "miss"))
            end
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "data/missing-values"

        err = try
            _capture() do
                _data_import(; data=csv, kind="panel", vars="y1",
                             output=joinpath(dir, "p"))
            end
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "usage/missing"

        err = try
            _capture() do
                _data_import(; data=joinpath(dir, "macro.jld2"), kind="timeseries",
                             output=joinpath(dir, "macro2"))
            end
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "usage/invalid"
    end
end

@testset "data export and typed fix" begin
    node = register_data_commands!()
    @test haskey(node.subcmds, "export")
    export_spec = only(s for s in data_specs() if s.path == ["data", "export"])
    @test :io ∉ export_spec.data_kinds
    mktempdir() do dir
        csv = joinpath(dir, "macro.csv")
        CSV.write(csv, DataFrame(y1=[1.0, NaN, 3.0], y2=[4.0, 5.0, 6.0]))
        _capture() do
            _data_import(; data=csv, kind="timeseries", output=joinpath(dir, "macro"))
        end
        h = joinpath(dir, "macro.jld2")
        _capture() do
            _data_export(; data=joinpath(dir, "macro"), output=joinpath(dir, "round.csv"))
        end
        @test isfile(joinpath(dir, "round.csv"))

        _capture() do
            _data_fix(; data=joinpath(dir, "macro"), method="listwise",
                      output=joinpath(dir, "macro_clean"))
        end
        @test isfile(joinpath(dir, "macro_clean.jld2"))
        cleaned = load_model_dispatch(joinpath(dir, "macro_clean.jld2"))
        @test cleaned isa TimeSeriesData

        err = try
            _capture() do
                _data_fix(; data=csv, method="listwise",
                          output=joinpath(dir, "nope.jld2"))
            end
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "usage/invalid"

        dropna_csv = joinpath(dir, "dropna.csv")
        _capture() do
            _data_dropna(; data=joinpath(dir, "macro"), output=dropna_csv)
        end
        dropna_df = CSV.read(dropna_csv, DataFrame)
        @test names(dropna_df) == ["y1", "y2"]
        @test nrow(dropna_df) == 2

        ioh = joinpath(dir, "io.jld2")
        _capture() do
            save_model_dispatch(ioh, MacroEconometricModels._mock_wiot())
        end
        err = try
            _capture() do
                _data_export(; data=ioh, output=joinpath(dir, "io.csv"))
            end
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "data/wrong-kind"
    end
end

@testset "data describe on panel handle" begin
    validate_spec = only(s for s in data_specs() if s.path == ["data", "validate"])
    model_opt = only(o for o in validate_spec.options if o.name == "model")
    @test model_opt.handle === false
    @test model_opt.type === String

    mktempdir() do dir
        csv = _make_panel_csv(dir)
        pd = xtset(CSV.read(csv, DataFrame), :group, :time)
        h = joinpath(dir, "panel.jld2")
        save_model_dispatch(h, pd)
        outfile = joinpath(dir, "desc.json")
        result = Ref{Any}(nothing)
        _capture() do
            result[] = _data_describe(; data=joinpath(dir, "panel"), format="json", output=outfile)
        end
        @test isfile(outfile)
        # After implementation, describe_data(::PanelData) is used. Force a CrossSectionData
        # through describe — today's code always TimeSeriesData()s the matrix, which also
        # works. Fail by asserting the handler returns the loaded object type:
        @test result[] isa PanelData
        rows = JSON3.read(read(outfile, String))
        @test all(r -> r.n isa Integer, rows)

        # Real describe_data(::PanelData) prints panel_summary to stdout. The
        # handler must capture that dump onto stderr so stdout stays data-only.
        streams = _capture_all() do
            _data_describe(; data=joinpath(dir, "panel"), format="json")
        end
        @test !occursin("Panel Structure", streams.out)
        @test occursin("Panel Structure", streams.err)
        @test JSON3.read(streams.out) isa AbstractVector

        csv_out = joinpath(dir, "desc_csv.json")
        _capture() do
            _data_describe(; data=csv, format="json", output=csv_out)
        end
        @test isfile(csv_out)

        diag_out = joinpath(dir, "diag.json")
        diag = Ref{Any}(nothing)
        _capture() do
            diag[] = _data_diagnose(; data=joinpath(dir, "panel"), format="json", output=diag_out)
        end
        @test isfile(diag_out)
        @test diag[] isa PanelData

        val = Ref{Any}(nothing)
        _capture() do
            val[] = _data_validate(; data=h, model="var")
        end
        @test val[] isa PanelData
    end
end

@testset "load_multivariate_data from handle" begin
    mktempdir() do dir
        csv = joinpath(dir, "macro.csv")
        CSV.write(csv, DataFrame(y1=randn(20), y2=randn(20), y3=randn(20)))
        _capture() do
            _data_import(; data=csv, kind="timeseries", output=joinpath(dir, "macro"))
        end
        Yc, nc = load_multivariate_data(csv)
        Yh, nh = load_multivariate_data(joinpath(dir, "macro"))
        @test nc == nh
        @test Yc == Yh
    end
end

@testset "load_data reads .jld2 containers" begin
    mktempdir() do dir
        csv = joinpath(dir, "macro.csv")
        CSV.write(csv, DataFrame(y1=1.0:8.0, y2=2.0:9.0))
        _capture() do
            _data_import(; data=csv, kind="timeseries", output=joinpath(dir, "macro"))
        end
        df = load_data(joinpath(dir, "macro.jld2"))
        @test names(df) == ["y1", "y2"]
        @test size(df, 1) == 8
        @test Vector(df.y1) == collect(1.0:8.0)

        panel = joinpath(dir, "panel.csv")
        g = repeat(1:2, inner=4); t = repeat(1:4, outer=2)
        CSV.write(panel, DataFrame(group=g, time=t, y=randn(8), x=randn(8)))
        _capture() do
            _data_import(; data=panel, kind="panel", id_col="group", time_col="time",
                         output=joinpath(dir, "panel"))
        end
        dfp = load_data(joinpath(dir, "panel.jld2"))
        @test names(dfp)[1:2] == ["group", "time"]
        @test "y" in names(dfp) && "x" in names(dfp)

        Y, vn = load_multivariate_data(csv)
        model = estimate_var(Y, 1; varnames=vn)
        mjld = joinpath(dir, "varmodel.jld2")
        save_model_dispatch(mjld, model)
        err = try
            load_data(mjld)
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "data/wrong-kind"

        ioh = joinpath(dir, "io.jld2")
        io = MacroEconometricModels._mock_wiot()
        @test _data_kind_of(io) === :io
        _capture() do
            save_model_dispatch(ioh, io)
        end
        err_io = try
            load_data(ioh)
            nothing
        catch e; e; end
        @test err_io isa CliError
        @test err_io.code == "data/wrong-kind"
    end
end

@testset "load_data skips FRIEDMAN_DATA_ROOT for model://" begin
    mktempdir() do root
        outside = tempname() * ".csv"
        CSV.write(outside, DataFrame(a=[1.0, 2.0]))
        withenv("FRIEDMAN_DATA_ROOT" => root) do
            err = try
                load_data("model://x")
                nothing
            catch e; e; end
            @test err isa CliError
            @test err.code != "data/bad-path"
            err_fs = try
                load_data(outside)
                nothing
            catch e; e; end
            @test err_fs isa CliError
            @test err_fs.code == "data/bad-path"
        end
        rm(outside; force=true)
    end
end

@testset "estimate var declares timeseries kind" begin
    specs = with_config_ergonomics(with_save_model(estimate_specs()))
    # After register overlays:
    node = register_estimate_commands!()
    # Look up via REGISTRY — register! appends, so findlast not findfirst.
    s = findlast(x -> x.path == ["estimate", "var"], REGISTRY)
    @test s !== nothing
    @test :timeseries in REGISTRY[s].data_kinds
    @test :csv in REGISTRY[s].data_kinds
    @test haskey(node.subcmds, "var")

    s_pvar = findlast(x -> x.path == ["estimate", "pvar"], REGISTRY)
    @test s_pvar !== nothing
    @test :panel in REGISTRY[s_pvar].data_kinds
    @test :csv in REGISTRY[s_pvar].data_kinds

    s_reg = findlast(x -> x.path == ["estimate", "reg"], REGISTRY)
    @test s_reg !== nothing
    @test :cross_section in REGISTRY[s_reg].data_kinds
    @test :timeseries in REGISTRY[s_reg].data_kinds
    @test :csv in REGISTRY[s_reg].data_kinds

    register_data_commands!()
    s_imp = findlast(x -> x.path == ["data", "import"], REGISTRY)
    @test :csv in REGISTRY[s_imp].data_kinds
    @test :timeseries in REGISTRY[s_imp].data_kinds
    s_exp = findlast(x -> x.path == ["data", "export"], REGISTRY)
    @test :csv ∉ REGISTRY[s_exp].data_kinds
    @test :io ∉ REGISTRY[s_exp].data_kinds
    s_list = findlast(x -> x.path == ["data", "list"], REGISTRY)
    @test isempty(REGISTRY[s_list].data_kinds)

    register_test_commands!()
    s_dh = findlast(x -> x.path == ["test", "dh-causality"], REGISTRY)
    @test s_dh !== nothing
    @test :panel in REGISTRY[s_dh].data_kinds
    @test :csv in REGISTRY[s_dh].data_kinds

    mktempdir() do dir
        csv = joinpath(dir, "p.csv")
        CSV.write(csv, DataFrame(group=repeat(1:2, inner=4),
                                 time=repeat(1:4, outer=2),
                                 y=randn(8), x=randn(8)))
        pd = xtset(CSV.read(csv, DataFrame), :group, :time)
        save_model_dispatch(joinpath(dir, "panel.jld2"), pd)
        err = try
            node.subcmds["var"].handler(; data=joinpath(dir, "panel"),
                                        format="json", output="")
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "data/wrong-kind"
        @test occursin("PanelData", err.message)
    end
end

@testset "schema x-handle" begin
    node = register_estimate_commands!()
    leaf = node.subcmds["var"]
    sch = _input_schema(leaf, ["estimate", "var"])
    @test haskey(sch["properties"]["data"], "x-handle")
    xh = sch["properties"]["data"]["x-handle"]
    @test xh["role"] == "data"
    @test "timeseries" in xh["kinds"]

    irf_node = register_irf_commands!()
    irf_sch = _input_schema(irf_node.subcmds["var"], ["irf", "var"])
    @test haskey(irf_sch["properties"]["data"], "x-handle")
    @test irf_sch["properties"]["model"]["x-handle"]["role"] == "model"
    @test irf_sch["properties"]["model"]["x-handle"]["types"] isa AbstractVector

    data_node = register_data_commands!()
    val_sch = _input_schema(data_node.subcmds["validate"], ["data", "validate"])
    @test haskey(val_sch["properties"]["data"], "x-handle")
    @test !haskey(val_sch["properties"]["model"], "x-handle")
end

@testset "save-result NamedTuple" begin
    mktempdir() do dir
        fake_model = estimate_var(randn(30, 2), 1; varnames=["y1","y2"])
        fake_irf = fake_model  # mock may not have ImpulseResponse; use a native type
        handler = wrap_legacy((; data="", model=nothing, result=nothing, format="table", output="") ->
            (; model=fake_model, result=fake_model))
        spec = CommandSpec(path=["irf", "var"], summary="x",
            args=[ArgSpec(name="data", required=false, default="")],
            options=[MODEL_OPTION, SAVE_MODEL_OPTION, RESULT_OPTION, SAVE_RESULT_OPTION,
                     OptionSpec(name="format", default="table"), OptionSpec(name="output", default="")],
            handler=handler,
            data_kinds=[:timeseries, :csv],
            model_types=[:VARModel],
            result_types=[Symbol(nameof(typeof(fake_model)))])
        leaf = to_leaf(spec)
        mp = joinpath(dir, "var"); rp = joinpath(dir, "irf")
        leaf.handler(; data="", save_model=mp, save_result=rp, format="json", output="")
        @test isfile(mp * ".jld2")
        @test isfile(rp * ".jld2")
    end
end

@testset "result handle flags in wrap_legacy" begin
    @test RESULT_OPTION.handle === true
    @test SAVE_RESULT_OPTION.handle === false
    s = CommandSpec(path=["irf", "var"], summary="x")
    @test with_result_handles([s])[1] === s
    tagged = with_result_handles([_copy_spec(s; result_types=[:ImpulseResponse])])
    @test any(o -> o.name == "result" && o.handle, tagged[1].options)
    @test any(o -> o.name == "save-result" && !o.handle, tagged[1].options)

    mktempdir() do dir
        fake_model = estimate_var(randn(30, 2), 1; varnames=["y1", "y2"])
        hp = joinpath(dir, "obj.jld2")
        save_model_dispatch(hp, fake_model)
        csv = joinpath(dir, "x.csv")
        CSV.write(csv, DataFrame(y1=randn(10), y2=randn(10)))

        function _leaf(; handler, model_types=[:VARModel], result_types=[:VARModel])
            spec = CommandSpec(path=["irf", "var"], summary="x",
                args=[ArgSpec(name="data", required=false, default="")],
                options=[MODEL_OPTION, SAVE_MODEL_OPTION, RESULT_OPTION, SAVE_RESULT_OPTION,
                         OptionSpec(name="format", default="table"), OptionSpec(name="output", default="")],
                handler=handler,
                data_kinds=[:timeseries, :csv],
                model_types=model_types,
                result_types=result_types)
            return to_leaf(spec)
        end

        # data/wrong-result: VARModel is not an ImpulseResponse
        h_wrong = wrap_legacy((; data="", model=nothing, result=nothing, format="table", output="") -> result)
        leaf_wrong = _leaf(; handler=h_wrong, result_types=[:ImpulseResponse])
        err_wr = try
            leaf_wrong.handler(; data="", result=joinpath(dir, "obj"), format="json", output="")
            nothing
        catch e; e; end
        @test err_wr isa CliError
        @test err_wr.code == "data/wrong-result"
        @test exit_class(err_wr) == 3
        @test occursin("VARModel", err_wr.message)

        # XOR: --result + --model
        err_xor_m = try
            leaf_wrong.handler(; data="", model=joinpath(dir, "obj"),
                               result=joinpath(dir, "obj"), format="json", output="")
            nothing
        catch e; e; end
        @test err_xor_m isa CliError
        @test err_xor_m.code == "usage/invalid"
        @test exit_class(err_xor_m) == 2

        # XOR: --result + nonempty data
        err_xor_d = try
            leaf_wrong.handler(; data=csv, result=joinpath(dir, "obj"),
                               format="json", output="")
            nothing
        catch e; e; end
        @test err_xor_d isa CliError
        @test err_xor_d.code == "usage/invalid"

        # --result with empty data injects the loaded object
        got = Ref{Any}(nothing)
        h_inj = wrap_legacy((; data="", model=nothing, result=nothing, format="table", output="") ->
            (got[] = result; result))
        leaf_inj = _leaf(; handler=h_inj)
        @test leaf_inj.handler(; data="", result=joinpath(dir, "obj"),
                               format="json", output="") isa typeof(fake_model)
        @test got[] isa typeof(fake_model)

        # model/wrong-kind + suffix-less --model when model_types nonempty
        h_m = wrap_legacy((; data="", model=nothing, result=nothing, format="table", output="") -> model)
        leaf_m = _leaf(; handler=h_m, model_types=[:BVARPosterior], result_types=Symbol[])
        err_mk = try
            leaf_m.handler(; data="", model=joinpath(dir, "obj"), format="json", output="")
            nothing
        catch e; e; end
        @test err_mk isa CliError
        @test err_mk.code == "model/wrong-kind"
        @test exit_class(err_mk) == 5
        @test occursin("VARModel", err_mk.message)

        gotm = Ref{Any}(nothing)
        h_stem = wrap_legacy((; data="", model=nothing, format="table", output="") ->
            (gotm[] = model; model))
        leaf_stem = _leaf(; handler=h_stem, model_types=[:VARModel], result_types=Symbol[])
        @test leaf_stem.handler(; data="", model=joinpath(dir, "obj"),
                                format="json", output="") isa typeof(fake_model)
        @test gotm[] isa typeof(fake_model)

        # Both flags + bare return → usage/invalid
        h_bare = wrap_legacy((; data="", format="table", output="") -> fake_model)
        leaf_bare = _leaf(; handler=h_bare)
        err_both = try
            leaf_bare.handler(; data="", save_model=joinpath(dir, "m"),
                              save_result=joinpath(dir, "r"), format="json", output="")
            nothing
        catch e; e; end
        @test err_both isa CliError
        @test err_both.code == "usage/invalid"

        # Bare return + only --save-result
        rp = joinpath(dir, "only_result")
        leaf_bare.handler(; data="", save_result=rp, format="json", output="")
        @test isfile(rp * ".jld2")
        @test load_model_dispatch(rp * ".jld2") isa typeof(fake_model)

        # Existing estimate --save-model (bare return, no --save-result) stays green
        mp = joinpath(dir, "only_model")
        leaf_bare.handler(; data="", save_model=mp, format="json", output="")
        @test isfile(mp * ".jld2")
        @test load_model_dispatch(mp * ".jld2") isa typeof(fake_model)

        # NamedTuple missing field → model/no-result
        h_half = wrap_legacy((; data="", format="table", output="") -> (; model=fake_model))
        leaf_half = _leaf(; handler=h_half)
        err_nr = try
            leaf_half.handler(; data="", save_result=joinpath(dir, "missing"),
                              format="json", output="")
            nothing
        catch e; e; end
        @test err_nr isa CliError
        @test err_nr.code == "model/no-result"
    end
end

@testset "producing leaf --result re-render" begin
    irf_node = register_irf_commands!()
    irf_var = irf_node.subcmds["var"]
    @test any(o -> o.name == "result", irf_var.options)
    @test any(o -> o.name == "save-result", irf_var.options)
    spec = _spec_for_path(["irf", "var"])
    @test spec !== nothing
    @test :VARModel in spec.model_types
    @test :ImpulseResponse in spec.result_types
    @test !isempty(spec.result_types)
    @test any(o -> o.name == "result" && o.handle, spec.options)

    fc_node = register_forecast_commands!()
    @test any(o -> o.name == "result", fc_node.subcmds["var"].options)
    @test !any(o -> o.name == "result", fc_node.subcmds["evaluate"].subcmds["metrics"].options)

    data_node = register_data_commands!()
    val_spec = _spec_for_path(["data", "validate"])
    @test isempty(val_spec.model_types)
    @test !any(o -> o.name == "model" && o.handle, val_spec.options)

    mktempdir() do dir
        irf_obj = ImpulseResponse(zeros(4, 2, 2), nothing, nothing)
        hp = joinpath(dir, "irf.jld2")
        save_model_dispatch(hp, irf_obj)

        # --lags with --result via wrap_legacy (no full IRF compute)
        err_lags = try
            irf_var.handler(; data="", result=joinpath(dir, "irf"), lags=2,
                            format="json", output="")
            nothing
        catch e; e; end
        @test err_lags isa CliError
        @test err_lags.code == "usage/invalid"
        @test occursin("--lags", err_lags.message)

        # XOR still fires at wrap_legacy before the handler
        csv = joinpath(dir, "x.csv")
        CSV.write(csv, DataFrame(y1=randn(10), y2=randn(10)))
        err_xor = try
            irf_var.handler(; data=csv, result=joinpath(dir, "irf"),
                            format="json", output="")
            nothing
        catch e; e; end
        @test err_xor isa CliError
        @test err_xor.code == "usage/invalid"

        # Handler-level --lags without wrap_legacy
        err_direct = try
            _irf_var(; data="", result=irf_obj, lags=2, format="json", output="")
            nothing
        catch e; e; end
        @test err_direct isa CliError
        @test err_direct.code == "usage/invalid"
        @test occursin("--lags", err_direct.message)

        err_id = try
            _irf_var(; data="", result=irf_obj, id="arias", format="json", output="")
            nothing
        catch e; e; end
        @test err_id isa CliError
        @test err_id.code == "usage/invalid"
        @test occursin("--id", err_id.message)

        err_h = try
            _irf_var(; data="", result=irf_obj, horizons=10, format="json", output="")
            nothing
        catch e; e; end
        @test err_h isa CliError
        @test occursin("--horizons", err_h.message)
    end
end

@testset "remaining producing families --result" begin
    filt = register_filter_commands!()
    @test any(o -> o.name == "result", filt.subcmds["hp"].options)
    hp_spec = _spec_for_path(["filter", "hp"])
    @test :HPFilterResult in hp_spec.result_types

    tnode = register_test_commands!()
    @test any(o -> o.name == "result", tnode.subcmds["adf"].options)
    adf_spec = _spec_for_path(["test", "adf"])
    @test :ADFResult in adf_spec.result_types
    @test isempty(adf_spec.model_types)

    dnode = register_data_commands!()
    @test !any(o -> o.name == "result", dnode.subcmds["filter"].options)
    val_spec = _spec_for_path(["data", "validate"])
    @test isempty(val_spec.model_types)
    @test !any(o -> o.name == "model" && o.handle, val_spec.options)

    pnode = register_predict_commands!()
    pspec = _spec_for_path(["predict", "var"])
    @test :VARModel in pspec.model_types
end

@testset "irf/filter --result re-render tables" begin
    err = try
        _rerender_long_table(ADFResult(1.0, 0.1, 1); format="json", output="", title="x", key="x")
        nothing
    catch e; e; end
    @test err isa CliError
    @test err.code == "model/unsupported"

    n = 2; H = 4; nd = 3
    restr = SVARRestrictions(n)
    Qs = [Float64[1.0 0.0; 0.0 1.0] for _ in 1:nd]
    arias = AriasSVARResult(Qs, ones(nd, H, n, n), ones(nd), 0.5, restr)
    streams = _capture_all() do
        _irf_var(; data="", result=arias, format="json", output="")
    end
    @test occursin("horizon", streams.out)
    @test !occursin("MethodError", streams.err)

    mktempdir() do dir
        csv = joinpath(dir, "y.csv")
        CSV.write(csv, DataFrame(y=randn(40)))
        hp_leaf = register_filter_commands!().subcmds["hp"]
        stem = joinpath(dir, "hp")
        _capture() do
            hp_leaf.handler(; data=csv, save_result=stem, format="json", output="")
        end
        @test isfile(stem * ".jld2")
        streams = _capture_all() do
            hp_leaf.handler(; data="", result=stem, format="json", output="")
        end
        @test occursin("cycle", streams.out)
        @test occursin("trend", streams.out)

        kpss_leaf = register_test_commands!().subcmds["kpss"]
        kstem = joinpath(dir, "kpss")
        _capture() do
            kpss_leaf.handler(; data=csv, save_result=kstem, format="json", output="")
        end
        @test isfile(kstem * ".jld2")
    end

    n = 2; H = 3
    props = ones(n, n, H) / n
    lp = LPFEVD(props, props, props, props, props, :R2, H, 200, 0.95, true)
    @test _result_varnames(lp, n) == ["var_1", "var_2"]
    @test !any(==("y1"), _result_varnames(lp, n))
end
