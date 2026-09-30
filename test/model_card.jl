# Model card unit — aggregator. One include per task; see .superpowers/sdd/.
# The T1 suite includes src files directly into Main, so the unit is loaded the
# same way here (io.jl / errors.jl, hence CliError, are already in by now).
if !isdefined(@__MODULE__, :parse_card)
    include(joinpath(dirname(@__DIR__), "src", "model_card.jl"))
end

include(joinpath(@__DIR__, "card", "task_1_grammar.jl"))
include(joinpath(@__DIR__, "card", "task_2_priors_constraints.jl"))
include(joinpath(@__DIR__, "card", "task_3_gmm_smm_system.jl"))
include(joinpath(@__DIR__, "card", "task_7_config_routing.jl"))
include(joinpath(@__DIR__, "card", "task_8_smm_sur.jl"))
include(joinpath(@__DIR__, "card", "task_9_model_file_splitter.jl"))
include(joinpath(@__DIR__, "card", "task_10_resolver_stanzas.jl"))
