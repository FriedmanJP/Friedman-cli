@testset "typed-handles registry fields" begin
    s = CommandSpec(path=["estimate", "multivariate", "var"], summary="x",
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
        spec = CommandSpec(path=["estimate", "multivariate", "var"], summary="x",
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

@testset "estimate multivariate var declares timeseries kind" begin
    specs = with_config_ergonomics(with_save_model(estimate_specs()))
    # After register overlays:
    node = register_estimate_commands!()
    # Look up via REGISTRY — register! appends, so findlast not findfirst.
    s = findlast(x -> x.path == ["estimate", "multivariate", "var"], REGISTRY)
    @test s !== nothing
    @test :timeseries in REGISTRY[s].data_kinds
    @test :csv in REGISTRY[s].data_kinds
    @test haskey(node.subcmds, "multivariate")

    s_pvar = findlast(x -> x.path == ["estimate", "panel", "pvar"], REGISTRY)
    @test s_pvar !== nothing
    @test :panel in REGISTRY[s_pvar].data_kinds
    @test :csv in REGISTRY[s_pvar].data_kinds

    s_reg = findlast(x -> x.path == ["estimate", "regression", "reg"], REGISTRY)
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
    s_dh = findlast(x -> x.path == ["test", "panel", "dh-causality"], REGISTRY)
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
            node.subcmds["multivariate"].subcmds["var"].handler(; data=joinpath(dir, "panel"),
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
    leaf = node.subcmds["multivariate"].subcmds["var"]
    sch = _input_schema(leaf, ["estimate", "multivariate", "var"])
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

    show_leaf = register_show_commands!()
    show_sch = _input_schema(show_leaf, ["show"])
    @test haskey(show_sch["properties"]["path"], "x-handle")
    xh_show = show_sch["properties"]["path"]["x-handle"]
    @test xh_show["role"] == "any"
    @test xh_show["kinds"] == String[]
    @test xh_show["types"] == String[]
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
    @test any(o -> o.name == "result", fc_node.subcmds["multivariate"].subcmds["var"].options)
    eval_metrics = fc_node.subcmds["evaluate"].subcmds["metrics"]
    @test any(o -> o.name == "result", eval_metrics.options)
    eval_spec = _spec_for_path(["forecast", "evaluate", "metrics"])
    @test any(o -> o.name == "result" && !o.handle, eval_spec.options)
    @test isempty(eval_spec.result_types)

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
    @test any(o -> o.name == "result", tnode.subcmds["unit-root"].subcmds["adf"].options)
    adf_spec = _spec_for_path(["test", "unit-root", "adf"])
    @test :ADFResult in adf_spec.result_types
    @test isempty(adf_spec.model_types)

    dnode = register_data_commands!()
    @test !any(o -> o.name == "result", dnode.subcmds["filter"].options)
    val_spec = _spec_for_path(["data", "validate"])
    @test isempty(val_spec.model_types)
    @test !any(o -> o.name == "model" && o.handle, val_spec.options)

    # Registered leaf goes through to_leaf → spec.handler(ctx); bare kwargs handlers MethodError.
    mktempdir() do dir
        csv = joinpath(dir, "y.csv")
        CSV.write(csv, DataFrame(y=Float64.(1:20)))
        streams = _capture_all() do
            dnode.subcmds["filter"].handler(; data=csv, method="hp", format="json", output="")
        end
        @test occursin("data_filter", streams.out) || occursin("\"y\"", streams.out)
        @test !occursin("MethodError", streams.err)
    end

    pnode = register_predict_commands!()
    pspec = _spec_for_path(["predict", "multivariate", "var"])
    @test :VARModel in pspec.model_types
    aspec = _spec_for_path(["predict", "univariate", "arima"])
    @test :ARIMAModel in aspec.model_types
    @test :ARMAModel in aspec.model_types
    @test :ARModel in aspec.model_types
    @test :MAModel in aspec.model_types
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

        kpss_leaf = register_test_commands!().subcmds["unit-root"].subcmds["kpss"]
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

@testset "friedman show renders any handle" begin
    leaf = register_show_commands!()
    @test leaf isa LeafCommand
    @test leaf.name == "show"
    @test any(a -> a.name == "path" && a.required, leaf.args)
    @test any(o -> o.name == "format", leaf.options)
    @test any(o -> o.name == "plot-save", leaf.options)
    @test any(f -> f.name == "plot", leaf.flags)

    mktempdir() do dir
        csv = joinpath(dir, "macro.csv")
        CSV.write(csv, DataFrame(y1=randn(12), y2=randn(12)))
        ts = TimeSeriesData(df_to_matrix(CSV.read(csv, DataFrame));
                            varnames=["y1", "y2"])
        save_model_dispatch(joinpath(dir, "macro.jld2"), ts)

        outfile = joinpath(dir, "show.json")
        shown = Ref{Any}(nothing)
        _capture() do
            shown[] = _show_handle(; path=joinpath(dir, "macro"),
                                   format="json", output=outfile)
        end
        @test shown[] isa TimeSeriesData
        @test isfile(outfile)
        rows = JSON3.read(read(outfile, String))
        @test all(r -> string(r.variable) in ("y1", "y2"), rows)
        @test all(r -> haskey(r, :mean) && haskey(r, :n), rows)

        streams = _capture_all() do
            leaf.handler(; path=joinpath(dir, "macro"), format="json", output="")
        end
        @test occursin("y1", streams.out)
        @test occursin("variable", streams.out)

        pd = xtset(CSV.read(_make_panel_csv(dir), DataFrame), :group, :time)
        save_model_dispatch(joinpath(dir, "panel.jld2"), pd)
        streams = _capture_all() do
            shown[] = _show_handle(; path=joinpath(dir, "panel"), format="json")
        end
        @test shown[] isa PanelData
        @test !occursin("Panel Structure", streams.out)
        @test occursin("Panel Structure", streams.err)

        m = estimate_var(randn(40, 2), 1; varnames=["y1", "y2"])
        bundle = Dict{String,Any}("data" => ts, "model" => m)
        save_model_dispatch(joinpath(dir, "bundle.fmod"), bundle)
        streams = _capture_all() do
            _show_handle(; path=joinpath(dir, "bundle.fmod"), format="json")
        end
        @test occursin("data", streams.out)
        @test occursin("model", streams.out)
        @test occursin("TimeSeriesData", streams.out)
        @test occursin("VARModel", streams.out)
        @test occursin("not unpacked", streams.err)

        save_model_dispatch(joinpath(dir, "var.jld2"), m)
        streams = _capture_all() do
            shown[] = _show_handle(; path=joinpath(dir, "var"), format="json")
        end
        @test shown[] isa VARModel
        @test occursin("term", streams.out) || occursin("estimate", streams.out)

        ioh = joinpath(dir, "io.jld2")
        save_model_dispatch(ioh, MacroEconometricModels._mock_wiot())
        streams = _capture_all() do
            shown[] = _show_handle(; path=joinpath(dir, "io"), format="json")
        end
        @test shown[] isa IOData
        @test !occursin("MethodError", streams.out)
        @test !occursin("MethodError", streams.err)
        io_rows = JSON3.read(streams.out)
        @test io_rows isa AbstractVector
        @test !isempty(io_rows)
        @test any(r -> haskey(r, :field) && string(r.field) in ("sectors", "Z", "Y", "x"),
                  io_rows) || any(r -> haskey(r, :variable) || haskey(r, :sector), io_rows)

        ir = irf(m, 4)
        save_model_dispatch(joinpath(dir, "irf.jld2"), ir)
        streams = _capture_all() do
            shown[] = _show_handle(; path=joinpath(dir, "irf"), format="json")
        end
        @test shown[] isa ImpulseResponse
        @test occursin("horizon", streams.out) || occursin("variable", streams.out)
        @test occursin("value", streams.out) || occursin("shock", streams.out)

        # mock plot_result is generic (always succeeds) — skip model/unsupported;
        # still invoke --plot on TimeSeriesData so the data-path is not a silent no-op.
        streams = _capture_all() do
            _show_handle(; path=joinpath(dir, "macro"), format="json", plot=true)
        end
        @test occursin("Plot opened", streams.err)
        @test !occursin("MethodError", streams.err)

        err = try
            _show_handle(; path="", data="")
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "usage/missing-arg"

        streams = _capture_all() do
            _dispatch_via_app(["show", joinpath(dir, "macro"), "--format", "json"])
        end
        doc = JSON3.read(streams.out)
        @test haskey(doc.data, :show_payload)
    end
end

@testset "forecast evaluate --result handles" begin
    fc_node = register_forecast_commands!()
    eval_node = fc_node.subcmds["evaluate"]
    for leaf in ("metrics", "dm", "clark-west", "mincer-zarnowitz", "encompassing", "combine")
        @test any(o -> o.name == "result", eval_node.subcmds[leaf].options)
        @test !any(o -> o.name == "model", eval_node.subcmds[leaf].options)
        @test !any(o -> o.name == "save-result", eval_node.subcmds[leaf].options)
        spec = _spec_for_path(["forecast", "evaluate", leaf])
        @test spec !== nothing
        @test isempty(spec.result_types)
        @test any(o -> o.name == "result" && !o.handle, spec.options)
    end
    metrics_leaf = eval_node.subcmds["metrics"]
    sch = _input_schema(metrics_leaf, ["forecast", "evaluate", "metrics"])
    @test haskey(sch["properties"], "result")
    @test !haskey(sch["properties"]["result"], "x-handle")

    @test _forecast_points((forecast = [1.0, 2.0, 3.0],)) == [1.0, 2.0, 3.0]
    err_wr = try
        _forecast_points((not_a_forecast = 1,))
        nothing
    catch e; e; end
    @test err_wr isa CliError
    @test err_wr.code == "data/wrong-result"

    mktempdir() do dir
        n = 20
        y = 5.0 .+ randn(n)
        f1 = y .+ 0.1 .* randn(n)
        f2 = y .+ 0.4 .* randn(n)
        csv = joinpath(dir, "actual.csv")
        CSV.write(csv, DataFrame(y=y))

        p1 = joinpath(dir, "fcst_var.fmod")
        p2 = joinpath(dir, "fcst_bvar.fmod")
        save_model_dispatch(p1, (forecast = f1,))
        save_model_dispatch(p2, (forecast = f2,))

        y2, names, cols = _fceval_load(csv, "y", ""; leaf="metrics", result="$(p1),$(p2)")
        @test names == ["fcst_var", "fcst_bvar"]
        @test length(cols) == 2
        @test cols[1] ≈ f1
        @test cols[2] ≈ f2
        @test length(y2) == n

        a1 = ARIMAForecast(f1, f1, f1, abs.(f1) .* 0.1, n, 0.95)
        a2 = ARIMAForecast(f2, f2, f2, abs.(f2) .* 0.1, n, 0.95)
        save_model_dispatch(joinpath(dir, "stem_a.jld2"), a1)
        save_model_dispatch(joinpath(dir, "stem_b.jld2"), a2)
        _, nstems, c2 = _fceval_load(csv, "y", ""; leaf="metrics",
            result="$(joinpath(dir, "stem_a")),$(joinpath(dir, "stem_b"))")
        @test nstems == ["stem_a", "stem_b"]
        @test c2[1] ≈ f1

        short = joinpath(dir, "short.fmod")
        save_model_dispatch(short, (forecast = f1[1:5],))
        err_sh = try
            _fceval_load(csv, "y", ""; leaf="metrics", result=short)
            nothing
        catch e; e; end
        @test err_sh isa CliError
        @test err_sh.code == "data/shape"

        csv2 = joinpath(dir, "both.csv")
        CSV.write(csv2, DataFrame(y=y, f1=f1, f2=f2))
        y3, n3, c3 = _fceval_load(csv2, "y", "f1,f2"; leaf="metrics")
        @test n3 == ["f1", "f2"]
        @test length(c3) == 2
        @test y3 ≈ y

        err_both = try
            _fceval_load(csv2, "y", "f1,f2"; leaf="metrics", result=p1)
            nothing
        catch e; e; end
        @test err_both isa CliError
        @test err_both.code == "usage/invalid"

        streams = _capture_all() do
            metrics_leaf.handler(; data=csv, actual="y", result="$(p1),$(p2)",
                                 format="json", output="")
        end
        @test occursin("RMSE", streams.out) || occursin("fcst_var", streams.out)
        @test !occursin("MethodError", streams.err)

        dm = eval_node.subcmds["dm"]
        err_ar = try
            dm.handler(; data=csv, actual="y", result=p1, format="json", output="")
            nothing
        catch e; e; end
        @test err_ar isa CliError
        @test err_ar.code == "usage/arity"

        mz = eval_node.subcmds["mincer-zarnowitz"]
        streams = _capture_all() do
            mz.handler(; data=csv, actual="y", result=p1, format="json", output="")
        end
        @test occursin("Mincer-Zarnowitz", streams.out)

        streams = _capture_all() do
            metrics_leaf.handler(; data=csv2, actual="y", forecasts="f1,f2",
                                 format="json", output="")
        end
        @test occursin("RMSE", streams.out)

        err_m = try
            _dispatch_via_app(["forecast", "evaluate", "metrics", csv,
                               "--actual", "y", "--result", p1, "--model", "foo"])
            nothing
        catch e; e; end
        @test err_m !== nothing
        @test occursin("unknown option", sprint(showerror, err_m))
    end
end

@testset "_forecast_points matrix and result kinds" begin
    H = 8
    col1 = collect(1.0:H)
    col2 = collect(100.0:100.0 + H - 1)
    M = hcat(col1, col2)  # H×2 — must not vec() to length 2H
    @test _forecast_points((forecast = M,)) == col1
    @test _forecast_points((forecast = M, varnames=["y1", "y2"]); actual="y1") == col1
    @test _forecast_points((forecast = M, varnames=["y1", "y2"]); actual="y2") == col2
    @test _forecast_points((forecast = M, varnames=["y1", "y2"]); actual="nope") == col1

    err_nn = try
        _forecast_points((forecast = "not-numeric",))
        nothing
    catch e; e; end
    @test err_nn isa CliError
    @test err_nn.code == "data/wrong-result"

    levels = hcat(col1, col2)
    vf = VECMForecast(levels, ones(H, 2), nothing, nothing, H, :none)
    @test _forecast_points(vf) == col1

    fac = ones(H, 1)
    ff = FactorForecast(fac, levels, nothing, nothing, nothing, H, 0.95)
    @test _forecast_points(ff) == col1

    mktempdir() do dir
        csv = joinpath(dir, "actual.csv")
        CSV.write(csv, DataFrame(y1=col1, y2=col2))
        p = joinpath(dir, "fcst.fmod")
        save_model_dispatch(p, (forecast = M, varnames=["y1", "y2"]))
        _, _, cols = _fceval_load(csv, "y1", ""; leaf="metrics", result=p)
        @test length(cols[1]) == H
        @test cols[1] ≈ col1
        _, _, cols2 = _fceval_load(csv, "y2", ""; leaf="metrics", result=p)
        @test cols2[1] ≈ col2
    end
end

@testset "irf --result applies shock filter" begin
    vals = zeros(4, 2, 2)
    vals[:, :, 1] .= 1.0
    vals[:, :, 2] .= 2.0
    irf_obj = ImpulseResponse(vals, nothing, nothing, 4, ["y1", "y2"],
                              ["shock1", "shock2"], :none)
    shocks_of(out) = Set(String(string(r.shock)) for r in JSON3.read(out))
    err_shock = try
        _irf_var(; data="", result=irf_obj, shock=2, format="json", output="")
        nothing
    catch e; e; end
    @test !(err_shock isa CliError && occursin("--shock", err_shock.message))

    streams = _capture_all() do
        _irf_var(; data="", result=irf_obj, shock=2, format="json", output="")
    end
    @test occursin("shock2", streams.out)
    @test !occursin("shock1", streams.out)
    @test !occursin("does not apply with --result", streams.err)

    # Unfiltered callers (irf favar / sdfm) must keep every shock. Filter only
    # when the caller passes an Int — default nothing must not subset to shock 1.
    streams = _capture_all() do
        _rerender_irf_result(irf_obj; format="json", output="",
                             title="Impulse Responses", key="irf")
    end
    @test shocks_of(streams.out) == Set(["shock1", "shock2"])
    @test length(JSON3.read(streams.out)) == 16  # 4 horizons × 2 vars × 2 shocks

    streams = _capture_all() do
        _rerender_irf_result(irf_obj; format="json", output="",
                             title="Impulse Responses", key="irf", shock=1)
    end
    @test shocks_of(streams.out) == Set(["shock1"])
    @test length(JSON3.read(streams.out)) == 8
    @test !occursin("shock2", streams.out)

    for handler in (_irf_favar, _irf_sdfm)
        streams = _capture_all() do
            handler(; data="", result=irf_obj, format="json", output="")
        end
        @test shocks_of(streams.out) == Set(["shock1", "shock2"])
        @test length(JSON3.read(streams.out)) == 16
    end

    mktempdir() do dir
        hp = joinpath(dir, "irf.jld2")
        save_model_dispatch(hp, irf_obj)
        irf_node = register_irf_commands!()
        stem = joinpath(dir, "irf")
        for name in ("favar", "sdfm")
            leaf = irf_node.subcmds[name]
            streams = _capture_all() do
                leaf.handler(; data="", result=stem, format="json", output="")
            end
            @test !occursin("wrong-result", streams.out)
            @test !occursin("MethodError", streams.err)
            @test shocks_of(streams.out) == Set(["shock1", "shock2"])
            @test length(JSON3.read(streams.out)) == 16
        end
    end
end

@testset "test result_types catalog matches returns" begin
    register_test_commands!()
    white = _spec_for_path(["test", "serial", "white"])
    @test white !== nothing
    @test :RegDiagnosticResult in white.result_types
    @test :LMTestResult ∉ white.result_types
    glejser = _spec_for_path(["test", "serial", "glejser"])
    @test :RegDiagnosticResult in glejser.result_types
    chow = _spec_for_path(["test", "stability", "chow"])
    @test :RegDiagnosticResult in chow.result_types
    cusum = _spec_for_path(["test", "stability", "cusum"])
    @test :StabilityResult in cusum.result_types
    @test :LMTestResult ∉ cusum.result_types
    hausman = _spec_for_path(["test", "panel", "hausman"])
    @test :PanelTestResult in hausman.result_types
    @test :LMTestResult ∉ hausman.result_types

    for path in (["test", "identifiability"], ["test", "vif"],
                 ["test", "stability", "recursive-residuals"],
                 ["test", "serial", "arch-lm"],
                 ["test", "serial", "sign-bias"],
                 ["test", "stability", "nyblom"])
        spec = _spec_for_path(path)
        @test spec !== nothing
        @test isempty(spec.result_types)
        @test !any(o -> o.name == "result", spec.options)
        @test !any(o -> o.name == "save-result", spec.options)
    end

    mktempdir() do dir
        csv = _make_csv(dir; T=40, n=3)
        white_leaf = register_test_commands!().subcmds["serial"].subcmds["white"]
        wstem = joinpath(dir, "white")
        _capture() do
            white_leaf.handler(; data=csv, save_result=wstem, format="json", output="")
        end
        @test isfile(wstem * ".jld2")
        loaded = load_model_dispatch(wstem * ".jld2")
        @test nameof(typeof(loaded)) === :RegDiagnosticResult
        streams = _capture_all() do
            white_leaf.handler(; data="", result=wstem, format="json", output="")
        end
        @test !occursin("wrong-result", streams.out)
        @test !occursin("MethodError", streams.err)
        @test occursin("statistic", streams.out) || occursin("White", streams.out)
    end
end

@testset "irf/fevd pvar panel kinds and load_panel_data handle" begin
    register_irf_commands!()
    register_fevd_commands!()
    irf_pvar = _spec_for_path(["irf", "pvar"])
    @test irf_pvar !== nothing
    @test irf_pvar.data_kinds == [:panel, :csv]
    fevd_pvar = _spec_for_path(["fevd", "pvar"])
    @test fevd_pvar !== nothing
    @test fevd_pvar.data_kinds == [:panel, :csv]
    irf_var = _spec_for_path(["irf", "var"])
    @test :timeseries in irf_var.data_kinds

    mktempdir() do dir
        csv = joinpath(dir, "macro.csv")
        CSV.write(csv, DataFrame(y1=randn(20), y2=randn(20)))
        ts = TimeSeriesData(df_to_matrix(CSV.read(csv, DataFrame));
                            varnames=["y1", "y2"])
        save_model_dispatch(joinpath(dir, "ts.jld2"), ts)
        irf_node = register_irf_commands!()
        err = try
            irf_node.subcmds["pvar"].handler(; data=joinpath(dir, "ts"),
                                            format="json", output="")
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "data/wrong-kind"

        panel_csv = _make_panel_csv(dir; G=4, T_per=10, n=2)
        pd = xtset(CSV.read(panel_csv, DataFrame), :group, :time)
        ph = joinpath(dir, "panel.jld2")
        save_model_dispatch(ph, pd)
        loaded = load_panel_data(ph, "", "")
        @test nameof(typeof(loaded)) === :PanelData
        @test loaded.varnames == pd.varnames

        err_csv = try
            load_panel_data(panel_csv, "", "")
            nothing
        catch e; e; end
        @test err_csv isa CliError
        @test err_csv.code == "usage/missing"

        err_est = try
            _estimate_pvar(; data=panel_csv, format="json", output="")
            nothing
        catch e; e; end
        @test err_est isa CliError
        @test err_est.code == "usage/missing"
    end
end

@testset "data filter kinds are timeseries+csv" begin
    register_data_commands!()
    spec = _spec_for_path(["data", "filter"])
    @test spec !== nothing
    @test spec.data_kinds == [:timeseries, :csv]
    @test :panel ∉ spec.data_kinds
    @test :cross_section ∉ spec.data_kinds

    mktempdir() do dir
        panel_csv = _make_panel_csv(dir; G=4, T_per=8, n=2)
        pd = xtset(CSV.read(panel_csv, DataFrame), :group, :time)
        save_model_dispatch(joinpath(dir, "panel.jld2"), pd)
        filt = register_data_commands!().subcmds["filter"]
        err = try
            filt.handler(; data=joinpath(dir, "panel"), method="hp",
                         format="json", output="")
            nothing
        catch e; e; end
        @test err isa CliError
        @test err.code == "data/wrong-kind"
    end
end

@testset "serialized .jls and plain .jld2 tabular handles" begin
    import JLD2
    mktempdir() do dir
        # 1. _is_handle_path & resolve_stem (.jld2 -> .jls -> .csv / .fmod)
        @test _is_handle_path("foo.jls")
        @test _is_handle_path("FOO.JLS")
        jls_df = joinpath(dir, "d.jls")
        open(io -> Serialization.serialize(io, DataFrame(y1=[1.0, 2.0, 3.0], y2=[4.0, 5.0, 6.0])), jls_df, "w")
        @test resolve_stem(joinpath(dir, "d"); slot=:data) == jls_df
        @test resolve_stem(joinpath(dir, "d"); slot=:result) == jls_df

        fmod_only = joinpath(dir, "legacy.fmod")
        save_model_handle(fmod_only, estimate_var(randn(20, 2), 1; varnames=["a", "b"]))
        @test resolve_stem(joinpath(dir, "legacy"); slot=:result) == fmod_only

        # 2. save_model_dispatch / load_model_dispatch round-trip on .jls
        m_jls = joinpath(dir, "var_m.jls")
        m_orig = estimate_var(randn(24, 2), 1; varnames=["a", "b"])
        save_model_dispatch(m_jls, m_orig)
        m_back = load_model_dispatch(m_jls)
        @test typeof(m_back) == typeof(m_orig)

        # 3. Tabular .jls payloads: DataFrame, Matrix, Vector, NamedTuple
        df_loaded = load_data(jls_df)
        @test names(df_loaded) == ["y1", "y2"]
        @test nrow(df_loaded) == 3
        Y_df, vn_df = load_multivariate_data(joinpath(dir, "d"))
        @test size(Y_df) == (3, 2)
        @test vn_df == ["y1", "y2"]

        jls_mat = joinpath(dir, "mat.jls")
        open(io -> Serialization.serialize(io, [1.0 2.0; 3.0 4.0; 5.0 6.0]), jls_mat, "w")
        Y_mat, vn_mat = load_multivariate_data(jls_mat)
        @test size(Y_mat) == (3, 2)
        @test vn_mat == ["x1", "x2"]

        jls_vec = joinpath(dir, "vec.jls")
        open(io -> Serialization.serialize(io, [10.0, 20.0, 30.0]), jls_vec, "w")
        y_vec, nm_vec = load_univariate_series(jls_vec, 1)
        @test y_vec == [10.0, 20.0, 30.0]
        @test nm_vec == "y"

        jls_nt = joinpath(dir, "nt.jls")
        open(io -> Serialization.serialize(io, (a=[1.0, 2.0], b=[3.0, 4.0])), jls_nt, "w")
        df_nt = resolve_data(jls_nt)
        @test df_nt isa DataFrame
        @test names(df_nt) == ["a", "b"]

        # 4. Plain .jld2 user archives ("data" key and single-key archive)
        raw_jld = joinpath(dir, "raw.jld2")
        JLD2.jldsave(raw_jld; data=DataFrame(y1=[1.0, 2.0], y2=[3.0, 4.0]), meta="extra")
        df_raw = load_data(raw_jld)
        @test names(df_raw) == ["y1", "y2"]
        Y_raw, vn_raw = load_multivariate_data(joinpath(dir, "raw"))
        @test size(Y_raw) == (2, 2)
        @test vn_raw == ["y1", "y2"]

        single_jld = joinpath(dir, "single.jld2")
        JLD2.jldsave(single_jld; df=DataFrame(y=[5.0, 6.0]))
        df_single = resolve_data(single_jld)
        @test df_single isa DataFrame
        @test names(df_single) == ["y"]

        # 5. Review Focus #3: missing values in serialized DataFrame -> data/missing-values
        miss_jld = joinpath(dir, "miss.jld2")
        JLD2.jldsave(miss_jld; data=DataFrame(y=[1.0, missing, 3.0], x=[2.0, 4.0, 6.0]))
        err_miss = try
            load_multivariate_data(miss_jld)
            nothing
        catch e; e; end
        @test err_miss isa CliError
        @test err_miss.code == "data/missing-values"

        # 6. Review Focus #4: corrupt .jls, ambiguous multi-key .jld2, empty DataFrame
        bad_jls = joinpath(dir, "bad.jls")
        write(bad_jls, UInt8[0x37, 0x4a, 0x4c])  # truncated Serialization stream
        err_bad_jls = try
            load_model_dispatch(bad_jls)
            nothing
        catch e; e; end
        @test err_bad_jls isa CliError
        @test err_bad_jls.code == "data/serialization"

        amb_jld = joinpath(dir, "amb.jld2")
        JLD2.jldsave(amb_jld; a=[1.0, 2.0], b=[3.0, 4.0])
        err_amb = try
            load_model_dispatch(amb_jld)
            nothing
        catch e; e; end
        @test err_amb isa CliError
        @test err_amb.code == "data/serialization"

        empty_jls = joinpath(dir, "empty.jls")
        open(io -> Serialization.serialize(io, DataFrame()), empty_jls, "w")
        err_empty = try
            load_data(empty_jls)
            nothing
        catch e; e; end
        @test err_empty isa CliError
        @test err_empty.code == "data/empty"
    end
end

@testset "pipeline serialized writers and secondary data flags" begin
    import JLD2
    mktempdir() do dir
        # 1. data simulate --save-data (.jld2 stem & .jls)
        dnode = register_data_commands!()
        sim_node = dnode.subcmds["simulate"]
        @test any(o -> o.name == "save-data", sim_node.subcmds["var"].options)
        sim_var_stem = joinpath(dir, "sim_var")
        _capture() do
            sim_node.subcmds["var"].handler(; periods=40, burn=10, seed=7,
                                            save_data=sim_var_stem, format="json", output="")
        end
        @test isfile(sim_var_stem * ".jld2")
        ts_sim = load_model_dispatch(sim_var_stem * ".jld2")
        @test ts_sim isa TimeSeriesData
        @test size(to_matrix(ts_sim), 1) == 40
        @test !("time" in varnames(ts_sim))

        sim_pan_stem = joinpath(dir, "sim_pan")
        _capture() do
            sim_node.subcmds["panel"].handler(; n=6, periods=8, seed=7,
                                              save_data=sim_pan_stem, format="json", output="")
        end
        @test isfile(sim_pan_stem * ".jld2")
        pan_sim = load_model_dispatch(sim_pan_stem * ".jld2")
        @test pan_sim isa PanelData

        sim_xs_jls = joinpath(dir, "sim_xs.jls")
        _capture() do
            sim_node.subcmds["cross-section"].handler(; n=30, seed=7,
                                                      save_data=sim_xs_jls, format="json", output="")
        end
        @test isfile(sim_xs_jls)
        @test load_model_dispatch(sim_xs_jls) isa CrossSectionData

        # 2. data load -o .jld2 / .jls
        sl_jld = joinpath(dir, "sl.jld2")
        _data_load(; name=":stackloss", output=sl_jld)
        @test load_model_dispatch(sl_jld) isa CrossSectionData

        dk_jld = joinpath(dir, "dk.jld2")
        _data_load(; name=":denmark", vars="LRM,LRY", output=dk_jld)
        dk_obj = load_model_dispatch(dk_jld)
        @test dk_obj isa TimeSeriesData
        @test varnames(dk_obj) == ["LRM", "LRY"]

        gr_jls = joinpath(dir, "gr.jls")
        _data_load(; name=":grunfeld", output=gr_jls)
        @test load_model_dispatch(gr_jls) isa PanelData

        # 3. data fix <csv> -o .jls allowed, while -o .jld2 still guarded
        csv = joinpath(dir, "raw.csv")
        CSV.write(csv, DataFrame(y1=[1.0, 2.0, 3.0, 4.0], y2=[2.0, 3.0, 4.0, 5.0]))
        fixed_jls = joinpath(dir, "fixed.jls")
        _data_fix(; data=csv, output=fixed_jls)
        @test isfile(fixed_jls)

        err_jld_guard = try
            _data_fix(; data=csv, output=joinpath(dir, "nope.jld2"))
            nothing
        catch e; e; end
        @test err_jld_guard isa CliError
        @test err_jld_guard.code == "usage/invalid"

        # 4. data import promotes .jls and plain .jld2 tabular data, rejects existing typed containers
        imp_stem = joinpath(dir, "imported")
        _capture() do
            _data_import(; data=fixed_jls, kind="timeseries", output=imp_stem, format="json")
        end
        @test isfile(imp_stem * ".jld2")
        @test load_model_dispatch(imp_stem * ".jld2") isa TimeSeriesData

        plain_jld = joinpath(dir, "plain_tab.jld2")
        JLD2.jldsave(plain_jld; data=DataFrame(y1=[1.0, 2.0, 3.0], y2=[4.0, 5.0, 6.0]))
        imp_plain = joinpath(dir, "imported_plain")
        _capture() do
            _data_import(; data=plain_jld, kind="timeseries", output=imp_plain, format="json")
        end
        @test load_model_dispatch(imp_plain * ".jld2") isa TimeSeriesData

        err_imp_typed = try
            _data_import(; data=imp_stem * ".jld2", kind="timeseries", output=joinpath(dir, "dup"))
            nothing
        catch e; e; end
        @test err_imp_typed isa CliError
        @test err_imp_typed.code == "usage/invalid"

        # 5. Secondary data flags: _load_midas_data (hf_data), _nowcast_news (data_old), _fceval_load (data + .jls result)
        lf_jls = joinpath(dir, "lf.jls")
        hf_jld = joinpath(dir, "hf.jld2")
        open(io -> Serialization.serialize(io, DataFrame(gdp=collect(1.0:10.0))), lf_jls, "w")
        save_model_dispatch(hf_jld, TimeSeriesData(reshape(collect(1.0:30.0), :, 1); varnames=["ind"]))
        y_lf, x_hf, ynm, xnm = _load_midas_data(joinpath(dir, "lf"), 1, joinpath(dir, "hf"), 1; m=3)
        @test length(y_lf) == 10
        @test length(x_hf) == 30
        @test ynm == "gdp"
        @test xnm == "ind"

        old_mat = randn(24, 3)
        new_mat = copy(old_mat)
        old_mat[end, end] = NaN
        save_model_dispatch(joinpath(dir, "v_old.jld2"), TimeSeriesData(old_mat; varnames=["m1", "m2", "q1"]))
        open(io -> Serialization.serialize(io, DataFrame(new_mat, ["m1", "m2", "q1"])), joinpath(dir, "v_new.jls"), "w")
        nc_out = _capture() do
            _nowcast_news(; data_new=joinpath(dir, "v_new"), data_old=joinpath(dir, "v_old"),
                          monthly_vars=2, quarterly_vars=1, method="dfm", factors=1, lags=1, format="json")
        end
        @test occursin("news_impact", nc_out)

        fc_res_jls = joinpath(dir, "fc1.jls")
        save_model_dispatch(fc_res_jls, (forecast=collect(1.0:10.0) .+ 0.1,))
        y_ev, nms_ev, cols_ev = _fceval_load(joinpath(dir, "lf"), "gdp", ""; leaf="metrics", result=joinpath(dir, "fc1"))
        @test length(y_ev) == 10
        @test nms_ev == ["fc1"]
        @test length(cols_ev[1]) == 10
    end
end

@testset "positional model auto-routing, coexistence, and <model> passthrough" begin
    mktempdir() do dir
        # 1. Positional <data> auto-routes saved model (.jld2, stem, .jls) to kwargs[:model]
        m = estimate_var(randn(40, 2), 2; varnames=["y1", "y2"])
        save_model_dispatch(joinpath(dir, "vmod.jld2"), m)
        save_model_dispatch(joinpath(dir, "vmod_jls.jls"), m)

        out_jld = _capture() do
            _dispatch_via_app(["irf", "var", joinpath(dir, "vmod.jld2"), "--horizons", "4", "--format", "json"])
        end
        @test occursin("irf", out_jld)

        out_stem = _capture() do
            _dispatch_via_app(["irf", "var", joinpath(dir, "vmod"), "--horizons", "4", "--format", "json"])
        end
        @test occursin("irf", out_stem)

        out_jls = _capture() do
            _dispatch_via_app(["irf", "var", joinpath(dir, "vmod_jls.jls"), "--horizons", "4", "--format", "json"])
        end
        @test occursin("irf", out_jls)

        # 2. Conflict: model handle in <data> AND --model throws usage/invalid
        err_conf = try
            _capture() do
                _dispatch_via_app(["irf", "var", joinpath(dir, "vmod.jld2"), "--model", joinpath(dir, "vmod.jld2")])
            end
            nothing
        catch e; e; end
        @test err_conf isa CliError
        @test err_conf.code == "usage/invalid"

        # 3. Review Focus #2 (coexistence): data handle in <data> + model handle in --model
        ts_new = TimeSeriesData(randn(20, 2); varnames=["y1", "y2"])
        save_model_dispatch(joinpath(dir, "new_ts.jld2"), ts_new)
        out_pred = _capture() do
            _dispatch_via_app(["predict", "multivariate", "var", joinpath(dir, "new_ts.jld2"),
                               "--model", joinpath(dir, "vmod.jld2"), "--format", "json"])
        end
        @test occursin("fitted", out_pred) || occursin("y1", out_pred)

        # 4. Tabular .jls accepted on :csv leaves via wrap_legacy, rejected on non-:csv leaves (data export)
        tab_jls = joinpath(dir, "tab.jls")
        open(io -> Serialization.serialize(io, DataFrame(y1=randn(30), y2=randn(30))), tab_jls, "w")
        out_est_jls = _capture() do
            _dispatch_via_app(["estimate", "multivariate", "var", tab_jls, "--lags", "1", "--format", "json"])
        end
        @test occursin("y1", out_est_jls)

        err_exp = try
            _dispatch_via_app(["data", "export", tab_jls, "-o", joinpath(dir, "out.csv")])
            nothing
        catch e; e; end
        @test err_exp isa CliError
        @test err_exp.code == "data/wrong-kind"

        # 5. Review Focus #1: positional <model> passthrough ("huggett" / "rbc.toml" vs on-disk handle) + bind_args --result
        seen_model = Ref{Any}(nothing)
        seen_result = Ref{Any}(nothing)
        pos_spec = CommandSpec(
            path=["hadsge", "irf"],
            summary="test positional model",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing)],
            options=[RESULT_OPTION, OptionSpec(name="format", default="table"), OptionSpec(name="output", default="")],
            model_types=[:VARModel],
            result_types=[:ImpulseResponse],
            handler=wrap_legacy((; model="", result=nothing, format="table", output="") -> begin
                seen_model[] = model
                seen_result[] = result
                nothing
            end),
        )
        pos_leaf = to_leaf(pos_spec)
        # Extensionless builtin token passes through as String when no huggett.{jld2,jls,fmod} exists
        pos_leaf.handler(; model="huggett", format="json", output="")
        @test seen_model[] === "huggett"

        # On-disk stem loads typed model handle
        pos_leaf.handler(; model=joinpath(dir, "vmod"), format="json", output="")
        @test seen_model[] isa VARModel

        # bind_args allows omitting required <model> when --result is supplied
        parsed_res = tokenize(["--result", joinpath(dir, "irf_r.jld2")])
        bound_res = bind_args(parsed_res, pos_leaf)
        @test bound_res.model == ""

        # schema x-handle on positional ArgSpec(name="model") when model_types nonempty
        register!([pos_spec])
        sch_pos = _input_schema(pos_leaf, ["hadsge", "irf"])
        @test haskey(sch_pos["properties"]["model"], "x-handle")
        @test sch_pos["properties"]["model"]["x-handle"]["role"] == "model"
        @test "VARModel" in sch_pos["properties"]["model"]["x-handle"]["types"]
    end
end

@testset "SVAR/SVEC and post-estimation test model handles" begin
    mktempdir() do dir
        ts_csv = joinpath(dir, "macro.csv")
        CSV.write(ts_csv, DataFrame(y1=cumsum(randn(60)), y2=cumsum(randn(60))))

        # 1. estimate multivariate svar --save-model -> irf/fevd/hd var (positional & --model)
        svar_stem = joinpath(dir, "svar_m")
        _capture() do
            _dispatch_via_app(["estimate", "multivariate", "svar", ts_csv, "--lags", "2",
                               "--save-model", svar_stem, "--format", "json"])
        end
        @test isfile(svar_stem * ".jld2")

        out_svar_irf = _capture() do
            _dispatch_via_app(["irf", "var", svar_stem, "--horizons", "4", "--ci", "none", "--format", "json"])
        end
        @test occursin("irf", out_svar_irf)

        out_svar_fevd = _capture() do
            _dispatch_via_app(["fevd", "var", svar_stem, "--horizons", "4", "--format", "json"])
        end
        @test occursin("fevd", out_svar_fevd)

        out_svar_hd = _capture() do
            _dispatch_via_app(["hd", "var", "--model", svar_stem, "--format", "json"])
        end
        @test occursin("historical_decomposition", out_svar_hd)

        # 2. estimate multivariate svec --save-model -> irf/fevd/hd vecm
        svec_stem = joinpath(dir, "svec_m")
        _capture() do
            _dispatch_via_app(["estimate", "multivariate", "svec", ts_csv, "--lags", "2", "--rank", "1",
                               "--save-model", svec_stem, "--format", "json"])
        end
        @test isfile(svec_stem * ".jld2")

        out_svec_irf = _capture() do
            _dispatch_via_app(["irf", "vecm", svec_stem, "--horizons", "4", "--ci", "none", "--format", "json"])
        end
        @test occursin("vecm_irf", out_svec_irf)

        out_svec_fevd = _capture() do
            _dispatch_via_app(["fevd", "vecm", svec_stem, "--horizons", "4", "--format", "json"])
        end
        @test occursin("vecm_fevd", out_svec_fevd)

        out_svec_hd = _capture() do
            _dispatch_via_app(["hd", "vecm", svec_stem, "--format", "json"])
        end
        @test occursin("vecm_historical_decomposition", out_svec_hd)

        # 3. Post-estimation test leaves accept saved models (positional and --model)
        var_stem = joinpath(dir, "var_m")
        save_model_dispatch(var_stem * ".jld2", estimate_var(randn(50, 2), 2; varnames=["y1", "y2"]))

        out_gr_pos = _capture() do
            _dispatch_via_app(["test", "multivariate", "granger", var_stem * ".jld2", "--format", "json"])
        end
        @test occursin("granger_causality", out_gr_pos)

        out_gr_opt = _capture() do
            _dispatch_via_app(["test", "multivariate", "granger", "--model", var_stem, "--format", "json"])
        end
        @test occursin("granger_causality", out_gr_opt)

        # Legacy domain --model var with CSV still works
        out_gr_dom = _capture() do
            _dispatch_via_app(["test", "multivariate", "granger", ts_csv, "--model", "var", "--format", "json"])
        end
        @test occursin("granger_causality", out_gr_dom)

        # VECM weak-exog with saved VECMModel
        vecm_stem = joinpath(dir, "vecm_m")
        save_model_dispatch(vecm_stem * ".jld2", estimate_vecm(randn(50, 2), 2; rank=1, varnames=["y1", "y2"]))
        out_vex = _capture() do
            _dispatch_via_app(["test", "vecm", "weak-exog", vecm_stem, "--vars", "1", "--format", "json"])
        end
        @test occursin("vecm_weak_exogeneity", out_vex)

        # PVAR hansen-j and mmsc with saved PVARModel
        pan_df = DataFrame(id=repeat(1:6, inner=10), t=repeat(1:10, outer=6), y1=randn(60), y2=randn(60))
        pd = xtset(pan_df, :id, :t)
        pvar_stem = joinpath(dir, "pvar_m")
        save_model_dispatch(pvar_stem * ".jld2", estimate_pvar(pd, 1))
        out_hj = _capture() do
            _dispatch_via_app(["test", "pvar", "hansen-j", pvar_stem, "--format", "json"])
        end
        @test occursin("hansen_j_test", out_hj)
        out_mmsc = _capture() do
            _dispatch_via_app(["test", "pvar", "mmsc", "--model", pvar_stem, "--format", "json"])
        end
        @test occursin("mmsc_results", out_mmsc)

        # Dispersion with saved PoissonModel
        cnt_csv = joinpath(dir, "cnt.csv")
        CSV.write(cnt_csv, DataFrame(y=rand(0:5, 50), x1=randn(50), x2=randn(50)))
        pois_stem = joinpath(dir, "pois_m")
        _capture() do
            _dispatch_via_app(["estimate", "choice", "poisson", cnt_csv, "--dep", "y",
                               "--save-model", pois_stem, "--format", "json"])
        end
        out_disp = _capture() do
            _dispatch_via_app(["test", "dispersion", pois_stem, "--format", "json"])
        end
        @test occursin("overdispersion_test", out_disp)

        # VIF with saved RegModel
        reg_stem = joinpath(dir, "reg_m")
        _capture() do
            _dispatch_via_app(["estimate", "regression", "reg", cnt_csv, "--dep", "y",
                               "--save-model", reg_stem, "--format", "json"])
        end
        out_vif = _capture() do
            _dispatch_via_app(["test", "vif", "--model", reg_stem, "--format", "json"])
        end
        @test occursin("variance_inflation_factors", out_vif)

        # Serial correlation diagnostics (ljung-box, durbin-watson, box-pierce, arch-lm, bartlett-wn) on saved model
        out_lb = _capture() do
            _dispatch_via_app(["test", "serial", "ljung-box", var_stem, "--column", "1", "--format", "json"])
        end
        @test occursin("ljung_box_squared_test", out_lb)
        out_dw = _capture() do
            _dispatch_via_app(["test", "serial", "durbin-watson", "--model", reg_stem, "--format", "json"])
        end
        @test occursin("durbin_watson_test", out_dw)
    end
end

@testset "dsge, hadsge, and policy saved model & result handles" begin
    mktempdir() do dir
        rbc_toml = joinpath(dir, "rbc.toml")
        write(rbc_toml, """
        [model]
        parameters = { rho = 0.9 }
        endogenous = ["Y", "C", "K"]
        exogenous = ["e"]
        [[model.equations]]
        expr = "Y[t] = C[t] + K[t]"
        [[model.equations]]
        expr = "C[t] = rho * Y[t]"
        [[model.equations]]
        expr = "K[t] = e[t]"
        """)
        obs_csv = joinpath(dir, "obs1.csv")
        CSV.write(obs_csv, DataFrame(Y=randn(40)))
        obs3_csv = joinpath(dir, "obs3.csv")
        CSV.write(obs3_csv, DataFrame(infl=randn(60), ygap=randn(60), rate=randn(60)))

        # 1. RA DSGE saved solutions + OccBin (#246) + frequentist estimate (#246) + data simulate dsge
        rbc_sol = joinpath(dir, "rbc_sol")
        _capture() do
            _dispatch_via_app(["dsge", "solve", rbc_toml, "--save-model", rbc_sol, "--format", "json"])
        end
        @test isfile(rbc_sol * ".jld2")

        out_dirf = _capture() do
            _dispatch_via_app(["dsge", "irf", rbc_sol, "--horizon", "6", "--format", "json"])
        end
        @test occursin("dsge_irf", out_dirf)

        out_dfevd = _capture() do
            _dispatch_via_app(["dsge", "fevd", rbc_sol, "--horizon", "6", "--format", "json"])
        end
        @test occursin("dsge_fevd", out_dfevd)

        out_dsim = _capture() do
            _dispatch_via_app(["dsge", "simulate", rbc_sol, "--periods", "12", "--burn", "4", "--format", "json"])
        end
        @test occursin("dsge_simulation", out_dsim)

        out_dhd = _capture() do
            _dispatch_via_app(["dsge", "hd", rbc_sol, "--data", obs_csv, "--observables", "Y", "--format", "json"])
        end
        @test occursin("dsge_historical_decomposition", out_dhd)

        out_datasim_dsge = _capture() do
            _dispatch_via_app(["data", "simulate", "dsge", rbc_sol, "--periods", "12", "--burn", "4", "--format", "json"])
        end
        @test occursin("simulated_data", out_datasim_dsge)

        pert_sol = joinpath(dir, "pert_sol")
        _capture() do
            _dispatch_via_app(["dsge", "solve", rbc_toml, "--method", "perturbation", "--order", "2",
                               "--save-model", pert_sol, "--format", "json"])
        end
        @test isfile(pert_sol * ".jld2")
        out_dmom = _capture() do
            _dispatch_via_app(["dsge", "moments", pert_sol, "--lags", "1", "--format", "json"])
        end
        @test occursin("dsge_theoretical_moments", out_dmom)

        ob_sol = joinpath(dir, "ob_sol")
        _capture() do
            _dispatch_via_app(["dsge", "solve", rbc_toml, "--constraint", "Y[t] >= -0.5",
                               "--periods", "10", "--save-model", ob_sol, "--format", "json"])
        end
        @test isfile(ob_sol * ".jld2")
        out_ob_irf = _capture() do
            _dispatch_via_app(["dsge", "irf", ob_sol, "--horizon", "6", "--format", "json"])
        end
        @test occursin("occbin_irf", out_ob_irf)

        dsge_est = joinpath(dir, "dsge_est")
        _capture() do
            _dispatch_via_app(["dsge", "estimate", rbc_toml, "--data", obs3_csv, "--params", "rho",
                               "--save-model", dsge_est, "--format", "json"])
        end
        @test isfile(dsge_est * ".jld2")

        # 2. Bayesian DSGE saved posterior (#246 + #240)
        bdsge_stem = joinpath(dir, "bdsge")
        _capture() do
            _dispatch_via_app(["dsge", "bayes", "estimate", rbc_toml, "--data", obs_csv,
                               "--params", "rho", "--prior", "rho ~ beta(2, 2)",
                               "--n-smc", "10", "--n-particles", "20", "--n-draws", "10",
                               "--save-model", bdsge_stem, "--format", "json"])
        end
        @test isfile(bdsge_stem * ".jld2")

        out_birf = _capture() do
            _dispatch_via_app(["dsge", "bayes", "irf", bdsge_stem, "--horizon", "5", "--n-draws", "5", "--format", "json"])
        end
        @test occursin("bayesian_dsge_irf", out_birf)

        out_bfevd = _capture() do
            _dispatch_via_app(["dsge", "bayes", "fevd", bdsge_stem, "--horizon", "5", "--n-draws", "5", "--format", "json"])
        end
        @test occursin("bayesian_dsge_fevd", out_bfevd)

        out_bsim = _capture() do
            _dispatch_via_app(["dsge", "bayes", "simulate", bdsge_stem, "--periods", "8", "--n-draws", "5", "--format", "json"])
        end
        @test occursin("bayesian_dsge_simulation", out_bsim)

        out_bsum = _capture() do
            _dispatch_via_app(["dsge", "bayes", "summary", bdsge_stem, "--format", "json"])
        end
        @test occursin("bayesian_dsge_posterior_summary", out_bsum)

        out_bdiag = _capture() do
            _dispatch_via_app(["dsge", "bayes", "mcmc-diag", bdsge_stem, "--format", "json"])
        end
        @test occursin("mcmc_convergence_diagnostics", out_bdiag)

        out_bhd = _capture() do
            _dispatch_via_app(["dsge", "bayes", "hd", bdsge_stem, "--data", obs_csv, "--observables", "Y",
                               "--n-hd-draws", "5", "--format", "json"])
        end
        @test occursin("bayesian_dsge_historical_decomposition", out_bhd)

        # 3. HA-DSGE saved solutions + builtin name passthrough (Review Focus #1)
        hasol_stem = joinpath(dir, "hasol")
        _capture() do
            _dispatch_via_app(["hadsge", "solve", "huggett", "--method", "reiter",
                               "--save-model", hasol_stem, "--format", "json"])
        end
        @test isfile(hasol_stem * ".jld2")

        out_hairf = _capture() do
            _dispatch_via_app(["hadsge", "irf", hasol_stem, "--horizon", "6", "--format", "json"])
        end
        @test occursin("ha_dsge_irf", out_hairf)

        out_hafevd = _capture() do
            _dispatch_via_app(["hadsge", "fevd", hasol_stem, "--horizon", "6", "--format", "json"])
        end
        @test occursin("ha_dsge_fevd", out_hafevd)

        out_hasim = _capture() do
            _dispatch_via_app(["hadsge", "simulate", hasol_stem, "--periods", "10", "--format", "json"])
        end
        @test occursin("ha_dsge_simulation", out_hasim)

        out_hadirf = _capture() do
            _dispatch_via_app(["hadsge", "distribution-irf", hasol_stem, "--horizon", "6", "--format", "json"])
        end
        @test occursin("ha_distribution_irf", out_hadirf)

        out_haiirf = _capture() do
            _dispatch_via_app(["hadsge", "inequality-irf", hasol_stem, "--horizon", "6", "--format", "json"])
        end
        @test occursin("ha_inequality_irf", out_haiirf)

        out_hapan = _capture() do
            _dispatch_via_app(["hadsge", "simulate-panel", hasol_stem, "--n-agents", "20", "--periods", "8", "--format", "json"])
        end
        @test occursin("ha_panel_simulation_summary", out_hapan)

        out_datasim_ha = _capture() do
            _dispatch_via_app(["data", "simulate", "ha", hasol_stem, "--periods", "8", "--format", "json"])
        end
        @test occursin("simulated_data", out_datasim_ha)

        # Review Focus #1: builtin name "huggett" with no file on disk passes through as String
        out_hairf_builtin = _capture() do
            _dispatch_via_app(["hadsge", "irf", "huggett", "--horizon", "6", "--format", "json"])
        end
        @test occursin("ha_dsge_irf", out_hairf_builtin)

        kssol_stem = joinpath(dir, "kssol")
        _capture() do
            _dispatch_via_app(["hadsge", "solve", "krusell-smith", "--method", "krusell-smith",
                               "--save-model", kssol_stem, "--format", "json"])
        end
        @test isfile(kssol_stem * ".jld2")
        out_haacc = _capture() do
            _dispatch_via_app(["hadsge", "accuracy", kssol_stem, "--t-sim", "120", "--t-burn", "20", "--format", "json"])
        end
        @test occursin("den_haan_accuracy", out_haacc)

        # 4. Policy saved model & --save-result / --result handles
        var_stem = joinpath(dir, "pol_var")
        save_model_dispatch(var_stem * ".jld2",
            estimate_var(randn(60, 3), 2; varnames=["infl", "ygap", "rate"]))
        svar_stem = joinpath(dir, "pol_svar")
        _capture() do
            _dispatch_via_app(["estimate", "multivariate", "svar", obs3_csv, "--lags", "2",
                               "--save-model", svar_stem, "--format", "json"])
        end

        eff_stem = joinpath(dir, "pol_eff")
        out_peff = _capture() do
            _dispatch_via_app(["policy", "effects", "var", var_stem * ".jld2",
                               "--horizon", "6", "--shocks", "3",
                               "--outcomes", "infl=1,ygap=2", "--instruments", "rate=3",
                               "--save-result", eff_stem, "--format", "json"])
        end
        @test occursin("policy_causal_effects_menu", out_peff)
        @test isfile(eff_stem * ".jld2")

        out_peff_rerender = _capture() do
            _dispatch_via_app(["policy", "effects", "var", "--result", eff_stem, "--format", "json"])
        end
        @test occursin("policy_causal_effects_menu", out_peff_rerender)

        out_peff_svar = _capture() do
            _dispatch_via_app(["policy", "effects", "var", svar_stem,
                               "--horizon", "6", "--shocks", "3",
                               "--outcomes", "infl=1,ygap=2", "--instruments", "rate=3", "--format", "json"])
        end
        @test occursin("policy_causal_effects_menu", out_peff_svar)

        cf_stem = joinpath(dir, "pol_cf")
        out_pcf = _capture() do
            _dispatch_via_app(["policy", "counterfactual", "var", "--model", var_stem,
                               "--horizon", "6", "--shocks", "3", "--nonpolicy-shock", "1",
                               "--outcomes", "infl=1,ygap=2", "--instruments", "rate=3",
                               "--rule", "taylor", "--save-result", cf_stem, "--format", "json"])
        end
        @test occursin("policy_counterfactual_paths", out_pcf)
        @test isfile(cf_stem * ".jld2")

        out_pcf_rerender = _capture() do
            _dispatch_via_app(["policy", "counterfactual", "var", "--result", cf_stem, "--format", "json"])
        end
        @test occursin("policy_counterfactual_paths", out_pcf_rerender)

        hist_stem = joinpath(dir, "pol_hist")
        out_phist = _capture() do
            _dispatch_via_app(["policy", "history", "var", var_stem,
                               "--horizon", "8", "--shocks", "3",
                               "--outcomes", "infl=1,ygap=2", "--instruments", "rate=3",
                               "--rule", "taylor", "--t-range", "5:8",
                               "--save-result", hist_stem, "--format", "json"])
        end
        @test occursin("counterfactual_history", out_phist)
        @test isfile(hist_stem * ".jld2")

        out_phist_rerender = _capture() do
            _dispatch_via_app(["policy", "history", "var", "--result", hist_stem, "--format", "json"])
        end
        @test occursin("counterfactual_history", out_phist_rerender)

        news_stem = joinpath(dir, "pol_news")
        out_pnews = _capture() do
            _dispatch_via_app(["policy", "news", "dsge", rbc_sol,
                               "--policy-shock", "e", "--outcomes", "y=Y", "--instruments", "k=K",
                               "--horizon", "6", "--save-result", news_stem, "--format", "json"])
        end
        @test occursin("policy_causal_effects_menu", out_pnews)
        @test isfile(news_stem * ".jld2")

        out_pnews_rerender = _capture() do
            _dispatch_via_app(["policy", "news", "dsge", "--result", news_stem, "--format", "json"])
        end
        @test occursin("policy_causal_effects_menu", out_pnews_rerender)

        fs_stem = joinpath(dir, "pol_fs")
        out_pfs = _capture() do
            _dispatch_via_app(["policy", "sufficiency", "dsge", rbc_sol,
                               "--observables", "Y", "--horizon", "6",
                               "--save-result", fs_stem, "--format", "json"])
        end
        @test occursin("forecast_sufficiency_fev_ratios", out_pfs)
        @test isfile(fs_stem * ".jld2")

        out_pfs_rerender = _capture() do
            _dispatch_via_app(["policy", "sufficiency", "dsge", "--result", fs_stem, "--format", "json"])
        end
        @test occursin("forecast_sufficiency_fev_ratios", out_pfs_rerender)

        # dsge moments on saved DSGESolution + policy effects lp on saved LPModel + policy spanning dual-positional
        out_dmom = _capture() do
            _dispatch_via_app(["dsge", "moments", rbc_sol, "--lags", "2", "--format", "json"])
        end
        @test occursin("dsge_theoretical_moments", out_dmom)

        lp_stem = joinpath(dir, "pol_lp")
        _capture() do
            _dispatch_via_app(["estimate", "multivariate", "lp", obs3_csv, "--horizons", "6",
                               "--shock", "3", "--save-model", lp_stem, "--format", "json"])
        end
        out_plp = _capture() do
            _dispatch_via_app(["policy", "effects", "lp", lp_stem,
                               "--horizon", "6", "--outcomes", "infl=1,ygap=2",
                               "--instruments", "rate=3", "--format", "json"])
        end
        @test occursin("policy_causal_effects_menu", out_plp)

        sp_stem = joinpath(dir, "pol_span")
        out_pspan = _capture() do
            _dispatch_via_app(["policy", "spanning", "var", obs3_csv, rbc_sol,
                               "--horizon", "6", "--shocks", "3", "--nonpolicy-shock", "1",
                               "--outcomes", "infl=1", "--instruments", "rate=3",
                               "--model-outcomes", "infl=Y", "--model-instruments", "rate=K",
                               "--policy-shock", "e", "--rule", "rate-peg",
                               "--save-result", sp_stem, "--format", "json"])
        end
        @test occursin("spanning_verdict", out_pspan)
        @test isfile(sp_stem * ".jld2")
        out_pspan_rerender = _capture() do
            _dispatch_via_app(["policy", "spanning", "var", "--result", sp_stem, "--format", "json"])
        end
        @test occursin("spanning_verdict", out_pspan_rerender)
    end
end

@testset "test granger <data> --model var not hijacked by cwd var.jld2" begin
    mktempdir() do dir
        cd(dir) do
            # Save a 2-variable VARModel (varnames ["a", "b"]) to ./var.jld2 in CWD
            save_model_dispatch("var.jld2", estimate_var(randn(40, 2), 1; varnames=["a", "b"]))
            # Create a 4-variable dataset d4.csv (columns y1..y4)
            d4_csv = _make_csv(dir; T=50, n=4, colnames=["y1", "y2", "y3", "y4"])
            out_explicit_data = _capture() do
                _dispatch_via_app(["test", "multivariate", "granger", d4_csv,
                                   "--model", "var", "--all", "--format", "json"])
            end
            @test occursin("\"y3\"", out_explicit_data)
            @test !occursin("\"a\"", out_explicit_data)

            # Without <data>, `--model var` still loads ./var.jld2 (varnames ["a", "b"])
            out_handle = _capture() do
                _dispatch_via_app(["test", "multivariate", "granger",
                                   "--model", "var", "--all", "--format", "json"])
            end
            @test occursin("\"a\"", out_handle)
            @test !occursin("\"y3\"", out_handle)

            # On other leaves (e.g. forecast multivariate var <oos> --model var --lags 3),
            # stem `var` still loads ./var.jld2 (VAR(1)) rather than estimating VAR(3) on oos2.csv
            oos_csv = joinpath(dir, "oos2.csv")
            CSV.write(oos_csv, DataFrame(a=randn(20), b=randn(20)))
            out_fc = _capture() do
                _dispatch_via_app(["forecast", "multivariate", "var", oos_csv, "--model", "var", "--lags", "3", "--horizons", "2", "--format", "json"])
            end
            @test occursin("VAR(1)", out_fc)
        end
    end
end
