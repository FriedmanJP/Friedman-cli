# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# REPL / interactive session mode

"""
    Session

Mutable state for the interactive REPL session.
"""
mutable struct Session
    data_path::String
    df::Union{DataFrame,Nothing}
    Y::Union{Matrix{Float64},Nothing}
    varnames::Vector{String}
    results::Dict{Symbol,Any}
    last_model::Symbol
end

Session() = Session("", nothing, nothing, String[], Dict{Symbol,Any}(), :none)

function session_load_data!(s::Session, path::String)
    df = load_data(path)
    Y = df_to_matrix(df)
    vnames = variable_names(df)
    s.data_path = path
    s.df = df
    s.Y = Y
    s.varnames = vnames
    s.results = Dict{Symbol,Any}()
    s.last_model = :none
    return s
end

function session_clear!(s::Session)
    s.data_path = ""
    s.df = nothing
    s.Y = nothing
    s.varnames = String[]
    s.results = Dict{Symbol,Any}()
    s.last_model = :none
    return s
end

function session_store_result!(s::Session, model_type::Symbol, result)
    s.results[model_type] = result
    s.last_model = model_type
    return s
end

session_has_data(s::Session) = !isempty(s.data_path)

session_get_result(s::Session, model_type::Symbol) = get(s.results, model_type, nothing)

const SESSION = Session()
