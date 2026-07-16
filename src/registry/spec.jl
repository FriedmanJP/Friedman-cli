# Declarative command registry (P2-1)

Base.@kwdef struct ArgSpec
    name::String
    type::Type = String
    required::Bool = true
    default::Any = nothing
    description::String = ""
end

Base.@kwdef struct OptionSpec
    name::String
    short::String = ""
    type::Type = String
    default::Any = nothing
    choices::Union{Nothing,Vector{String}} = nothing
    description::String = ""
    since::VersionNumber = v"0.5.0"
end

Base.@kwdef struct FlagSpec
    name::String
    short::String = ""
    description::String = ""
end

Base.@kwdef struct TableSpec
    name::Symbol
    description::String = ""
end

Base.@kwdef struct CommandSpec
    path::Vector{String}
    summary::String
    args::Vector{ArgSpec} = ArgSpec[]
    options::Vector{OptionSpec} = OptionSpec[]
    flags::Vector{FlagSpec} = FlagSpec[]
    tables::Vector{TableSpec} = TableSpec[]
    category::String = ""
    aliases::Vector{String} = String[]
    handler::Function = (ctx) -> ctx  # (ctx::CmdContext) -> Any
end

"""
Validated invocation context for a CommandSpec handler.
"""
struct CmdContext
    args::Dict{Symbol,Any}
    opts::Dict{Symbol,Any}
    flags::Dict{Symbol,Bool}
    fmt::Symbol
    output::String
    env::Envelope
    status::Function
end

# ── Shared option groups (compose by name — never index-slice) ──────────

const OUTPUT_OPTIONS = [
    OptionSpec(name="format", short="f", type=String, default="table",
               choices=["table", "csv", "json"], description="Output format"),
    OptionSpec(name="output", short="o", type=String, default="",
               description="Write to file instead of stdout"),
]

const PLOT_OPTIONS = [
    OptionSpec(name="plot-save", type=String, default="",
               description="Save interactive plot to HTML file"),
]

const PLOT_FLAGS = [
    FlagSpec(name="plot", description="Open interactive plot in browser"),
]

"""Replace the default of a named option in a group (by name, not index)."""
function with_default(group::Vector{OptionSpec}, name::String, default)
    out = OptionSpec[]
    found = false
    for o in group
        if o.name == name
            push!(out, OptionSpec(name=o.name, short=o.short, type=o.type,
                                  default=default, choices=o.choices,
                                  description=o.description, since=o.since))
            found = true
        else
            push!(out, o)
        end
    end
    found || error("option '$name' not found in group")
    return out
end

# Global registry of migrated specs (build_app merges with legacy nodes)
const REGISTRY = CommandSpec[]

function register!(spec::CommandSpec)
    push!(REGISTRY, spec)
    return spec
end

function register!(specs::Vector{CommandSpec})
    append!(REGISTRY, specs)
    return specs
end

function clear_registry!()
    empty!(REGISTRY)
    return nothing
end
