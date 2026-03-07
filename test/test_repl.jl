using Test
using CSV, DataFrames

# Set up minimal Friedman context for testing repl.jl
module Friedman
    using CSV, DataFrames
    # Minimal stubs matching io.jl functions
    function load_data(path::String)
        isfile(path) || error("file not found: $path")
        df = CSV.read(path, DataFrame)
        nrow(df) == 0 && error("empty dataset: $path")
        return df
    end
    function df_to_matrix(df::DataFrame)
        numeric_cols = [n for n in names(df) if eltype(df[!, n]) <: Union{Number, Missing}]
        isempty(numeric_cols) && error("no numeric columns found")
        return Matrix{Float64}(df[!, numeric_cols])
    end
    variable_names(df::DataFrame) = [n for n in names(df) if eltype(df[!, n]) <: Union{Number, Missing}]

    function load_example(name::Symbol)
        if name == :fred_md
            data = [1.0 2.0 3.0; 4.0 5.0 6.0; 7.0 8.0 9.0]
            return (data=data, varnames=["INDPRO", "CPI", "FEDFUNDS"])
        elseif name == :fred_qd
            data = [1.0 2.0; 3.0 4.0]
            return (data=data, varnames=["GDP", "PCE"])
        elseif name == :pwt
            data = ones(5, 3)
            return (data=data, varnames=["rgdpe", "pop", "emp"])
        elseif name == :mpdta
            data = ones(4, 2)
            return (data=data, varnames=["lemp", "lpop"])
        elseif name == :ddcg
            data = ones(3, 2)
            return (data=data, varnames=["y", "d"])
        else
            error("unknown dataset: $name")
        end
    end

    include(joinpath(@__DIR__, "..", "src", "repl.jl"))
end

@testset "REPL Session" begin
    @testset "Session initialization" begin
        s = Friedman.Session()
        @test s.data_path == ""
        @test isnothing(s.df)
        @test isnothing(s.Y)
        @test isempty(s.varnames)
        @test isempty(s.results)
        @test s.last_model == :none
    end

    @testset "session_load_data!" begin
        s = Friedman.Session()
        tmpfile = tempname() * ".csv"
        open(tmpfile, "w") do io
            println(io, "x,y,z")
            println(io, "1.0,2.0,3.0")
            println(io, "4.0,5.0,6.0")
            println(io, "7.0,8.0,9.0")
        end
        Friedman.session_load_data!(s, tmpfile)
        @test s.data_path == tmpfile
        @test !isnothing(s.df)
        @test size(s.Y) == (3, 3)
        @test s.varnames == ["x", "y", "z"]
        @test isempty(s.results)
        rm(tmpfile; force=true)
    end

    @testset "session_load_data! clears results" begin
        s = Friedman.Session()
        s.results[:var] = "fake_model"
        s.last_model = :var
        tmpfile = tempname() * ".csv"
        open(tmpfile, "w") do io
            println(io, "a,b")
            println(io, "1.0,2.0")
            println(io, "3.0,4.0")
        end
        Friedman.session_load_data!(s, tmpfile)
        @test isempty(s.results)
        @test s.last_model == :none
        rm(tmpfile; force=true)
    end

    @testset "session_clear!" begin
        s = Friedman.Session()
        s.data_path = "test.csv"
        s.results[:var] = "fake"
        s.last_model = :var
        Friedman.session_clear!(s)
        @test s.data_path == ""
        @test isnothing(s.df)
        @test isempty(s.results)
        @test s.last_model == :none
    end

    @testset "session_store_result!" begin
        s = Friedman.Session()
        Friedman.session_store_result!(s, :var, "var_model")
        @test s.results[:var] == "var_model"
        @test s.last_model == :var
        Friedman.session_store_result!(s, :bvar, "bvar_model")
        @test s.results[:bvar] == "bvar_model"
        @test s.last_model == :bvar
        @test s.results[:var] == "var_model"
        Friedman.session_store_result!(s, :var, "var_model_v2")
        @test s.results[:var] == "var_model_v2"
        @test s.last_model == :var
    end

    @testset "session_has_data" begin
        s = Friedman.Session()
        @test !Friedman.session_has_data(s)
        s.data_path = "test.csv"
        @test Friedman.session_has_data(s)
    end

    @testset "session_get_result" begin
        s = Friedman.Session()
        @test isnothing(Friedman.session_get_result(s, :var))
        Friedman.session_store_result!(s, :var, "model")
        @test Friedman.session_get_result(s, :var) == "model"
        @test isnothing(Friedman.session_get_result(s, :bvar))
    end

    @testset "parse_data_source" begin
        @test Friedman.parse_data_source(":fred-md") == (:builtin, :fred_md)
        @test Friedman.parse_data_source(":fred-qd") == (:builtin, :fred_qd)
        @test Friedman.parse_data_source(":pwt") == (:builtin, :pwt)
        @test Friedman.parse_data_source(":mpdta") == (:builtin, :mpdta)
        @test Friedman.parse_data_source(":ddcg") == (:builtin, :ddcg)
        @test Friedman.parse_data_source("myfile.csv") == (:file, "myfile.csv")
        @test_throws ErrorException Friedman.parse_data_source(":nonexistent")
    end

    @testset "session_load_builtin!" begin
        s = Friedman.Session()
        Friedman.session_load_builtin!(s, :fred_md)
        @test s.data_path == ":fred-md"
        @test !isnothing(s.df)
        @test !isnothing(s.Y)
        @test size(s.Y) == (3, 3)
        @test s.varnames == ["INDPRO", "CPI", "FEDFUNDS"]
        @test isempty(s.results)
        @test s.last_model == :none
    end
end
