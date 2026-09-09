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
