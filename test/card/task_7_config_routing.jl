# Model card unit — task 7: `--config` routing between TOML and cards
# (W3 / #208).  Self-contained fixtures so this file stands alone.

_task7_tmp = tempname() * ".toml"
_task7_card(s) = (p = tempname() * ".card"; write(p, s); p)
_task7_err(f) = try f(); nothing catch e; e end

# The adapter branch lives in src/registry/adapter.jl, which the T1 suite
# does not load (test_commands.jl does, later). Pull in the same chain so the
# routing is tested against the real wrap_legacy, not a copy of it.
if !isdefined(@__MODULE__, :wrap_legacy)
    _t7root = dirname(dirname(@__DIR__))
    for f in ("commands/shared.jl", "model_handle.jl", "handles.jl",
              "registry/spec.jl", "registry/adapter.jl")
        include(joinpath(_t7root, "src", f))
    end
end

@testset "_load_config_or_card (CARD-W3 #208)" begin
    @testset "a .toml path is unchanged" begin
        # Realistic multi-section fixture: the == is against load_config
        # itself, so ANY drift in the TOML branch shows red here.
        toml = (write(_task7_tmp, """
        [gmm]
        moment_conditions = ["output", "inflation"]
        dep = ""
        endogenous = []
        instruments = []
        theta0 = []
        weighting = "twostep"
        iterations = 1000

        [metadata]
        label = "probe"
        """); _task7_tmp)
        got = _load_config_or_card(toml, :gmm)
        @test got == load_config(toml)
        @test got isa Dict{String,Any}
        @test get_gmm(got)["moment_conditions"] == ["output", "inflation"]
        @test get_gmm(got)["weighting"] == "twostep"
    end

    @testset "a .toml path keeps the --set override merge" begin
        # The adapter's TOML branch must stay on merge_config; a card branch
        # that swallowed this would make --set a silent no-op on 40 leaves.
        toml = (write(_task7_tmp, """
        [gmm]
        moment_conditions = ["output"]
        weighting = "twostep"
        """); _task7_tmp)
        merged = merge_config(toml; set=["gmm.weighting=identity"])
        @test get_gmm(merged)["weighting"] == "identity"
        # And the routing helper refuses --set on a card instead.
        card = _task7_card("gmm lp:\n  moments: output\n")
        err = _task7_err(() -> _card_config_path(card, ["gmm.weighting=identity"], ""))
        @test err isa CliError && err.code == "config/invalid"
        @test occursin("--set", err.message)
    end

    @testset "a non-.toml path is a card" begin
        card = _task7_card("gmm lp:\n  moments: output, inflation\n  weighting: twostep\n")
        g = _load_config_or_card(card, :gmm)
        @test g["moment_conditions"] == ["output", "inflation"]
        @test g["dep"] == "" && g["theta0"] == Float64[]
    end

    @testset "a card path passes --config through the adapter untouched" begin
        # _card_config_path returns the ORIGINAL path: the adapter must not
        # rewrite a card into a merged temp file.
        card = _task7_card("gmm lp:\n  moments: output\n")
        @test _card_config_path(card, String[], "") == card
        @test _is_card_path(card)
        @test !_is_card_path("x.TOML")
        @test !_is_card_path("")   # empty -> merge_config(""), not a card
    end

    @testset "a foreign stanza names itself" begin
        card = _task7_card("smm:\n  model: ar1\n  theta0: 0.4\n")
        err = _task7_err(() -> _load_config_or_card(card, :gmm))
        @test err isa CliError && err.code == "config/invalid"
        @test occursin("smm", err.message)
    end

    @testset "a card saved as .toml is a TOML error that names the card format" begin
        card = (write(_task7_tmp, "gmm lp:\n  moments: output\n"); _task7_tmp)
        err = _task7_err(() -> _load_config_or_card(card, :gmm))
        @test err isa CliError
        @test occursin("card", lowercase(err.hint))
        @test occursin("toml", lowercase(err.hint))
    end

    @testset "a valid TOML saved as .card is a card error that names TOML" begin
        card = _task7_card("[gmm]\nmoment_conditions = [\"output\"]\n")
        err = _task7_err(() -> _load_config_or_card(card, :gmm))
        @test err isa CliError && err.code == "config/invalid"
        @test occursin("toml", lowercase(err.hint))
        @test occursin("card", lowercase(err.hint))
    end

    @testset "--set against a card is config/invalid, never a silent no-op" begin
        card = _task7_card("gmm lp:\n  moments: output\n")
        err = _task7_err(() -> _card_config_path(card, "gmm.weighting=identity", String[]))
        @test err isa CliError && err.code == "config/invalid"
    end

    @testset "a missing card is data/file-not-found, never exit 1" begin
        err = _task7_err(() -> _load_config_or_card(tempname() * ".card", :gmm))
        @test err isa CliError && err.code == "data/file-not-found"
    end
end

@testset "adapter routes --config by extension (CARD-W3 #208)" begin
    # Exercises the real partition + wrap_legacy path through to_leaf, so the
    # TOML branch under test is the one all ~40 config leaves run.
    function _probe(spec_path)
        seen = Ref{Any}(nothing)
        spec = CommandSpec(path=spec_path, args=[], summary="probe",
            options=[OptionSpec(name="config", type=String, default=""),
                     OptionSpec(name="config-json", type=String, default=""),
                     OptionSpec(name="set", type=String, default="", repeatable=true)],
            handler=wrap_legacy((; config="", format="", output="") -> (seen[] = config; nothing)))
        (seen, to_leaf(spec).handler)
    end

    @testset "a card reaches the handler as its original path" begin
        card = _task7_card("gmm lp:\n  moments: output\n")
        seen, run = _probe(["probe", "card"])
        run(; config=card)
        @test seen[] == card
    end

    @testset "a .toml reaches the handler merged, with --set applied" begin
        toml = (write(_task7_tmp, """
        [gmm]
        moment_conditions = ["output"]
        weighting = "twostep"
        """); _task7_tmp)
        seen, run = _probe(["probe", "toml"])
        run(; config=toml, set=["gmm.weighting=identity"])
        @test seen[] != toml                       # rewritten, as today
        @test get_gmm(load_config(seen[]))["weighting"] == "identity"
    end

    @testset "--set against a card is a typed refusal through the adapter" begin
        card = _task7_card("gmm lp:\n  moments: output\n")
        _seen, run = _probe(["probe", "cardset"])
        err = _task7_err(() -> run(; config=card, set=["gmm.weighting=identity"]))
        @test err isa CliError && err.code == "config/invalid"
        @test occursin("card", err.message)
    end

    @testset "no --config and no --set leaves the handler at its default" begin
        seen, run = _probe(["probe", "none"])
        run()
        @test seen[] == ""                         # default, not a card path
    end
end
