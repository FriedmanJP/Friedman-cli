# Model card unit — task 10: a `priors:` / `constraints:` stanza is the THIRD
# prior/constraint source, not a different path (W2 / #210).
# `_resolve_dsge_priors` / `_resolve_dsge_constraints` and the leaf guards live in
# `shared.jl` / `dsge.jl`; `dsge.jl` is NOT included by the card unit (task 9
# includes `shared.jl` only), so pull it in here the same way.
if !isdefined(@__MODULE__, :_resolve_dsge_priors)
    include(joinpath(dirname(@__DIR__), "..", "src", "commands", "shared.jl"))
end
if !isdefined(@__MODULE__, :_dsge_bayes_inputs)
    include(joinpath(dirname(@__DIR__), "..", "src", "commands", "dsge.jl"))
end

# NOT `_toml_fixture` from task 2: that one writes to a single shared `const _TMP`
# path, so a fixture that is written once and read twice would silently read
# whatever the NEXT write put there. One fresh path per call.
_t10_toml(content) = (p = tempname() * ".toml"; write(p, content); p)

"""`priors:` stanzas keyed the way `_model_card_stanzas` returns them."""
_t10_priors(lines...) =
    Dict{Symbol,Any}(:priors => lower_priors(parse_card("priors:\n" *
        join(("  " * l for l in lines), "\n") * "\n"), "m.jl"))

"""`constraints:` stanzas keyed the way `_model_card_stanzas` returns them."""
_t10_constraints(lines...) =
    Dict{Symbol,Any}(:constraints => lower_constraints(parse_card("constraints:\n" *
        join(("  " * l for l in lines), "\n") * "\n"), "m.jl"))

_t10_err(f) = try; f(); nothing; catch e; e; end

"""A `.jl` model file whose card preamble is `card`, over an AR(1) body with a
`phi_pi`-driven `i`, so a `constraints:` bound has a variable to bind."""
function _t10_model(card::AbstractString)
    f = tempname() * ".jl"
    write(f, string(card, """
    @dsge begin
        parameters: rho = 0.9, sigma = 0.01, phi_pi = 1.5
        endogenous: Y, C, i
        exogenous: e
        linear: true

        Y[t] = rho * Y[t-1] + sigma * e[t]
        C[t] = Y[t]
        i[t] = phi_pi * Y[t]
    end
    """))
    return f
end

"""A two-column CSV; the handler-level probes below die at the LOADER, long
before any of this is read, so the contents only have to be readable."""
_t10_csv() = (p = tempname() * ".csv"; write(p, "Y\n0.1\n0.2\n0.15\n"); p)

"""The four leaves that declare `--constraints` / `--constraint`, as callables."""
function _t10_occbin_probes(model::AbstractString)
    return Any[
        ("solve", () -> _dsge_solve(; model, periods=3, output=tempname() * ".json", format="json")),
        ("steady-state", () -> _dsge_steady_state(; model, output=tempname() * ".json", format="json")),
        ("irf", () -> _dsge_irf(; model, horizon=3, output=tempname() * ".json", format="json")),
        ("perfect-foresight", () -> _dsge_perfect_foresight(; model, periods=3,
                                    output=tempname() * ".json", format="json")),
    ]
end

@testset "an empty constraints: stanza is refused, exactly like an empty priors: one (CARD-W2 #210)" begin
    # F3. `lower_priors` refuses an empty `priors:` stanza; `lower_constraints` did
    # not, so a bare `constraints:` header lowered to ZERO bounds, the four OccBin
    # leaves' branch guard (`haskey(stanzas, :constraints)`) fired anyway, and
    # `dsge solve` printed "Solving with OccBin constraints..." while solving with
    # none. Mirroring the lowerer is the symmetric fix — and the more informative
    # one: it names the stanza, whereas gating the guard on `!isempty(bounds)`
    # would silently fall back to the unconstrained path and say nothing.
    empty_c = lower_constraints(parse_card("constraints:\n"), "m.jl")
    @test isempty(empty_c["bounds"])                 # the lowerer does NOT refuse it
    e = _t10_err(() -> _resolve_dsge_constraints("", String[];
                                                 stanzas=Dict{Symbol,Any}(:constraints => empty_c)))
    @test e isa CliError
    @test e.code == "config/invalid"
    @test occursin("empty", e.message)
    @test occursin("constraints", e.message)

    # The mirror, and the symmetry itself: same code, same word, from the layer
    # that already did it. Pinning BOTH is what stops the next asymmetry.
    p = _t10_err(() -> lower_priors(parse_card("priors:\n"), "m.jl"))
    @test p isa CliError && p.code == e.code
    @test occursin("empty", p.message)
    @test occursin("priors", p.message)

    # At the leaf: all four, not just the resolver. Delete the `isempty(bounds)`
    # throw and the branch guard still fires, the resolver returns an EMPTY vector
    # and all four exit 0 — which is the defect.
    empty_model = _t10_model("constraints:\n")
    for (label, thunk) in _t10_occbin_probes(empty_model)
        err = _t10_err(thunk)
        @test err isa CliError
        @test err.code == "config/invalid"
        @test occursin("empty", err.message)
        @test occursin("constraints", err.message)
    end
end

@testset "the stanza policy is symmetric: no leaf ignores a stanza it cannot use (CARD-W2 #210)" begin
    # F2. The rule, as a table. Every combination is asserted in BOTH directions —
    # a policy that only ever refuses (or only ever allows) cannot pass.
    both = Dict{Symbol,Any}(
        :priors => _t10_priors("rho ~ beta(2, 2)")[:priors],
        :constraints => _t10_constraints("i[t] >= -10")[:constraints])
    for (allow_p, allow_c) in ((true, true), (true, false), (false, true), (false, false))
        if allow_p && allow_c
            # NOT through `_t10_err`: that helper discards a non-throwing return, so
            # the "allowed" direction has to be called directly or it is vacuous.
            @test _model_card_stanza_policy(both; allow_priors=true, allow_constraints=true) === both
        else
            got = _t10_err(() -> _model_card_stanza_policy(both;
                              allow_priors=allow_p, allow_constraints=allow_c))
            @test got isa CliError
            @test got.code == "config/invalid"
            # the refused stanza is the one NAMED: with both off it is priors, which
            # is checked first
            @test occursin(allow_p ? "constraints:" : "priors:", got.message)
        end
    end
    # An empty dict is always fine — the overwhelming majority of model files.
    @test _model_card_stanza_policy(Dict{Symbol,Any}()) == Dict{Symbol,Any}()

    # The two loaders apply it with BOTH flags off, so the ~25 leaves that consume
    # neither stanza are covered by one call rather than 25 call sites.
    prior_model = _t10_model("priors:\n  rho ~ beta(2, 2)\n")
    cons_model = _t10_model("constraints:\n  i[t] >= -10\n")
    for (label, path) in (("priors:", prior_model), ("constraints:", cons_model))
        for (which, thunk) in (("_load_dsge_model", () -> _load_dsge_model(path)),
                               ("_load_ha_model", () -> _load_ha_model(path)))
            err = _t10_err(thunk)
            @test err isa CliError
            @test err.code == "config/invalid"
            @test occursin(label, err.message)
        end
    end
    # …and the opt-in still works, so the refusal is a policy and not a block.
    @test _load_dsge_model(prior_model; allow_priors=true) isa MacroEconometricModels.ModelSpec
    @test _load_dsge_model(cons_model; allow_constraints=true) isa MacroEconometricModels.ModelSpec

    # The Bayesian mirror: a `constraints:` stanza is refused BY NAME, ahead of the
    # priors guard. Pre-fix this reported "priors are required…" — a message about
    # the wrong source entirely. Asserting the code, not just the throw, is what
    # tells the two failures apart.
    csv = _t10_csv()
    for (label, thunk) in (
            ("bayes inputs", () -> _dsge_bayes_inputs(; model=cons_model, data=csv,
                        params="rho", priors="", prior=String[], observables="Y",
                        solver="gensys", order=1)),
            ("ha estimate",  () -> _dsge_ha_estimate(; model=cons_model, data=csv,
                        priors="", prior=String[], observables="Y",
                        n_draws=1, burnin=0, n_smc=1)))
        err = _t10_err(thunk)
        @test err isa CliError
        @test err.code == "config/invalid"
        @test err.code != "usage/missing" && err.code != "usage/missing-option"
        @test occursin("constraints:", err.message)
    end

    # A representative sample of the leaves that consume NEITHER stanza, one from
    # each family the grep enumeration in the policy docstring names. Each dies at
    # the loader, before any solve, so this is cheap. Drop the policy from either
    # loader and every one of these goes green (silent acceptance).
    plain_csv = _t10_csv()
    for (label, path) in (("priors:", prior_model), ("constraints:", cons_model))
        for (leaf, thunk) in (
                ("dsge moments",  () -> _dsge_moments(; model=path, output=tempname() * ".json", format="json")),
                ("dsge simulate", () -> _dsge_simulate(; model=path, output=tempname() * ".json", format="json")),
                ("dsge fevd",     () -> _dsge_fevd(; model=path, output=tempname() * ".json", format="json")),
                ("dsge hd",       () -> _dsge_hd(; model=path, data=plain_csv,
                                       observables="Y", output=tempname() * ".json", format="json")),
                ("dsge estimate", () -> _dsge_estimate(; model=path, data=plain_csv, params="rho",
                                       output=tempname() * ".json", format="json")),
                ("dsge ha solve", () -> _dsge_ha_solve(; model=path, output=tempname() * ".json", format="json")))
            err = _t10_err(thunk)
            @test err isa CliError
            @test err.code == "config/invalid"
            @test occursin(label, err.message)
        end
    end

    # …and the other direction of the same policy is untouched: the OccBin leaves
    # still CONSUME a `constraints:` stanza rather than refusing it.
    @test _t10_err(() -> _dsge_steady_state(; model=cons_model,
                    output=tempname() * ".json", format="json")) === nothing
    @test _t10_err(() -> _dsge_bayes_inputs(; model=prior_model, data=csv, params="rho",
                    priors="", prior=String[], observables="Y", solver="gensys", order=1)) === nothing
end

@testset "dsge bayes compare gives model 2 the same third source (CARD-W2 #210)" begin
    # F1. `isempty(priors2) && error(...)` ran before any model was loaded, so the
    # third source was UNREACHABLE for model 2: a user who put `priors:` in both
    # model files still had to write a priors TOML for model 2, and any parameter
    # the two shared became a hard three-source collision.
    # A 1-endogenous AR(1) so the mock SMC actually completes: case (a) needs the
    # whole comparison to run, and that is what makes it a proof that model 2's
    # stanza is CONSUMED rather than merely tolerated.
    ar1(card) = (f = tempname() * ".jl"; write(f, card * """
    @dsge begin
        parameters: rho = 0.9, sigma = 0.01
        endogenous: Y
        exogenous: e
        linear: true

        Y[t] = rho * Y[t-1] + sigma * e[t]
    end
    """); f)
    csv = (p = tempname() * ".csv";
           write(p, "Y\n" * join([string(0.1 * i) for i in 1:40], "\n") * "\n"); p)
    plain_model = ar1("")
    prior_model = ar1("priors:\n  rho ~ beta(2, 2)\n  sigma ~ inv_gamma(2, 0.1)\n")
    pri_toml = _t10_toml("[priors.rho]\ndist = \"beta\"\na = 2.0\nb = 2.0\n" *
                         "[priors.sigma]\ndist = \"inv_gamma\"\na = 2.0\nb = 0.1\n")
    cmp(; model, model2, params2, priors2) = _dsge_bayes_compare(;
        model, data=csv, params="rho,sigma", priors=pri_toml, sampler="smc",
        n_smc=2, n_particles=4, n_draws=4, burnin=1, ess_target=0.5,
        observables="Y", solver="gensys", order=1, delayed_acceptance=false,
        model2, params2, priors2, output=tempname() * ".json", format="json")

    # (a) Model 2's own `priors:` stanza, with NO --priors2, and the comparison
    # completes. Pre-fix `isempty(priors2) && error(...)` fired before any model
    # was loaded, so this was an untyped ErrorException; the guard asserted the
    # ABSENCE of its message (over both that and a typed CliError), so any revert
    # goes red. A COMPLETED run is the stronger half: it can only happen if the
    # stanza was read, merged and bridged into model 2's prior distributions.
    @test _t10_err(() -> cmp(model=plain_model, model2=prior_model,
                             params2="rho,sigma", priors2="")) === nothing

    # (b) The trap the review described, now with model 1's behaviour rather than
    # inverted: a --priors2 file that shares a parameter with model 2's stanza is a
    # two-of-three collision naming BOTH sources. Revert the guard and this exits 0
    # instead; keep the guard and skip the merge and it exits 0 too.
    e = _t10_err(() -> cmp(model=plain_model, model2=prior_model,
                           params2="rho,sigma", priors2=pri_toml))
    @test e isa CliError
    @test e.code == "config/invalid"
    # WHICH shared parameter is named depends on Dict iteration order, so the test
    # says so: the message must name a real one of the two, not just "conflict".
    named = match(r"prior '(\w+)' is given twice", e.message)
    @test named !== nothing
    @test named[1] in ("rho", "sigma")
    @test occursin("stanza", e.message)      # one of the two sources is the stanza
    @test occursin("--priors", e.message)    # …and the other is the file
    @test !occursin("--prior ", e.message)   # NOT the --prior line source

    # (c) Neither source for model 2: the guard fires, with the SHARED message
    # const (one copy, as everywhere else) plus a hint naming the Model-2 flag the
    # user actually has. The old code raised a bare `error()` → exit 1, no envelope.
    e2 = _t10_err(() -> cmp(model=plain_model, model2=plain_model,
                            params2="rho,sigma", priors2=""))
    @test e2 isa CliError
    @test e2.code == "usage/missing-option"
    @test e2.message == _PRIORS_REQUIRED_MESSAGE
    @test occursin("--priors2", e2.hint)
    m = lowercase(e2.message)
    @test findfirst("--prior", m) < findfirst("priors:", m) < findfirst("--priors", m)

    # (d) --priors2 still satisfies it — the guard is not now unconditional.
    e0 = _t10_err(() -> cmp(model=plain_model, model2=plain_model,
                            params2="rho,sigma", priors2=pri_toml))
    m0 = e0 === nothing ? "" : (e0 isa CliError ? e0.message : sprint(showerror, e0))
    @test !occursin("--priors2", m0)
    @test !occursin("priors are required", m0)

    # (e) The two other compare guards are TYPED now. They were bare `error()` →
    # exit 1 with no envelope, which `@test_throws Exception` in test_commands.jl
    # cannot tell but a user could.
    for (kw, token) in (((; model2="", params2="rho,sigma", priors2=pri_toml), "--model2"),
                        ((; model2=plain_model, params2="", priors2=pri_toml), "--params2"))
        err = _t10_err(() -> cmp(; model=plain_model, kw...))
        @test err isa CliError
        @test err.code == "usage/missing-option"
        @test occursin(token, err.message)
    end
end

@testset "stanza + flag + file are one set (CARD-W2 #210)" begin
    @testset "a priors: stanza alone satisfies a required-priors leaf" begin
        # The whole point of the wave: `dsge bayes` is a REQUIRED-priors leaf, and
        # before this task a model file's `priors:` stanza was lowered, VALIDATED and
        # then thrown away — so a user who wrote the priors where the model lives
        # still got `usage/missing`.
        #
        # Goes through the real handler, not the resolver, because the guard
        # (`isempty(priors) && isempty(prior) && !haskey(stanzas, :priors)`) is a
        # separate piece of behaviour from the merge.
        mj = tempname() * ".jl"
        write(mj, """
        priors:
          rho ~ beta(0.5, 0.2)

        @dsge begin
            parameters: rho = 0.9
            endogenous: Y
            exogenous: e
            linear: true

            Y[t] = rho * Y[t-1] + e[t]
        end
        """)
        csv = tempname() * ".csv"
        write(csv, "Y\n0.1\n0.2\n0.15\n")

        inp = _dsge_bayes_inputs(; model=mj, data=csv, params="rho", priors="",
                                 prior=String[], observables="Y", solver="gensys", order=1)
        # The VALUE, not merely "it did not throw": a prior map that lost the stanza
        # would be empty, and a default the fixture happens to match would prove
        # nothing. beta(0.5, 0.2) is the fixture's own choice.
        @test collect(keys(inp.priors_dict)) == [:rho]
        d = inp.priors_dict[:rho]
        @test d isa MacroEconometricModels.Distributions.Beta
        @test d.α == 0.5 && d.β == 0.2
    end

    @testset "neither stanza, flag nor file — still the shared usage/missing" begin
        # The other direction, and the reason the stanza branch above is not a way
        # to delete the guard. Deleting `|| !haskey(...)`-style checks, or the whole
        # guard, is what this pins: a plain model with no priors anywhere must still
        # be told about all THREE ways to supply them, from the ONE const.
        mj = tempname() * ".jl"
        write(mj, "@dsge begin\n    parameters: rho = 0.9\n    endogenous: Y\n" *
                  "    exogenous: e\n    linear: true\n    Y[t] = rho * Y[t-1] + e[t]\nend\n")
        csv = tempname() * ".csv"
        write(csv, "Y\n0.1\n0.2\n")

        e = _t10_err(() -> _dsge_bayes_inputs(; model=mj, data=csv, params="rho",
            priors="", prior=String[], observables="Y", solver="gensys", order=1))
        @test e isa CliError && e.code == "usage/missing"
        @test e.message == _PRIORS_REQUIRED_MESSAGE
        # The message still names all three sources, in the mandated order.
        m = lowercase(e.message)
        @test findfirst("--prior", m) < findfirst("priors:", m) < findfirst("--priors", m)
        # `_model_card_stanzas_for` must not turn a missing/builtin model path into
        # an untyped `read` error: it is a no-op, and the loader's own typed
        # data/file-not-found still fires.
        e2 = _t10_err(() -> _dsge_bayes_inputs(; model="no_such_model_210.jl", data=csv,
            params="rho", priors="", prior=String[], observables="Y", solver="gensys", order=1))
        @test e2 isa CliError && e2.code == "usage/missing"
        @test e2.message == _PRIORS_REQUIRED_MESSAGE
    end

    @testset "the HA Bayesian guard takes the same third source" begin
        # `_dsge_ha_estimate` guards on the same const but a DIFFERENT error code
        # (`usage/missing-option`), so it needs its own probe — the two signatures
        # share no kwarg superset and a merged probe would MethodError before
        # reaching the guard.
        csv = tempname() * ".csv"
        write(csv, "K\n0.1\n0.2\n")

        # No card anywhere: the guard fires, with the shared message.
        e = _t10_err(() -> _dsge_ha_estimate(; model="huggett", data=csv, priors="",
            prior=String[], observables="K", n_draws=1, burnin=0, n_smc=1))
        @test e isa CliError && e.code == "usage/missing-option"
        @test e.message == _PRIORS_REQUIRED_MESSAGE

        # A `huggett` BUILTIN is not a file: the stanza probe must not read it.
        # (Without the isfile guard this is an untyped SystemError, exit 1.)
        @test _model_card_stanzas_for("huggett") == Dict{Symbol,Any}()
        @test _model_card_stanzas_for("") == Dict{Symbol,Any}()
        @test isempty(_model_card_stanzas_for(tempname() * ".jl"))   # never written

        # A card-bearing model file gets PAST the priors guard. The load then fails
        # for an unrelated reason (this is a representative-agent spec, and the
        # Bayesian machinery is not reached on mocks) — what matters is that the
        # failure is NO LONGER the priors one, which is exactly what reverting the
        # stanza source would restore.
        card = tempname() * ".jl"
        write(card, """
        priors:
          k ~ beta(0.5, 0.2)

        @dsge begin
            parameters: k = 0.9
            endogenous: Y
            exogenous: e
            linear: true

            Y[t] = k * Y[t-1] + e[t]
        end
        """)
        e2 = _t10_err(() -> _dsge_ha_estimate(; model=card, data=csv, priors="",
            prior=String[], observables="Y", n_draws=1, burnin=0, n_smc=1))
        @test e2 isa CliError
        @test e2.code != "usage/missing-option"
        @test e2.message != _PRIORS_REQUIRED_MESSAGE
    end

    @testset "all three prior sources merge, and each pair collides" begin
        # No collision: one parameter from each of the three sources, all present.
        toml = _t10_toml("[priors.sigma]\ndist = \"inv_gamma\"\na = 2.0\nb = 0.5\n")
        got = _resolve_dsge_priors(toml, ["rho ~ beta(2, 2)"];
                                   stanzas=_t10_priors("alpha ~ gamma(3, 4)"))
        @test sort(collect(keys(got))) == ["alpha", "rho", "sigma"]
        @test got["alpha"] == Dict("dist" => "gamma", "a" => 3.0, "b" => 4.0)

        # A parameter in TWO of the three is config/invalid, and the message names
        # the parameter AND both sources. Three separate pairs — a guard that only
        # covered the file would leave two of these green.
        rho_toml = _t10_toml("[priors.rho]\ndist = \"beta\"\na = 2.0\nb = 2.0\n")
        cases = Any[
            ("flag x stanza",  () -> _resolve_dsge_priors("", ["rho ~ beta(3, 3)"]; stanzas=_t10_priors("rho ~ beta(2, 2)"))),
            ("file x stanza",  () -> _resolve_dsge_priors(rho_toml, String[]; stanzas=_t10_priors("rho ~ beta(2, 2)"))),
            ("flag x file",    () -> _resolve_dsge_priors(rho_toml, ["rho ~ beta(3, 3)"])),
        ]
        for (label, thunk) in cases
            e = _t10_err(thunk)
            @test e isa CliError
            @test e.code == "config/invalid"
            @test occursin("rho", e.message)              # the duplicated NAME
            @test occursin("twice", e.message)
            @test !occursin("sigma", e.message)           # and no other parameter
            if label == "flag x stanza"
                @test occursin("--prior", e.message)
                @test occursin("stanza", e.message)
            elseif label == "file x stanza"
                @test occursin("--priors", e.message)
                @test occursin("stanza", e.message)
            else
                @test occursin("--priors", e.message) && occursin("--prior", e.message)
                @test !occursin("stanza", e.message)
            end
        end

        # The stanza ALONE is a complete source (no flag, no file).
        only_st = _resolve_dsge_priors("", String[]; stanzas=_t10_priors("rho ~ beta(2, 2)"))
        @test only_st == Dict("rho" => Dict("dist" => "beta", "a" => 2.0, "b" => 2.0))
    end

    @testset "all three bound sources merge, and each pair collides" begin
        toml = _t10_toml("[[constraints.bounds]]\nvariable = \"c\"\nlower = -2.0\n")
        got = _resolve_dsge_constraints(toml, ["i[t] >= 0"]; stanzas=_t10_constraints("j[t] <= 5"))
        @test length(got) == 3
        @test sort([String(c.var_name) for c in got]) == ["c", "i", "j"]

        cases = Any[
            ("flag x stanza",  () -> _resolve_dsge_constraints("", ["i[t] >= -5"]; stanzas=_t10_constraints("i[t] >= -10"))),
            ("file x stanza",  () -> _resolve_dsge_constraints(_t10_toml("[[constraints.bounds]]\nvariable = \"i\"\nlower = -10.0\n"), String[]; stanzas=_t10_constraints("i[t] >= -10"))),
            ("flag x file",    () -> _resolve_dsge_constraints(_t10_toml("[[constraints.bounds]]\nvariable = \"i\"\nlower = -10.0\n"), ["i[t] >= -5"])),
        ]
        for (label, thunk) in cases
            e = _t10_err(thunk)
            @test e isa CliError
            @test e.code == "config/invalid"
            @test occursin("'i'", e.message)              # the duplicated VARIABLE
            @test occursin(">=", e.message)               # the duplicated DIRECTION
            @test occursin("supply it once", e.message)
            if label == "flag x stanza"
                @test occursin("--constraint", e.message) && occursin("stanza", e.message)
            elseif label == "file x stanza"
                @test occursin("--constraints", e.message) && occursin("stanza", e.message)
            else
                @test occursin("--constraints", e.message) && occursin("--constraint", e.message)
            end
        end

        # A different DIRECTION is not a collision, stanza or not: the same variable
        # bounded from both sides is two bounds. A guard that keyed on the variable
        # alone would reject this.
        both = _resolve_dsge_constraints("", String[]; stanzas=_t10_constraints("-1.0 <= i[t] <= 2.0"))
        @test length(both) == 1
        @test both[1].var_name == :i && both[1].lower == -1.0 && both[1].upper == 2.0
        cross = _resolve_dsge_constraints("", ["i[t] <= 0"]; stanzas=_t10_constraints("i[t] >= -10"))
        @test length(cross) == 2

        # A card's constraints stanza declares BOUNDS only; a hand-built dict
        # carrying a nonlinear OccBin expression must not be silently dropped.
        nl = Dict{Symbol,Any}(:constraints =>
            Dict{String,Any}("bounds" => [Dict{String,Any}("variable" => "i", "lower" => -10.0)],
                             "nonlinear" => [Dict{String,Any}("expr" => "g(i[t])")]))
        e = _t10_err(() -> _resolve_dsge_constraints("", String[]; stanzas=nl))
        @test e isa CliError && e.code == "config/invalid"
        @test occursin("nonlinear", e.message)
    end

    @testset "the two-positional-arg form is unchanged (the defaults are load-bearing)" begin
        # Every Task 6 call site passes two positional args. If the new keyword had
        # a non-empty default, or the positional path bypassed the merge, this is
        # where it shows — the comparison is against the SAME call made explicitly
        # with an empty stanza dict, over a fixture that exercises the file+lines
        # merge rather than the trivial one-source case.
        toml = _t10_toml("[priors.sigma]\ndist = \"inv_gamma\"\na = 2.0\nb = 0.5\n")
        @test _resolve_dsge_priors(toml, ["rho ~ beta(2, 2)"]) ==
              _resolve_dsge_priors(toml, ["rho ~ beta(2, 2)"]; stanzas=Dict{Symbol,Any}())
        @test _resolve_dsge_priors(toml, ["rho ~ beta(2, 2)"])["sigma"] ==
              Dict("dist" => "inv_gamma", "a" => 2.0, "b" => 0.5)

        cfile = _t10_toml("[[constraints.bounds]]\nvariable = \"c\"\nlower = -2.0\n")
        @test _resolve_dsge_constraints(cfile, ["i[t] >= 0"]) ==
              _resolve_dsge_constraints(cfile, ["i[t] >= 0"];
                                          stanzas=Dict{Symbol,Any}(), spec=nothing)
        @test length(_resolve_dsge_constraints(cfile, ["i[t] >= 0"])) == 2

        # The same two-positional call on the EMPTY case: still an empty result, not
        # an exception (the leaf guards own the user-facing error).
        @test _resolve_dsge_priors("", String[]) == Dict{String,Any}()
        @test isempty(_resolve_dsge_constraints("", String[]))

        # `spec` appears exactly once on the constraints resolver — Task 6 added it
        # and this task must not add it a second time (which would be a parse error,
        # so what is really pinned is that `spec` is still honoured when given).
        @test length(_resolve_dsge_constraints(cfile, String[]; spec=nothing)) == 1
    end
end

@testset "the four OccBin leaves take a constraints: stanza and refuse a priors: one (CARD-W2 #210)" begin
    # `_dsge_solve`, `_dsge_steady_state`, `_dsge_irf`, `_dsge_perfect_foresight`
    # are the four leaves that declare `--constraints` / `--constraint`.
    mkmodel(card) = _t10_model(card)   # hoisted: the policy testset needs it too

    cons_model = mkmodel("constraints:\n  i[t] >= -10\n")
    prior_model = mkmodel("priors:\n  rho ~ beta(2, 2)\n")

    # A `constraints:` stanza with NO --constraints and NO --constraint must still
    # ENTER the constrained branch. Proved by a collision: the stanza's bound plus a
    # --constraint line on the same variable in the same direction is
    # config/invalid. Drop `haskey(stanzas, :constraints)` from the branch guard
    # and the branch is skipped entirely — exit 0, the stanza silently dropped —
    # which is exactly what this assertion turns red.
    probes = Any[
        ("solve",            () -> _dsge_solve(; model=cons_model, constraints="",
                                    constraint=["i[t] >= -5"], periods=3, format="json")),
        ("steady-state",     () -> _dsge_steady_state(; model=cons_model, constraints="",
                                    constraint=["i[t] >= -5"], format="json")),
        ("irf",              () -> _dsge_irf(; model=cons_model, constraints="",
                                    constraint=["i[t] >= -5"], horizon=3, format="json")),
        ("perfect-foresight",() -> _dsge_perfect_foresight(; model=cons_model, constraints="",
                                    constraint=["i[t] >= -5"], periods=3, format="json")),
    ]
    for (label, thunk) in probes
        e = _t10_err(thunk)
        @test e isa CliError
        @test e.code == "config/invalid"
        @test occursin("'i'", e.message)
        @test occursin("stanza", e.message)       # the stanza is one of the two sources
    end

    # The probes above also pass a --constraint line, so they cannot tell a dropped
    # BRANCH GUARD from a dropped merge. This one is stanza-ONLY, and the card
    # grammar does NOT reject a within-stanza duplicate bound (unlike
    # `lower_priors`, which does), so the resolver is the only thing that can.
    # Delete `|| haskey(stanzas, :constraints)` from any of the four branch guards
    # and the resolver is never called: all four exit 0 with the stanza dropped.
    dup_stanza = mkmodel("constraints:\n  i[t] >= -10\n  i[t] >= -5\n")
    dup_probes = Any[
        ("solve",            () -> _dsge_solve(; model=dup_stanza, periods=3,
                                    output=tempname() * ".json", format="json")),
        ("steady-state",     () -> _dsge_steady_state(; model=dup_stanza,
                                    output=tempname() * ".json", format="json")),
        ("irf",              () -> _dsge_irf(; model=dup_stanza, horizon=3,
                                    output=tempname() * ".json", format="json")),
        ("perfect-foresight",() -> _dsge_perfect_foresight(; model=dup_stanza, periods=3,
                                    output=tempname() * ".json", format="json")),
    ]
    for (label, thunk) in dup_probes
        e = _t10_err(thunk)
        @test e isa CliError
        @test e.code == "config/invalid"
        @test occursin("'i'", e.message)
        @test occursin("supply it once", e.message)
        # within ONE source there is no "across …" clause: nothing to blame
        @test !occursin("--constraint", e.message)
        @test !occursin("stanza", e.message)
    end

    # A `priors:` stanza is a BAYESIAN concept and these four leaves are
    # frequentist. Accepting it would drop configuration the user believed was
    # applied, so it is loud and it names the stanza. Removing the rejection makes
    # every one of these exit 0 on the mock solvers instead.
    priors_probes = Any[
        ("solve",            () -> _dsge_solve(; model=prior_model, constraints="",
                                    constraint=["i[t] >= -10"], periods=3, format="json")),
        ("steady-state",     () -> _dsge_steady_state(; model=prior_model, constraints="",
                                    constraint=["i[t] >= -10"], format="json")),
        ("irf",              () -> _dsge_irf(; model=prior_model, constraints="",
                                    constraint=["i[t] >= -10"], horizon=3, format="json")),
        ("perfect-foresight",() -> _dsge_perfect_foresight(; model=prior_model, constraints="",
                                    constraint=["i[t] >= -10"], periods=3, format="json")),
    ]
    for (label, thunk) in priors_probes
        e = _t10_err(thunk)
        @test e isa CliError
        @test e.code == "config/invalid"
        @test occursin("priors:", e.message)
        @test occursin("frequentist", e.message)
    end

    # The plainest control: a model file with NO card is accepted, so the two cases
    # above are rejecting the STANZA and not the file. `output=` sends the
    # steady-state table to a file so this probe cannot pollute the test stdout.
    plain = mkmodel("")
    sink = tempname() * ".json"
    @test _t10_err(() -> _dsge_steady_state(; model=plain, output=sink, format="json")) === nothing
    @test isfile(sink)
end

@testset "a gmm lp: stanza in a dsge file is config/invalid (CARD-W2 #210, regression pin)" begin
    # Shipped and pinned by task 9 (Wave D), so this is GREEN from the start and is
    # here only so a future widening of `_model_card_stanzas` cannot quietly let a
    # non-model card into a model file. The assertion is on the DISTINCTIVE wording
    # rather than the code, because a Julia ParseError also yields config/invalid
    # and quotes the offending source line.
    f = tempname() * ".jl"
    write(f, "gmm lp:\n  moments: y\n@dsge begin\nend\n")
    e = _t10_err(() -> _load_dsge_model(f))
    @test e isa CliError && e.code == "config/invalid"
    @test occursin("gmm lp", e.message)
    @test occursin("is not allowed in a .jl model file", e.message)
end

@testset "round 3: the empty-source advice and the dcegm loader (CARD-W2 #210)" begin
    @testset "an empty --constraint value is not told to delete a stanza header (NEW-4)" begin
        # `_card_inline("constraints", [""])` is `"constraints:\n  "`, which lowers to
        # ZERO bounds — so `--constraint ""` reaches the SAME guard as an empty
        # stanza and must not be advised to remove a header the user never wrote.
        # That is the rule the duplicate-bound message already follows.
        e = _t10_err(() -> _resolve_dsge_constraints("", [""]))
        @test e isa CliError
        @test e.code == "config/invalid"
        @test occursin("--constraint", e.message)
        @test occursin("var[t] >= 0", e.message)
        @test !occursin("stanza", e.message)          # ← the pin

        # …and the branch is not one-directional: the STANZA still gets the stanza
        # advice, so neither message can absorb the other.
        empty_st = Dict{Symbol,Any}(
            :constraints => lower_constraints(parse_card("constraints:\n"), "m.jl"))
        e2 = _t10_err(() -> _resolve_dsge_constraints("", String[]; stanzas=empty_st))
        @test e2 isa CliError && e2.code == "config/invalid"
        @test occursin("stanza", e2.message)
        @test !occursin("--constraint", e2.message)

        # At a leaf, on the path a user actually types.
        leaf = _t10_err(() -> _dsge_steady_state(; model=_t10_model(""),
                             constraint=[""], output=tempname() * ".json", format="json"))
        @test leaf isa CliError && leaf.code == "config/invalid"
        @test !occursin("stanza", leaf.message)
        @test occursin("--constraint", leaf.message)
    end

    @testset "dsge dcegm is governed by the same policy (NEW-3)" begin
        # `_load_dcegm_source` is the THIRD `.jl` model loader in src/ and it does
        # not go through `_load_dsge_model`, so the docstring's enumeration used to
        # claim coverage that did not exist. `dsge dcegm` consumes NEITHER stanza, so
        # a `priors:` card in its model file is refused like everywhere else.
        carded = _t10_model("priors:\n  rho ~ beta(2, 2)\n")
        e = _t10_err(() -> _load_dcegm_source(carded))
        @test e isa CliError
        @test e.code == "config/invalid"
        @test occursin("priors:", e.message)

        cons = _t10_model("constraints:\n  i[t] >= -10\n")
        e1 = _t10_err(() -> _load_dcegm_source(cons))
        @test e1 isa CliError && e1.code == "config/invalid"
        @test occursin("constraints:", e1.message)

        # The control that makes the two above mean something: a CARD-FREE dcegm
        # model file still reaches the loader body and fails there for its own
        # reason (this RA spec has no DCEGMSystem), so the policy did not fire.
        e2 = _t10_err(() -> _load_dcegm_source(_t10_model("")))
        @test e2 isa CliError
        @test e2.code != "config/invalid"
        @test !occursin("stanza", e2.message)
    end
end
