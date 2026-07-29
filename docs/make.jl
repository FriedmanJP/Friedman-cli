using Documenter
using Friedman

makedocs(;
    modules = [Friedman],
    sitename = "Friedman-cli",
    repo = Remotes.GitHub("FriedmanJP", "Friedman-cli"),
    pages = [
        "Home" => "index.md",
        "Installation" => "installation.md",
        "Agent Guide" => "agent-guide.md",
        "CLI Reference" => [
            "Overview" => "commands/overview.md",
            # Generated option/arg tables (docs/generate_cli_reference.jl)
            "Generated: estimate" => "commands/generated/estimate.md",
            "Generated: test" => "commands/generated/test.md",
            "Generated: irf" => "commands/generated/irf.md",
            "Generated: fevd" => "commands/generated/fevd.md",
            "Generated: hd" => "commands/generated/hd.md",
            "Generated: forecast" => "commands/generated/forecast.md",
            "Generated: predict" => "commands/generated/predict.md",
            "Generated: residuals" => "commands/generated/residuals.md",
            "Generated: filter" => "commands/generated/filter.md",
            "Generated: data" => "commands/generated/data.md",
            "Generated: io" => "commands/generated/io.md",
            "Generated: nowcast" => "commands/generated/nowcast.md",
            "Generated: dsge" => "commands/generated/dsge.md",
            "Generated: did" => "commands/generated/did.md",
            "Generated: multipliers" => "commands/generated/multipliers.md",
            "Generated: spectral" => "commands/generated/spectral.md",
            # Workflow guides (hand-written)
            "estimate (guide)" => "commands/estimate.md",
            "test (guide)" => "commands/test.md",
            "irf (guide)" => "commands/irf.md",
            "fevd (guide)" => "commands/fevd.md",
            "hd (guide)" => "commands/hd.md",
            "forecast (guide)" => "commands/forecast.md",
            "predict & residuals (guide)" => "commands/predict_residuals.md",
            "filter (guide)" => "commands/filter.md",
            "data (guide)" => "commands/data.md",
            "io (guide)" => "commands/io.md",
            "nowcast (guide)" => "commands/nowcast.md",
            "dsge (guide)" => "commands/dsge.md",
            "HA-DSGE workflow" => "commands/ha-dsge.md",
            "did (guide)" => "commands/did.md",
            "multipliers (guide)" => "commands/multipliers.md",
            "favar & sdfm (guide)" => "commands/favar.md",
            "structural breaks (guide)" => "commands/structural-breaks.md",
            "panel unit root (guide)" => "commands/panel-unit-root.md",
            "spectral (guide)" => "commands/spectral.md",
            "panel regression (guide)" => "commands/panel-regression.md",
            "ordered & multinomial (guide)" => "commands/ordered-multinomial.md",
        ],
        "Interactive REPL" => "repl.md",
        "Configuration" => "configuration.md",
        "API Reference" => "api.md",
        "Architecture" => "architecture.md",
        "Documentation rules" => "docrule.md",
    ],
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://friedmanjp.github.io/Friedman-cli",
        edit_link = "master",
        # The generated CLI reference is one page per top-level command, and the
        # biggest (estimate: 66 leaves, test: 65) render well past Documenter's
        # 200 KiB default. These are lookup tables an agent greps, not prose —
        # raise the ceiling instead of fragmenting the reference across pages.
        size_threshold = 500 * 2^10,
        size_threshold_warn = 300 * 2^10,
    ),
    # docs_block: internal API surface is large; missing @docs bindings must not fail CI
    warnonly = [:missing_docs, :docs_block],
)

deploydocs(;
    repo = "github.com/FriedmanJP/Friedman-cli.git",
    devbranch = "master",
    push_preview = true,
)
