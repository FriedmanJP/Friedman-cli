@testset "parse_card — stanza structure" begin
    # Line numbering: 1 blank, 2 comment, 3 priors, 4-5 body, 6 constraints,
    # 7 body — the brief's linenos. Written as an explicit literal because a
    # triple-quoted block drops its leading newline and shifts every line by one.
    src = "\n# a comment\npriors:\n  rho ~ beta(2, 2)\n  sigma ~ inv_gamma(2, 0.5)\n" *
          "constraints:\n  i[t] >= 0\n"
    st = parse_card(src)
    @test [s.header for s in st] == ["priors", "constraints"]
    @test st[1].lineno == 3
    @test length(st[1].lines) == 2
    @test st[2].lines[1] == (7, "i[t] >= 0")
end

@testset "parse_card — two-word headers" begin
    st = parse_card("gmm lp:\n  moments: output, inflation\n")
    @test st[1].header == "gmm lp"
    @test st[1].lineno == 1
end

@testset "parse_card — @dsge is not a header" begin
    @test isempty(parse_card("@dsge begin\n  parameters: rho = 0.9\nend\n"))
end

@testset "parse_card — CRLF (Review Focus 2)" begin
    st = parse_card("priors:\r\n  rho ~ beta(2, 2)\r\n")
    @test st[1].header == "priors"
    @test st[1].lines == [(2, "rho ~ beta(2, 2)")]
end

@testset "parse_card — tab and 4-space bodies (Review Focus 4)" begin
    for body in ("\t  rho ~ beta(2, 2)", "    rho ~ beta(2, 2)", "  rho ~ beta(2, 2)")
        st = parse_card("priors:\n$body\n")
        @test length(st) == 1
        @test length(st[1].lines) == 1
    end
end

@testset "parse_card — blank lines and comments inside a body" begin
    st = parse_card("priors:\n  # note\n\n  rho ~ beta(2, 2)\n")
    @test length(st[1].lines) == 1
end

@testset "parse_card — config/invalid cases" begin
    for (src, why) in [
        ("nosuch:\n  a: 1\n", "unknown header"),
        ("priors:\n  a: 1\npriors:\n  b: 2\n", "duplicate stanza"),
        ("priors:\nrho ~ beta(2, 2)\n", "unindented body line"),
        ("  priors:\n  rho ~ beta(2, 2)\n", "indented header"),
    ]
        err = try; parse_card(src); nothing; catch e; e; end
        @test err isa CliError
        @test err.code == "config/invalid"
        @test !isempty(err.message)
        @test occursin("line", lowercase(err.message))
        @test occursin(r"^<card> line \d+: ", err.message)
    end
end

@testset "read_card — a card file round-trips" begin
    p = tempname() * ".card"
    write(p, "priors:\r\n  rho ~ beta(2, 2)\r\n")
    st = read_card(p)
    @test length(st) == 1
    @test st[1].header == "priors"
    @test st[1].lines == [(2, "rho ~ beta(2, 2)")]
end

@testset "parse_card — a @dsge block after a stanza is skipped" begin
    st = parse_card("priors:\n  rho ~ beta(2, 2)\n@dsge begin\n  parameters: rho = 0.9\nend\n")
    @test [s.header for s in st] == ["priors"]
    @test length(st[1].lines) == 1
end

@testset "parse_card — every card header the lowerers use is accepted" begin
    # Compared against the constant, not a second copy of it: Tasks 2-3 extend
    # CARD_HEADERS and a spelled-out list here would leave the new ones uncovered.
    @test CARD_HEADERS == Set(["priors", "constraints", "gmm lp", "gmm iv", "smm",
                               "equations", "instruments"])
    for h in CARD_HEADERS
        st = parse_card("$h:\n  a: 1\n")
        @test length(st) == 1 && st[1].header == h
    end
end

@testset "parse_card — a tab between header words normalises" begin
    st = parse_card("gmm\tlp:\n  moments: y\n")
    @test st[1].header == "gmm lp"
    @test st[1].header in CARD_HEADERS
end

@testset "parse_card — a leading UTF-8 BOM is stripped" begin
    st = parse_card("﻿priors:\n  rho ~ beta(2, 2)\n")
    @test st[1].header == "priors"
    @test st[1].lineno == 1
end

@testset "parse_card — an unterminated @dsge block is config/invalid" begin
    err = try
        parse_card("priors:\n  a: 1\n@dsge begin\n  parameters: rho = 0.9\n")
        nothing
    catch e
        e
    end
    @test err isa CliError
    @test err.code == "config/invalid"
    @test occursin("line 3", err.message)   # names the @dsge line, not the last line
end

@testset "parse_card — an indented 'end' does not close a @dsge block" begin
    src = "priors:\n  a: 1\n@dsge begin\n  for i in 1:2\n  end\nend\nconstraints:\n  b: 2\n"
    st = parse_card(src)
    @test [s.header for s in st] == ["priors", "constraints"]
    @test st[1].lines == [(2, "a: 1")]
end

@testset "read_card — a missing card is typed data/file-not-found" begin
    err = try
        read_card(joinpath(tempdir(), "definitely-not-here-93f1.card"))
        nothing
    catch e
        e
    end
    @test err isa CliError
    @test err.code == "data/file-not-found"
    @test exit_class(err.code) == 3
end

@testset "read_card — accepts a SubString path" begin
    p = tempname() * ".card"
    write(p, "smm:\n  lags: 2\n")
    @test length(read_card(SubString(p, 1))) == 1
end
