# Model card unit — task 3: GMM, SMM and system lowerers, plus family
# dispatch (W0 / #206).  `_TMP` / `_toml_fixture` come from task 2.

@testset "lower_gmm lp — oracle" begin
    toml = _toml_fixture("""
    [gmm]
    moment_conditions = ["output", "inflation"]
    weighting = "twostep"
    """)
    got = lower_gmm(parse_card("gmm lp:\n  moments: output, inflation\n  weighting: twostep\n"), "c")
    @test got == get_gmm(load_config(toml))
    @test got["dep"] == "" && got["theta0"] == Float64[]
end

@testset "lower_gmm iv — oracle" begin
    toml = _toml_fixture("""
    [gmm]
    dep = "output"
    endogenous = ["inflation"]
    instruments = ["lag_output", "lag_inflation"]
    theta0 = [0.0, 0.5]
    weighting = "twostep"
    """)
    got = lower_gmm(parse_card("""
    gmm iv:
      dep: output
      endogenous: inflation
      instruments: lag_output, lag_inflation
      theta0: 0.0, 0.5
      weighting: twostep
    """), "c")
    @test got == get_gmm(load_config(toml))
    @test got["theta0"] == [0.0, 0.5]
end

@testset "lower_gmm — refusals" begin
    for (src, why) in [
        ("gmm lp:\n  moments: output\n  instruments: z\n", "no meaning"),
        ("gmm lp:\n  moments: output\n  dep: y\n",          "no meaning"),
        ("gmm lp:\n  moments: output\n  theta0: 0.5\n",     "no meaning"),
        ("gmm lp:\n  moments: output\n  endogenous: y\n",   "no meaning"),
        ("gmm lp:\n  moments: output\n  exogenous: e\n",    "no meaning"),
        ("gmm:\n  moments: output\n",                        "unknown stanza header"),
        ("gmm iv:\n  dep: y\n  endogenous: x\n",            "requires a 'theta0'"),
        ("gmm lp:\n  moment_conditions: output\n",           "unknown 'gmm lp' key"),
    ]
        err = try; lower_gmm(parse_card(src), "c"); nothing; catch e; e; end
        @test err isa CliError && err.code == "config/invalid"
        @test occursin(why, err.message)
    end
end

@testset "lower_gmm — the IV requirements point at the gmm stanza, not line 1" begin
    src = "priors:\n  rho ~ beta(2, 2)\n\ngmm iv:\n  dep: y\n  endogenous: x\n"
    err = try; lower_gmm(parse_card(src), "c"); nothing; catch e; e; end
    @test err isa CliError && err.code == "config/invalid"
    @test occursin("line 4", err.message)     # the `gmm iv:` header, not `priors`
end

@testset "lower_gmm/lower_smm — a repeated key is config/invalid" begin
    err = try
        lower_gmm(parse_card("gmm lp:\n  moments: a\n  moments: b\n"), "c"); nothing
    catch e; e; end
    @test err isa CliError && err.code == "config/invalid"
    @test occursin("duplicate", err.message)

    err = try
        lower_smm(parse_card("smm:\n  model: ar1\n  model: ar2\n"), "c"); nothing
    catch e; e; end
    @test err isa CliError && err.code == "config/invalid"
    @test occursin("duplicate", err.message)
end

@testset "lower_smm — omitted keys take the loader's defaults" begin
    @test lower_smm(parse_card("smm:\n  model: ar1\n"), "c") ==
          get_smm(load_config(_toml_fixture("[smm]\nmodel = \"ar1\"\n")))
end

@testset "lower_smm — oracle" begin
    toml = _toml_fixture("""
    [smm]
    model = "ar1"
    theta0 = [0.4, 0.5]
    lags = 2
    lower = [-0.99, 1.0e-4]
    upper = [0.99, 10.0]
    """)
    got = lower_smm(parse_card("""
    smm:
      model: ar1
      theta0: 0.4, 0.5
      lags: 2
      lower: -0.99, 1.0e-4
      upper: 0.99, 10.0
    """), "c")
    @test got == get_smm(load_config(toml))
    @test got["weighting"] == "two_step" && got["sim_ratio"] == 5 && got["burn"] == 100
end

@testset "lower_system — named, unnamed, and per-equation instruments" begin
    got = lower_system(parse_card("""
    equations:
      consumption: cons = income, wealth | gov, lag_income
      inv = income, interest
    """), "c")
    @test got["equations"][1] == Dict{String,Any}(
        "name"=>"consumption", "dep"=>"cons",
        "indep"=>["income","wealth"], "instr"=>["gov","lag_income"])
    @test got["equations"][2]["name"] == "eq2"
    @test got["equations"][2]["indep"] == ["income", "interest"]
    @test got["common_instruments"] === nothing
end

@testset "lower_system — shared common instruments only" begin
    got = lower_system(parse_card("""
    equations:
      consumption: cons = income, wealth
      inv = income, interest
    instruments:
      common: taxes
    """), "c")
    @test got["common_instruments"] == ["taxes"]
    @test got["equations"][1]["instr"] === nothing
end

@testset "lower_system — an empty or blank column list is config/shape" begin
    for src in ["equations:\n  cons =\n",
                "equations:\n  = y, x\n",
                "equations:\n  cons = y, , x\n",
                "equations:\n  cons = y | , z\n",
                "equations:\n  cons = y\ninstruments:\n  common:\n",
                "equations:\n  cons = y\ninstruments:\n  common: z, , w\n"]
        err = try; lower_system(parse_card(src), "c"); nothing; catch e; e; end
        @test err isa CliError && err.code == "config/shape"
    end
    # a blank equation name is a different mistake and keeps its own class
    err = try
        lower_system(parse_card("equations:\n  : cons = y\n"), "c"); nothing
    catch e; e; end
    @test err isa CliError && err.code == "config/invalid"
end

@testset "lower_system — the TOML loader refuses the same column lists" begin
    for toml in ["[[equations]]\ndep = \"y\"\nindep = [\"y\"]\ninstr = [\"\"]\n",
                 "[[equations]]\ndep = \"y\"\nindep = []\n",
                 "[[equations]]\ndep = \"y\"\nindep = [\"y\", \"\", \"x\"]\n",
                 "[[equations]]\ndep = \"y\"\nindep = [\"y\"]\n[instruments]\ncommon = []\n"]
        err = try
            get_system(load_config(_toml_fixture(toml))); nothing
        catch e; e; end
        @test err isa CliError && err.code == "config/shape"
    end
end

@testset "every card header has a family" begin
    @test Set(collect(keys(_CARD_FAMILIES))) == Set(collect(CARD_HEADERS))
end

@testset "lower_system — | with common instruments is config/invalid" begin
    err = try
        lower_system(parse_card("equations:\n  cons = y, x | z\ninstruments:\n  common: w\n"), "c")
        nothing
    catch e; e; end
    @test err isa CliError && err.code == "config/invalid"
end

@testset "lower_system — TOML oracle" begin
    toml = _toml_fixture("""
    [[equations]]
    name = "consumption"
    dep = "cons"
    indep = ["income", "wealth"]
    instr = ["gov", "lag_income"]
    """)
    @test lower_system(parse_card("""
    equations:
      consumption: cons = income, wealth | gov, lag_income
    """), "c") == get_system(load_config(toml))
end

@testset "card_family and lowered_card" begin
    @test card_family("priors") === :priors
    @test card_family("constraints") === :constraints
    @test card_family("gmm lp") === :gmm
    @test card_family("gmm iv") === :gmm
    @test card_family("smm") === :smm
    @test card_family("equations") === :system
    @test card_family("instruments") === :system
    @test card_family("nope") === nothing

    # a foreign stanza names itself in the error
    err = try
        lowered_card("smm:\n  model: ar1\n  theta0: 0.4\n", :gmm, "c"); nothing
    catch e; e; end
    @test err isa CliError && err.code == "config/invalid"
    @test occursin("smm", err.message)

    # each family dispatches to its own lowerer
    @test lowered_card("gmm lp:\n  moments: output\n", :gmm, "c") ==
          lower_gmm(parse_card("gmm lp:\n  moments: output\n"), "c")
    @test lowered_card("smm:\n  model: ar1\n", :smm, "c") ==
          lower_smm(parse_card("smm:\n  model: ar1\n"), "c")
    @test lowered_card("equations:\n  cons = y, x\n", :system, "c") ==
          lower_system(parse_card("equations:\n  cons = y, x\n"), "c")
    @test lowered_card("priors:\n  rho ~ beta(2, 0.5)\n", :priors, "c") ==
          lower_priors(parse_card("priors:\n  rho ~ beta(2, 0.5)\n"), "c")
    @test lowered_card("constraints:\n  i[t] >= 0\n", :constraints, "c") ==
          lower_constraints(parse_card("constraints:\n  i[t] >= 0\n"), "c")
end
