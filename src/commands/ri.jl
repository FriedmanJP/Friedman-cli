# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# ── ri: Rational Inattention family + choice ri-logit ([MEM111-W5] #317) ─────
#
# Top-level `ri` command node (11 leaves):
#   solve, transition, statespace, irf, fevd, simulate,
#   estimate, cg-test, mw, discrete, iia-test
# Plus choice-family estimator/predictor specs:
#   estimate choice ri-logit (`w5_estimate_specs()`)
#   predict choice ri-logit  (`w5_predict_specs()`)
#
# All 10 Wave-5 result types (`SteadyStateKalman`, `RationalInattentionProblem`,
# `SimsKalmanSolution`, `DynamicRISolution`, `RIEstimationResult`, `CGTestResult`,
# `MWAttentionResult`, `RIDiscreteChoiceSolution`, `RIIIADiagnostic`, `RILogitModel`)
# plus `ABCDSystem` route through `_emit_result` (zero hand-built tables for them)
# and advertise `--plot` / `--plot-save`.

# ── Shared RI helpers ────────────────────────────────────────────────────────

function _ri_observables_sym(obs::String)::Symbol
    s = strip(obs)
    s == "all" && return :all
    s == "actions" && return :actions
    (s == "states" || s == "actions-and-states") && return :actions_and_states
    throw(CliError("usage/invalid-option",
        "invalid --observables '$obs'; must be all, actions, states, or actions-and-states"))
end

function _ri_resolve_cap_omega(cfg_cap, cfg_om, cli_cap::Float64, cli_om::Float64;
                               require_one::Bool=true, context::String="ri")
    (!isnan(cli_cap) && !isnan(cli_om)) && throw(CliError("usage/invalid",
        "$context: --capacity and --omega are mutually exclusive"))
    if !isnan(cli_cap)
        (isfinite(cli_cap) && cli_cap > 0.0) || throw(CliError("usage/invalid",
            "$context: --capacity must be finite and > 0 (got $cli_cap)"))
        return cli_cap, nothing
    elseif !isnan(cli_om)
        (isfinite(cli_om) && cli_om > 0.0) || throw(CliError("usage/invalid",
            "$context: --omega must be finite and > 0 (got $cli_om)"))
        return nothing, cli_om
    elseif cfg_cap !== nothing || cfg_om !== nothing
        return cfg_cap, cfg_om
    elseif require_one
        throw(CliError("usage/missing",
            "$context: specify exactly one of --capacity or --omega (or set capacity/omega in --config)"))
    else
        return nothing, nothing
    end
end

function _ri_resolve_units(cfg_units::Symbol, cli_units::String; context::String="ri")::Symbol
    isempty(strip(cli_units)) && return cfg_units
    s = strip(cli_units)
    s in ("bits", "nats") || throw(CliError("usage/invalid-option",
        "$context: invalid --units '$cli_units'; must be bits or nats"))
    return Symbol(s)
end

function _ri_build_problem_from_config(config::String;
                                       capacity::Float64=NaN, omega::Float64=NaN,
                                       units::String="", require_constraint::Bool=true,
                                       default_param::Symbol=:capacity,
                                       context::String="ri")
    isempty(strip(config)) && throw(CliError("usage/missing",
        "$context: --config <toml> with a [ri] section is required";
        hint="define [ri] with A, B, H (and capacity or omega)"))
    cfg = get_ri_problem(load_config(config))
    cap, om = _ri_resolve_cap_omega(cfg.capacity, cfg.omega, capacity, omega;
                                    require_one=require_constraint, context=context)
    if cap === nothing && om === nothing
        if default_param === :omega
            om = 1.0
        else
            cap = 1.0
        end
    end
    u_sym = _ri_resolve_units(cfg.units, units; context=context)
    prob = try
        RationalInattentionProblem(cfg.A, cfg.B, cfg.H;
            M=cfg.M, B_u=cfg.B_u, beta=cfg.beta,
            capacity=cap, omega=om, units=u_sym,
            state_names=cfg.state_names, action_names=cfg.action_names,
            shock_names=cfg.shock_names)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, context))
    end
    return prob, cfg
end

function _ri_resolve_solution(model, config::String; context::String="ri")
    if model !== nothing
        if model isa SimsKalmanSolution
            return model
        elseif model isa RationalInattentionProblem
            return try
                solve_ri_kalman(model)
            catch e
                throw(_domain_or_data_error(e, context))
            end
        else
            throw(CliError("model/wrong-kind",
                "$context: unsupported model handle $(typeof(model)); expected SimsKalmanSolution or RationalInattentionProblem"))
        end
    end
    isempty(strip(config)) && throw(CliError("usage/missing",
        "$context: provide --model <SimsKalmanSolution.jld2> or --config <toml>"))
    prob, _ = _ri_build_problem_from_config(config; require_constraint=true, context=context)
    return try
        solve_ri_kalman(prob)
    catch e
        throw(_domain_or_data_error(e, context))
    end
end

function _ri_transition_overrides_from_config(config::String, n::Int)
    isempty(strip(config)) && return (Sigma_init=nothing, omega_path=nothing, capacity_path=nothing)
    raw = load_config(config)
    sec = get(raw, "ri", nothing)
    sec isa AbstractDict || throw(CliError("config/missing",
        "ri transition --config requires a [ri] section"))
    S0 = if haskey(sec, "Sigma_init")
        m = _ri_parse_mat(sec["Sigma_init"], "[ri] Sigma_init"; allow_scalar=(n == 1), allow_vec=false)
        size(m) == (n, n) || throw(CliError("config/shape",
            "[ri] Sigma_init must be n×n = ($n, $n), got $(size(m))"))
        m
    else
        nothing
    end
    om_p = _ri_parse_path_opt(sec, "omega_path", "[ri]"; allow_zero=false)
    cap_p = _ri_parse_path_opt(sec, "capacity_path", "[ri]"; allow_zero=true)
    (om_p !== nothing && cap_p !== nothing) && throw(CliError("config/invalid",
        "[ri] omega_path and capacity_path are mutually exclusive"))
    return (Sigma_init=S0, omega_path=om_p, capacity_path=cap_p)
end

# ── Summary KV builders (shared by live execution & --result replay) ─────────

function _ri_solve_summary(sol::SimsKalmanSolution)
    Pair{String,Any}[
        "method"        => string(sol.method),
        "converged"     => sol.converged,
        "iterations"    => sol.iterations,
        "omega"         => Float64(sol.omega),
        "capacity_bits" => Float64(sol.capacity_bits),
        "capacity_nats" => Float64(sol.capacity_nats),
        "signal_rank"   => sol.signal_rank,
        "expected_loss" => Float64(sol.expected_loss),
    ]
end

function _ri_transition_summary(dyn::DynamicRISolution)
    Pair{String,Any}[
        "T_path"           => dyn.T_path,
        "n_state"          => size(dyn.Sigma_init, 1),
        "converged"        => dyn.converged,
        "iterations"       => dyn.iterations,
        "residual"         => Float64(dyn.residual),
        "initial_bits"     => Float64(dyn.capacity_bits_path[1]),
        "terminal_bits"    => Float64(dyn.capacity_bits_path[end]),
        "initial_omega"    => Float64(dyn.omega_path[1]),
        "terminal_omega"   => Float64(dyn.omega_path[end]),
        "initial_rank"     => dyn.signal_rank_path[1],
        "terminal_rank"    => dyn.signal_rank_path[end],
    ]
end

function _ri_estimation_summary(res::RIEstimationResult)
    pairs = Pair{String,Any}[
        "method"          => string(res.method),
        "estimate_param"  => string(res.estimate_param),
        "capacity"        => Float64(res.capacity),
        "omega"           => Float64(res.omega),
        "loglik"          => Float64(res.loglik),
        "loglik_fullinfo" => Float64(res.loglik_fullinfo),
        "lr_stat"         => Float64(res.lr_stat),
        "lr_pvalue"       => Float64(res.lr_pvalue),
        "aic"             => Float64(res.aic),
        "bic"             => Float64(res.bic),
        "n_obs"           => res.n_obs,
        "converged"       => res.converged,
    ]
    if res.method === :bayes && isfinite(res.acceptance_rate)
        push!(pairs, "acceptance_rate" => Float64(res.acceptance_rate))
    end
    return pairs
end

function _ri_cg_summary(res::CGTestResult; model=nothing, horizon::Int=1)
    pairs = Pair{String,Any}[
        "n_obs"            => res.n_obs,
        "hac_lags"         => res.hac_lags,
        "beta_cg"          => Float64(res.beta_cg),
        "se_cg"            => Float64(res.se_cg),
        "t_stat"           => Float64(res.t_stat),
        "pvalue"           => Float64(res.pvalue),
        "implied_gain"     => Float64(res.implied_gain),
        "implied_capacity" => Float64(res.implied_capacity),
    ]
    if model !== nothing
        m_slope = try
            implied_cg_slope(model; horizon=horizon)
        catch e
            throw(_domain_or_data_error(e, "implied_cg_slope"))
        end
        push!(pairs, "comparison_horizon" => horizon)
        push!(pairs, "model_implied_cg_slope" => Float64(m_slope))
        push!(pairs, "cg_slope_diff" => Float64(res.beta_cg - m_slope))
    end
    return pairs
end

function _ri_mw_summary(res::MWAttentionResult)
    share = res.total_kappa > 0 ? res.kappa_agg / res.total_kappa : NaN
    Pair{String,Any}[
        "kappa_agg"                 => Float64(res.kappa_agg),
        "kappa_idio"                => Float64(res.kappa_idio),
        "total_kappa"               => Float64(res.total_kappa),
        "agg_attention_share"       => Float64(share),
        "omega"                     => Float64(res.omega),
        "strategic_complementarity" => Float64(res.strategic_complementarity),
        "units"                     => string(res.units),
        "converged"                 => res.converged,
        "iterations"                => res.iterations,
    ]
end

function _ri_discrete_summary(sol::RIDiscreteChoiceSolution)
    J, S = size(sol.payoffs)
    cset = isempty(sol.consideration_set) ? "empty" : join(sol.consideration_set, ",")
    Pair{String,Any}[
        "alternatives"       => J,
        "states"             => S,
        "omega"              => Float64(sol.omega),
        "consideration_set"  => cset,
        "mutual_info_bits"   => Float64(sol.mutual_info_bits),
        "mutual_info_nats"   => Float64(sol.mutual_info_nats),
        "expected_utility"   => Float64(sol.expected_utility),
        "net_welfare"        => Float64(sol.net_welfare),
        "converged"          => sol.converged,
        "iterations"         => sol.iterations,
    ]
end

function _ri_iia_summary(diag::RIIIADiagnostic)
    max_uncond = isempty(diag.uncond_odds_ratio_shift) ? 0.0 : maximum(diag.uncond_odds_ratio_shift)
    Pair{String,Any}[
        "base_alternatives"         => size(diag.base_solution.payoffs, 1),
        "base_consideration_set"    => join(diag.base_solution.consideration_set, ","),
        "expanded_consideration_set"=> join(diag.expanded_solution.consideration_set, ","),
        "max_uncond_odds_shift"     => Float64(max_uncond),
        "cond_odds_ratio_max_diff"  => Float64(diag.cond_odds_ratio_max_diff),
        "max_iia_violation"         => Float64(diag.max_iia_violation),
    ]
end

# ── --result replay renderer (1:1 JSON schema parity) ───────────────────────

function _rerender_ri_result(result; format::String="table", output::String="",
                             title::String="", key::String="",
                             plot::Bool=false, plot_save::String="")
    tn = nameof(typeof(result))
    if tn === :SimsKalmanSolution
        _emit_result(result; title="Sims (2003) RI Kalman Solution",
                     key="ri_kalman_solution", format=format, output=output)
        output_kv(_ri_solve_summary(result); format=format,
                  output=_per_var_output_path(output, "summary"),
                  title="RI Summary", key="ri_summary")
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :RationalInattentionProblem
        _emit_result(result; title="Rational Inattention Problem",
                     key="ri_problem", format=format, output=output)
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :DynamicRISolution
        _emit_result(result; title="Dynamic RI Transition Path",
                     key="ri_transition_path", format=format, output=output)
        output_kv(_ri_transition_summary(result); format=format,
                  output=_per_var_output_path(output, "summary"),
                  title="RI Transition Summary", key="ri_transition_summary")
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :StateSpaceModel
        output_result(_statespace_system_table(result); format=Symbol(format), output=output,
                      title="RI State-Space System", key="ri_statespace_system")
        output_kv(Pair{String,Any}[
            "representation" => "statespace",
            "n_obs"          => result.n_obs,
            "n_state"        => result.n_state,
            "init_mode"      => string(result.init_mode),
        ]; format=format, output=_per_var_output_path(output, "summary"),
           title="RI State-Space Summary", key="ri_statespace_summary")
        if (plot || !isempty(plot_save)) && result.T_obs == 0
            throw(CliError("usage/invalid",
                "ri statespace: plotting requires --as abcd or --as steady-kalman (to_statespace returns an unfitted StateSpaceModel)"))
        end
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :ABCDSystem
        _emit_result(result; title="RI ABCD Representation",
                     key="ri_abcd_system", format=format, output=output)
        output_kv(Pair{String,Any}[
            "representation" => "abcd",
            "n_states"       => size(result.A, 1),
            "n_obs"          => size(result.C, 1),
            "n_shocks"       => size(result.B, 2),
        ]; format=format, output=_per_var_output_path(output, "summary"),
           title="RI State-Space Summary", key="ri_statespace_summary")
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :SteadyStateKalman
        _emit_result(result; title="RI Steady-State Kalman Filter",
                     key="ri_steady_kalman", format=format, output=output)
        max_eig = isempty(result.closed_loop_eigs) ? 0.0 : maximum(abs, result.closed_loop_eigs)
        output_kv(Pair{String,Any}[
            "representation"  => "steady-kalman",
            "n_state"         => size(result.K_gain, 1),
            "n_obs"           => size(result.K_gain, 2),
            "max_eig_modulus" => Float64(max_eig),
        ]; format=format, output=_per_var_output_path(output, "summary"),
           title="RI State-Space Summary", key="ri_statespace_summary")
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :ImpulseResponse
        _emit_result(result; title="RI Impulse Response Functions",
                     key="ri_irf", format=format, output=output)
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :FEVD
        _emit_result(result; title="RI Forecast Error Variance Decomposition",
                     key="ri_fevd", format=format, output=output)
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :RIEstimationResult
        _emit_result(result; title="Rational Inattention Estimation ($(result.method))",
                     key="ri_estimation", format=format, output=output)
        output_kv(_ri_estimation_summary(result); format=format,
                  output=_per_var_output_path(output, "summary"),
                  title="RI Estimation Summary", key="ri_estimation_summary")
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :CGTestResult
        _emit_result(result; title="Coibion-Gorodnichenko (2015) Information-Rigidity Test",
                     key="cg_test", format=format, output=output)
        output_kv(_ri_cg_summary(result); format=format,
                  output=_per_var_output_path(output, "summary"),
                  title="CG Test Summary", key="cg_summary")
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :MWAttentionResult
        _emit_result(result; title="Maćkowiak-Wiederholt (2009) Attention Allocation",
                     key="ri_mw_attention", format=format, output=output)
        output_kv(_ri_mw_summary(result); format=format,
                  output=_per_var_output_path(output, "summary"),
                  title="MW Attention Summary", key="ri_mw_summary")
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :RIDiscreteChoiceSolution
        _emit_result(result; title="Matějka-McKay Discrete-Choice RI Solution",
                     key="ri_discrete_choice", format=format, output=output)
        output_kv(_ri_discrete_summary(result); format=format,
                  output=_per_var_output_path(output, "summary"),
                  title="Discrete RI Summary", key="ri_discrete_summary")
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    elseif tn === :RIIIADiagnostic
        _emit_result(result; title="RI IIA Breakdown Diagnostic",
                     key="ri_iia_diagnostic", format=format, output=output)
        output_kv(_ri_iia_summary(result); format=format,
                  output=_per_var_output_path(output, "summary"),
                  title="RI IIA Summary", key="ri_iia_summary")
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    else
        _emit_result(result; title=title, key=key, format=format, output=output)
        _maybe_plot(result; plot=plot, plot_save=plot_save)
    end
    return result
end

# ── Handlers: 11 `ri` leaves ─────────────────────────────────────────────────

function _ri_solve(; config::String="", method::String="water-filling",
                   capacity::Float64=NaN, omega::Float64=NaN, units::String="",
                   tol::Float64=1e-11, max_iter::Int=2000,
                   problem_only::Bool=false,
                   output::String="", format::String="table",
                   plot::Bool=false, plot_save::String="")
    method in ("water-filling", "logdet-barrier") || throw(CliError("usage/invalid-option",
        "ri solve: invalid --method '$method'; must be water-filling or logdet-barrier"))
    (isfinite(tol) && tol > 0.0) || throw(CliError("usage/invalid",
        "ri solve: --tol must be finite and > 0 (got $tol)"))
    max_iter >= 1 || throw(CliError("usage/invalid",
        "ri solve: --max-iter must be ≥ 1 (got $max_iter)"))

    prob, _ = _ri_build_problem_from_config(config; capacity=capacity, omega=omega,
                                            units=units, require_constraint=true,
                                            context="ri solve")
    if problem_only
        _status("Rational Inattention Problem: n=$(size(prob.A, 1)), m=$(size(prob.B, 2)), d=$(size(prob.H, 2))")
        _status()
        _emit_result(prob; title="Rational Inattention Problem",
                     key="ri_problem", format=format, output=output)
        _maybe_plot(prob; plot=plot, plot_save=plot_save)
        return prob
    end

    _status("Solving Sims RI Kalman filter (method=$method, n=$(size(prob.A, 1)), d=$(size(prob.H, 2)))")
    _status()
    sol = try
        solve_ri_kalman(prob; method=_to_sym(method), tol=tol, max_iter=max_iter)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "ri solve"))
    end
    _emit_result(sol; title="Sims (2003) RI Kalman Solution",
                 key="ri_kalman_solution", format=format, output=output)
    output_kv(_ri_solve_summary(sol); format=format,
              output=_per_var_output_path(output, "summary"),
              title="RI Summary", key="ri_summary")
    _maybe_plot(sol; plot=plot, plot_save=plot_save)
    return sol
end

function _ri_transition(; config::String="", model=nothing,
                        t_path::Int=100, damping::Float64=0.7,
                        tol::Float64=1e-10, max_iter::Int=500,
                        capacity::Float64=NaN, omega::Float64=NaN,
                        output::String="", format::String="table",
                        plot::Bool=false, plot_save::String="")
    t_path >= 1 || throw(CliError("usage/invalid",
        "ri transition: --t-path must be ≥ 1 (got $t_path)"))
    (isfinite(damping) && 0.0 < damping <= 1.0) || throw(CliError("usage/invalid",
        "ri transition: --damping must lie in (0, 1] (got $damping)"))
    (isfinite(tol) && tol > 0.0) || throw(CliError("usage/invalid",
        "ri transition: --tol must be finite and > 0 (got $tol)"))
    max_iter >= 1 || throw(CliError("usage/invalid",
        "ri transition: --max-iter must be ≥ 1 (got $max_iter)"))
    (!isnan(capacity) && !isnan(omega)) && throw(CliError("usage/invalid",
        "ri transition: --capacity and --omega are mutually exclusive"))
    if !isnan(capacity)
        (isfinite(capacity) && capacity >= 0.0) || throw(CliError("usage/invalid",
            "ri transition: --capacity must be finite and ≥ 0 (got $capacity)"))
    end
    if !isnan(omega)
        (isfinite(omega) && omega > 0.0) || throw(CliError("usage/invalid",
            "ri transition: --omega must be finite and > 0 (got $omega)"))
    end

    prob, Sigma_init, om_path, cap_path = if model !== nothing
        p = if model isa SimsKalmanSolution
            model.problem
        elseif model isa RationalInattentionProblem
            model
        else
            throw(CliError("model/wrong-kind",
                "ri transition: unsupported --model handle $(typeof(model))"))
        end
        n = size(p.A, 1)
        ov = _ri_transition_overrides_from_config(config, n)
        S0 = ov.Sigma_init !== nothing ? ov.Sigma_init :
             (model isa SimsKalmanSolution ? copy(model.Sigma_prior) : Matrix{Float64}(I, n, n))
        (p, S0, ov.omega_path, ov.capacity_path)
    else
        p, cfg = _ri_build_problem_from_config(config; require_constraint=true,
                                               context="ri transition")
        n = size(p.A, 1)
        S0 = cfg.Sigma_init !== nothing ? cfg.Sigma_init : Matrix{Float64}(I, n, n)
        (p, S0, cfg.omega_path, cfg.capacity_path)
    end

    if !isnan(capacity)
        cap_path = capacity
        om_path = nothing
    elseif !isnan(omega)
        om_path = omega
        cap_path = nothing
    end

    _status("Solving Afrouzi-Yang dynamic RI transition (T_path=$t_path, damping=$damping)")
    _status()
    dyn = try
        solve_ri_transition(prob, Sigma_init;
            T_path=t_path, omega_path=om_path, capacity_path=cap_path,
            tol=tol, max_iter=max_iter, damping=damping)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "ri transition"))
    end
    _emit_result(dyn; title="Dynamic RI Transition Path",
                 key="ri_transition_path", format=format, output=output)
    output_kv(_ri_transition_summary(dyn); format=format,
              output=_per_var_output_path(output, "summary"),
              title="RI Transition Summary", key="ri_transition_summary")
    _maybe_plot(dyn; plot=plot, plot_save=plot_save)
    return dyn
end

function _ri_statespace(; config::String="", model=nothing,
                        observables::String="all", as::String="statespace",
                        init_mode::String="", kappa::Float64=1e6,
                        output::String="", format::String="table",
                        plot::Bool=false, plot_save::String="")
    as in ("statespace", "abcd", "steady-kalman") || throw(CliError("usage/invalid-option",
        "ri statespace: invalid --as '$as'; must be statespace, abcd, or steady-kalman"))
    obs_sym = _ri_observables_sym(observables)
    im_sym = if isempty(strip(init_mode))
        nothing
    else
        s = strip(init_mode)
        s in ("stationary", "kappa", "diffuse") || throw(CliError("usage/invalid-option",
            "ri statespace: invalid --init-mode '$init_mode'; must be stationary, kappa, or diffuse"))
        Symbol(s)
    end
    if as == "statespace" && (plot || !isempty(plot_save))
        throw(CliError("usage/invalid",
            "ri statespace: plotting requires --as abcd or --as steady-kalman (to_statespace returns an unfitted StateSpaceModel)"))
    end

    sol = _ri_resolve_solution(model, config; context="ri statespace")
    _status("RI representation: as=$as, observables=$obs_sym")
    _status()

    if as == "statespace"
        ss = try
            to_statespace(sol; observables=obs_sym, init_mode=im_sym, kappa=kappa)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, "ri statespace"))
        end
        output_result(_statespace_system_table(ss); format=Symbol(format), output=output,
                      title="RI State-Space System", key="ri_statespace_system")
        output_kv(Pair{String,Any}[
            "representation" => "statespace",
            "observables"    => string(obs_sym),
            "n_obs"          => ss.n_obs,
            "n_state"        => ss.n_state,
            "init_mode"      => string(ss.init_mode),
        ]; format=format, output=_per_var_output_path(output, "summary"),
           title="RI State-Space Summary", key="ri_statespace_summary")
        return ss
    elseif as == "abcd"
        abcd = try
            to_abcd(sol; observables=obs_sym)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, "ri statespace (abcd)"))
        end
        _emit_result(abcd; title="RI ABCD Representation",
                     key="ri_abcd_system", format=format, output=output)
        output_kv(Pair{String,Any}[
            "representation" => "abcd",
            "observables"    => string(obs_sym),
            "n_states"       => size(abcd.A, 1),
            "n_obs"          => size(abcd.C, 1),
            "n_shocks"       => size(abcd.B, 2),
        ]; format=format, output=_per_var_output_path(output, "summary"),
           title="RI State-Space Summary", key="ri_statespace_summary")
        _maybe_plot(abcd; plot=plot, plot_save=plot_save)
        return abcd
    else  # steady-kalman
        ssk = try
            ss = to_statespace(sol; observables=obs_sym, init_mode=im_sym, kappa=kappa)
            steady_state_kalman(ss)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, "ri statespace (steady-kalman)"))
        end
        _emit_result(ssk; title="RI Steady-State Kalman Filter",
                     key="ri_steady_kalman", format=format, output=output)
        max_eig = isempty(ssk.closed_loop_eigs) ? 0.0 : maximum(abs, ssk.closed_loop_eigs)
        output_kv(Pair{String,Any}[
            "representation"  => "steady-kalman",
            "observables"     => string(obs_sym),
            "n_state"         => size(ssk.K_gain, 1),
            "n_obs"           => size(ssk.K_gain, 2),
            "max_eig_modulus" => Float64(max_eig),
        ]; format=format, output=_per_var_output_path(output, "summary"),
           title="RI State-Space Summary", key="ri_statespace_summary")
        _maybe_plot(ssk; plot=plot, plot_save=plot_save)
        return ssk
    end
end

function _ri_irf(; config::String="", model=nothing,
                 horizons::Int=20, observables::String="all",
                 output::String="", format::String="table",
                 plot::Bool=false, plot_save::String="")
    horizons >= 1 || throw(CliError("usage/invalid",
        "ri irf: --horizons must be ≥ 1 (got $horizons)"))
    obs_sym = _ri_observables_sym(observables)
    sol = _ri_resolve_solution(model, config; context="ri irf")
    _status("RI Impulse Response Functions: H=$horizons, observables=$obs_sym")
    _status()
    ir = try
        irf(sol, horizons; observables=obs_sym)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "ri irf"))
    end
    _emit_result(ir; title="RI Impulse Response Functions (H=$horizons)",
                 key="ri_irf", format=format, output=output)
    _maybe_plot(ir; plot=plot, plot_save=plot_save)
    return ir
end

function _ri_fevd(; config::String="", model=nothing,
                  horizons::Int=20, observables::String="actions",
                  output::String="", format::String="table",
                  plot::Bool=false, plot_save::String="")
    horizons >= 1 || throw(CliError("usage/invalid",
        "ri fevd: --horizons must be ≥ 1 (got $horizons)"))
    obs_sym = _ri_observables_sym(observables)
    sol = _ri_resolve_solution(model, config; context="ri fevd")
    _status("RI Forecast Error Variance Decomposition: H=$horizons, observables=$obs_sym")
    _status()
    fv = try
        fevd(sol, horizons; observables=obs_sym)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "ri fevd"))
    end
    _emit_result(fv; title="RI Forecast Error Variance Decomposition (H=$horizons)",
                 key="ri_fevd", format=format, output=output)
    _maybe_plot(fv; plot=plot, plot_save=plot_save)
    return fv
end

function _ri_simulate(; config::String="", model=nothing,
                      periods::Int=200, burn::Int=100, seed::Int=0,
                      save_data::String="",
                      output::String="", format::String="table")
    periods >= 1 || throw(CliError("usage/invalid",
        "ri simulate: --periods must be ≥ 1 (got $periods)"))
    burn >= 0 || throw(CliError("usage/invalid",
        "ri simulate: --burn must be ≥ 0 (got $burn)"))
    seed >= 0 || throw(CliError("usage/invalid",
        "ri simulate: --seed must be ≥ 0 (got $seed)"))

    sol = _ri_resolve_solution(model, config; context="ri simulate")
    eff_seed = seed > 0 ? seed : (_SEED[] === nothing ? 0 : Int(_SEED[]))
    _status("Simulating RI system: periods=$periods, burn=$burn, seed=$eff_seed")
    _status()
    sim = try
        simulate(sol, periods; burn=burn, seed=eff_seed)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "ri simulate"))
    end

    prob = sol.problem
    n = size(prob.A, 1)
    d = size(prob.H, 2)
    r_s = sol.signal_rank
    df = DataFrame(time = collect(1:periods))
    vnames = String[]
    mats = Matrix{Float64}[]
    used = Set{String}(["time"])
    function _add_block!(M::AbstractMatrix, names_vec::Vector{String})
        isempty(names_vec) && return
        M64 = Matrix{Float64}(M)
        push!(mats, M64)
        for (j, raw_nm) in enumerate(names_vec)
            nm = raw_nm
            while nm in used
                nm = nm * "_col"
            end
            push!(used, nm)
            push!(vnames, nm)
            df[!, Symbol(nm)] = M64[:, j]
        end
    end
    _add_block!(sim.states, copy(prob.state_names))
    _add_block!(sim.beliefs, [nm * "_hat" for nm in prob.state_names])
    if r_s > 0
        _add_block!(sim.signals, ["signal_$j" for j in 1:r_s])
    end
    _add_block!(sim.actions, copy(prob.action_names))

    output_result(df; format=Symbol(format), output=output,
                  title="RI Simulated Data (T=$periods)", key="ri_simulated_data")
    output_kv(Pair{String,Any}[
        "periods"     => periods,
        "burn"        => burn,
        "seed"        => eff_seed,
        "n_state"     => n,
        "n_action"    => d,
        "signal_rank" => r_s,
    ]; format=format, output=_per_var_output_path(output, "settings"),
       title="RI Simulation Settings", key="ri_simulation_settings")

    if !isempty(save_data)
        full_mat = hcat(mats...)
        tsd = TimeSeriesData(full_mat; varnames=vnames, tcode=fill(1, length(vnames)),
                             time_index=collect(1:periods))
        sp = resolve_save_path(save_data)
        save_model_dispatch(sp, tsd; artifact_kind="data")
        return tsd
    end
    return nothing
end

function _ri_parse_estimate_obs(obs::String)
    s = strip(obs)
    isempty(s) && return nothing
    s == "actions" && return :actions
    s == "all" && return :all
    (s == "states" || s == "actions-and-states") && return :actions_and_states
    toks = String[String(strip(t)) for t in split(s, ",") if !isempty(strip(t))]
    isempty(toks) && return nothing
    ints = [tryparse(Int, t) for t in toks]
    if all(!isnothing, ints)
        vals = Int[x::Int for x in ints]
        all(>=(1), vals) || throw(CliError("usage/invalid",
            "ri estimate: --observables indices must be ≥ 1 (got '$obs')"))
        return vals
    end
    return toks
end

function _ri_parse_meas_err(me::String)
    s = strip(me)
    isempty(s) && return nothing
    toks = [strip(t) for t in split(s, ",") if !isempty(strip(t))]
    vals = Float64[]
    for t in toks
        v = tryparse(Float64, t)
        (v === nothing || !isfinite(v) || v < 0.0) && throw(CliError("usage/invalid",
            "ri estimate: --measurement-error values must be finite and ≥ 0 (got '$t')"))
        push!(vals, v)
    end
    isempty(vals) && return nothing
    return length(vals) == 1 ? vals[1] : vals
end

function _ri_estimate(; data::String="", config::String="", model=nothing,
                      method::String="mle", estimate_param::String="capacity",
                      cov_type::String="hessian", observables::String="",
                      init_param::Float64=NaN, measurement_error::String="",
                      draws::Int=1000, burnin::Int=250, step_scale::Float64=0.1,
                      output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="")
    isempty(strip(data)) && throw(CliError("usage/missing",
        "ri estimate: <data> path is required"))
    method in ("mle", "bayes") || throw(CliError("usage/invalid-option",
        "ri estimate: invalid --method '$method'; must be mle or bayes"))
    estimate_param in ("capacity", "omega") || throw(CliError("usage/invalid-option",
        "ri estimate: invalid --estimate-param '$estimate_param'; must be capacity or omega"))
    cov_type in ("hessian", "sandwich") || throw(CliError("usage/invalid-option",
        "ri estimate: invalid --cov-type '$cov_type'; must be hessian or sandwich"))
    draws >= 1 || throw(CliError("usage/invalid",
        "ri estimate: --draws must be ≥ 1 (got $draws)"))
    burnin >= 0 || throw(CliError("usage/invalid",
        "ri estimate: --burnin must be ≥ 0 (got $burnin)"))
    (isfinite(step_scale) && step_scale > 0.0) || throw(CliError("usage/invalid",
        "ri estimate: --step-scale must be finite and > 0 (got $step_scale)"))
    if !isnan(init_param)
        (isfinite(init_param) && init_param > 0.0) || throw(CliError("usage/invalid",
            "ri estimate: --init-param must be finite and > 0 (got $init_param)"))
    end

    ep_sym = Symbol(estimate_param)
    prob = if model !== nothing
        if model isa SimsKalmanSolution
            model.problem
        elseif model isa RationalInattentionProblem
            model
        else
            throw(CliError("model/wrong-kind",
                "ri estimate: unsupported --model handle $(typeof(model))"))
        end
    else
        p, _ = _ri_build_problem_from_config(config; require_constraint=false,
                                             default_param=ep_sym, context="ri estimate")
        p
    end

    Y, vnames = load_multivariate_data(data)
    obs_arg = _ri_parse_estimate_obs(observables)
    me_arg = _ri_parse_meas_err(measurement_error)
    init_arg = isnan(init_param) ? nothing : init_param

    _status("Estimating RI $(estimate_param) ($method): T=$(size(Y, 1)), series=$(join(vnames, ", "))")
    _status()
    res = try
        estimate_ri(prob, Y;
            method=Symbol(method), estimate_param=ep_sym,
            observables=obs_arg, cov_type=Symbol(cov_type),
            init_param=init_arg, measurement_error=me_arg,
            n_draws=draws, burnin=burnin, step_scale=step_scale,
            _fwd_seed()...)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "ri estimate"))
    end
    _emit_result(res; title="Rational Inattention Estimation ($method)",
                 key="ri_estimation", format=format, output=output)
    output_kv(_ri_estimation_summary(res); format=format,
              output=_per_var_output_path(output, "summary"),
              title="RI Estimation Summary", key="ri_estimation_summary")
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    return res
end

function _ri_extract_cg_col(df::DataFrame, spec::String, default_idx::Int, role::String)
    cols = names(df)
    num_cols = [c for c in cols if eltype(df[!, c]) <: Union{Missing,Real}]
    target_col = if isempty(strip(spec))
        default_idx <= length(num_cols) || throw(CliError("data/shape",
            "ri cg-test: need at least $default_idx numeric columns for --$role (found $(length(num_cols)))"))
        num_cols[default_idx]
    else
        s = strip(spec)
        if s in cols
            s
        else
            idx = tryparse(Int, s)
            if idx !== nothing
                (1 <= idx <= length(cols)) || throw(CliError("data/missing-column",
                    "ri cg-test: --$role column index $idx out of range 1:$(length(cols))"))
                cols[idx]
            else
                throw(CliError("data/missing-column",
                    "ri cg-test: --$role column '$s' not found (available: $(join(cols, ", ")))"))
            end
        end
    end
    raw = df[!, target_col]
    vec_out = Vector{Float64}(undef, length(raw))
    for i in eachindex(raw)
        v = raw[i]
        if ismissing(v)
            vec_out[i] = NaN
        elseif v isa Real
            vec_out[i] = Float64(v)
        else
            throw(CliError("data/invalid",
                "ri cg-test: --$role column '$target_col' contains non-numeric entry '$(v)' at row $i"))
        end
    end
    return vec_out, target_col
end

function _ri_cg_test(; data::String="", realized::String="",
                     forecast_now::String="", forecast_lag::String="",
                     hac_lags::String="auto", horizon::Int=1, model=nothing,
                     output::String="", format::String="table",
                     plot::Bool=false, plot_save::String="")
    isempty(strip(data)) && throw(CliError("usage/missing",
        "ri cg-test: <data> path is required"))
    horizon >= 1 || throw(CliError("usage/invalid",
        "ri cg-test: --horizon must be ≥ 1 (got $horizon)"))
    hl = if strip(hac_lags) == "auto"
        :auto
    else
        v = tryparse(Int, strip(hac_lags))
        (v === nothing || v < 0) && throw(CliError("usage/invalid",
            "ri cg-test: --hac-lags must be 'auto' or a non-negative integer (got '$hac_lags')"))
        v
    end

    df = load_data(data)
    y_vec, c1 = _ri_extract_cg_col(df, realized, 1, "realized")
    fn_vec, c2 = _ri_extract_cg_col(df, forecast_now, 2, "forecast-now")
    fl_vec, c3 = _ri_extract_cg_col(df, forecast_lag, 3, "forecast-lag")

    _status("Coibion-Gorodnichenko test: realized=$c1, forecast_now=$c2, forecast_lag=$c3, hac_lags=$hl")
    _status()
    res = try
        coibion_gorodnichenko_test(y_vec, fn_vec, fl_vec; hac_lags=hl)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "ri cg-test"))
    end
    _emit_result(res; title="Coibion-Gorodnichenko (2015) Information-Rigidity Test",
                 key="cg_test", format=format, output=output)
    output_kv(_ri_cg_summary(res; model=model, horizon=horizon); format=format,
              output=_per_var_output_path(output, "summary"),
              title="CG Test Summary", key="cg_summary")
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    return res
end

function _ri_mw(; config::String="", capacity::Float64=NaN, omega::Float64=NaN,
                strategic_complementarity::Float64=NaN,
                horizons::Int=40, tol::Float64=1e-8, max_iter::Int=200,
                output::String="", format::String="table",
                plot::Bool=false, plot_save::String="")
    isempty(strip(config)) && throw(CliError("usage/missing",
        "ri mw: --config <toml> with a [ri.mw] section is required"))
    horizons >= 1 || throw(CliError("usage/invalid",
        "ri mw: --horizons must be ≥ 1 (got $horizons)"))
    (isfinite(tol) && tol > 0.0) || throw(CliError("usage/invalid",
        "ri mw: --tol must be finite and > 0 (got $tol)"))
    max_iter >= 1 || throw(CliError("usage/invalid",
        "ri mw: --max-iter must be ≥ 1 (got $max_iter)"))

    cfg = get_ri_mw(load_config(config))
    cap, om = _ri_resolve_cap_omega(cfg.capacity, cfg.omega, capacity, omega;
                                    require_one=true, context="ri mw")
    r_sc = if !isnan(strategic_complementarity)
        (isfinite(strategic_complementarity) && 0.0 <= strategic_complementarity < 1.0) ||
            throw(CliError("usage/invalid",
                "ri mw: --strategic-complementarity must lie in [0, 1) (got $strategic_complementarity)"))
        strategic_complementarity
    elseif cfg.strategic_complementarity !== nothing
        cfg.strategic_complementarity
    else
        0.85
    end
    h_eff = horizons

    _status("Solving Maćkowiak-Wiederholt multi-block RI (r=$r_sc, H=$h_eff)")
    _status()
    res = try
        solve_mw_attention(cfg.agg_block, cfg.idio_block;
            capacity=cap, omega=om, strategic_complementarity=r_sc,
            horizon=h_eff, tol=tol, maxiter=max_iter)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "ri mw"))
    end
    _emit_result(res; title="Maćkowiak-Wiederholt (2009) Attention Allocation",
                 key="ri_mw_attention", format=format, output=output)
    output_kv(_ri_mw_summary(res); format=format,
              output=_per_var_output_path(output, "summary"),
              title="MW Attention Summary", key="ri_mw_summary")
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    return res
end

function _ri_discrete(; config::String="", omega::Float64=NaN, capacity::Float64=NaN,
                      units::String="", tol::Float64=1e-12, max_iter::Int=5000,
                      output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="")
    isempty(strip(config)) && throw(CliError("usage/missing",
        "ri discrete: --config <toml> with a [ri.discrete] section is required"))
    (isfinite(tol) && tol > 0.0) || throw(CliError("usage/invalid",
        "ri discrete: --tol must be finite and > 0 (got $tol)"))
    max_iter >= 1 || throw(CliError("usage/invalid",
        "ri discrete: --max-iter must be ≥ 1 (got $max_iter)"))

    cfg = get_ri_discrete(load_config(config))
    cap, om = _ri_resolve_cap_omega(cfg.capacity, cfg.omega, capacity, omega;
                                    require_one=true, context="ri discrete")
    u_sym = _ri_resolve_units(cfg.units, units; context="ri discrete")

    _status("Solving discrete-choice RI: J=$(cfg.J) alternatives, S=$(cfg.S) states")
    _status()
    sol = try
        solve_ri_discrete(cfg.U, cfg.mu; omega=om, capacity=cap, units=u_sym,
                          tol=tol, max_iter=max_iter)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "ri discrete"))
    end
    _emit_result(sol; title="Matějka-McKay Discrete-Choice RI Solution",
                 key="ri_discrete_choice", format=format, output=output)
    output_kv(_ri_discrete_summary(sol); format=format,
              output=_per_var_output_path(output, "summary"),
              title="Discrete RI Summary", key="ri_discrete_summary")
    _maybe_plot(sol; plot=plot, plot_save=plot_save)
    return sol
end

function _ri_iia_test(; config::String="", omega::Float64=NaN, capacity::Float64=NaN,
                      units::String="", tol::Float64=1e-12,
                      output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="")
    isempty(strip(config)) && throw(CliError("usage/missing",
        "ri iia-test: --config <toml> with [ri.discrete] U, mu, and new_option_payoffs is required"))
    (isfinite(tol) && tol > 0.0) || throw(CliError("usage/invalid",
        "ri iia-test: --tol must be finite and > 0 (got $tol)"))

    cfg = get_ri_discrete(load_config(config))
    cfg.new_option_payoffs !== nothing || throw(CliError("config/missing-key",
        "[ri.discrete] must define new_option_payoffs = [...] (length S=$(cfg.S)) for ri iia-test"))
    cap, om = _ri_resolve_cap_omega(cfg.capacity, cfg.omega, capacity, omega;
                                    require_one=true, context="ri iia-test")
    u_sym = _ri_resolve_units(cfg.units, units; context="ri iia-test")

    _status("Testing RI IIA breakdown: base J=$(cfg.J), S=$(cfg.S)")
    _status()
    diag = try
        ri_iia_diagnostic(cfg.U, cfg.mu, cfg.new_option_payoffs;
                          omega=om, capacity=cap, units=u_sym, tol=tol)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "ri iia-test"))
    end
    _emit_result(diag; title="RI IIA Breakdown Diagnostic",
                 key="ri_iia_diagnostic", format=format, output=output)
    output_kv(_ri_iia_summary(diag); format=format,
              output=_per_var_output_path(output, "summary"),
              title="RI IIA Summary", key="ri_iia_summary")
    _maybe_plot(diag; plot=plot, plot_save=plot_save)
    return diag
end

# ── Registry for `ri` node (11 leaves) ───────────────────────────────────────

function ri_specs()::Vector{CommandSpec}
    plot_opts = [OUTPUT_OPTIONS; PLOT_OPTIONS]
    plot_flags = copy(PLOT_FLAGS)
    obs_opt(default_val::String) = OptionSpec(
        name="observables", type=String, default=default_val,
        choices=["all", "actions", "actions-and-states", "states"],
        description="Observable block: all | actions | actions-and-states | states",
    )

    return CommandSpec[
        CommandSpec(
            path=["ri", "solve"],
            summary="Solve Sims (2003) steady-state LQG Rational Inattention Kalman filter",
            args=ArgSpec[],
            options=[
                OptionSpec(name="config", type=String, default="",
                           description="TOML with [ri] A, B, H (plus optional M, B_u, beta, capacity/omega, units)"),
                OptionSpec(name="method", short="m", type=String, default="water-filling",
                           choices=["water-filling", "logdet-barrier"],
                           description="Solver method: water-filling | logdet-barrier"),
                OptionSpec(name="capacity", type=Float64, default=NaN,
                           description="Override Shannon capacity kappa > 0 (mutually exclusive with --omega)"),
                OptionSpec(name="omega", type=Float64, default=NaN,
                           description="Override marginal info shadow cost omega > 0 per nat (mutually exclusive with --capacity)"),
                OptionSpec(name="units", type=String, default="",
                           description="Override information units: bits | nats (from config, else bits)"),
                OptionSpec(name="tol", type=Float64, default=1e-11,
                           description="Solver convergence tolerance (> 0)"),
                OptionSpec(name="max-iter", type=Int, default=2000,
                           description="Maximum outer fixed-point iterations (≥ 1)"),
                plot_opts...,
            ],
            flags=[
                FlagSpec(name="problem-only",
                         description="Construct and emit RationalInattentionProblem without solving"),
                plot_flags...,
            ],
            tables=[
                TableSpec(name=:ri_kalman_solution,
                          description="Sims steady-state RI Kalman gains, shadow cost, capacity, signal rank and expected loss"),
                TableSpec(name=:ri_problem,
                          description="Rational Inattention problem specification (only with --problem-only)"),
                TableSpec(name=:ri_summary,
                          description="Solver method, convergence, iterations, shadow cost, capacity (bits/nats) and expected loss"),
            ],
            category="ri",
            result_types=[:SimsKalmanSolution, :RationalInattentionProblem],
            handler=_ri_solve,
        ),
        CommandSpec(
            path=["ri", "transition"],
            summary="Solve Afrouzi-Yang (2021) dynamic LQG Rational Inattention transition path",
            args=ArgSpec[],
            options=[
                OptionSpec(name="config", type=String, default="",
                           description="TOML with [ri] problem and/or Sigma_init, omega_path, capacity_path"),
                MODEL_OPTION,
                OptionSpec(name="t-path", type=Int, default=100,
                           description="Transition horizon T_path (≥ 1)"),
                OptionSpec(name="damping", type=Float64, default=0.7,
                           description="Forward-backward shooting damping weight in (0, 1]"),
                OptionSpec(name="tol", type=Float64, default=1e-10,
                           description="Shooting convergence tolerance (> 0)"),
                OptionSpec(name="max-iter", type=Int, default=500,
                           description="Maximum shooting iterations (≥ 1)"),
                OptionSpec(name="capacity", type=Float64, default=NaN,
                           description="Override constant per-period capacity ≥ 0 along transition path"),
                OptionSpec(name="omega", type=Float64, default=NaN,
                           description="Override constant shadow cost omega > 0 along transition path"),
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[
                TableSpec(name=:ri_transition_path,
                          description="Dynamic RI transition path of shadow cost, capacity (bits/nats), signal rank and convergence by period"),
                TableSpec(name=:ri_transition_summary,
                          description="Transition horizon, convergence, iterations, residual and initial/terminal information flow"),
            ],
            category="ri",
            model_types=[:SimsKalmanSolution, :RationalInattentionProblem],
            result_types=[:DynamicRISolution],
            handler=_ri_transition,
        ),
        CommandSpec(
            path=["ri", "statespace"],
            summary="Convert a SimsKalmanSolution into joint StateSpaceModel, ABCDSystem, or SteadyStateKalman",
            args=ArgSpec[],
            options=[
                OptionSpec(name="config", type=String, default="",
                           description="TOML with [ri] problem (solved first when --model is omitted)"),
                MODEL_OPTION,
                obs_opt("all"),
                OptionSpec(name="as", type=String, default="statespace",
                           choices=["statespace", "abcd", "steady-kalman"],
                           description="Output representation: statespace | abcd | steady-kalman"),
                OptionSpec(name="init-mode", type=String, default="",
                           description="Kalman initialization mode for --as statespace: stationary | kappa | diffuse"),
                OptionSpec(name="kappa", type=Float64, default=1e6,
                           description="Diffuse variance scale for init-mode=kappa|diffuse"),
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[
                TableSpec(name=:ri_statespace_system,
                          description="Joint (x_t, x_hat_t) state-space matrix dimensions (--as statespace)"),
                TableSpec(name=:ri_abcd_system,
                          description="Canonical ABCD representation eigenvalues and dimensions (--as abcd)"),
                TableSpec(name=:ri_steady_kalman,
                          description="Steady-state Kalman filter closed-loop eigenvalues and diagonal gain (--as steady-kalman)"),
                TableSpec(name=:ri_statespace_summary,
                          description="Representation kind, observables block and state/obs/shock dimensions"),
            ],
            category="ri",
            model_types=[:SimsKalmanSolution, :RationalInattentionProblem],
            result_types=[:StateSpaceModel, :ABCDSystem, :SteadyStateKalman],
            handler=_ri_statespace,
        ),
        CommandSpec(
            path=["ri", "irf"],
            summary="Analytical inertial impulse response functions for a SimsKalmanSolution",
            args=ArgSpec[],
            options=[
                OptionSpec(name="config", type=String, default="",
                           description="TOML with [ri] problem (solved first when --model is omitted)"),
                MODEL_OPTION,
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizons, type=Int, default=20,
                           description="Impulse response horizon H (≥ 1)"),
                obs_opt("all"),
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[
                TableSpec(name=:ri_irf,
                          description="Analytical impulse responses to fundamental shocks and endogenous RI processing noise"),
            ],
            category="ri",
            model_types=[:SimsKalmanSolution, :RationalInattentionProblem],
            result_types=[:ImpulseResponse],
            handler=_ri_irf,
        ),
        CommandSpec(
            path=["ri", "fevd"],
            summary="Analytical FEVD decomposing fundamental vs endogenous RI processing-noise variance shares",
            args=ArgSpec[],
            options=[
                OptionSpec(name="config", type=String, default="",
                           description="TOML with [ri] problem (solved first when --model is omitted)"),
                MODEL_OPTION,
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizons, type=Int, default=20,
                           description="Variance decomposition horizon H (≥ 1)"),
                obs_opt("actions"),
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[
                TableSpec(name=:ri_fevd,
                          description="Forecast error variance shares attributable to fundamental vs RI noise shocks"),
            ],
            category="ri",
            model_types=[:SimsKalmanSolution, :RationalInattentionProblem],
            result_types=[:FEVD],
            handler=_ri_fevd,
        ),
        CommandSpec(
            path=["ri", "simulate"],
            summary="Simulate true states, posterior beliefs, endogenous signals and actions from a SimsKalmanSolution",
            args=ArgSpec[],
            options=[
                OptionSpec(name="config", type=String, default="",
                           description="TOML with [ri] problem (solved first when --model is omitted)"),
                MODEL_OPTION,
                OptionSpec(name="periods", type=Int, default=200,
                           description="Post-burn-in simulation periods (≥ 1)"),
                OptionSpec(name="burn", type=Int, default=100,
                           description="Burn-in periods discarded before recording (≥ 0)"),
                OptionSpec(name="seed", type=Int, default=0,
                           description="RNG seed (0 defers to global --seed, else Xoshiro(0))"),
                OptionSpec(name="save-data", type=String, default="",
                           description="Save simulated series as a TimeSeriesData handle (.jld2 or .jls)"),
                OUTPUT_OPTIONS...,
            ],
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:ri_simulated_data,
                          description="Simulated paths of states, posterior beliefs, endogenous signals and actions"),
                TableSpec(name=:ri_simulation_settings,
                          description="Simulation length, burn-in, effective seed and dimensions"),
            ],
            category="ri",
            model_types=[:SimsKalmanSolution, :RationalInattentionProblem],
            handler=_ri_simulate,
        ),
        CommandSpec(
            path=["ri", "estimate"],
            summary="Estimate RI capacity or shadow cost from observed series via Kalman MLE or Bayesian RWMH",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing,
                          description="Path to observed data CSV or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="config", type=String, default="",
                           description="TOML with [ri] structural matrices A, B, H (plus optional M, B_u, beta, units)"),
                MODEL_OPTION,
                OptionSpec(name="method", short="m", type=String, default="mle",
                           choices=["mle", "bayes"],
                           description="Estimation method: mle | bayes"),
                OptionSpec(name="estimate-param", type=String, default="capacity",
                           choices=["capacity", "omega"],
                           description="Primary RI parameter to estimate: capacity | omega"),
                OptionSpec(name="cov-type", type=String, default="hessian",
                           choices=["hessian", "sandwich"],
                           description="MLE covariance estimator: hessian | sandwich"),
                OptionSpec(name="observables", type=String, default="",
                           description="Observable subset (actions|all|states|actions-and-states) or comma-separated indices/names"),
                OptionSpec(name="init-param", type=Float64, default=NaN,
                           description="Optional positive initial guess for capacity or omega"),
                OptionSpec(name="measurement-error", type=String, default="",
                           description="Optional measurement-error std dev (scalar or comma-separated per observable)"),
                OptionSpec(name="draws", type=Int, default=1000,
                           description="Retained posterior draws for --method bayes (≥ 1)"),
                OptionSpec(name="burnin", type=Int, default=250,
                           description="Adaptive burn-in draws for --method bayes (≥ 0)"),
                OptionSpec(name="step-scale", type=Float64, default=0.1,
                           description="Initial RWMH proposal step scale for --method bayes (> 0)"),
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[
                TableSpec(name=:ri_estimation,
                          description="Estimated RI capacity or shadow cost with standard errors, z-stats and confidence intervals"),
                TableSpec(name=:ri_estimation_summary,
                          description="Estimation method, capacity/omega, log-likelihood, full-info LR test, AIC/BIC and convergence"),
            ],
            category="ri",
            data_kinds=[:timeseries, :csv],
            model_types=[:RationalInattentionProblem, :SimsKalmanSolution],
            result_types=[:RIEstimationResult],
            allow_data_with_model=true,
            handler=_ri_estimate,
        ),
        CommandSpec(
            path=["ri", "cg-test"],
            summary="Coibion-Gorodnichenko (2015) information-rigidity regression test (with optional model slope comparison)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing,
                          description="Path to forecast/realization CSV or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="realized", type=String, default="",
                           description="Column name or 1-based index for realized outcome y_{t+h} (default: 1st numeric col)"),
                OptionSpec(name="forecast-now", type=String, default="",
                           description="Column name or 1-based index for current forecast F_t y_{t+h} (default: 2nd numeric col)"),
                OptionSpec(name="forecast-lag", type=String, default="",
                           description="Column name or 1-based index for lagged forecast F_{t-1} y_{t+h} (default: 3rd numeric col)"),
                OptionSpec(name="hac-lags", type=String, default="auto",
                           description="Newey-West Bartlett lag truncation: auto or non-negative integer"),
                OptionSpec(name="horizon", aliases=["horizons"], kwarg=:horizon, type=Int, default=1,
                           description="Forecast horizon h ≥ 1 for --model implied CG slope comparison"),
                MODEL_OPTION,
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[
                TableSpec(name=:cg_test,
                          description="Coibion-Gorodnichenko regression estimates (alpha, beta_cg), HAC SEs, t-stats, p-values and implied gain/capacity"),
                TableSpec(name=:cg_summary,
                          description="Sample size, HAC bandwidth, implied Kalman gain/capacity and optional model-implied CG slope comparison"),
            ],
            category="ri",
            data_kinds=[:timeseries, :cross_section, :csv],
            model_types=[:SimsKalmanSolution],
            result_types=[:CGTestResult],
            allow_data_with_model=true,
            handler=_ri_cg_test,
        ),
        CommandSpec(
            path=["ri", "mw"],
            summary="Solve Maćkowiak-Wiederholt (2009) multi-block attention allocation and GE price fixed point",
            args=ArgSpec[],
            options=[
                OptionSpec(name="config", type=String, default="",
                           description="TOML with [ri.mw] agg_block and idio_block (plus optional capacity/omega, strategic_complementarity)"),
                OptionSpec(name="capacity", type=Float64, default=NaN,
                           description="Override total Shannon capacity kappa > 0 (mutually exclusive with --omega)"),
                OptionSpec(name="omega", type=Float64, default=NaN,
                           description="Override common marginal cost omega > 0 (mutually exclusive with --capacity)"),
                OptionSpec(name="strategic-complementarity", type=Float64, default=NaN,
                           description="Override strategic complementarity r in [0, 1) (from config, else 0.85)"),
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizons, type=Int, default=40,
                           description="Price and real-output impulse response horizon H (≥ 1)"),
                OptionSpec(name="tol", type=Float64, default=1e-8,
                           description="Fixed-point convergence tolerance (> 0)"),
                OptionSpec(name="max-iter", aliases=["maxiter"], kwarg=:max_iter, type=Int, default=200,
                           description="Maximum general-equilibrium fixed-point iterations (≥ 1)"),
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[
                TableSpec(name=:ri_mw_attention,
                          description="Aggregate/idiosyncratic price and real output IRFs alongside equilibrium attention allocation"),
                TableSpec(name=:ri_mw_summary,
                          description="Equilibrium kappa_agg, kappa_idio, total_kappa, omega, strategic complementarity and convergence"),
            ],
            category="ri",
            result_types=[:MWAttentionResult],
            handler=_ri_mw,
        ),
        CommandSpec(
            path=["ri", "discrete"],
            summary="Solve Matějka-McKay (2015) / Caplin-Dean-Leahy (2019) discrete-choice RI problem",
            args=ArgSpec[],
            options=[
                OptionSpec(name="config", type=String, default="",
                           description="TOML with [ri.discrete] payoff matrix U and prior mu (plus optional omega/capacity, units)"),
                OptionSpec(name="omega", type=Float64, default=NaN,
                           description="Override marginal information cost omega > 0 per nat (mutually exclusive with --capacity)"),
                OptionSpec(name="capacity", type=Float64, default=NaN,
                           description="Override Shannon capacity kappa > 0 (mutually exclusive with --omega)"),
                OptionSpec(name="units", type=String, default="",
                           description="Override information units: bits | nats (from config, else bits)"),
                OptionSpec(name="tol", type=Float64, default=1e-12,
                           description="Solver convergence tolerance (> 0)"),
                OptionSpec(name="max-iter", type=Int, default=5000,
                           description="Maximum Blahut-Arimoto / active-set Newton iterations (≥ 1)"),
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[
                TableSpec(name=:ri_discrete_choice,
                          description="Optimal conditional and unconditional choice probabilities and payoffs by state and alternative"),
                TableSpec(name=:ri_discrete_summary,
                          description="Shadow cost omega, consideration set, mutual info (bits/nats), expected utility and net welfare"),
            ],
            category="ri",
            result_types=[:RIDiscreteChoiceSolution],
            handler=_ri_discrete,
        ),
        CommandSpec(
            path=["ri", "iia-test"],
            summary="Diagnose IIA breakdown under discrete-choice RI when adding a new alternative",
            args=ArgSpec[],
            options=[
                OptionSpec(name="config", type=String, default="",
                           description="TOML with [ri.discrete] U, mu, and new_option_payoffs (plus optional omega/capacity, units)"),
                OptionSpec(name="omega", type=Float64, default=NaN,
                           description="Override marginal information cost omega > 0 per nat (mutually exclusive with --capacity)"),
                OptionSpec(name="capacity", type=Float64, default=NaN,
                           description="Override Shannon capacity kappa > 0 (mutually exclusive with --omega)"),
                OptionSpec(name="units", type=String, default="",
                           description="Override information units: bits | nats (from config, else bits)"),
                OptionSpec(name="tol", type=Float64, default=1e-12,
                           description="Solver convergence tolerance (> 0)"),
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[
                TableSpec(name=:ri_iia_diagnostic,
                          description="IIA violation diagnostic: max odds-ratio shifts and base vs expanded mutual information"),
                TableSpec(name=:ri_iia_summary,
                          description="Base vs expanded consideration sets and unconditional/conditional odds-ratio shifts"),
            ],
            category="ri",
            result_types=[:RIIIADiagnostic],
            handler=_ri_iia_test,
        ),
    ]
end

const _RI_SAVE_MODEL_PATHS = Set([
    ["ri", "solve"],
    ["ri", "transition"],
    ["ri", "statespace"],
    ["ri", "estimate"],
    ["ri", "mw"],
    ["ri", "discrete"],
])

function register_ri_commands!()
    specs = CommandSpec[]
    for s in ri_specs()
        key = isempty(s.tables) ? "" : string(s.tables[1].name)
        h = if isempty(s.result_types)
            wrap_legacy(s.handler)
        else
            wrap_legacy(_with_result(s.handler, join(s.path, " "); key=key,
                                     render_fn=_rerender_ri_result))
        end
        s2 = _copy_spec(s; handler=h)
        s2 = s2.path in _RI_SAVE_MODEL_PATHS ? with_save_model([s2])[1] : s2
        push!(specs, s2)
    end
    specs = with_result_handles(with_config_ergonomics(with_default_csv_kinds(specs)))
    specs = register!(specs)
    return build_node("ri", specs;
        description="Rational Inattention (Sims LQG Kalman, Afrouzi-Yang transition, estimation, CG test, Maćkowiak-Wiederholt, Matějka-McKay discrete choice)")
end

# ── Choice family: Rational Inattention Logit (`estimate/predict choice ri-logit`) ──

function _load_ri_logit_data(data::String; env_col::String="env", choice_col::String="choice",
                             alt_col::String="alt", state_col::String="state",
                             obs_col::String="", attr_cols::String="",
                             unobserved_state::Bool=false)
    df = load_data(data)
    cols = names(df)
    for (flag, col) in (("--env-col", env_col), ("--choice-col", choice_col),
                        ("--alt-col", alt_col), ("--state-col", state_col))
        isempty(strip(col)) && throw(CliError("usage/missing", "ri-logit: $flag cannot be empty"))
        col in cols || throw(CliError("data/missing-column",
            "ri-logit: $flag column '$col' not found in $data (available: $(join(cols, ", ")))"))
    end
    if !isempty(strip(obs_col))
        obs_col in cols || throw(CliError("data/missing-column",
            "ri-logit: --obs-col column '$obs_col' not found in $data (available: $(join(cols, ", ")))"))
    end

    structural_cols = Set{String}([env_col, choice_col, alt_col, state_col])
    !isempty(strip(obs_col)) && push!(structural_cols, obs_col)

    acols = if isempty(strip(attr_cols))
        String[c for c in cols if !(c in structural_cols) && eltype(df[!, c]) <: Union{Missing,Real}]
    else
        req = String[String(strip(s)) for s in split(attr_cols, ",") if !isempty(strip(s))]
        for c in req
            c in cols || throw(CliError("data/missing-column",
                "ri-logit: --attr-cols column '$c' not found in $data (available: $(join(cols, ", ")))"))
        end
        req
    end

    nrows = nrow(df)
    nrows >= 2 || throw(CliError("data/shape", "ri-logit: dataset must have at least 2 rows (got $nrows)"))

    envs_raw = collect(df[!, env_col])
    alts_raw = collect(df[!, alt_col])
    states_raw = collect(df[!, state_col])
    choices_raw = collect(df[!, choice_col])
    (any(ismissing, envs_raw) || any(ismissing, alts_raw) ||
     any(ismissing, states_raw) || any(ismissing, choices_raw)) &&
        throw(CliError("data/missing-value",
            "ri-logit: env/alt/state/choice columns must not contain missing values"))

    uniq_envs = sort!(unique(envs_raw))
    uniq_alts = sort!(unique(alts_raw))
    uniq_states = sort!(unique(states_raw))
    M = length(uniq_envs)
    J = length(uniq_alts)
    S = length(uniq_states)
    J >= 2 || throw(CliError("data/shape", "ri-logit: need at least 2 alternatives (got J=$J)"))
    S >= 1 || throw(CliError("data/shape", "ri-logit: need at least 1 state (got S=$S)"))

    env_map = Dict(v => i for (i, v) in enumerate(uniq_envs))
    alt_map = Dict(v => i for (i, v) in enumerate(uniq_alts))
    state_map = Dict(v => i for (i, v) in enumerate(uniq_states))

    K = length(acols)
    menu_attrs = zeros(Float64, J, S, K, M)
    seen = falses(J, S, M)
    for r in 1:nrows
        m = env_map[envs_raw[r]]
        j = alt_map[alts_raw[r]]
        s = state_map[states_raw[r]]
        if !seen[j, s, m]
            for (k, c) in enumerate(acols)
                val = df[r, c]
                (ismissing(val) || !(val isa Real) || !isfinite(Float64(val))) &&
                    throw(CliError("data/invalid",
                        "ri-logit: attribute column '$c' has missing/non-finite value at row $r"))
                menu_attrs[j, s, k, m] = Float64(val)
            end
            seen[j, s, m] = true
        end
    end

    # Extract per-observation (choices, env_id, state_id)
    choices_vec = Int[]
    env_vec = Int[]
    state_vec = Int[]

    if !isempty(strip(obs_col))
        obs_raw = collect(df[!, obs_col])
        any(ismissing, obs_raw) && throw(CliError("data/missing-value",
            "ri-logit: --obs-col column '$obs_col' contains missing values"))
        # Preserve first-appearance order of observations
        obs_order = Any[]
        obs_rows = Dict{Any,Vector{Int}}()
        for r in 1:nrows
            oid = obs_raw[r]
            if !haskey(obs_rows, oid)
                push!(obs_order, oid)
                obs_rows[oid] = Int[]
            end
            push!(obs_rows[oid], r)
        end
        is_binary = all(v -> v isa Real && (v == 0 || v == 1), choices_raw) &&
                    any(v -> v == 0, choices_raw)
        for oid in obs_order
            rs = obs_rows[oid]
            if is_binary
                chosen_rs = [r for r in rs if choices_raw[r] == 1]
                length(chosen_rs) == 1 || throw(CliError("data/invalid",
                    "ri-logit: observation '$oid' has $(length(chosen_rs)) chosen rows (expected exactly 1)"))
                cr = chosen_rs[1]
                push!(choices_vec, alt_map[alts_raw[cr]])
                push!(env_vec, env_map[envs_raw[cr]])
                push!(state_vec, state_map[states_raw[cr]])
            else
                r0 = rs[1]
                cval = choices_raw[r0]
                haskey(alt_map, cval) || throw(CliError("data/invalid",
                    "ri-logit: choice value '$(cval)' for observation '$oid' not in alternatives $(uniq_alts)"))
                push!(choices_vec, alt_map[cval])
                push!(env_vec, env_map[envs_raw[r0]])
                push!(state_vec, state_map[states_raw[r0]])
            end
        end
    else
        is_binary = all(v -> v isa Real && (v == 0 || v == 1), choices_raw) &&
                    any(v -> v == 0, choices_raw)
        if is_binary
            for r in 1:nrows
                choices_raw[r] == 1 || continue
                push!(choices_vec, alt_map[alts_raw[r]])
                push!(env_vec, env_map[envs_raw[r]])
                push!(state_vec, state_map[states_raw[r]])
            end
        else
            # Non-binary choice column holds chosen alt ID; detect J-row blocks vs 1-row-per-obs
            block_layout = (nrows % J == 0) && all(0:(div(nrows, J) - 1)) do b
                rs = (b * J + 1):((b + 1) * J)
                length(unique(alts_raw[rs])) == J &&
                length(unique(envs_raw[rs])) == 1 &&
                length(unique(choices_raw[rs])) == 1
            end
            if block_layout
                for b in 0:(div(nrows, J) - 1)
                    r0 = b * J + 1
                    cval = choices_raw[r0]
                    haskey(alt_map, cval) || throw(CliError("data/invalid",
                        "ri-logit: choice value '$(cval)' at row $r0 not in alternatives $(uniq_alts)"))
                    push!(choices_vec, alt_map[cval])
                    push!(env_vec, env_map[envs_raw[r0]])
                    push!(state_vec, state_map[states_raw[r0]])
                end
            else
                for r in 1:nrows
                    cval = choices_raw[r]
                    haskey(alt_map, cval) || throw(CliError("data/invalid",
                        "ri-logit: choice value '$(cval)' at row $r not in alternatives $(uniq_alts)"))
                    push!(choices_vec, alt_map[cval])
                    push!(env_vec, env_map[envs_raw[r]])
                    push!(state_vec, state_map[states_raw[r]])
                end
            end
        end
    end

    isempty(choices_vec) && throw(CliError("data/shape",
        "ri-logit: no chosen observations extracted from --choice-col '$choice_col'"))

    sid = unobserved_state ? nothing : state_vec
    return (choices=choices_vec, menu_attributes=menu_attrs, env_id=env_vec,
            state_id=sid, varnames=acols, J=J, S=S, K=K, M=M,
            alt_labels=String[string(a) for a in uniq_alts])
end

function _fit_ri_logit_from_args(; data::String, env_col::String="env",
                                 choice_col::String="choice", alt_col::String="alt",
                                 state_col::String="state", obs_col::String="",
                                 attr_cols::String="", config::String="",
                                 priors::String="", normalize::String="auto",
                                 cov_type::String="hessian", tol::Float64=1e-10,
                                 max_iter::Int=400, unobserved_state::Bool=false)
    normalize in ("auto", "omega-one", "none", "first-coef") ||
        throw(CliError("usage/invalid-option",
            "ri-logit: invalid --normalize '$normalize'; must be auto, omega-one, none, or first-coef"))
    cov_type in ("hessian", "sandwich") ||
        throw(CliError("usage/invalid-option",
            "ri-logit: invalid --cov-type '$cov_type'; must be hessian or sandwich"))
    (isfinite(tol) && tol > 0.0) || throw(CliError("usage/invalid",
        "ri-logit: --tol must be finite and > 0 (got $tol)"))
    max_iter >= 1 || throw(CliError("usage/invalid",
        "ri-logit: --max-iter must be ≥ 1 (got $max_iter)"))
    isempty(strip(priors)) || strip(priors) in ("uniform", "empirical") ||
        throw(CliError("usage/invalid-option",
            "ri-logit: invalid --priors '$priors'; must be uniform or empirical (or set matrix in --config)"))

    d = _load_ri_logit_data(data; env_col=env_col, choice_col=choice_col,
                            alt_col=alt_col, state_col=state_col, obs_col=obs_col,
                            attr_cols=attr_cols, unobserved_state=unobserved_state)

    cfg_priors, cfg_base = if !isempty(strip(config))
        c = get_ri_logit_config(load_config(config), d.J, d.S, d.M)
        (c.priors, c.base_payoff)
    else
        (nothing, nothing)
    end

    priors_arg = if !isempty(strip(priors))
        strip(priors) == "empirical" ? :empirical : nothing
    else
        cfg_priors
    end
    norm_sym = if normalize == "auto"
        cfg_base === nothing ? :omega_one : :none
    else
        _to_sym(normalize)
    end

    model = try
        estimate_ri_logit(d.choices, d.menu_attributes, d.env_id;
            state_id=d.state_id, priors=priors_arg, base_payoff=cfg_base,
            normalize=norm_sym, cov_type=Symbol(cov_type),
            varnames=d.varnames, tol=tol, max_iter=max_iter)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "estimate choice ri-logit"))
    end
    return model, d
end

function _ri_logit_coef_table(model::RILogitModel, conf_level::Float64)
    K = length(model.beta)
    if K == 0
        return DataFrame(term=["omega"], estimate=[Float64(model.omega)],
                         std_error=[NaN], stat=[NaN], p_value=[NaN],
                         ci_lower=[NaN], ci_upper=[NaN])
    end
    b = Float64.(model.beta)
    # Work around upstream MEMs v1.1.2 `_coef_nt(m::RILogitModel)` checking
    # `size(m.vcov_mat) == (K, K)` when `m.vcov_mat` is `(K+1, K+1)` (beta + omega).
    se = if size(model.vcov_mat, 1) >= K && size(model.vcov_mat, 2) >= K
        Float64[sqrt(max(Float64(model.vcov_mat[i, i]), 0.0)) for i in 1:K]
    else
        fill(NaN, K)
    end
    zcrit = _normal_quantile(1.0 - (1.0 - conf_level) / 2.0)
    stat = Float64[se[i] > 0.0 ? b[i] / se[i] : NaN for i in 1:K]
    pval = Float64[isfinite(stat[i]) ? 2.0 * (1.0 - _normal_cdf(abs(stat[i]))) : NaN for i in 1:K]
    lo = b .- zcrit .* se
    hi = b .+ zcrit .* se
    vn = length(model.varnames) == K ? String.(model.varnames) : ["x$i" for i in 1:K]
    return DataFrame(term=vn, estimate=b, std_error=se, stat=stat, p_value=pval,
                     ci_lower=lo, ci_upper=hi)
end

function _estimate_ri_logit(; data::String, env_col::String="env",
                            choice_col::String="choice", alt_col::String="alt",
                            state_col::String="state", obs_col::String="",
                            attr_cols::String="", config::String="",
                            priors::String="", normalize::String="auto",
                            cov_type::String="hessian", tol::Float64=1e-10,
                            max_iter::Int=400, unobserved_state::Bool=false,
                            conf_level::Float64=0.90,
                            output::String="", format::String="table",
                            plot::Bool=false, plot_save::String="")
    conf_level = _validate_conf_level(conf_level, "estimate choice ri-logit")
    model, d = _fit_ri_logit_from_args(; data=data, env_col=env_col,
        choice_col=choice_col, alt_col=alt_col, state_col=state_col,
        obs_col=obs_col, attr_cols=attr_cols, config=config,
        priors=priors, normalize=normalize, cov_type=cov_type,
        tol=tol, max_iter=max_iter, unobserved_state=unobserved_state)

    _status("RI Logit: N=$(model.n_obs), M=$(d.M) envs, J=$(d.J) alts, S=$(d.S) states, K=$(d.K) attrs")
    _status()

    output_result(_ri_logit_coef_table(model, conf_level);
                  title="RI Logit Coefficients",
                  key="ri_logit_coefficients", format=Symbol(format), output=output)
    output_kv(Pair{String,Any}[
        "omega"        => Float64(model.omega),
        "normalize"    => string(model.normalize),
        "cov_type"     => string(model.cov_type),
        "loglik"       => Float64(model.loglik),
        "loglik_mnl"   => Float64(model.loglik_mnl),
        "lr_vs_mnl"    => Float64(model.lr_vs_mnl),
        "lr_pval"      => Float64(model.lr_pval),
        "pseudo_r2"    => Float64(model.pseudo_r2),
        "aic"          => Float64(model.aic),
        "bic"          => Float64(model.bic),
        "converged"    => model.converged,
        "iterations"   => model.iterations,
        "n_obs"        => model.n_obs,
    ]; format=format, output=_per_var_output_path(output, "fit"),
       title="Fit Statistics", key="fit_statistics")
    _maybe_plot(model; plot=plot, plot_save=plot_save, conf_level=conf_level)
    return model
end

function _predict_ri_logit(; data::String="", env_col::String="env",
                           choice_col::String="choice", alt_col::String="alt",
                           state_col::String="state", obs_col::String="",
                           attr_cols::String="", config::String="",
                           priors::String="", normalize::String="auto",
                           cov_type::String="hessian", tol::Float64=1e-10,
                           max_iter::Int=400, unobserved_state::Bool=false,
                           kind::String="auto",
                           output::String="", format::String="table",
                           model=nothing)
    kind in ("auto", "conditional", "unconditional") || throw(CliError("usage/invalid-option",
        "predict choice ri-logit: invalid --kind '$kind'; must be auto, conditional, or unconditional"))

    m = if model === nothing
        isempty(strip(data)) && throw(CliError("usage/missing",
            "predict choice ri-logit: <data> or --model <RILogitModel.jld2> is required"))
        first(_fit_ri_logit_from_args(; data=data, env_col=env_col,
            choice_col=choice_col, alt_col=alt_col, state_col=state_col,
            obs_col=obs_col, attr_cols=attr_cols, config=config,
            priors=priors, normalize=normalize, cov_type=cov_type,
            tol=tol, max_iter=max_iter, unobserved_state=unobserved_state))
    else
        model
    end

    _status("RI Logit Predicted Probabilities (kind=$kind, N=$(m.n_obs))")
    _status()
    P = try
        predict(m; kind=Symbol(kind))
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "predict choice ri-logit"))
    end

    N, J = size(P)
    pred_df = DataFrame(obs = collect(1:N), env = copy(m.env_id))
    if m.state_id !== nothing && kind != "unconditional"
        pred_df[!, :state] = copy(m.state_id)
    end
    for j in 1:J
        pred_df[!, Symbol("P_alt_$j")] = Float64.(P[:, j])
    end
    output_result(pred_df; format=Symbol(format), output=output,
                  title="RI Logit Predicted Probabilities",
                  key="ri_logit_predicted_probabilities")
    return P
end

const _RI_LOGIT_COMMON_OPTIONS = OptionSpec[
    OptionSpec(name="env-col", type=String, default="env",
               description="Environment/market ID column name"),
    OptionSpec(name="choice-col", type=String, default="choice",
               description="Choice indicator (0/1) or chosen alternative ID column name"),
    OptionSpec(name="alt-col", type=String, default="alt",
               description="Alternative ID column name"),
    OptionSpec(name="state-col", type=String, default="state",
               description="State ID column name"),
    OptionSpec(name="obs-col", type=String, default="",
               description="Optional observation ID column name for grouped long-format tables"),
    OptionSpec(name="attr-cols", type=String, default="",
               description="Comma-separated menu attribute column names (default: remaining numeric columns)"),
    OptionSpec(name="config", type=String, default="",
               description="Optional TOML with [ri.logit] priors (S×M) and/or base_payoff (J×S×M)"),
    OptionSpec(name="priors", type=String, default="",
               description="Prior mode override: uniform | empirical (or supply S×M matrix in --config)"),
    OptionSpec(name="normalize", type=String, default="auto",
               choices=["auto", "omega-one", "none", "first-coef"],
               description="Scale identification: auto | omega-one | none | first-coef"),
    OptionSpec(name="cov-type", type=String, default="hessian",
               choices=["hessian", "sandwich"],
               description="Covariance estimator: hessian | sandwich"),
    OptionSpec(name="tol", type=Float64, default=1e-10,
               description="Optimizer convergence tolerance (> 0)"),
    OptionSpec(name="max-iter", type=Int, default=400,
               description="Maximum L-BFGS iterations (≥ 1)"),
]

function w5_estimate_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["estimate", "ri-logit"],
            summary="Fit Matějka-McKay (2015) Rational Inattention discrete-choice logit model",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing,
                          description="Path to long-format menu CSV or handle stem (.csv, .jld2, .jls)")],
            options=[_RI_LOGIT_COMMON_OPTIONS..., CONF_LEVEL_MICRO_OPTION, OUTPUT_OPTIONS..., PLOT_OPTIONS...],
            flags=[
                FlagSpec(name="unobserved-state",
                         description="Treat state as unobserved by the econometrician (estimate from unconditional shares)"),
                PLOT_FLAGS...,
            ],
            tables=[
                TableSpec(name=:ri_logit_coefficients,
                          description="Estimated preference coefficients with standard errors, z-stats and CIs"),
                TableSpec(name=:fit_statistics,
                          description="Attention cost omega, log-likelihood, MNL benchmark LR test, pseudo R-squared, AIC and BIC"),
            ],
            category="estimate",
            handler=wrap_legacy(_estimate_ri_logit),
        ),
    ]
end

function w5_predict_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["predict", "ri-logit"],
            summary="Predicted conditional or unconditional choice probabilities for an RI logit model",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing,
                          description="Path to long-format menu CSV or handle stem (.csv, .jld2, .jls)")],
            options=[
                _RI_LOGIT_COMMON_OPTIONS...,
                OptionSpec(name="kind", type=String, default="auto",
                           choices=["auto", "conditional", "unconditional"],
                           description="Predicted probability kind: auto | conditional | unconditional"),
                OUTPUT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="unobserved-state",
                         description="Treat state as unobserved by the econometrician"),
            ],
            tables=[
                TableSpec(name=:ri_logit_predicted_probabilities,
                          description="Predicted choice probabilities P(j | s) or P(j) per observation and alternative"),
            ],
            category="predict",
            handler=_predict_ri_logit,
        ),
    ]
end
