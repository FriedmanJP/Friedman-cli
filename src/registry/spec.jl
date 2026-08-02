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

# Model handles (P2-7 / C029) — compose onto estimate vs downstream specs
const SAVE_MODEL_OPTION = OptionSpec(
    name="save-model", type=String, default="",
    description="Save estimated model to a .fmod handle file",
)
const MODEL_OPTION = OptionSpec(
    name="model", type=String, default="",
    description="Load model from a .fmod handle (skip re-estimation)",
)

# Config ergonomics (P2-8 / C030) — append to every leaf that has --config
const CONFIG_ERGONOMICS_OPTIONS = [
    OptionSpec(name="config-json", type=String, default="",
               description="JSON object merged over --config (file < json < --set)"),
    OptionSpec(name="set", type=String, default="",
               description="Override config key=value; repeatable; dotted keys OK"),
]
const STRICT_FLAG = FlagSpec(name="strict",
                             description="Treat config schema warnings as errors (exit 4)")

"""Append --config-json/--set/--strict to specs that already declare --config."""
function with_config_ergonomics(specs::Vector{CommandSpec})
    out = CommandSpec[]
    for s in specs
        has_config = any(o -> o.name == "config", s.options)
        if !has_config
            push!(out, s)
            continue
        end
        push!(out, CommandSpec(
            path=s.path, summary=s.summary, args=s.args,
            options=vcat(s.options, CONFIG_ERGONOMICS_OPTIONS),
            flags=vcat(s.flags, [STRICT_FLAG]),
            tables=s.tables, category=s.category, aliases=s.aliases,
            handler=s.handler,
        ))
    end
    return out
end

"""Append option specs to every CommandSpec (by copy)."""
function with_options(specs::Vector{CommandSpec}, extra::Vector{OptionSpec})
    out = CommandSpec[]
    for s in specs
        push!(out, CommandSpec(
            path=s.path, summary=s.summary, args=s.args,
            options=vcat(s.options, extra), flags=s.flags,
            tables=s.tables, category=s.category, aliases=s.aliases,
            handler=s.handler,
        ))
    end
    return out
end

with_save_model(specs::Vector{CommandSpec}) = with_options(specs, [SAVE_MODEL_OPTION])
with_model_option(specs::Vector{CommandSpec}) = with_options(specs, [MODEL_OPTION])

const PLOT_FLAGS = [
    FlagSpec(name="plot", description="Open interactive plot in browser"),
]

# Cross-sectional regression shared options
const REG_OPTIONS = [
    OptionSpec(name="dep", type=String, default="",
               description="Dependent variable column name (default: first numeric column)"),
    OptionSpec(name="cov-type", type=String, default="hc1",
               choices=["ols", "hc0", "hc1", "hc2", "hc3", "cluster"],
               description="ols|hc0|hc1|hc2|hc3|cluster"),
    OptionSpec(name="clusters", type=String, default="",
               description="Cluster variable column name"),
    OptionSpec(name="output", short="o", type=String, default="",
               description="Export results to file"),
    OptionSpec(name="format", short="f", type=String, default="table",
               choices=["table", "csv", "json"], description="table|csv|json"),
]

# Panel regression shared options
# W2/#107 count-data regression. `--offset` and `--exposure` are mutually exclusive
# (exposure is log-transformed into the offset) and the handler rejects the pair with a
# typed usage/invalid. `--irr` is a FlagSpec because its handler kwarg is a Bool — a String
# OptionSpec bound to a Bool kwarg fails on EVERY invocation (#85).
const COUNT_COMMON_OPTIONS = [
    OptionSpec(name="dep", type=String, default="",
               description="Dependent count column (default: first numeric column)"),
    OptionSpec(name="offset", type=String, default="",
               description="Offset column, already on the log scale (exclusive with --exposure)"),
    OptionSpec(name="exposure", type=String, default="",
               description="Exposure column, strictly positive; enters as log(exposure)"),
]
const COUNT_IRR_OPTIONS = [
    OptionSpec(name="conf-level", type=Float64, default=0.95,
               description="Confidence level for the incidence-rate-ratio CI (0 < level < 1)"),
    OptionSpec(name="output", short="o", type=String, default="",
               description="Export results to file"),
    OptionSpec(name="format", short="f", type=String, default="table",
               choices=["table", "csv", "json"], description="table, csv or json"),
]
const COUNT_IRR_FLAG = FlagSpec(name="irr",
    description="Also report incidence-rate ratios exp(beta) with delta-method SEs")

const PREG_OPTIONS = [
    OptionSpec(name="dep", type=String, default="", description="Dependent variable column name"),
    OptionSpec(name="indep", type=String, default="", description="Independent variables (comma-separated)"),
    OptionSpec(name="id-col", type=String, default="", description="Panel group ID column (default: first column)"),
    OptionSpec(name="time-col", type=String, default="", description="Panel time column (default: second column)"),
    OptionSpec(name="cov-type", type=String, default="cluster",
               choices=["ols", "cluster", "twoway", "driscoll-kraay"],
               description="ols|cluster|twoway|driscoll-kraay"),
    OptionSpec(name="method", short="m", type=String, default="fe", description="Estimation method"),
    OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
    OptionSpec(name="format", short="f", type=String, default="table",
               choices=["table", "csv", "json"], description="table|csv|json"),
]

# Bayesian DSGE shared options (replaces _bayes_common_options)
const BAYES_OPTIONS = [
    OptionSpec(name="data", short="d", type=String, default="", description="Path to CSV data file"),
    OptionSpec(name="params", type=String, default="", description="Comma-separated parameter names"),
    OptionSpec(name="priors", type=String, default="", description="Path to priors TOML file"),
    OptionSpec(name="sampler", type=String, default="smc", description="smc|smc2|mh"),
    OptionSpec(name="n-smc", type=Int, default=5000, description="SMC particles"),
    OptionSpec(name="n-particles", type=Int, default=500, description="Particle filter particles (smc2)"),
    OptionSpec(name="n-draws", type=Int, default=10000, description="Total posterior draws"),
    OptionSpec(name="burnin", type=Int, default=5000, description="Burn-in draws"),
    OptionSpec(name="ess-target", type=Float64, default=0.5, description="ESS target for resampling"),
    OptionSpec(name="observables", type=String, default="", description="Observable variable names (comma-separated)"),
    OptionSpec(name="solver", type=String, default="gensys", description="gensys|klein|perturbation"),
    OptionSpec(name="order", type=Int, default=1, description="Perturbation order (1, 2, or 3)"),
    OptionSpec(name="constraint-solver", type=String, default="",
               description="Constraint solver: nonlinearsolve|optim|nlopt|ipopt|path"),
    OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
    OptionSpec(name="format", short="f", type=String, default="table",
               choices=["table", "csv", "json"], description="table|csv|json"),
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

"""Select named options from a group (order follows `names`, not the group)."""
function select_options(group::Vector{OptionSpec}, names::String...)
    out = OptionSpec[]
    for name in names
        idx = findfirst(o -> o.name == name, group)
        isnothing(idx) && error("option '$name' not found in group")
        push!(out, group[idx])
    end
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

