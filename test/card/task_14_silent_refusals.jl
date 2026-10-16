# Model card unit — task 14: the two silent-refusal fixes (W3 / #208)
#
#   1. an empty `gmm lp:` stanza must be refused, not estimated as a GMM with
#      ZERO moment conditions (it returned exit 0 with an empty table and a
#      J-statistic of 0.0 on 0 degrees of freedom);
#   2. the `.jl`-preamble refusal must name only the stanzas that are accepted
#      there — `priors` and `constraints` — not all seven card headers.
#
# Both refusals fire in the card layer, before any estimator is called, so the
# mock is never reached on either input and mock-vs-real parity is structural
# here; the exit class is asserted explicitly so a future reordering that let a
# handler run first would still be caught.

_t14_err(f) = try f(); nothing catch e; e end
_t14_card(s) = (p = tempname() * ".card"; write(p, s); p)

@testset "an empty gmm lp: stanza is refused (W3 #208)" begin
    # A bare header lowered to zero moments, which the estimator reported as a
    # perfect overidentifying-restriction test at exit 0.
    err = _t14_err(() -> lower_gmm(parse_card("gmm lp:\n"), "c.card"))
    @test err isa CliError
    @test err.code == "config/invalid"
    @test exit_class(err) == 4
    # The distinctive phrase: "gmm lp" alone is in the header of every other
    # refusal in this family, so only this names THIS guard.
    @test occursin("lists no moment conditions", err.message)
    @test occursin("moments:", err.message)

    # Not just a bare header — a stanza that sets ONLY the weighting is the same
    # zero-moment GMM. This is the assertion that separates "refuse an empty
    # stanza" from "refuse zero moment conditions".
    err2 = _t14_err(() -> lower_gmm(parse_card("gmm lp:\n  weighting: identity\n"), "c.card"))
    @test err2 isa CliError && err2.code == "config/invalid"
    @test occursin("lists no moment conditions", err2.message)

    # A comment-only body is content-free the same way (the scanner drops
    # comments, so this is the "author thought they wrote something" case).
    err3 = _t14_err(() -> lower_gmm(parse_card("gmm lp:\n  # moments: output\n"), "c.card"))
    @test err3 isa CliError && err3.code == "config/invalid"
    @test occursin("lists no moment conditions", err3.message)

    # The house rule this mirrors: an empty priors stanza is refused the same
    # way, in the same class — so the docs' "an empty stanza is refused" holds
    # for every family, not just the three that were already true.
    perr = _t14_err(() -> lower_priors(parse_card("priors:\n"), "c.card"))
    @test perr isa CliError && perr.code == "config/invalid"
    @test occursin("priors stanza is empty", perr.message)

    # The neighbours are untouched: a named moment is accepted, and `gmm iv:`
    # still refuses on its own required key rather than on this one.
    ok = lower_gmm(parse_card("gmm lp:\n  moments: output, inflation\n"), "c.card")
    @test ok["moment_conditions"] == ["output", "inflation"]
    iv = _t14_err(() -> lower_gmm(parse_card("gmm iv:\n  moments: output\n"), "c.card"))
    @test iv isa CliError && iv.code == "config/invalid"
    @test occursin("requires a 'dep' column", iv.message)
end

@testset "the .jl preamble refusal names only what is accepted there (W3 #208)" begin
    # A column-0 non-card header, e.g. a typo'd Julia assignment.
    f = tempname() * ".jl"
    write(f, "labels: = [\"a\", \"b\"]\n@dsge begin\nend\n")
    err = _t14_err(() -> _split_card_and_model(f))
    @test err isa CliError && err.code == "config/invalid"
    @test occursin("is not a model-card stanza header", err.message)
    # The list is the whole point: naming the seven headers sent an author
    # straight into the next refusal, one call deeper.
    @test occursin("may declare only priors, constraints", err.message)
    @test !occursin("gmm lp", err.message)
    @test !occursin("smm", err.message)
    @test !occursin("instruments", err.message)

    # The other site of the same rule stays consistent with it.
    f2 = tempname() * ".jl"
    write(f2, "gmm lp:\n  moments: y\n@dsge begin\nend\n")
    err2 = _t14_err(() -> _model_card_stanzas(f2))
    @test err2 isa CliError && err2.code == "config/invalid"
    @test occursin("declares only 'priors' and 'constraints'", err2.message)

    # And the accepted pair is still accepted (the refusal is not a regression
    # of the splitter into rejecting every preamble).
    f3 = tempname() * ".jl"
    write(f3, "priors:\n  rho ~ beta(2, 2)\n\n@dsge begin\nend\n")
    st = _model_card_stanzas(f3)
    @test haskey(st, :priors)
    @test st[:priors]["rho"]["dist"] == "beta"
end