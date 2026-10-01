# Model card unit — task 8: SMM and SUR/3SLS card routing (W4 / #207).
#
# These are COMPOSITION pins, not new behaviour: the `smm` and `system`
# lowerers shipped in wave C (`src/model_card.jl`) and the `--config` routing
# shipped in wave D (`_load_config_or_card`) already exist.  What is new is
# that the two compose for the two families wave D left on the TOML branch, and
# that a card reaches the SMM handler's own `p` requirement.
#
# Self-contained fixtures so this file stands alone; `_load_config_or_card`
# comes from src/model_card.jl, which the aggregator includes before us.

# The `arp` case has to be observed at the SMM handler's own check
# (`_smm_simulator`, src/commands/estimate.jl), because wave C/D only have to
# deliver the ABSENT key — nothing in the card layer refuses `arp`.  The
# aggregator includes this file before test_commands.jl has loaded the command
# files, so pull in the same chain, in the same order, when it is missing.
# Each file is guarded on a symbol IT defines, so this file also runs when the
# aggregator has already loaded part of the chain.
_t8root = dirname(dirname(@__DIR__))
for (f, sym) in (("cli/types.jl", :LeafCommand),
                 ("cli/parser.jl", :tokenize),
                 ("cli/help.jl", :print_help),
                 ("cli/dispatch.jl", :dispatch),
                 ("commands/shared.jl", :_load_and_estimate_var),
                 ("model_handle.jl", :save_model_dispatch),
                 ("handles.jl", :resolve_save_path),
                 ("registry/spec.jl", :CommandSpec),
                 ("registry/adapter.jl", :wrap_legacy),
                 ("registry/families.jl", :_PATH_REPLACEMENTS),
                 ("commands/estimate.jl", :_smm_simulator))
    isdefined(@__MODULE__, sym) || include(joinpath(_t8root, "src", f))
end

_task8_card(s) = (p = tempname() * ".card"; write(p, s); p)
_task8_toml(s) = (p = tempname() * ".toml"; write(p, s); p)
_task8_err(f) = try f(); nothing catch e; e end

@testset "_load_config_or_card (CARD-W4 #207)" begin
    @testset "smm card lowers to the get_smm dict" begin
        card = _task8_card("smm:\n  model: ar1\n  theta0: 0.4, 0.5\n  lags: 2\n" *
                           "  lower: -0.99, 1.0e-4\n  upper: 0.99, 10.0\n")
        # `get_smm` is what the handler calls on the router's result, and it
        # reads the `[smm]` SECTION — so the assertion goes through it, not
        # around it: that is what catches a router that hands back a flat dict.
        s = get_smm(_load_config_or_card(card, :smm))
        @test s["model"] == "ar1"
        @test s["theta0"] == [0.4, 0.5]
        # 1.0e-4 must come back as 1.0e-4, not 1.0e-5 or a string: a card
        # value routed through the wrong parser (e.g. the TOML branch's)
        # either fails here or lands on the other side of the `lower` bound.
        @test s["lower"] == [-0.99, 1.0e-4] && s["upper"] == [0.99, 10.0]
        @test s["lags"] == 2
    end

    @testset "a card arrives under its TOML section (regression, found here)" begin
        # `get_gmm` / `get_smm` read their keys out of the `[gmm]` / `[smm]`
        # SECTION.  The router used to return the lowered card flat, so every
        # gmm and smm card reached its handler as an EMPTY spec: `estimate smm`
        # exited config/missing-key and `estimate gmm` fitted zero moment
        # conditions and still exited 0.  Both spellings are pinned here, so
        # dropping the wrapping section reds this testset.
        gcard = _task8_card("gmm iv:\n  dep: y\n  endogenous: x\n  instruments: z1, z2\n  theta0: 0.0, 0.0\n")
        gcfg = _load_config_or_card(gcard, :gmm)
        @test haskey(gcfg, "gmm")
        @test gcfg["gmm"]["moment_conditions"] == String[]
        gtoml = _task8_toml("[gmm]\ndep = \"y\"\nendogenous = [\"x\"]\ninstruments = [\"z1\", \"z2\"]\ntheta0 = [0.0, 0.0]\n")
        @test get_gmm(gcfg) == get_gmm(load_config(gtoml))
        # And the moment conditions the card DID write are the ones that land.
        lcard = _task8_card("gmm lp:\n  moments: y1, y2\n")
        @test get_gmm(_load_config_or_card(lcard, :gmm))["moment_conditions"] == ["y1", "y2"]
        scard = _task8_card("smm:\n  model: ar1\n  theta0: 0.4, 0.5\n")
        scfg = _load_config_or_card(scard, :smm)
        @test haskey(scfg, "smm")
        @test get_smm(scfg)["model"] == "ar1" && get_smm(scfg)["theta0"] == [0.4, 0.5]
    end

    @testset "an smm card agrees with the TOML it replaces (wave C x wave D)" begin
        toml = _task8_toml("""
        [smm]
        model = "ar1"
        theta0 = [0.4, 0.5]
        lags = 2
        lower = [-0.99, 1.0e-4]
        upper = [0.99, 10.0]
        """)
        card = _task8_card("smm:\n  model: ar1\n  theta0: 0.4, 0.5\n  lags: 2\n" *
                           "  lower: -0.99, 1.0e-4\n  upper: 0.99, 10.0\n")
        @test get_smm(_load_config_or_card(card, :smm)) == get_smm(load_config(toml))
    end

    @testset "an smm card takes get_smm's defaults for the keys it omits" begin
        # `weighting`/`sim_ratio`/`burn` are defaults in BOTH lowerers, so
        # asserting only those would pass against an empty dict.  The
        # observable part is that the omitted `model`/`theta0` stay `nothing`
        # (the handler's own config/missing-key fires on them) and that the
        # whole dict matches the TOML it stands in for — lags included, so a
        # card value that silently replaced the default would show up.
        card = _task8_card("smm:\n  lags: 3\n")
        # `get_smm` is what the handler calls on the router's result, and it
        # reads the `[smm]` SECTION — so the assertion goes through it, not
        # around it: that is what catches a router that hands back a flat dict.
        s = get_smm(_load_config_or_card(card, :smm))
        @test s["model"] === nothing && s["theta0"] === nothing
        @test s["weighting"] == "two_step" && s["sim_ratio"] == 5 && s["burn"] == 100
        @test s == get_smm(load_config(_task8_toml("[smm]\nlags = 3\n")))
    end

    @testset "sur card lowers to the get_system dict" begin
        card = _task8_card("equations:\n  consumption: cons = income, wealth\n" *
                           "  investment: inv = income, interest\n" *
                           "instruments:\n  common: gov, taxes, lag_income\n")
        s = _load_config_or_card(card, :system)
        @test [e["name"] for e in s["equations"]] == ["consumption", "investment"]
        @test s["common_instruments"] == ["gov", "taxes", "lag_income"]
        # Names alone would survive dropping the body, so pin the body too.
        @test s["equations"][1]["dep"] == "cons"
        @test s["equations"][1]["indep"] == ["income", "wealth"]
        @test s["equations"][2]["indep"] == ["income", "interest"]
        @test all(e -> e["instr"] === nothing, s["equations"])
    end

    @testset "per-equation instruments" begin
        card = _task8_card("equations:\n  cons = income, wealth | gov, lag_income\n" *
                           "  inv = income, interest | gov, lag_income\n")
        s = _load_config_or_card(card, :system)
        @test all(e -> e["instr"] == ["gov", "lag_income"], s["equations"])
        # `|` splits the regressors off: if the bar were ignored, `instr` would
        # be nothing and `indep` would carry the instrument columns.
        @test s["equations"][1]["indep"] == ["income", "wealth"]
        # No `instruments:` stanza -> common is absent, NOT `[]`.
        @test s["common_instruments"] === nothing
        # Unnamed equations are named by position, so the two rows stay
        # distinguishable once the shared instrument list is factored out.
        @test [e["name"] for e in s["equations"]] == ["eq1", "eq2"]
    end

    @testset "get_system accepts the card spelling (regression, found here)" begin
        # A card lowers to `"instr" => nothing` on an equation with no `|`, and
        # to `"common_instruments"` for the shared set.  get_system read only
        # the TOML spellings, so EVERY sur card raised config/type before the
        # first column was resolved, and a 3SLS card would have silently lost
        # its shared instruments.  Both are pinned here.
        card = _task8_card("equations:\n  consumption: cons = income, wealth\n" *
                           "  investment: inv = income, interest\n" *
                           "instruments:\n  common: gov, taxes, lag_income\n")
        spec = get_system(_load_config_or_card(card, :system))
        @test spec["common_instruments"] == ["gov", "taxes", "lag_income"]
        @test all(e -> e["instr"] === nothing, spec["equations"])

        # Per-equation instruments still reach the spec.
        per = get_system(_load_config_or_card(
            _task8_card("equations:\n  cons = income, wealth | gov\n"), :system))
        @test per["equations"][1]["instr"] == ["gov"]
        @test per["common_instruments"] === nothing

        # TOML validation is NOT weakened by the tolerance: an empty column
        # list is still config/shape on the TOML path, so "instr => nothing"
        # is read as ABSENT, never as "accept whatever".
        for bad in ["[[equations]]\ndep = \"y\"\nindep = [\"x\"]\ninstr = [\"\"]\n",
                    "[[equations]]\ndep = \"y\"\nindep = [\"x\"]\n[instruments]\ncommon = []\n"]
            e = _task8_err(() -> get_system(load_config(_task8_toml(bad))))
            @test e isa CliError && e.code == "config/shape"
        end

        # Both spellings of the shared set in one config is a contradiction,
        # refused rather than resolved by a precedence the user cannot see.
        # (The documented `[instruments] common` is the one that used to win,
        # silently; the card key must not outrank it either.)
        dup = _task8_err(() -> get_system(load_config(_task8_toml("""
        common_instruments = ["top"]
        [[equations]]
        dep = "y"
        indep = ["x"]
        [instruments]
        common = ["nested"]
        """))))
        @test dup isa CliError && dup.code == "config/invalid"
        @test occursin("twice", dup.message)
    end

    @testset "a sur card agrees with the TOML it replaces (wave C x wave D)" begin
        toml = _task8_toml("""
        [[equations]]
        name = "consumption"
        dep = "cons"
        indep = ["income", "wealth"]
        [[equations]]
        name = "investment"
        dep = "inv"
        indep = ["income", "interest"]
        [instruments]
        common = ["gov", "taxes", "lag_income"]
        """)
        card = _task8_card("equations:\n  consumption: cons = income, wealth\n" *
                           "  investment: inv = income, interest\n" *
                           "instruments:\n  common: gov, taxes, lag_income\n")
        @test get_system(_load_config_or_card(card, :system)) ==
              get_system(load_config(toml))
    end

    @testset "arp without p is refused with config/missing-key" begin
        # Not `startswith(err.code, "config/")`: every card error is
        # config-prefixed, so that assertion cannot tell this one from a
        # duplicated-key or an unknown-key refusal.  The specific code is the
        # handler's own, at src/commands/estimate.jl:3499.
        card = _task8_card("smm:\n  model: arp\n  theta0: 0.3, 0.2, 0.1, 1.0\n")
        cfg = get_smm(_load_config_or_card(card, :smm))
        # Lowering must NOT invent a value for the absent key.
        @test cfg["p"] === nothing
        err = _task8_err(() -> _smm_simulator("arp", 1, cfg["theta0"], cfg))
        @test err isa CliError
        @test err.code == "config/missing-key"
        @test occursin("arp", err.message) && occursin("`p`", err.message)
        # Discriminating mutation: with p supplied the same call must get
        # past the arp branch entirely, so a `_smm_simulator` that ignored its
        # `p` and raised config/missing-key unconditionally would red here.
        ok = _task8_err(() -> _smm_simulator("arp", 1, [0.3, 1.0], merge(cfg, Dict("p" => 1))))
        @test !(ok isa CliError && ok.code == "config/missing-key")
    end

    @testset "an equation with an empty right-hand side is config/shape" begin
        card = _task8_card("equations:\n  cons =\n")
        err = _task8_err(() -> _load_config_or_card(card, :system))
        @test err isa CliError && err.code == "config/shape"
        @test occursin("regressor", err.message)
        # `occursin` on `err.message` is safe here: `parse_card` is its own
        # scanner and raises `CliError` only, so the `ParseError` of the CLI
        # tokenizer cannot arrive wrapped on this path (no `error.code` to
        # confuse it with either — the code is asserted above).
        # Same for a bar with nothing after it — a distinct refusal point in
        # lower_system, so assert the code for that one too.
        bar = _task8_err(() -> _load_config_or_card(
            _task8_card("equations:\n  cons = income |\n"), :system))
        @test bar isa CliError && bar.code == "config/shape"
    end
end