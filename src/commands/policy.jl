# ── policy: McKay–Wolf policy counterfactuals (W4/#126, MEMs 0.8.0 CF module) ──
#
# New top-level family (18 → 19). W4 lands the foundations: the causal-effects
# menu (`policy effects var|bvar|lp|sign`) and the rule-counterfactual engine
# (`policy counterfactual var|bvar|lp`). W5–W7 build on these.
#
# Design constraints inherited from the module (verified on the 0.8.0 tag):
# - None of the CF types is Tables.jl-registered or serializable → hand-built
#   tidy tables (the `io`-family precedent) and NO --save-model/--model handles.
#   Containers are re-derived per invocation; the global `Random.seed!` is the
#   reproducibility story (CF functions take `rng=`, never `seed=`).
# - The honesty numbers (rel_residual, spanned, error_path, n_draws_used/failed)
#   go in STDOUT DATA TABLES, not stderr — `report()` output is swallowed by
#   `_status_report`, and a thin menu that cannot enforce an H-period rule
#   exactly must be visible to a user reading only the envelope.
# - `outcomes`/`instruments` are `Pair{Symbol, Int|String}` maps (module symbol
#   → IRF variable). W7's `policy_news_matrix` uses `Pair{Symbol,Symbol}` — a
#   DIFFERENT shape; do not share this parser with it.
# - Square vs thin is the module's central axis (`is_square`): square = model
#   news menu (exact solve), thin = empirically identified shocks (least
#   squares). Surfaced in every effects/counterfactual summary.
# - plot_result exists for PolicyCounterfactual (recipe appends an
#   implementation-error panel past spanned_tol); PolicyCausalEffects has NO
#   recipe → `policy effects` carries no plot flags.

# ── Shared parsing ──────────────────────────────────────────

"""Parse `--outcomes infl=2,ygap=out` into the module's `Pair{Symbol,Int|String}`
maps (name → IRF variable index or column name)."""
function _parse_cf_pairs(spec::String, opt::String; required::Bool=true)
    out = Pair{Symbol,Union{Int,String}}[]
    for tok in split(spec, ",")
        tok = strip(tok)
        isempty(tok) && continue
        parts = split(tok, "=")
        (length(parts) == 2 && !isempty(strip(parts[1])) && !isempty(strip(parts[2]))) ||
            throw(CliError("usage/invalid",
                "policy: $opt entries must be name=column (got '$tok')";
                hint="e.g. $opt infl=2,ygap=1 (index) or $opt infl=cpi (column name)"))
        v = tryparse(Int, strip(parts[2]))
        push!(out, Symbol(strip(parts[1])) => (v === nothing ? String(strip(parts[2])) : v))
    end
    (required && isempty(out)) && throw(CliError("usage/missing",
        "policy: $opt is required";
        hint="map module names to IRF variables, e.g. $opt infl=2,ygap=1"))
    length(unique(first.(out))) == length(out) || throw(CliError("usage/invalid",
        "policy: $opt names must be distinct"))
    return out
end

"""Parse `--shocks 1,mp` into a vector of Int indices / String shock names."""
function _parse_cf_shocks(spec::String, opt::String="--shocks")
    isempty(strip(spec)) && throw(CliError("usage/missing",
        "policy: $opt is required (the identified POLICY shock columns of the IRF)";
        hint="indices or names, e.g. $opt 3 or $opt mp1,mp2"))
    out = Union{Int,String}[]
    for tok in split(spec, ",")
        tok = strip(tok)
        isempty(tok) && continue
        v = tryparse(Int, tok)
        push!(out, v === nothing ? String(tok) : v)
    end
    isempty(out) && throw(CliError("usage/missing", "policy: $opt is required"))
    return out
end

function _parse_cf_quantiles(spec::String)
    qs = Float64[]
    for tok in split(spec, ",")
        tok = strip(tok)
        isempty(tok) && continue
        v = tryparse(Float64, tok)
        (v === nothing || !(0.0 < v < 1.0)) && throw(CliError("usage/invalid",
            "policy: --quantiles must be numbers in (0, 1) (got '$tok')"))
        push!(qs, v)
    end
    isempty(qs) && throw(CliError("usage/invalid", "policy: --quantiles must not be empty"))
    issorted(qs) || throw(CliError("usage/invalid",
        "policy: --quantiles must be increasing (got $spec)"))
    return qs
end

# ── Rule construction ───────────────────────────────────────

"""Build the `PolicyRule` from `--rule <builtin>` or a `[rule]` TOML section.

Builtins use the CLI's `--outcomes`/`--instruments` symbols with upstream's
variable-name defaults (`:infl`/`:ygap`), so `--rule taylor` requires outcomes
actually NAMED infl/ygap — a friendly usage error points at the config route
otherwise. The TOML route controls everything, including the CMW-vs-textbook
Taylor coefficients (see `get_policy_rule`)."""
function _build_policy_rule(rule::String, config::String, H::Int,
                            cli_outcomes::Vector{Symbol},
                            cli_instruments::Vector{Symbol})
    if !isempty(config)
        isempty(rule) || throw(CliError("usage/invalid",
            "policy: give either --rule <builtin> or --config <toml>, not both"))
        spec = get_policy_rule(load_config(config))
        for s in spec.outcomes
            s in cli_outcomes || throw(CliError("config/invalid",
                "[rule] outcome '$s' is not among the --outcomes names ($(join(cli_outcomes, ", ")))";
                hint="the rule can only reference variables the causal-effects menu maps"))
        end
        for s in spec.instruments
            s in cli_instruments || throw(CliError("config/invalid",
                "[rule] instrument '$s' is not among the --instruments names ($(join(cli_instruments, ", ")))"))
        end
        p = spec.params
        return spec.type === :rate_peg ?
                   rate_peg_rule(H; outcomes=spec.outcomes, instruments=spec.instruments) :
               spec.type === :rate_target ?
                   (length(p.path) == H || throw(CliError("config/shape",
                        "[rule] path has $(length(p.path)) entries but --horizon is $H"));
                    rate_target_rule(H, p.path; outcomes=spec.outcomes,
                                     instruments=spec.instruments)) :
               spec.type === :inflation_target ?
                   inflation_target_rule(H; pi_var=p.pi_var, outcomes=spec.outcomes,
                                         instruments=spec.instruments) :
               spec.type === :output_gap ?
                   output_gap_rule(H; y_var=p.y_var, outcomes=spec.outcomes,
                                   instruments=spec.instruments) :
               spec.type === :ngdp ?
                   ngdp_rule(H; pi_var=p.pi_var, y_var=p.y_var, outcomes=spec.outcomes,
                             instruments=spec.instruments) :
               taylor_rule(H; rho=p.rho, phi_pi=p.phi_pi, phi_y=p.phi_y, z_lag=p.z_lag,
                           pi_var=p.pi_var, y_var=p.y_var, outcomes=spec.outcomes,
                           instruments=spec.instruments)
    end
    isempty(rule) && throw(CliError("usage/missing",
        "policy counterfactual: --rule <builtin> or --config <toml> is required";
        hint="builtins: rate-peg|inflation-target|output-gap|ngdp|taylor"))
    rule in ("rate-peg", "inflation-target", "output-gap", "ngdp", "taylor") ||
        throw(CliError("usage/invalid-option",
            "invalid --rule '$rule'; must be rate-peg, inflation-target, output-gap, ngdp or taylor";
            hint="rate-target (a fixed instrument path) needs --config (the path lives in the TOML)"))
    needs = rule == "inflation-target" ? [:infl] :
            rule == "output-gap" ? [:ygap] :
            rule in ("ngdp", "taylor") ? [:infl, :ygap] : Symbol[]
    for s in needs
        s in cli_outcomes || throw(CliError("usage/invalid",
            "--rule $rule expects an outcome named '$s' (builtins use upstream's variable-name defaults)";
            hint="name it in --outcomes (e.g. $s=2), or use --config to pick pi_var/y_var freely"))
    end
    length(cli_instruments) == 1 || rule in ("inflation-target", "output-gap", "ngdp") ||
        throw(CliError("usage/invalid",
            "--rule $rule needs exactly ONE instrument (got $(length(cli_instruments)))"))
    return rule == "rate-peg" ?
               rate_peg_rule(H; outcomes=cli_outcomes, instruments=cli_instruments) :
           rule == "inflation-target" ?
               inflation_target_rule(H; outcomes=cli_outcomes, instruments=cli_instruments) :
           rule == "output-gap" ?
               output_gap_rule(H; outcomes=cli_outcomes, instruments=cli_instruments) :
           rule == "ngdp" ?
               ngdp_rule(H; outcomes=cli_outcomes, instruments=cli_instruments) :
           taylor_rule(H; outcomes=cli_outcomes, instruments=cli_instruments)  # textbook defaults
end

# ── Loss construction (W5/#127) ─────────────────────────────

"""Build `(PolicyLoss, z_wedge)` from a `[loss]` TOML. The `smoothing_penalty`
split is owned HERE: its `.W_z` feeds `policy_loss(W_z=…)`, its `.wedge_term`
the engines' `z_wedge=` — handlers cannot get the split wrong."""
function _build_policy_loss(loss_config::String, H::Int,
                            cli_outcomes::Vector{Symbol},
                            cli_instruments::Vector{Symbol})
    isempty(loss_config) && throw(CliError("usage/missing",
        "policy: --loss-config <toml> is required (the quadratic loss; lambda has NO default upstream)";
        hint="e.g. [loss] outcomes = [\"infl\",\"ygap\"], lambda = [1.0, 0.5]"))
    spec = get_policy_loss(load_config(loss_config))
    sm = spec.smoothing
    W_z = nothing
    z_wedge = nothing
    loss_instruments = Symbol[]
    if sm !== nothing
        length(cli_instruments) == 1 || throw(CliError("usage/invalid",
            "policy: [loss.smoothing] penalizes ONE instrument; map exactly one in --instruments (got $(length(cli_instruments)))"))
        sp = smoothing_penalty(H; lambda=sm.lambda, beta=sm.beta, z_lag=sm.z_lag)
        W_z = [sp.W_z]
        z_wedge = [sp.wedge_term]
        loss_instruments = cli_instruments
    end
    if spec.type === :ait
        for s in (spec.pi_var, spec.y_var)
            s in cli_outcomes || throw(CliError("config/invalid",
                "[loss] ait variable '$s' is not among the --outcomes names ($(join(cli_outcomes, ", ")))"))
        end
        base = ait_loss(H; beta=spec.beta, lambda_avg=spec.lambda_avg,
                        lambda_t=spec.lambda_t, lambda_y=spec.lambda_y,
                        delta=spec.delta, K=spec.K,
                        pi_var=spec.pi_var, y_var=spec.y_var)
        # ait_loss carries no instrument penalty — rebuild with the smoothing block.
        loss = sm === nothing ? base :
               PolicyLoss(outcomes=base.outcomes, W_x=base.W_x,
                          instruments=loss_instruments, W_z=W_z,
                          lambda=base.lambda, beta=base.beta, name=base.name)
        return loss, z_wedge
    end
    for s in spec.outcomes
        s in cli_outcomes || throw(CliError("config/invalid",
            "[loss] outcome '$s' is not among the --outcomes names ($(join(cli_outcomes, ", ")))"))
    end
    loss = policy_loss(spec.outcomes, H; lambda=spec.lambda, beta=spec.beta,
                       instruments=loss_instruments, W_z=W_z)
    return loss, z_wedge
end

# ── Menu construction per source route ──────────────────────

"""Build `(ce, ir_or_bir)` for one source route. The IRF object is returned too
because `policy counterfactual` extracts the baseline from the SAME estimate."""
function _policy_menu(route::String; data::String, lags, horizon::Int, draws::Int,
                      replications::Int, n_draws::Int, config::String,
                      shocks, outcomes, instruments, normalize::Symbol)
    if route == "var"
        model, Y, varnames, p = _load_and_estimate_var(data, lags)
        kw = Dict{Symbol,Any}()
        if replications > 0
            kw[:ci_type] = :bootstrap
            kw[:reps] = replications
        end
        ir = irf(model, horizon; kw...)
        ce = policy_causal_effects(ir, shocks, outcomes, instruments;
                                   H=horizon, normalize=normalize)
        return ce, ir
    elseif route == "bvar"
        post, Y, varnames, p, n = _load_and_estimate_bvar(data, lags === nothing ? 4 : lags,
                                                          config, draws, "direct")
        bir = irf(post, horizon)
        ce = policy_causal_effects(bir, shocks, outcomes, instruments;
                                   H=horizon, normalize=normalize)
        return ce, bir
    elseif route == "lp"
        slp, Y, varnames = _load_and_structural_lp(data, horizon,
            lags === nothing ? 4 : lags, nothing, "cholesky", "newey_west", config;
            ci_type=:none, reps=200, conf_level=0.95)
        # LP draws are an INDEPENDENT-NORMAL N(value, se) approximation — fine
        # for pointwise bands, not a joint posterior (documented + settings row).
        ce = policy_causal_effects(slp, shocks, outcomes, instruments;
                                   H=horizon, n_draws=n_draws)
        normalize === :none || throw(CliError("usage/invalid",
            "policy: --normalize applies to the var|bvar|sign routes; the lp route keeps the estimator's scale"))
        return ce, slp.irf
    elseif route == "sign"
        model, Y, varnames, p = _load_and_estimate_var(data, lags)
        check_func, _ = _build_check_func(config)
        check_func === nothing && throw(CliError("usage/missing",
            "policy effects sign requires --config with [identification] sign restrictions"))
        set = identify_sign(model, horizon, check_func; max_draws=replications > 0 ? replications : 1000,
                            store_all=true)
        ce = policy_causal_effects(set, shocks, outcomes, instruments;
                                   H=horizon, normalize=normalize)
        return ce, set
    end
    throw(CliError("usage/invalid", "unknown policy source route '$route'"))
end

# ── Renderers ───────────────────────────────────────────────

"""Tidy causal-effects menu: variable|role|shock|horizon|value."""
function _policy_effects_table(ce)
    rows_var = String[]; rows_role = String[]; rows_shock = String[]
    rows_h = Int[]; rows_v = Float64[]
    for (i, sym) in enumerate(ce.outcomes), (k, lab) in enumerate(ce.shock_labels), h in 1:ce.H
        push!(rows_var, String(sym)); push!(rows_role, "outcome")
        push!(rows_shock, lab); push!(rows_h, h)
        push!(rows_v, round(Float64(ce.Theta_x[i][h, k]); digits=6))
    end
    for (i, sym) in enumerate(ce.instruments), (k, lab) in enumerate(ce.shock_labels), h in 1:ce.H
        push!(rows_var, String(sym)); push!(rows_role, "instrument")
        push!(rows_shock, lab); push!(rows_h, h)
        push!(rows_v, round(Float64(ce.Theta_z[i][h, k]); digits=6))
    end
    DataFrame(variable=rows_var, role=rows_role, shock=rows_shock,
              horizon=rows_h, value=rows_v)
end

function _policy_effects_summary(ce, normalize)
    # upstream's n_draws(ce) is NOT exported — read the container fields directly
    nd = ce.Theta_x_draws === nothing ? 0 : size(ce.Theta_x_draws[1], 3)
    Pair{String,Any}[
        "H (horizon)"    => ce.H,
        "n_shocks"       => length(ce.shock_labels),
        "shock_labels"   => join(ce.shock_labels, ", "),
        # Square = model news menu (exact solve); thin = empirically identified
        # shocks (least-squares counterfactual) — the module's central axis.
        "is_square"      => is_square(ce),
        "source"         => String(ce.source),
        "normalize"      => String(normalize),
        "n_draws"        => nd,
    ]
end

# ── policy effects handlers ─────────────────────────────────

function _policy_effects(route::String; data::String, lags=nothing, horizon::Int=20,
                         draws::Int=2000, replications::Int=0, n_draws::Int=500,
                         config::String="", shocks::String="", outcomes::String="",
                         instruments::String="", normalize::String="none",
                         output::String="", format::String="table")
    horizon >= 1 || throw(CliError("usage/invalid",
        "policy: --horizon must be ≥ 1 (got $horizon)"))
    replications >= 0 || throw(CliError("usage/invalid",
        "policy: --replications must be ≥ 0 (got $replications)"))
    n_draws >= 1 || throw(CliError("usage/invalid",
        "policy: --n-draws must be ≥ 1 (got $n_draws)"))
    draws >= 1 || throw(CliError("usage/invalid",
        "policy: --draws must be ≥ 1 (got $draws)"))
    normalize in ("none", "instrument-impact") || throw(CliError("usage/invalid-option",
        "invalid --normalize '$normalize'; must be none or instrument-impact"))
    norm_sym = normalize == "none" ? :none : :instrument_impact
    shock_list = _parse_cf_shocks(shocks)
    out_pairs = _parse_cf_pairs(outcomes, "--outcomes")
    ins_pairs = _parse_cf_pairs(instruments, "--instruments"; required=false)
    norm_sym === :instrument_impact && isempty(ins_pairs) && throw(CliError("usage/invalid",
        "policy: --normalize instrument-impact needs at least one --instruments entry (it rescales to the FIRST instrument's impact)"))

    _status("Policy causal effects ($route): H=$horizon, shocks=$shocks")
    _status()

    ce, _ = try
        _policy_menu(route; data=data, lags=lags, horizon=horizon, draws=draws,
                     replications=replications, n_draws=n_draws, config=config,
                     shocks=shock_list, outcomes=out_pairs, instruments=ins_pairs,
                     normalize=norm_sym)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "policy causal effects"))
    end

    output_result(_policy_effects_table(ce); format=Symbol(format), output=output,
                  title="Policy Causal Effects Menu")
    output_kv(_policy_effects_summary(ce, norm_sym); format=format,
              title="Policy Causal Effects Summary")
    return ce
end

# ── policy counterfactual handlers ──────────────────────────

function _policy_counterfactual(route::String; data::String, lags=nothing,
                                horizon::Int=20, draws::Int=2000, replications::Int=0,
                                n_draws::Int=500, config::String="",
                                shocks::String="", nonpolicy_shock::String="",
                                outcomes::String="", instruments::String="",
                                normalize::String="none", rule::String="",
                                rule_config::String="", method::String="auto",
                                use_draws::String="auto", baseline_draws::String="fixed",
                                quantiles::String="0.16,0.5,0.84",
                                spanned_tol::Float64=0.05, negate::Bool=false,
                                output::String="", format::String="table",
                                plot::Bool=false, plot_save::String="")
    horizon >= 1 || throw(CliError("usage/invalid",
        "policy: --horizon must be ≥ 1 (got $horizon)"))
    replications >= 0 || throw(CliError("usage/invalid",
        "policy: --replications must be ≥ 0 (got $replications)"))
    n_draws >= 1 || throw(CliError("usage/invalid",
        "policy: --n-draws must be ≥ 1 (got $n_draws)"))
    draws >= 1 || throw(CliError("usage/invalid",
        "policy: --draws must be ≥ 1 (got $draws)"))
    spanned_tol > 0 || throw(CliError("usage/invalid",
        "policy: --spanned-tol must be > 0 (got $spanned_tol)"))
    method in ("auto", "ls", "exact") || throw(CliError("usage/invalid-option",
        "invalid --method '$method'; must be auto, ls or exact"))
    use_draws in ("auto", "on", "off") || throw(CliError("usage/invalid-option",
        "invalid --use-draws '$use_draws'; must be auto, on or off"))
    baseline_draws in ("fixed", "match") || throw(CliError("usage/invalid-option",
        "invalid --baseline-draws '$baseline_draws'; must be fixed or match"))
    normalize in ("none", "instrument-impact") || throw(CliError("usage/invalid-option",
        "invalid --normalize '$normalize'; must be none or instrument-impact"))
    norm_sym = normalize == "none" ? :none : :instrument_impact
    qs = _parse_cf_quantiles(quantiles)
    isempty(strip(nonpolicy_shock)) && throw(CliError("usage/missing",
        "policy counterfactual: --nonpolicy-shock is required (the disturbance the rule responds to)";
        hint="a shock index or name, distinct from the policy --shocks"))
    np_shock = (v = tryparse(Int, strip(nonpolicy_shock)); v === nothing ?
                String(strip(nonpolicy_shock)) : v)
    shock_list = _parse_cf_shocks(shocks)
    out_pairs = _parse_cf_pairs(outcomes, "--outcomes")
    ins_pairs = _parse_cf_pairs(instruments, "--instruments")
    out_syms = Symbol[first(p) for p in out_pairs]
    ins_syms = Symbol[first(p) for p in ins_pairs]

    # Rule construction is pure config/argument work — before any estimation.
    rule_obj = _build_policy_rule(rule, rule_config, horizon, out_syms, ins_syms)

    _status("Policy counterfactual ($route): rule=$(rule_obj.name), H=$horizon")
    _status()

    result = try
        ce, ir = _policy_menu(route; data=data, lags=lags, horizon=horizon, draws=draws,
                              replications=replications, n_draws=n_draws, config=config,
                              shocks=shock_list, outcomes=out_pairs, instruments=ins_pairs,
                              normalize=norm_sym)
        # The LP route has no draw-bearing IRF object for the baseline; its
        # baseline comes from the SAME LP point estimates (draws are the
        # container's independent-normal approximation) — baseline stays fixed.
        base = baseline_path(ir, np_shock, out_pairs, ins_pairs;
                             H=horizon, negate=negate)
        policy_counterfactual(base, ce, rule_obj;
                              method=Symbol(method), draws=Symbol(use_draws),
                              baseline_draws=Symbol(baseline_draws),
                              quantiles=Tuple(qs), spanned_tol=spanned_tol)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "policy counterfactual"))
    end

    _maybe_plot(result; plot=plot, plot_save=plot_save)
    _render_policy_counterfactual(result; format=format, output=output)
    return result
end

# ── policy optimal handler (W5/#127) ────────────────────────

function _policy_optimal(route::String; data::String, lags=nothing,
                         horizon::Int=20, draws::Int=2000, replications::Int=0,
                         n_draws::Int=500, config::String="",
                         shocks::String="", nonpolicy_shock::String="",
                         outcomes::String="", instruments::String="",
                         normalize::String="none", loss_config::String="",
                         use_draws::String="auto", baseline_draws::String="fixed",
                         quantiles::String="0.16,0.5,0.84", negate::Bool=false,
                         output::String="", format::String="table",
                         plot::Bool=false, plot_save::String="")
    horizon >= 1 || throw(CliError("usage/invalid",
        "policy: --horizon must be ≥ 1 (got $horizon)"))
    replications >= 0 || throw(CliError("usage/invalid",
        "policy: --replications must be ≥ 0 (got $replications)"))
    n_draws >= 1 || throw(CliError("usage/invalid",
        "policy: --n-draws must be ≥ 1 (got $n_draws)"))
    draws >= 1 || throw(CliError("usage/invalid",
        "policy: --draws must be ≥ 1 (got $draws)"))
    use_draws in ("auto", "on", "off") || throw(CliError("usage/invalid-option",
        "invalid --use-draws '$use_draws'; must be auto, on or off"))
    baseline_draws in ("fixed", "match") || throw(CliError("usage/invalid-option",
        "invalid --baseline-draws '$baseline_draws'; must be fixed or match"))
    normalize in ("none", "instrument-impact") || throw(CliError("usage/invalid-option",
        "invalid --normalize '$normalize'; must be none or instrument-impact"))
    norm_sym = normalize == "none" ? :none : :instrument_impact
    qs = _parse_cf_quantiles(quantiles)
    isempty(strip(nonpolicy_shock)) && throw(CliError("usage/missing",
        "policy optimal: --nonpolicy-shock is required (the disturbance the optimal policy responds to)"))
    np_shock = (v = tryparse(Int, strip(nonpolicy_shock)); v === nothing ?
                String(strip(nonpolicy_shock)) : v)
    shock_list = _parse_cf_shocks(shocks)
    out_pairs = _parse_cf_pairs(outcomes, "--outcomes")
    ins_pairs = _parse_cf_pairs(instruments, "--instruments")
    out_syms = Symbol[first(p) for p in out_pairs]
    ins_syms = Symbol[first(p) for p in ins_pairs]

    loss, z_wedge = _build_policy_loss(loss_config, horizon, out_syms, ins_syms)

    _status("Optimal policy ($route): loss=$(loss.name), H=$horizon")
    _status()

    result = try
        ce, ir = _policy_menu(route; data=data, lags=lags, horizon=horizon, draws=draws,
                              replications=replications, n_draws=n_draws, config=config,
                              shocks=shock_list, outcomes=out_pairs, instruments=ins_pairs,
                              normalize=norm_sym)
        base = baseline_path(ir, np_shock, out_pairs, ins_pairs;
                             H=horizon, negate=negate)
        # NOTE: optimal_policy hardcodes spanned_tol = 0.05 upstream (no kwarg) —
        # this leaf deliberately declares NO --spanned-tol (#85 class).
        optimal_policy(base, ce, loss;
                       z_wedge=z_wedge, draws=Symbol(use_draws),
                       baseline_draws=Symbol(baseline_draws), quantiles=Tuple(qs))
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "optimal policy"))
    end

    _maybe_plot(result; plot=plot, plot_save=plot_save)
    _render_policy_counterfactual(result; format=format, output=output)
    return result
end

# ── policy moments handler (W5/#127) ────────────────────────

function _parse_cf_frequencies(spec::String)
    s = strip(spec)
    s == "none" && return :none
    s == "business-cycle" && return :business_cycle
    parts = split(s, ",")
    length(parts) == 2 || throw(CliError("usage/invalid",
        "policy moments: --frequencies must be none, business-cycle, or lo,hi in radians (got '$spec')"))
    lo = tryparse(Float64, strip(parts[1]))
    hi = tryparse(Float64, strip(parts[2]))
    (lo === nothing || hi === nothing) && throw(CliError("usage/invalid",
        "policy moments: --frequencies band bounds must be numbers (got '$spec')"))
    (0.0 <= lo < hi <= Float64(π) + 1e-12) || throw(CliError("usage/invalid",
        "policy moments: --frequencies needs 0 ≤ lo < hi ≤ π (got $lo, $hi)"))
    return (lo, hi)
end

function _policy_moments(route::String; data::String, lags=nothing,
                         horizon::Int=20, draws::Int=2000, replications::Int=0,
                         config::String="", shocks::String="",
                         outcomes::String="", instruments::String="",
                         normalize::String="none", rule::String="",
                         rule_config::String="", loss_config::String="",
                         use_draws::String="auto", draw_source::String="ce",
                         quantiles::String="0.16,0.5,0.84",
                         frequencies::String="none",
                         output::String="", format::String="table",
                         plot::Bool=false, plot_save::String="",
                         plot_view::String="sd")
    horizon >= 1 || throw(CliError("usage/invalid",
        "policy: --horizon must be ≥ 1 (got $horizon)"))
    replications >= 0 || throw(CliError("usage/invalid",
        "policy: --replications must be ≥ 0 (got $replications)"))
    draws >= 1 || throw(CliError("usage/invalid",
        "policy: --draws must be ≥ 1 (got $draws)"))
    use_draws in ("auto", "on", "off") || throw(CliError("usage/invalid-option",
        "invalid --use-draws '$use_draws'; must be auto, on or off"))
    draw_source in ("ce", "wold", "both") || throw(CliError("usage/invalid-option",
        "invalid --draw-source '$draw_source'; must be ce, wold or both"))
    normalize in ("none", "instrument-impact") || throw(CliError("usage/invalid-option",
        "invalid --normalize '$normalize'; must be none or instrument-impact"))
    plot_view in ("sd", "corr") || throw(CliError("usage/invalid-option",
        "invalid --plot-view '$plot_view'; must be sd or corr"))
    norm_sym = normalize == "none" ? :none : :instrument_impact
    qs = _parse_cf_quantiles(quantiles)
    freq = _parse_cf_frequencies(frequencies)
    shock_list = _parse_cf_shocks(shocks)
    out_pairs = _parse_cf_pairs(outcomes, "--outcomes")
    ins_pairs = _parse_cf_pairs(instruments, "--instruments"; required=false)
    out_syms = Symbol[first(p) for p in out_pairs]
    ins_syms = Symbol[first(p) for p in ins_pairs]

    # Policy = a rule XOR a loss.
    has_rule = !isempty(rule) || !isempty(rule_config)
    has_loss = !isempty(loss_config)
    (has_rule && has_loss) && throw(CliError("usage/invalid",
        "policy moments: give a rule (--rule/--rule-config) OR a loss (--loss-config), not both"))
    (has_rule || has_loss) || throw(CliError("usage/missing",
        "policy moments: a counterfactual policy is required — --rule/--rule-config or --loss-config"))
    policy = has_rule ?
        _build_policy_rule(rule, rule_config, horizon, out_syms, ins_syms) :
        first(_build_policy_loss(loss_config, horizon, out_syms, ins_syms))

    _status("Counterfactual second moments ($route): H=$horizon" *
            (freq === :none ? "" : ", band=$frequencies"))
    _status()

    mom = try
        if route == "var"
            model, Y, varnames, p = _load_and_estimate_var(data, lags)
            kw = Dict{Symbol,Any}()
            if replications > 0
                kw[:ci_type] = :bootstrap
                kw[:reps] = replications
            end
            ir = irf(model, horizon; kw...)
            ce = policy_causal_effects(ir, shock_list, out_pairs, ins_pairs;
                                       H=horizon, normalize=norm_sym)
            # orthogonalize carries NO identification content here — moments are
            # rotation-invariant (CMW App. A.2); cholesky is just a factorization.
            wold = wold_representation(model; H=horizon)
        else
            post, Y, varnames, p, n = _load_and_estimate_bvar(data,
                lags === nothing ? 4 : lags, config, draws, "direct")
            bir = irf(post, horizon)
            ce = policy_causal_effects(bir, shock_list, out_pairs, ins_pairs;
                                       H=horizon, normalize=norm_sym)
            wold = wold_representation(post; H=horizon)
        end
        counterfactual_moments(wold, ce, policy;
                               outcomes=out_pairs, instruments=ins_pairs,
                               draws=Symbol(use_draws), draw_source=Symbol(draw_source),
                               quantiles=Tuple(qs), frequencies=freq)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "counterfactual moments"))
    end

    _maybe_plot(mom; plot=plot, plot_save=plot_save, view=Symbol(plot_view))
    _render_policy_moments(mom; format=format, output=output, draw_source=draw_source)
    return mom
end

function _render_policy_moments(m; format::String="table", output::String="",
                                draw_source::String="ce")
    nv = length(m.varnames)
    # 1. Standard deviations, baseline vs counterfactual (+ draw bands).
    sd = DataFrame(variable=String.(m.varnames),
                   sd_base=round.(Float64.(m.sd_base); digits=6),
                   sd_cf=round.(Float64.(m.sd_cf); digits=6))
    if m.sd_cf_bands !== nothing
        for q in 1:size(m.sd_cf_bands, 2)
            sd[!, Symbol("sd_cf_q$q")] = round.(Float64.(m.sd_cf_bands[:, q]); digits=6)
        end
    end
    output_result(sd; format=Symbol(format), output=output,
                  title="Counterfactual Standard Deviations")

    # 2. Correlations, tidy upper triangle.
    v1 = String[]; v2 = String[]; cb = Float64[]; cc = Float64[]
    for i in 1:nv, j in (i+1):nv
        push!(v1, String(m.varnames[i])); push!(v2, String(m.varnames[j]))
        push!(cb, round(Float64(m.corr_base[i, j]); digits=6))
        push!(cc, round(Float64(m.corr_cf[i, j]); digits=6))
    end
    isempty(v1) || output_result(
        DataFrame(var1=v1, var2=v2, corr_base=cb, corr_cf=cc);
        format=Symbol(format), output=_per_var_output_path(output, "corr"),
        title="Counterfactual Correlations")

    # 3. Summary — tail_share is the VMA-truncation honesty number.
    pairs = Pair{String,Any}[
        "policy"      => m.policy_name,
        "H"           => m.H,
        "tail_share (VMA truncation; > 0.01 means grow --horizon)" =>
            round(Float64(m.tail_share); digits=6),
        "draw_source" => draw_source,
        "freq_band"   => m.freq_band === nothing ? "full spectrum" :
                         "$(round(Float64(m.freq_band[1]); digits=4)):$(round(Float64(m.freq_band[2]); digits=4))",
    ]
    output_kv(pairs; format=format, title="Moments Summary")
end

function _render_policy_counterfactual(r; format::String="table", output::String="")
    # 1. Paths table (baseline vs counterfactual, bands when propagated).
    nq = length(r.quantile_levels)
    has_bands = r.x_bands !== nothing
    rows = DataFrame(variable=String[], role=String[], horizon=Int[],
                     baseline=Float64[], counterfactual=Float64[])
    if has_bands
        for q in 1:nq
            rows[!, Symbol("q", round(Int, 100 * r.quantile_levels[q]))] = Float64[]
        end
    end
    _push_paths!(rows, r.outcomes, "outcome", r.x_base, r.x_cf, r.x_bands, nq)
    _push_paths!(rows, r.instruments, "instrument", r.z_base, r.z_cf, r.z_bands, nq)
    # Title (→ envelope table key) is FIXED — the rule name lives in the summary
    # kv; a rule-dependent slug would make named_table selection impossible.
    output_result(rows; format=Symbol(format), output=output,
                  title="Policy Counterfactual Paths")

    # 2. The enforcing date-0 policy-shock vector ν*.
    nu_df = DataFrame(shock=r.shock_labels, nu=round.(Float64.(r.nu); digits=6))
    output_result(nu_df; format=Symbol(format),
                  output=_per_var_output_path(output, "nu"),
                  title="Enforcing Policy Shocks (nu)")

    # 3. Implementation-error path — the honesty signal for thin menus. NOT
    # indexed by horizon: optimal_policy stacks the outcome+instrument FOC
    # blocks, so the path can be a multiple of H — index it by component.
    err_df = DataFrame(index=1:length(r.error_path),
                       error=round.(Float64.(r.error_path); digits=6))
    output_result(err_df; format=Symbol(format),
                  output=_per_var_output_path(output, "error"),
                  title="Implementation Error Path")

    # 4. Honesty/summary kv — in the DATA, not stderr.
    pairs = Pair{String,Any}[
        "rule"            => r.rule_name,
        "H"               => r.H,
        "rel_residual"    => round(Float64(r.rel_residual); digits=6),
        "spanned"         => r.spanned,
        "n_draws_used"    => r.n_draws_used,
        "n_draws_failed"  => r.n_draws_failed,
        "quantile_levels" => join(r.quantile_levels, ", "),
    ]
    if r.rel_residual_bands !== nothing
        pairs = vcat(pairs, Pair{String,Any}[
            "rel_residual_bands" => join(round.(Float64.(r.rel_residual_bands); digits=6), ", ")])
    end
    # Loss accounting — populated by optimal_policy (W5), NaN on plain rule
    # counterfactuals. foc_norm ≈ 0 is the optimality check.
    if isfinite(r.loss_base)
        append!(pairs, Pair{String,Any}[
            "loss_base" => round(Float64(r.loss_base); digits=6),
            "loss_cf"   => round(Float64(r.loss_cf); digits=6),
            "foc_norm (≈0 at the optimum)" => round(Float64(r.foc_norm); digits=8),
        ])
        # Upstream warns "loss increased" on a kernel/sign bug — that is a
        # RESULT, so it must be data, not a swallowed stderr line.
        r.loss_cf > r.loss_base && push!(pairs, "warning" =>
            "loss INCREASED under the optimal policy — upstream flags this as a kernel/sign bug; do not use these paths")
    end
    r.spanned || push!(pairs, "note" =>
        "rule NOT enforceable within the span of the supplied policy shocks; the counterfactual is a least-squares approximation — read error_path")
    output_kv(pairs; format=format, title="Counterfactual Summary")
end

function _push_paths!(rows, syms, role, base, cf, bands, nq)
    for (i, sym) in enumerate(syms)
        for h in eachindex(base[i])
            row = Any[String(sym), role, h,
                      round(Float64(base[i][h]); digits=6),
                      round(Float64(cf[i][h]); digits=6)]
            if bands !== nothing
                append!(row, [round(Float64(bands[i][h, q]); digits=6) for q in 1:nq])
            end
            push!(rows, row)
        end
    end
end

# ── Registry ────────────────────────────────────────────────

const _POLICY_COMMON = [
    OptionSpec(name="horizon", type=Int, default=20,
               description="Truncation horizon H (≥ 1; MW use H=100)"),
    OptionSpec(name="shocks", type=String, default="",
               description="Identified POLICY shock columns (indices or names, comma-separated; REQUIRED)"),
    OptionSpec(name="outcomes", type=String, default="",
               description="Outcome map name=index-or-column, comma-separated (REQUIRED), e.g. infl=2,ygap=1"),
    OptionSpec(name="instruments", type=String, default="",
               description="Instrument map name=index-or-column, comma-separated, e.g. rate=3"),
    OptionSpec(name="output", short="o", type=String, default="",
               description="Export results to file"),
    OptionSpec(name="format", short="f", type=String, default="table",
               choices=["table", "csv", "json"], description="table|csv|json"),
]

function _policy_route_options(route::String)
    opts = [OptionSpec(name="lags", short="p", type=Int, default=nothing,
                       description="Lag order (default: AIC for var/sign, 4 for bvar/lp)")]
    extra = route == "bvar" ? [
        OptionSpec(name="draws", short="n", type=Int, default=2000, description="Posterior draws"),
        OptionSpec(name="config", type=String, default="", description="TOML prior config")] :
      route == "lp" ? [
        OptionSpec(name="n-draws", type=Int, default=500,
                   description="Independent-normal N(value, se) draws (pointwise approximation, NOT a joint posterior)"),
        OptionSpec(name="config", type=String, default="", description="TOML identification config")] :
      route == "sign" ? [
        OptionSpec(name="replications", type=Int, default=1000, description="Candidate rotations"),
        OptionSpec(name="config", type=String, default="", description="TOML sign-restriction config (REQUIRED)")] :
      [OptionSpec(name="replications", type=Int, default=0,
                  description="Bootstrap draws for uncertainty bands (0 = point only)")]
    return vcat(opts, extra)
end

const _POLICY_CF_OPTIONS = [
    OptionSpec(name="nonpolicy-shock", type=String, default="",
               description="The ONE non-policy shock the rule responds to (index or name; REQUIRED)"),
    OptionSpec(name="rule", type=String, default="",
               description="Builtin rule: rate-peg|inflation-target|output-gap|ngdp|taylor (taylor = TEXTBOOK rho/phi, not CMW — use --rule-config for that)"),
    OptionSpec(name="rule-config", type=String, default="",
               description="TOML [rule] section (rate-target paths, CMW taylor, custom pi_var/y_var)"),
    OptionSpec(name="method", type=String, default="auto",
               choices=["auto", "ls", "exact"],
               description="Projection: auto (exact when square) | ls | exact"),
    OptionSpec(name="use-draws", type=String, default="auto",
               choices=["auto", "on", "off"],
               description="Propagate menu draws into bands: auto|on|off"),
    OptionSpec(name="baseline-draws", type=String, default="fixed",
               choices=["fixed", "match"],
               description="fixed (MW convention, separate estimations) | match (pair draw d with draw d; equal counts enforced)"),
    OptionSpec(name="quantiles", type=String, default="0.16,0.5,0.84",
               description="Band quantiles, comma-separated in (0,1)"),
    OptionSpec(name="spanned-tol", type=Float64, default=0.05,
               description="rel_residual threshold for the spanned flag"),
]

function register_policy_commands!()
    specs = CommandSpec[]
    for route in ("var", "bvar", "lp", "sign")
        push!(specs, CommandSpec(
            path=["policy", "effects", route],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing,
                          description="Path to CSV data file")],
            options=[_POLICY_COMMON...; _policy_route_options(route)...;
                     # instrument-impact renormalizes per draw; near-zero-impact
                     # draws are dropped (count surfaced in the summary table)
                     OptionSpec(name="normalize", type=String, default="none",
                                choices=["none", "instrument-impact"],
                                description="none | instrument-impact (rescale so the first instrument's impact is +1)")],
            flags=FlagSpec[],   # PolicyCausalEffects has NO plot_result recipe
            tables=[TableSpec(name=Symbol("policy_effects_$route"),
                              description="Policy causal-effects menu")],
            category="policy",
            handler=wrap_legacy((; kw...) -> _policy_effects(route; kw...)),
        ))
    end
    for route in ("var", "bvar", "lp")
        push!(specs, CommandSpec(
            path=["policy", "counterfactual", route],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing,
                          description="Path to CSV data file")],
            options=[_POLICY_COMMON...; _policy_route_options(route)...;
                     _POLICY_CF_OPTIONS...;
                     OptionSpec(name="normalize", type=String, default="none",
                                choices=["none", "instrument-impact"],
                                description="none | instrument-impact");
                     PLOT_OPTIONS...],
            flags=[FlagSpec(name="negate",
                            description="Flip the non-policy shock's sign (e.g. the contractionary version)"),
                   FlagSpec(name="plot", description="Open interactive plot in browser")],
            tables=[TableSpec(name=Symbol("policy_counterfactual_$route"),
                              description="McKay-Wolf rule counterfactual")],
            category="policy",
            handler=wrap_legacy((; kw...) -> _policy_counterfactual(route; kw...)),
        ))
    end
    # ── W5/#127: policy optimal + policy moments ────────────
    for route in ("var", "bvar", "lp")
        push!(specs, CommandSpec(
            path=["policy", "optimal", route],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing,
                          description="Path to CSV data file")],
            options=[_POLICY_COMMON...; _policy_route_options(route)...;
                     OptionSpec(name="nonpolicy-shock", type=String, default="",
                                description="The ONE non-policy shock the optimal policy responds to (REQUIRED)");
                     OptionSpec(name="loss-config", type=String, default="",
                                description="TOML [loss] section (REQUIRED; lambda has no default upstream)");
                     OptionSpec(name="use-draws", type=String, default="auto",
                                choices=["auto", "on", "off"],
                                description="Propagate menu draws into bands: auto|on|off");
                     OptionSpec(name="baseline-draws", type=String, default="fixed",
                                choices=["fixed", "match"],
                                description="fixed | match (equal draw counts enforced)");
                     OptionSpec(name="quantiles", type=String, default="0.16,0.5,0.84",
                                description="Band quantiles, comma-separated in (0,1)");
                     # NO --spanned-tol: optimal_policy hardcodes 0.05 upstream.
                     OptionSpec(name="normalize", type=String, default="none",
                                choices=["none", "instrument-impact"],
                                description="none | instrument-impact");
                     PLOT_OPTIONS...],
            flags=[FlagSpec(name="negate",
                            description="Flip the non-policy shock's sign"),
                   FlagSpec(name="plot", description="Open interactive plot in browser")],
            tables=[TableSpec(name=Symbol("policy_optimal_$route"),
                              description="Optimal policy under a quadratic loss")],
            category="policy",
            handler=wrap_legacy((; kw...) -> _policy_optimal(route; kw...)),
        ))
    end
    for route in ("var", "bvar")
        push!(specs, CommandSpec(
            path=["policy", "moments", route],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing,
                          description="Path to CSV data file")],
            options=[_POLICY_COMMON...; _policy_route_options(route)...;
                     OptionSpec(name="rule", type=String, default="",
                                description="Builtin counterfactual rule (see policy counterfactual)");
                     OptionSpec(name="rule-config", type=String, default="",
                                description="TOML [rule] section");
                     OptionSpec(name="loss-config", type=String, default="",
                                description="TOML [loss] section (rule XOR loss)");
                     OptionSpec(name="use-draws", type=String, default="auto",
                                choices=["auto", "on", "off"],
                                description="Propagate draws into sd bands: auto|on|off");
                     OptionSpec(name="draw-source", type=String, default="ce",
                                choices=["ce", "wold", "both"],
                                description="Uncertainty source: ce | wold | both (matching counts enforced)");
                     OptionSpec(name="quantiles", type=String, default="0.16,0.5,0.84",
                                description="Band quantiles, comma-separated in (0,1)");
                     OptionSpec(name="frequencies", type=String, default="none",
                                description="none | business-cycle (2π/32..2π/6) | lo,hi in radians (0 ≤ lo < hi ≤ π)");
                     OptionSpec(name="plot-view", type=String, default="sd",
                                choices=["sd", "corr"],
                                description="Plot panel: sd | corr");
                     PLOT_OPTIONS...],
            flags=[FlagSpec(name="plot", description="Open interactive plot in browser")],
            tables=[TableSpec(name=Symbol("policy_moments_$route"),
                              description="Second moments under a counterfactual rule/loss")],
            category="policy",
            handler=wrap_legacy((; kw...) -> _policy_moments(route; kw...)),
        ))
    end
    register!(specs)
    return build_node("policy", specs;
        description="Policy counterfactuals: causal-effect menus, McKay-Wolf rule counterfactuals, optimal policy and second moments")
end
