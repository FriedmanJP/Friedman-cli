# Model card unit — task 2: prior and constraint lowerers (W0 / #206).

const _TMP = tempname() * ".toml"
_toml_fixture(s) = (write(_TMP, s); _TMP)

@testset "lower_priors — aliases, defaults, and the TOML oracle" begin
    for (cardline, dist) in ["beta" => "beta", "normal" => "normal",
                             "gaussian" => "normal", "inv_gamma" => "inv_gamma",
                             "inverse_gamma" => "inv_gamma", "invgamma" => "inv_gamma",
                             "gamma" => "gamma", "uniform" => "uniform"]
        got = lower_priors(parse_card("priors:\n  rho ~ $cardline(2, 0.5)\n"), "c")
        @test got["rho"]["dist"] == dist
        @test got["rho"]["a"] == 2.0
        @test got["rho"]["b"] == 0.5
    end

    # ORACLE: identical to the TOML loader
    toml = _toml_fixture("""
    [priors.rho]
    dist = "beta"
    a = 2.0
    b = 0.5
    """)
    @test lower_priors(parse_card("priors:\n  rho ~ beta(2, 0.5)\n"), "c") ==
          get_dsge_priors(load_config(toml))
end

@testset "lower_constraints — oracle, both ends, both directions" begin
    toml = _toml_fixture("""
    [[constraints.bounds]]
    variable = "i"
    lower = 0.0
    """)
    @test lower_constraints(parse_card("constraints:\n  i[t] >= 0\n"), "c") ==
          get_dsge_constraints(load_config(toml))

    both = lower_constraints(parse_card("constraints:\n  -2.5 <= i[t] <= 0.5\n"), "c")
    @test both["bounds"] == [Dict{String,Any}("variable"=>"i", "lower"=>-2.5, "upper"=>0.5)]

    leq = lower_constraints(parse_card("constraints:\n  i[t] <= 0.5\n"), "c")
    @test leq["bounds"] == [Dict{String,Any}("variable"=>"i", "upper"=>0.5)]
    @test lower_constraints(parse_card("constraints:\n  i[t] >= -1e-2\n"), "c")["bounds"] ==
          [Dict{String,Any}("variable"=>"i", "lower"=>-1e-2)]
end

@testset "lower_constraints — a literal bound expression is evaluated by the hand-written parser" begin
    # The evaluator is hand-written recursive descent over numeric literals; it
    # never calls `eval` or `Meta.parse` on stanza text.
    b = lower_constraints(parse_card("constraints:\n  i[t] >= 2 * 0.5\n"), "c")["bounds"]
    @test b == [Dict{String,Any}("variable"=>"i", "lower"=>1.0)]
end

@testset "lowerers — trailing comment on a value line (Review Focus 3)" begin
    b = lower_constraints(parse_card("constraints:\n  i[t] >= 0  # non-negativity\n"), "c")["bounds"]
    @test b == [Dict{String,Any}("variable"=>"i", "lower"=>0.0)]
end

@testset "lowerers — config/invalid with a line number" begin
    # Each case names the lowerer its stanza belongs to AND the reason it is
    # rejected, so a case cannot pass on some other lowerer's error.
    for (src, f, reason) in [
            ("priors:\n  rho ~ cauchy(2, 2)\n",       lower_priors,      "cauchy"),   # unknown dist
            ("priors:\n  rho ~ beta(2)\n",            lower_priors,      "exactly 2"),# wrong arity
            ("priors:\n  rho ~~ beta(2,2)\n",         lower_priors,      "name ~"),   # malformed
            ("constraints:\n  i[t] ~= 0\n",           lower_constraints, "constraints stanza"),
            ("constraints:\n  i >= 0\n",              lower_constraints, "constraints stanza")] # missing [t]
        err = try; f(parse_card(src), "c"); nothing; catch e; e; end
        @test err isa CliError && err.code == "config/invalid"
        @test occursin(reason, err.message)
        @test occursin("line 2", err.message)
    end

    # A card for the wrong family, a duplicate prior, a reversed two-sided
    # bound, and an out-of-range literal are all typed too.
    err = try; lower_constraints(parse_card("priors:\n  rho ~ beta(2, 2)\n"), "c"); nothing; catch e; e; end
    @test err isa CliError && err.code == "config/invalid"
    @test occursin("no 'constraints' stanza", err.message)
    for (src, f, reason) in [
            ("priors:\n  rho ~ beta(2, 2)\n  rho ~ beta(3, 3)\n", lower_priors, "duplicate prior"),
            ("constraints:\n  i[t] >= -2.5 <= 0.5\n",            lower_constraints, "mixed ordering"),
            ("constraints:\n  i[t] >= 1e400\n",                  lower_constraints, "not a numeric literal")]
        err = try; f(parse_card(src), "c"); nothing; catch e; e; end
        @test err isa CliError && err.code == "config/invalid"
        @test occursin(reason, err.message)
    end

    # An out-of-range literal is rejected by the evaluator, not by `parse`
    # throwing: `_card_bounds_expr` answers nothing rather than an exception.
    for s in ["1e400", "1e309", "1e-400", "1e-999", "0.1e-999", join(fill("9", 400))]
        @test _card_bounds_expr(s) === nothing
    end
end
