# Comprehensive storage edge-case, fuzz, security, session URI, and regression
# tests ([STORAGE-W6] #310). Included from test/test_commands.jl after test_handles.jl.

@testset "Storage path & naming matrix (#305, #310)" begin
    mktempdir() do dir
        # Dotted stems: macro.v1.csv, model_v1.2, a.b.c
        dotted_csv = joinpath(dir, "macro.v1.csv")
        CSV.write(dotted_csv, DataFrame(y1=randn(16), y2=randn(16)))
        @test resolve_stem(dotted_csv; slot=:data) == dotted_csv
        @test resolve_save_path(joinpath(dir, "model_v1.2")) == joinpath(dir, "model_v1.2.jld2")
        @test resolve_save_path(joinpath(dir, "a.b.c")) == joinpath(dir, "a.b.c.jld2")
        @test resolve_save_path(joinpath(dir, "a.b.jls")) == joinpath(dir, "a.b.jls")

        # Spaces and Unicode filenames
        uni_dir = joinpath(dir, "macro data 日本")
        mkpath(uni_dir)
        uni_csv = joinpath(uni_dir, "データ v1.csv")
        CSV.write(uni_csv, DataFrame(y1=randn(16), y2=randn(16)))
        uni_jld2 = joinpath(uni_dir, "ハンドル v1.jld2")
        _capture() do
            _data_import(; data=uni_csv, kind="timeseries", output=uni_jld2)
        end
        @test isfile(uni_jld2)
        @test load_model_dispatch(uni_jld2) isa TimeSeriesData

        # Tilde expansion via _expanduser
        @test startswith(_expanduser("~/test_handle.jld2"), homedir())

        # Ambiguous bare stem (shared.csv + shared.jld2 -> data/ambiguous-path)
        amb_csv = joinpath(dir, "shared.csv")
        amb_jld = joinpath(dir, "shared.jld2")
        CSV.write(amb_csv, DataFrame(y1=randn(10), y2=randn(10)))
        save_model_dispatch(amb_jld, TimeSeriesData(randn(10, 2); varnames=["y1", "y2"]))
        err_amb = try; resolve_stem(joinpath(dir, "shared"); slot=:data); nothing; catch e; e; end
        @test err_amb isa CliError && err_amb.code == "data/ambiguous-path"
        # Explicit extension resolves unambiguously
        @test resolve_stem(amb_csv; slot=:data) == amb_csv
        @test resolve_stem(amb_jld; slot=:data) == amb_jld

        # #key sub-entry syntax on plain multi-key .jld2
        # Note: JLD2 v0.6.7 cannot reconstruct raw DataFrame structs on Julia 1.14+
        # (`UnionAll has hidden fields`), so use NamedTuple payloads across all Julia
        # versions and keep raw DataFrame-in-JLD2 coverage on Julia < 1.14.
        multi = joinpath(dir, "multi.jld2")
        JLD2.jldsave(multi; df1=(a=collect(1.0:5.0), b=collect(6.0:10.0)), df2=(x=collect(1.0:3.0),))
        df1 = load_data(multi * "#df1")
        @test df1 isa DataFrame && names(df1) == ["a", "b"] && nrow(df1) == 5
        err_nokey = try; load_data(multi * "#nonexistent"); nothing; catch e; e; end
        @test err_nokey isa CliError && err_nokey.code == "data/key-not-found"
        if VERSION < v"1.14.0-DEV"
            multi_df = joinpath(dir, "multi_df.jld2")
            JLD2.jldsave(multi_df; df1=DataFrame(a=1.0:5.0, b=6.0:10.0), df2=DataFrame(x=1.0:3.0))
            df1_raw = load_data(multi_df * "#df1")
            @test df1_raw isa DataFrame && names(df1_raw) == ["a", "b"] && nrow(df1_raw) == 5
        end
    end
end

@testset "Storage atomicity & corruption fuzzing (#305, #310)" begin
    mktempdir() do dir
        # Atomic same-file overwrite & failure rollback (original byte-identical, zero .tmp leftovers)
        target = joinpath(dir, "atomic.jld2")
        ts1 = TimeSeriesData(ones(10, 2); varnames=["a", "b"])
        save_model_dispatch(target, ts1)
        orig_bytes = read(target)

        # Inject write failure inside _atomic_write
        err_inj = try
            _atomic_write(target) do tmp
                write(tmp, b"partial-corrupt-bytes")
                error("injected I/O failure")
            end
            nothing
        catch e; e; end
        @test err_inj !== nothing
        @test read(target) == orig_bytes
        @test isempty(filter(f -> occursin(".tmp", f), readdir(dir)))

        # Same-file overwrite via data fix f -o f
        na_ts = TimeSeriesData([1.0 2.0; NaN 4.0; 3.0 6.0]; varnames=["x", "y"])
        f_over = joinpath(dir, "overwrite_me.jld2")
        save_model_dispatch(f_over, na_ts)
        _capture() do
            _data_fix(; data=f_over, method="listwise", output=f_over)
        end
        fixed = load_model_dispatch(f_over)
        @test fixed isa TimeSeriesData
        @test isempty(filter(f -> occursin(".tmp", f), readdir(dir)))

        # Corrupt handle fuzz matrix: 0-byte, 4-byte, truncated HDF5, random bytes, mismatched ext
        corrupt_cases = Pair{String,Vector{UInt8}}[
            "zero.jld2"      => UInt8[],
            "zero.jls"       => UInt8[],
            "short4.jld2"    => UInt8[0x01, 0x02, 0x03, 0x04],
            "short4.jls"     => UInt8[0x37, 0x4a, 0x4c, 0x0b],
            "trunc_hdf5.jld2" => UInt8[0x89, 0x48, 0x44, 0x46, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00],
            "rand.jld2"      => rand(MersenneTwister(1), UInt8, 128),
            "rand.jls"       => rand(MersenneTwister(2), UInt8, 128),
            "rand.fmod"      => rand(MersenneTwister(3), UInt8, 128),
        ]
        # Mismatched extensions: genuine HDF5 bytes named .jls, real JLS bytes named .jld2
        real_hdf5 = joinpath(dir, "real_hdf5.jld2")
        JLD2.jldsave(real_hdf5; data=(a=[1, 2, 3],))
        real_jls = joinpath(dir, "real.jls")
        save_model_dispatch(real_jls, ts1)
        push!(corrupt_cases, "hdf5_named_jls.jls" => read(real_hdf5))
        push!(corrupt_cases, "jls_named_jld2.jld2" => read(real_jls))

        for (fname, bytes) in corrupt_cases
            fp = joinpath(dir, fname)
            write(fp, bytes)
            caught = Ref{Any}(nothing)
            streams = _capture_all() do
                try
                    load_model_dispatch(fp)
                catch e
                    caught[] = e
                end
            end
            @test caught[] !== nothing
            if caught[] isa CliError
                @test caught[].code in ("data/corrupt-handle", "data/serialization")
                @test exit_class(caught[]) == 3
            else
                # Mock load_model raises SerializationError (mapped to data/serialization exit 3 by run_cli)
                @test nameof(typeof(caught[])) === :SerializationError
            end
            @test !occursin("JLD2.MmapIO", streams.err)
            @test !occursin("JLD2.MmapIO", streams.out)
        end
    end
end

@testset "Storage security confinement (FRDC_DATA_ROOT & symlinks) (#305, #310)" begin
    mktempdir() do base
        allowed = joinpath(base, "allowed")
        outside = joinpath(base, "outside")
        mkpath(allowed); mkpath(outside)

        ts = TimeSeriesData(randn(20, 2); varnames=["y1", "y2"])
        in_h  = joinpath(allowed, "in.jld2")
        out_h = joinpath(outside, "secret.jld2")
        save_model_dispatch(in_h, ts)
        save_model_dispatch(out_h, ts)

        # Symlink inside allowed/ pointing to outside/secret.jld2
        sym_h = joinpath(allowed, "escape.jld2")
        symlink_ok = try
            symlink(out_h, sym_h)
            true
        catch
            false
        end

        withenv("FRDC_DATA_ROOT" => allowed, "FRIEDMAN_DATA_ROOT" => nothing) do
            # Allowed path succeeds
            @test load_model_dispatch(in_h) isa TimeSeriesData
            # Outside path blocked on read, model info, show, convert, write
            for fn in (
                () -> load_model_dispatch(out_h),
                () -> _model_info(; path=out_h, format="json"),
                () -> _show_handle(; path=out_h, format="json"),
                () -> _model_convert(; path=out_h, to="jls", format="json"),
                () -> resolve_write_ref(joinpath(outside, "write_out.jld2")),
            )
                err = try; fn(); nothing; catch e; e; end
                @test err isa CliError
                @test err.code == "data/bad-path"
                @test exit_class(err) == 3
            end
            # Symlink traversal blocked
            if symlink_ok
                err_sym = try; load_model_dispatch(sym_h); nothing; catch e; e; end
                @test err_sym isa CliError
                @test err_sym.code == "data/bad-path"
            end
        end

        # FRIEDMAN_DATA_ROOT fallback still honored when FRDC_DATA_ROOT unset
        withenv("FRDC_DATA_ROOT" => nothing, "FRIEDMAN_DATA_ROOT" => allowed) do
            err_fb = try; load_model_dispatch(out_h); nothing; catch e; e; end
            @test err_fb isa CliError
            @test err_fb.code == "data/bad-path"
        end
    end
end

@testset "Storage session URIs (data://, model://, result://, mem://) (#306, #310)" begin
    # Outside session -> typed usage/session-uri-requires-session (exit 2)
    for uri in ("data://d1", "model://m1", "result://r1", "mem://x1")
        err = try; load_model_dispatch(uri); nothing; catch e; e; end
        @test err isa CliError
        @test err.code == "usage/session-uri-requires-session"
        @test exit_class(err) == 2
    end

    # Inside session store: full data:// -> model:// -> result:// -> model info -> show -> convert
    mktempdir() do dir
        csv = _make_csv(dir; T=40, n=2)
        with_session_store() do
            _capture() do
                _data_import(; data=csv, kind="timeseries", output="data://d1")
            end
            @test load_model_dispatch("data://d1") isa TimeSeriesData

            m = estimate_var(randn(40, 2), 1; varnames=["y1", "y2"])
            save_model_dispatch("model://m1", m)
            @test load_model_dispatch("model://m1") isa VARModel

            ir = irf(m, 4)
            save_model_dispatch("result://r1", ir; source_model=m)
            @test load_model_dispatch("result://r1") isa ImpulseResponse

            save_model_dispatch("mem://scratch", DataFrame(a=1:3))
            @test load_model_dispatch("mem://scratch") isa DataFrame

            # model info & show work on session URIs
            info_s = _capture_all() do
                _model_info(; path="model://m1", format="json")
            end
            @test occursin("VARModel", info_s.out)
            show_s = _capture_all() do
                _show_handle(; path="result://r1", format="json")
            end
            @test occursin("horizon", show_s.out) || occursin("value", show_s.out)

            # model convert from session URI to disk .jld2
            disk_out = joinpath(dir, "from_session.jld2")
            _capture() do
                _model_convert(; path="model://m1", output=disk_out, note="exported")
            end
            @test isfile(disk_out)
            @test load_model_dispatch(disk_out) isa VARModel
        end
    end
end

@testset "Storage invocation cache, NaN/Inf guards & panel/IO regressions (#306-#309)" begin
    mktempdir() do dir
        # Single-load cache: repeated loads within one invocation hit disk once
        ts = TimeSeriesData(randn(30, 2); varnames=["y1", "y2"])
        h = joinpath(dir, "cached.jld2")
        save_model_dispatch(h, ts)
        with_handle_cache() do
            _HANDLE_LOAD_COUNTER[] = 0
            a = load_model_dispatch(h)
            b = load_model_dispatch(h)
            @test a === b
            @test _HANDLE_LOAD_COUNTER[] == 1
        end

        # Inf rejected uniformly on numeric matrix loads
        inf_csv = joinpath(dir, "inf.csv")
        CSV.write(inf_csv, DataFrame(y1=[1.0, Inf, 3.0], y2=[1.0, 2.0, 3.0]))
        err_inf = try; load_multivariate_data(inf_csv); nothing; catch e; e; end
        @test err_inf isa CliError && err_inf.code == "data/non-finite-values"

        # Plain tabular payload stored in .jld2 / .jls into load_panel_data
        pcsv = _make_panel_csv(dir; G=3, T_per=6, n=2)
        dfp = CSV.read(pcsv, DataFrame)
        pjld = joinpath(dir, "plain_panel.jld2")
        pjls = joinpath(dir, "plain_panel.jls")
        nt_p = NamedTuple{Tuple(Symbol.(names(dfp)))}(Tuple(collect(dfp[!, c]) for c in names(dfp)))
        JLD2.jldsave(pjld; df=nt_p)
        save_model_dispatch(pjls, dfp)
        pd1 = load_panel_data(pjld * "#df", "group", "time")
        pd2 = load_panel_data(pjls, "group", "time")
        @test pd1 isa PanelData && pd2 isa PanelData
        if VERSION < v"1.14.0-DEV"
            pjld_df = joinpath(dir, "plain_panel_df.jld2")
            JLD2.jldsave(pjld_df; df=dfp)
            @test load_panel_data(pjld_df * "#df", "group", "time") isa PanelData
        end

        # PanelData preservation in data dropna & TimeSeriesData return value in data balance
        p_typed = joinpath(dir, "typed_panel.jld2")
        save_model_dispatch(p_typed, pd1)
        drop_out = joinpath(dir, "drop_panel.jld2")
        drop_res = Ref{Any}(nothing)
        _capture() do
            drop_res[] = _data_dropna(; data=p_typed, output=drop_out)
        end
        @test drop_res[] isa PanelData
        @test isfile(drop_out) && load_model_dispatch(drop_out) isa PanelData

        bal_out = joinpath(dir, "bal_ts.jld2")
        bal_res = Ref{Any}(nothing)
        _capture() do
            bal_res[] = _data_balance(; data=h, output=bal_out)
        end
        @test bal_res[] isa TimeSeriesData
        @test isfile(bal_out) && load_model_dispatch(bal_out) isa TimeSeriesData

        # Header-only model info performs zero full deserializations on .jld2
        m = estimate_var(randn(30, 2), 1; varnames=["y1", "y2"])
        mh = joinpath(dir, "var_hdr.jld2")
        save_model_dispatch(mh, m; note="hdr-check")
        _HANDLE_LOAD_COUNTER[] = 0
        info = _capture() do
            _model_info(; path=mh, format="json")
        end
        @test _HANDLE_LOAD_COUNTER[] == 0
        @test occursin("VARModel", info) && occursin("hdr-check", info)

        # #349 P0-4: truncated HDF5/JLD2 header -> data/corrupt-handle with zero FileIO/HDF5/Stacktrace leakage
        trunc_p = joinpath(dir, "trunc.jld2")
        write(trunc_p, UInt8[0x89, 0x48, 0x44, 0x46, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00])
        err_trunc = try; load_model_dispatch(trunc_p); nothing; catch e; e; end
        @test err_trunc isa CliError
        @test err_trunc.code == "data/corrupt-handle"
        @test !occursin("FileIO", err_trunc.hint)
        @test !occursin("HDF5", err_trunc.hint)
        @test !occursin("Stacktrace:", err_trunc.hint)
        @test !occursin("\n", err_trunc.hint)

        # #350 P1-3: explicit #key archive upsert (JLD2 + .jls) & .fmod#key exit-2 refusal
        arch_jld = joinpath(dir, "arch.jld2")
        m1 = estimate_var(randn(30, 2), 1; varnames=["a", "b"])
        m2 = estimate_var(randn(30, 2), 2; varnames=["a", "b"])
        save_model_dispatch(arch_jld * "#m1", m1; note="first")
        save_model_dispatch(arch_jld * "#m2", m2; note="second")
        ks = _inspect_handle_keys(arch_jld)
        @test sort([r.key for r in ks]) == ["m1", "m2"]
        @test load_model_dispatch(arch_jld * "#m1").p == 1
        @test load_model_dispatch(arch_jld * "#m2").p == 2
        info_k1 = _native_model_info(arch_jld * "#m1")
        @test info_k1.note == "first"

        arch_jls = joinpath(dir, "arch.jls")
        save_model_dispatch(arch_jls * "#k1", m1)
        save_model_dispatch(arch_jls * "#k2", m2)
        @test sort([r.key for r in _inspect_handle_keys(arch_jls)]) == ["k1", "k2"]
        @test load_model_dispatch(arch_jls * "#k1").p == 1
        @test load_model_dispatch(arch_jls * "#k2").p == 2

        err_fmod_k = try; save_model_dispatch(joinpath(dir, "bad.fmod#k1"), m1); nothing; catch e; e; end
        @test err_fmod_k isa CliError && err_fmod_k.code == "usage/invalid"

        # #350 P2-10: _write_macro_data allows .jld2 from bundled :example container
        ts_ex = TimeSeriesData(randn(20, 2); varnames=["x1", "x2"])
        ex_out = joinpath(dir, "from_example.jld2")
        _write_macro_data(ts_ex, ex_out; input_path=":denmark")
        @test isfile(ex_out) && load_model_dispatch(ex_out) isa TimeSeriesData
    end
end
