# Model card unit — aggregator. One include per task; see .superpowers/sdd/.
# The T1 suite includes src files directly into Main, so the unit is loaded the
# same way here (io.jl / errors.jl, hence CliError, are already in by now).
if !isdefined(@__MODULE__, :parse_card)
    include(joinpath(dirname(@__DIR__), "src", "model_card.jl"))
end

include(joinpath(@__DIR__, "card", "task_1_grammar.jl"))
