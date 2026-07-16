# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

module Friedman

using CSV, DataFrames, PrettyTables, JSON3, TOML
using MacroEconometricModels
using LinearAlgebra: eigvals, diag, I, svd
using Statistics: mean, median, var, quantile
using Random

# CLI engine
include("cli/types.jl")
include("cli/parser.jl")
include("cli/help.jl")
include("cli/dispatch.jl")

# Errors before io (loaders throw CliError)
include("output/errors.jl")
# IO and config
include("io.jl")
include("output/envelope.jl")
include("output/render.jl")
include("config.jl")

# Shared utilities (must come before command files)
include("commands/shared.jl")

# Declarative registry (P2-1) — before command files that emit CommandSpecs
include("registry/spec.jl")
include("registry/adapter.jl")

# Commands (action-first hierarchy)
include("commands/estimate.jl")
include("commands/test.jl")
include("commands/irf.jl")
include("commands/fevd.jl")
include("commands/hd.jl")
include("commands/forecast.jl")
include("commands/predict.jl")
include("commands/residuals.jl")
include("commands/filter.jl")
include("commands/data.jl")
include("commands/nowcast.jl")
include("commands/dsge.jl")
include("commands/did.jl")
include("commands/spectral.jl")
include("commands/schema.jl")

# REPL (interactive session)
include("repl.jl")

# Single source of truth: Project.toml (F3). Resolved at precompile time;
# include_dependency invalidates the precompile cache when the version bumps.
Base.include_dependency(joinpath(dirname(@__DIR__), "Project.toml"))
const FRIEDMAN_VERSION = let proj = TOML.parsefile(joinpath(dirname(@__DIR__), "Project.toml"))
    VersionNumber(proj["version"])
end

"""
    build_app() -> Entry

Construct the full CLI command tree.
"""
function build_app()
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
        "schema"    => register_schema_command!(),
    )

    root = NodeCommand("friedman", root_cmds,
        "A macroeconometric analysis toolkit powered by MacroEconometricModels.jl")

    return Entry("friedman", root; version=FRIEDMAN_VERSION)
end

"""Memoized command tree, built once at precompile time (F57)."""
const APP = build_app()

"""
    run_cli(args)::Cint

Single entry shared by `main` (dev) and `julia_main` (compiled). Exit codes
(P1-4): 0 ok · 2 usage · 3 data · 4 config · 5 model · 6 env · 1 internal.
"""
function run_cli(args::Vector{String})::Cint
    # Launch REPL if "repl" is the first argument
    if !isempty(args) && args[1] == "repl"
        start_repl()
        return Cint(0)
    end

    app = APP
    try
        remaining = _extract_global_flags!(copy(args))
        _LAST_ARGV[] = copy(args)
        dispatch(app, remaining)
        return Cint(0)
    catch e
        if e isa CliError
            _status_styled("Error: "; bold=true, color=:red)
            println(stderr, sprint(showerror, e))
            return Cint(exit_class(e))
        elseif e isa ParseError || e isa DispatchError
            _status_styled("Error: "; bold=true, color=:red)
            println(stderr, e.message)
            return Cint(2)  # usage
        else
            _status_styled("Error: "; bold=true, color=:red)
            println(stderr, sprint(showerror, e))
            println(stderr, "this is likely a bug — please report")
            return Cint(1)
        end
    finally
        _QUIET[] = false
    end
end

"""
    main(args=ARGS)

Entry point: dispatch and exit non-zero on failure.
"""
function main(args::Vector{String}=ARGS)
    code = run_cli(args)
    code == 0 || exit(Int(code))
    return nothing
end

"""
    julia_main()::Cint

Entry point for PackageCompiler standalone executables.
"""
julia_main()::Cint = run_cli(ARGS)

export main, build_app, julia_main, run_cli

end # module Friedman
