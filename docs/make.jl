using Documenter
using Friedman

# Agent guide single source (W5/#140): src/commands/agent_guide.md is baked into
# the binary and served by `friedman schema --docs`; the site renders the SAME
# file. Copied here at build time — docs/src/agent-guide.md is generated, never
# hand-edited (it is untracked; edit src/commands/agent_guide.md).
cp(normpath(joinpath(@__DIR__, "..", "src", "commands", "agent_guide.md")),
   joinpath(@__DIR__, "src", "agent-guide.md"); force=true)

makedocs(;
    modules = [Friedman],
    sitename = "Friedman-cli",
    repo = Remotes.GitHub("FriedmanJP", "Friedman-cli"),
    checkdocs = :exports,
    pages = [
        "Home" => "index.md",
        "Getting Started" => [
            "Installation & Quickstart" => "getting-started/installation.md",
            "Pipelines, Handles & Reproducibility" => "getting-started/pipelines.md",
            "Choosing a Method" => "getting-started/method-guide.md",
            "Interactive REPL" => "getting-started/repl.md",
            "Agent Guide" => "agent-guide.md",
        ],
        "Macro & Time Series" => [
            "Data Management & Simulation" => "chapters/data.md",
            "Univariate, Filters & Spectral" => "chapters/univariate.md",
            "Volatility & Multivariate GARCH" => "chapters/volatility.md",
            "Regime-Switching & Nonlinear TS" => "chapters/nonlinear.md",
            "VAR, BVAR, VECM & Factor Models" => "chapters/multivariate.md",
        ],
        "Structural, Nowcast & Forecasting" => [
            "Structural ID, LP & Innovation Accounting" => "chapters/structural.md",
            "Nowcasting & Forecast Evaluation" => "chapters/nowcast.md",
        ],
        "Micro & Panel Econometrics" => [
            "Regression, Systems & GMM/SMM" => "chapters/regression.md",
            "Discrete Choice, Count & Selection" => "chapters/choice.md",
            "Panel Data, Panel VAR & Causal DiD" => "chapters/panel.md",
        ],
        "Equilibrium, Policy & Networks" => [
            "Representative-Agent & Bayesian DSGE" => "chapters/dsge.md",
            "Heterogeneous-Agent, CT & OLG Models" => "chapters/hadsge.md",
            "Policy Counterfactuals & Optimal Policy" => "chapters/policy.md",
            "Input-Output & Production Networks" => "chapters/io.md",
        ],
        "Diagnostics" => [
            "Hypothesis Testing & Diagnostics" => "chapters/tests.md",
        ],
        "Configuration & Model Cards" => [
            "Model Cards & Config Grammar" => "config/overview.md",
            "Priors, SVAR & VECM Identification" => "config/identification.md",
            "DSGE Specs, Priors & OccBin Constraints" => "config/dsge.md",
            "GMM, SMM, Systems, State-Space & Policy" => "config/models-policy.md",
        ],
        "CLI Reference" => [
            "Overview" => "commands/overview.md",
            "completions" => "commands/generated/completions.md",
            "data" => "commands/generated/data.md",
            "did" => "commands/generated/did.md",
            "dsge" => "commands/generated/dsge.md",
            "estimate" => "commands/generated/estimate.md",
            "fevd" => "commands/generated/fevd.md",
            "filter" => "commands/generated/filter.md",
            "forecast" => "commands/generated/forecast.md",
            "hadsge" => "commands/generated/hadsge.md",
            "hd" => "commands/generated/hd.md",
            "io" => "commands/generated/io.md",
            "irf" => "commands/generated/irf.md",
            "model" => "commands/generated/model.md",
            "nowcast" => "commands/generated/nowcast.md",
            "policy" => "commands/generated/policy.md",
            "predict" => "commands/generated/predict.md",
            "residuals" => "commands/generated/residuals.md",
            "serve" => "commands/generated/serve.md",
            "show" => "commands/generated/show.md",
            "spectral" => "commands/generated/spectral.md",
            "test" => "commands/generated/test.md",
        ],
        "Internals" => [
            "Architecture" => "internals/architecture.md",
            "API Reference" => "internals/api.md",
            "Unwrapped Upstream Surface" => "internals/not-wrapped.md",
        ],
    ],
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://friedmanjp.github.io/Friedman-cli",
        edit_link = "master",
        # Generated CLI reference pages hold complete option schemas for lookup;
        # raise Documenter's HTML size threshold so dense reference tables build cleanly.
        size_threshold = 500 * 2^10,
        size_threshold_warn = 300 * 2^10,
    ),
)

deploydocs(;
    repo = "github.com/FriedmanJP/Friedman-cli.git",
    devbranch = "master",
    push_preview = true,
)
