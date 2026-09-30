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
        # The DISTINCTIVE wording, not just the token: a Julia ParseError quotes
        # the source line and would also contain "labels", so only this string
        # separates our probe from a generic syntax error.
        @test occursin("is not a model-card stanza header", err.message)
        @test occursin("labels", err.message)
    end

    @testset "only a real header is a header — Julia colons are ordinary Julia" begin
        # Every one of these preambles is ordinary Julia or a non-card header and
        # must load EXACTLY as it did before the splitter existed. The first
        # group regressed a real file; the Greek identifier is here so the
        # behaviour can never come back by accident through the ASCII class.
        julia_ok = [
            "using Statistics: mean",
            "using LinearAlgebra: I",
            "import Printf: @sprintf",
            "const x::Float64 = 0.9",
            "rho_default::Float64 = 0.9",
            "const α::Float64 = 0.3",      # non-ASCII: must not depend on ASCII-ness
            "n_extra = 3",
            "labels = [\"a\", \"b\"]",
            "f(x) = x^2",
            "D = Dict(:a => 1)",
            "struct S; x; end",
            "# comment only",
            "",
        ]
        for line in julia_ok
            f = tempname() * ".jl"
            write(f, string(line, "\n@dsge begin\nend\n"))
            card, model = _split_card_and_model(f)
            @test card === nothing
            @test occursin("@dsge begin", model)          # still the model
            @test model == read(f, String)                # whole file, byte for byte
        end

        # A shape that is NOT one of the known headers is loud, and the message
        # names it. (`instruments` is deliberately absent — it IS a real card
        # header, so it is rejected one layer later, by `_model_card_stanzas`,
        # not by this probe.)
        for (line, token) in ["labels:" => "labels", "gmm sq:" => "gmm sq",
                              "constraints extra:" => "constraints extra"]
            f = tempname() * ".jl"
            write(f, string(line, "\n@dsge begin\nend\n"))
            err = try; _split_card_and_model(f); nothing; catch e; e; end
            @test err isa CliError && err.code == "config/invalid"
            @test occursin("is not a model-card stanza header", err.message)
            @test occursin(token, err.message)
        end
    end

    @testset "docstring prose is not a card header" begin
        # A docstring is the most common preamble idiom in a Julia model file,
        # and its prose is written as `Model: …` / `Parameters: …`. Reading that
        # as a header attempt rejects a file that loaded before the splitter
        # existed — with the actively-misleading "write the assignment without
        # the colon" wording, since there is no assignment in prose.
        doc = "\"\"\"\nModel: AR(1) with a constant.\nParameters: rho, sigma.\n\"\"\"\n"
        f = tempname() * ".jl"
        write(f, doc * "const MODEL_NOTE = \"AR(1)\"\n@dsge begin\nend\n")
        card, model = _split_card_and_model(f)
        @test card === nothing
        @test model == read(f, String)          # byte-for-byte, docstring intact

        # The same text in a TRAILING docstring must not be reported as a
        # misplaced card either — that was the second call site.
        f2 = tempname() * ".jl"
        write(f2, "priors:\n  rho ~ beta(2, 2)\n@dsge begin\nend\n" *
                   "\"\"\"\nModel: trailing note.\n\"\"\"\n")
        card2, model2 = _split_card_and_model(f2)
        @test occursin("priors:", card2)
        @test !occursin("Model:", model2)

        # A real header immediately AFTER a closed docstring is still found —
        # the parity flag must reset, not latch.
        f3 = tempname() * ".jl"
        write(f3, "\"\"\"\nDoc: prose.\n\"\"\"\nlabels: = [\"a\"]\n@dsge begin\nend\n")
        err = try; _split_card_and_model(f3); nothing; catch e; e; end
        @test err isa CliError && err.code == "config/invalid"
        @test occursin("is not a model-card stanza header", err.message)
        @test occursin("labels", err.message)

        # `x = """Model: a"""` is one line with an EVEN delimiter count, so it
        # opens nothing; the `x` keyword check would also cover it, but the
        # code-part cut is what keeps the prose out of the match.
        f4 = tempname() * ".jl"
        write(f4, "const NOTE = \"\"\"Model: inline\"\"\"\n@dsge begin\nend\n")
        @test _split_card_and_model(f4)[1] === nothing
    end

    @testset "two @dsge blocks — the LAST one is the model, with or without a card" begin
        # The loader's documented contract is that the file's LAST expression is
        # the ModelSpec, and the no-card path `include`s the whole file. A card
        # must not change which model is solved: taking the FIRST block would
        # silently swap the answer with exit 0 and no warning.
        two = "@dsge begin\n    parameters: rho = 0.5\n    endogenous: Y\n" *
              "    exogenous: e\n    Y[t] = rho * Y[t-1] + e[t]\nend\n" *
              "@dsge begin\n    parameters: rho = 0.9\n    endogenous: Y\n" *
              "    exogenous: e\n    Y[t] = rho * Y[t-1] + e[t]\nend\n"
        f1 = tempname() * ".jl"
        write(f1, two)
        @test _split_card_and_model(f1)[1] === nothing       # no card: whole file

        f2 = tempname() * ".jl"
        write(f2, "priors:\n  rho ~ beta(2, 2)\n" * two)
        card, model = _split_card_and_model(f2)
        @test occursin("priors:", card)
        @test occursin("rho = 0.9", model)     # the LAST block
        @test !occursin("rho = 0.5", model)    # the first block is not the model

        # And at the loader: both files must yield the same rho-dependent spec.
        # `allow_priors=true` declares that this caller CONSUMES the `priors:`
        # stanza; the loader's default policy refuses a stanza a leaf cannot use
        # (CARD-W2 #210, F2), and this probe is about which block is solved, not
        # about the priors themselves.
        s1 = _load_dsge_model(f1)
        s2 = _load_dsge_model(f2; allow_priors=true)
        @test s1 isa MacroEconometricModels.ModelSpec
        @test s2 isa MacroEconometricModels.ModelSpec
        @test s1.n_endog == s2.n_endog == 1

        # A model file that documents its own usage with an example `@dsge`
        # block is ordinary, and that example is a column-0 `@dsge` inside a
        # docstring. The block scan shares the header probe's triple-quote
        # parity, so `last` cannot land on the prose: pre-fix the docstring
        # example won and rho = 0.99 was solved with exit 0.
        f3 = tempname() * ".jl"
        write(f3, "priors:\n  rho ~ beta(2, 2)\n" * two *
                   "\n\"\"\"\nAn example model:\n\n@dsge begin\n" *
                   "    parameters: rho = 0.99\nend\n\"\"\"\n" *
                   "const EXAMPLE_NOTE = true\n")
        card3, model3 = _split_card_and_model(f3)
        @test occursin("priors:", card3)
        @test occursin("rho = 0.9", model3)     # the real LAST block
        @test !occursin("rho = 0.99", model3)   # never the docstring example
        # And at the loader: the documented example must not become the spec.
        # `f3` declares `priors:`, and this probe exercises the splitter, not the
        # leaf's stanza policy — opt in so the loader actually reaches the file.
        s3 = _load_dsge_model(f3; allow_priors=true)
        @test s3 isa MacroEconometricModels.ModelSpec
        @test s3.n_endog == 1
    end

    @testset "a stanza BETWEEN two @dsge blocks is named, not executed" begin
        # `pre` stops at the first block and the tail starts after the last, so
        # without an explicit scan of the inter-block region this text is
        # examined by nothing and reaches `include_string` as a bare
        # ParseError — same exit class, but the line-naming message is lost.
        blk(rho) = "@dsge begin\n    parameters: rho = $rho\n    endogenous: Y\n" *
                   "    exogenous: e\n    Y[t] = rho * Y[t-1] + e[t]\nend\n"
        for stanza in ("priors:\n  rho ~ beta(2, 2)\n",
                       "gmm lp:\n  moments: y\n",
                       "Model: notes\n")
            f = tempname() * ".jl"
            write(f, blk(0.5) * stanza * blk(0.9))
            err = try; _split_card_and_model(f); nothing; catch e; e; end
            @test err isa CliError && err.code == "config/invalid"
            @test occursin("below the @dsge block", err.message)
        end
        # The same rule, at the loader, where the text used to be executed.
        f = tempname() * ".jl"
        write(f, blk(0.5) * "priors:\n  rho ~ beta(2, 2)\n" * blk(0.9))
        err = try; _load_dsge_model(f); nothing; catch e; e; end
        @test err isa CliError && err.code == "config/invalid"
        @test occursin("below the @dsge block", err.message)
        # The named line number is the real one in the file (line 7 = `priors:`).
        @test occursin("line 7:", err.message)
        # A well-formed file with two blocks and nothing between them is unaffected.
        f2 = tempname() * ".jl"
        write(f2, blk(0.5) * blk(0.9))
        @test _split_card_and_model(f2)[1] === nothing
    end

    @testset "a stanza below the @dsge block is rejected and never executed" begin
        f = tempname() * ".jl"
        write(f, "@dsge begin\nend\nconstraints:\n  Y[t] >= -10\n")
        err = try; _split_card_and_model(f); nothing; catch e; e; end
        @test err isa CliError && err.code == "config/invalid"
        @test occursin("below the @dsge block", err.message)
        # And the post-block text is not handed to the evaluator.
        f2 = tempname() * ".jl"
        write(f2, "priors:\n  rho ~ beta(2, 2)\n@dsge begin\nend\n# trailing note\n")
        card, model = _split_card_and_model(f2)
        @test !occursin("trailing note", model)
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

    # `using X: y` and `x::T` above @dsge: ordinary Julia that loaded before the
    # splitter existed. The probe must not read either as a bad header — this is
    # the regression that broke real model files.
    f6 = tempname() * ".jl"
    write(f6, """
    using LinearAlgebra: I
    const rho_default::Float64 = 0.9
    import Printf: @sprintf
    @dsge begin
        parameters: rho = 0.9
        endogenous: Y
        exogenous: e
        Y[t] = rho * Y[t-1] + e[t]
    end
    """)
    spec6 = _load_dsge_model(f6)
    @test spec6 isa MacroEconometricModels.ModelSpec
    @test spec6.n_endog == 1

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
    spec2 = _load_dsge_model(f2; allow_priors=true)
    @test spec2 isa MacroEconometricModels.ModelSpec
    @test spec2.n_endog == 1

    # A non-priors/constraints stanza in a model file is loud, not ignored.
    f3 = tempname() * ".jl"
    write(f3, "gmm lp:\n  moments: y\n@dsge begin\nend\n")
    err = try; _load_dsge_model(f3); nothing; catch e; e; end
    @test err isa CliError && err.code == "config/invalid"

    # A column-0 `ident:` is loud, with the line named. Assert the DISTINCTIVE
    # wording: pre-patch this input also ended in config/invalid (a Julia
    # ParseError that quotes the source line, which contains "labels"), so
    # `occursin("labels", …)` alone cannot tell the two apart.
    f4 = tempname() * ".jl"
    write(f4, "labels: = [\"a\"]\n@dsge begin\nend\n")
    err4 = try; _load_dsge_model(f4); nothing; catch e; e; end
    @test err4 isa CliError && err4.code == "config/invalid"
    @test occursin("is not a model-card stanza header", err4.message)
    @test occursin("labels", err4.message)

    # A card below the model is rejected at the loader, not evaluated.
    f5 = tempname() * ".jl"
    write(f5, "@dsge begin\n    parameters: rho = 0.9\n    endogenous: Y\n" *
                "    exogenous: e\n    Y[t] = rho * Y[t-1] + e[t]\nend\n" *
                "constraints:\n  Y[t] >= -10\n")
    err5 = try; _load_dsge_model(f5); nothing; catch e; e; end
    @test err5 isa CliError && err5.code == "config/invalid"
    @test occursin("below the @dsge block", err5.message)
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
    @test occursin("is not a model-card stanza header", err.message)

    # Validation is NOT split-only: a `gmm lp:` preamble is rejected on the HA
    # loader exactly as on the RA one, instead of being silently ignored.
    f3 = tempname() * ".jl"
    write(f3, "gmm lp:\n  moments: y\n@dsge begin\nend\n")
    err3 = try; _load_ha_model(f3); nothing; catch e; e; end
    @test err3 isa CliError && err3.code == "config/invalid"
    @test occursin("gmm lp", err3.message)

    # `using X: y` and `x::T` above @dsge stay ordinary Julia here too.
    f4 = tempname() * ".jl"
    write(f4, "using LinearAlgebra: I\nconst k::Float64 = 1.0\n" *
                "MacroEconometricModels.load_ha_example(:huggett)\n")
    @test _load_ha_model(f4) isa MacroEconometricModels.ModelSpec
end
end
