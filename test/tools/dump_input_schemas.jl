# Dump every leaf's input_schema to a directory for conformant metaschema
# validation (W5/#140). Runs under real MEMs (the T3 CI job):
#
#   julia --project=test/integration test/tools/dump_input_schemas.jl <outdir>
#
# The python side (validate_envelopes.py --input-schemas <outdir>) runs
# Draft7Validator.check_schema on every file — the same don't-trust-the-in-house
# validator division of labor as the W1 envelope cross-validation.

using Friedman
using JSON3

isempty(ARGS) && error("usage: dump_input_schemas.jl <outdir>")
outdir = ARGS[1]
mkpath(outdir)

n = 0
function _walk(node, path)
    for name in sort!(collect(keys(node.subcmds)))
        sub = node.subcmds[name]
        Friedman.is_hidden_alias(name, sub) && continue
        p = vcat(path, [name])
        if sub isa Friedman.LeafCommand
            schema = Friedman._input_schema(sub, p)
            write(joinpath(outdir, join(p, "_") * ".json"), JSON3.write(schema))
            global n += 1
        else
            _walk(sub, p)
        end
    end
end
_walk(Friedman.APP.root, String[])
println("dumped $n input schema(s) → $outdir")
