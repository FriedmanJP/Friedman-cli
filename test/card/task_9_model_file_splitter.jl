# Model card unit — task 9: the `.jl` model-file splitter (W2 / #210).
# `shared.jl` is where `_split_card_and_model` / `_model_card_stanzas` live, and
# the card unit runs before `test_commands.jl` (which includes it), so include
# it here the same way.
if !isdefined(@__MODULE__, :_split_card_and_model)
    include(joinpath(dirname(@__DIR__), "..", "src", "commands", "shared.jl"))
end

@testset "_split_card_and_model (CARD-W2 #210)" begin
    @testset "no stanza header — whole file is the model" begin
        f = tempname() * ".jl"
        write(f, "n_extra = 3\n@dsge begin\nend\n")
        card, model = _split_card_and_model(f)
        @test card === nothing
        @test occursin("n_extra = 3", model)   # helper code survives
    end

    @testset "no @dsge at all — whole file is the model" begin
        f = tempname() * ".jl"
        write(f, "n_extra = 3\nlabels = [\"a\", \"b\"]\n")
        card, model = _split_card_and_model(f)
        @test card === nothing
        @test occursin("labels", model)
    end

    @testset "comments-only preamble — whole file is the model" begin
        f = tempname() * ".jl"
        write(f, "# a note\n\n@dsge begin\nend\n")
        card, model = _split_card_and_model(f)
        @test card === nothing
        @test occursin("a note", model)
    end

    @testset "a stanza header — preamble is the card, model is the @dsge slice" begin
        f = tempname() * ".jl"
        write(f, "priors:\n  rho ~ beta(2, 2)\n\n@dsge begin\n    parameters: rho = 0.9\nend\n")
        card, model = _split_card_and_model(f)
        @test occursin("priors:", card)
        @test !occursin("priors:", model)
        @test startswith(strip(model), "@dsge begin")
    end

    @testset "a column-0 ident: in helper code is a loud config/invalid (Review Focus 1)" begin
        f = tempname() * ".jl"
        write(f, "labels: = [\"a\", \"b\"]\n@dsge begin\nend\n")
        err = try; _split_card_and_model(f); nothing; catch e; e; end
        @test err isa CliError && err.code == "config/invalid"
        @test occursin("labels", err.message)
    end

    @testset "a .toml file is never a card" begin
        f = _toml_fixture("[model]\nendogenous = [\"Y\"]\n")
        card, model = _split_card_and_model(f)
        @test card === nothing && model === nothing
    end

    @testset "_model_card_stanzas lowers known stanzas" begin
        f = tempname() * ".jl"
        write(f, """
        priors:
          rho ~ beta(2, 2)
        constraints:
          Y[t] >= -10
        @dsge begin
        end
        """)
        got = _model_card_stanzas(f)
        @test haskey(got, :priors) && haskey(got, :constraints)
        @test got[:priors] == get_dsge_priors(load_config(_toml_fixture("""
        [priors.rho]
        dist = "beta"
        a = 2.0
        b = 2.0
        """)))
        @test length(got[:constraints]["bounds"]) == 1
    end

    @testset "_model_card_stanzas is empty without a card" begin
        f = tempname() * ".jl"
        write(f, "n = 1\n@dsge begin\nend\n")
        @test isempty(_model_card_stanzas(f))
    end

    @testset "_model_card_stanzas rejects a gmm lp stanza in a .jl (Review Focus 1)" begin
        f = tempname() * ".jl"
        write(f, "priors:\n  rho ~ beta(2, 2)\ngmm lp:\n  moments: y\n@dsge begin\nend\n")
        err = try; _model_card_stanzas(f); nothing; catch e; e; end
        @test err isa CliError && err.code == "config/invalid"
        @test occursin("gmm lp", err.message)
    end

@testset "_load_dsge_model routes a .jl through the splitter (CARD-W2 #210)" begin
    mk() = (f = tempname() * ".jl"; write(f, """
    n_extra = 3
    @dsge begin
        parameters: rho = 0.9
        endogenous: Y
        exogenous: e
        Y[t] = rho * Y[t-1] + e[t]
    end
    """); f)

    # Helper code, no card: the whole file is included, so the spec still builds.
    spec = _load_dsge_model(mk())
    @test spec isa MacroEconometricModels.ModelSpec
    @test spec.n_endog == 1

    # Card header present: only the @dsge slice is executed — the card text is
    # parsed, never evaluated, so `rho ~ beta(2, 2)` cannot reach include_string.
    f2 = tempname() * ".jl"
    write(f2, """
    priors:
      rho ~ beta(2, 2)
    @dsge begin
        parameters: rho = 0.9
        endogenous: Y
        exogenous: e
        Y[t] = rho * Y[t-1] + e[t]
    end
    """)
    spec2 = _load_dsge_model(f2)
    @test spec2 isa MacroEconometricModels.ModelSpec
    @test spec2.n_endog == 1

    # A non-priors/constraints stanza in a model file is loud, not ignored.
    f3 = tempname() * ".jl"
    write(f3, "gmm lp:\n  moments: y\n@dsge begin\nend\n")
    err = try; _load_dsge_model(f3); nothing; catch e; e; end
    @test err isa CliError && err.code == "config/invalid"

    # A column-0 `ident:` in helper code is loud, with the line named.
    f4 = tempname() * ".jl"
    write(f4, "labels: = [\"a\"]\n@dsge begin\nend\n")
    err4 = try; _load_dsge_model(f4); nothing; catch e; e; end
    @test err4 isa CliError && err4.code == "config/invalid"
    @test occursin("labels", err4.message)
end

@testset "_load_ha_model takes the same preamble rule (CARD-W2 #210)" begin
    # Ordinary .jl, no @dsge at all: included whole, unchanged behaviour.
    f1 = tempname() * ".jl"
    write(f1, "n_extra = 3\nMacroEconometricModels.load_ha_example(:huggett)\n")
    @test _load_ha_model(f1) isa MacroEconometricModels.ModelSpec

    # A column-0 `ident:` must fail loudly rather than be included as Julia.
    f2 = tempname() * ".jl"
    write(f2, "labels: = [\"a\"]\n@dsge begin\nend\n")
    err = try; _load_ha_model(f2); nothing; catch e; e; end
    @test err isa CliError && err.code == "config/invalid"
    @test occursin("labels", err.message)
end
end
