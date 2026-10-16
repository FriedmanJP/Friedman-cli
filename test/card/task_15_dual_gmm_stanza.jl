# Model card unit — task 15: `gmm lp:` and `gmm iv:` are alternatives (W3 / #208)
#
# Both headers belong to the gmm family, so the family cross-check in
# `lowered_card` passed them through, and `lower_gmm` resolved the card with
# `_card_stanza_any`, which returned the FIRST match. A card carrying both was
# therefore half-read: the second stanza was discarded and the command exited 0
# with the other one's result. Reversing the two stanzas reversed the outcome.
#
# The refusal fires in the card layer, before any estimator is called, so the
# mock is never reached on these inputs and mock-vs-real parity is structural
# here; the exit class is asserted explicitly so a future reordering that let a
# handler run first would still be caught.

_t15_err(f) = try f(); nothing catch e; e end

@testset "a card carries only one of 'gmm lp:' / 'gmm iv:' (W3 #208)" begin
    lp_then_iv = """
    gmm lp:
      moments: output, inflation

    gmm iv:
      dep: output
      endogenous: inflation
      instruments: lag_output
      theta0: 0.0
    """
    err = _t15_err(() -> lower_gmm(parse_card(lp_then_iv), "c.card"))
    @test err isa CliError
    @test err.code == "config/invalid"
    @test exit_class(err) == 4
    # The distinctive phrase: no other refusal in this family calls two headers
    # alternatives, so this cannot be met by an unrelated failure.
    @test occursin("are alternatives", err.message)
    @test occursin("'gmm lp:'", err.message)
    @test occursin("'gmm iv:'", err.message)
    # The line of the SECOND stanza — the one that used to be dropped. The
    # `gmm iv:` header sits at line 4 (line 3 is blank).
    @test occursin("line 4", err.message)

    # Order does not matter: the later stanza is the dropped one either way, so
    # reversing the two moves the reported line, not the outcome.
    iv_then_lp = """
    gmm iv:
      dep: output
      endogenous: inflation
      instruments: lag_output
      theta0: 0.0

    gmm lp:
      moments: output, inflation
    """
    err2 = _t15_err(() -> lower_gmm(parse_card(iv_then_lp), "c.card"))
    @test err2 isa CliError && err2.code == "config/invalid" && exit_class(err2) == 4
    @test occursin("are alternatives", err2.message)
    @test occursin("'gmm iv:'", err2.message) && occursin("'gmm lp:'", err2.message)
    # The `gmm lp:` header now sits at line 7.
    @test occursin("line 7", err2.message)

    # Reached through the real entry point too, so the family cross-check in
    # `lowered_card` cannot let either ordering past this guard.
    err3 = _t15_err(() -> lowered_card(lp_then_iv, :gmm, "c.card"))
    @test err3 isa CliError && err3.code == "config/invalid" && exit_class(err3) == 4
    @test occursin("are alternatives", err3.message)

    # Negative control: each header alone still lowers, so the guard is about
    # the pairing and not about one of the two stanzas being rejected outright.
    only_lp = lower_gmm(parse_card("gmm lp:\n  moments: output, inflation\n"), "c.card")
    @test only_lp["moment_conditions"] == ["output", "inflation"]
    only_iv = lower_gmm(parse_card("gmm iv:\n  dep: output\n  endogenous: inflation\n  theta0: 0.0\n"),
                        "c.card")
    @test only_iv["dep"] == "output" && only_iv["instruments"] == String[]
end
