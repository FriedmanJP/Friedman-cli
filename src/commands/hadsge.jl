# Heterogeneous-agent DSGE (#203). The 11 HouseholdSystem leaves move here
# from `dsge ha`. Handlers stay in dsge.jl (same module); this file owns the node.

function register_hadsge_commands!()
    ha = register!(filter(s -> s.path[1] == "hadsge", _prepared_dsge_specs()))
    return build_node("hadsge", ha;
        description="Heterogeneous-agent DSGE (one HouseholdSystem): SSJ, Reiter, Krusell–Smith")
end
