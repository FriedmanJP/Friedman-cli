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

# Dynamic multipliers — new top-level command (C062b, action-first like irf/fevd/hd).
# `multipliers nardl`: cumulative asymmetric dynamic multipliers m⁺_h/m⁻_h of a NARDL model,
# with optional recursive-design residual-bootstrap bands. The NARDL is fit via the shared
# `_load_reg_data` + `_fit_nardl` helpers (estimate.jl). `NARDLMultipliers` is an array-valued
# result (n_asym × (H+1) matrices) rendered as ONE tidy long table (C051 convention); the
# bootstrap band columns are present only when bands are requested. rng-only reproducibility
# rides the global `Random.seed!` (project contract) — no per-estimator `seed=` here.

# `multipliers` was a one-leaf top-level. v1.0.0 folds the two tables and the
# horizon/nreps/level/--no-bootstrap options onto `estimate univariate nardl`.

# --------------------------------------------------------------------------
# Handler
# --------------------------------------------------------------------------

"""Melt a `NARDLMultipliers` (n_asym × (H+1) matrices) into ONE tidy long table:
`horizon | regressor | m_pos | m_neg | m_diff` plus per-band low/high columns when bands were
computed (`nreps>0 && bootstrap`). The band matrices are `0×0` when bands are skipped — guard
before touching them."""
function _nardl_multipliers_table(mm)
    has_ci = mm.nreps > 0 && size(mm.m_pos_lo, 1) == size(mm.m_pos, 1) && size(mm.m_pos_lo, 2) == size(mm.m_pos, 2)
    horizon = Int[]; regressor = String[]
    m_pos = Float64[]; m_neg = Float64[]; m_diff = Float64[]
    pos_lo = Float64[]; pos_hi = Float64[]; neg_lo = Float64[]; neg_hi = Float64[]
    dif_lo = Float64[]; dif_hi = Float64[]
    for (i, nm) in enumerate(mm.reg_names)
        for (h, hz) in enumerate(mm.horizons)
            push!(horizon, hz); push!(regressor, String(nm))
            push!(m_pos, round(Float64(mm.m_pos[i, h]); digits=6))
            push!(m_neg, round(Float64(mm.m_neg[i, h]); digits=6))
            push!(m_diff, round(Float64(mm.m_diff[i, h]); digits=6))
            if has_ci
                push!(pos_lo, round(Float64(mm.m_pos_lo[i, h]); digits=6))
                push!(pos_hi, round(Float64(mm.m_pos_hi[i, h]); digits=6))
                push!(neg_lo, round(Float64(mm.m_neg_lo[i, h]); digits=6))
                push!(neg_hi, round(Float64(mm.m_neg_hi[i, h]); digits=6))
                push!(dif_lo, round(Float64(mm.m_diff_lo[i, h]); digits=6))
                push!(dif_hi, round(Float64(mm.m_diff_hi[i, h]); digits=6))
            end
        end
    end
    df = DataFrame(horizon=horizon, regressor=regressor,
                   m_pos=m_pos, m_neg=m_neg, m_diff=m_diff)
    if has_ci
        df.m_pos_lo = pos_lo; df.m_pos_hi = pos_hi
        df.m_neg_lo = neg_lo; df.m_neg_hi = neg_hi
        df.m_diff_lo = dif_lo; df.m_diff_hi = dif_hi
    end
    return df
end

"""Emit the two NARDL multiplier tables from an already-fitted model (#204)."""
function _emit_nardl_multipliers(m, dep_name::String; horizon::Int=12, nreps::Int=500,
                                 level::Float64=0.95, no_bootstrap::Bool=false,
                                 output::String="", format::String="table")
    horizon >= 0 || throw(CliError("usage/invalid", "nardl multipliers: --horizon must be ≥ 0, got $horizon"))
    nreps >= 0 || throw(CliError("usage/invalid", "nardl multipliers: --nreps must be ≥ 0, got $nreps"))
    (0.0 < level < 1.0) || throw(CliError("usage/invalid", "nardl multipliers: --level must be in (0,1), got $level"))
    _status("NARDL dynamic multipliers: $dep_name (H=$horizon)"); _status()
    bootstrap = !no_bootstrap
    mm = try
        # MEMs#786: dynamic_multipliers takes seed= (recorded on NARDLMultipliers.manifest;
        # seed wins over rng). Forward --seed; otherwise the explicit default RNG.
        dynamic_multipliers(m, horizon; bootstrap=bootstrap, nreps=nreps, level=level,
                            rng=Random.default_rng(), _fwd_seed()...)
    catch e
        throw(_garch_variant_error(e, "NARDL dynamic multipliers"))
    end
    output_result(_nardl_multipliers_table(mm); format=Symbol(format),
                  output=_per_var_output_path(output, "multipliers"),
                  title="NARDL Cumulative Dynamic Multipliers (m⁺ / m⁻ / m⁺−m⁻) ($dep_name)",
                  key="nardl_cumulative_dynamic_multipliers")
    output_kv(Pair{String,Any}[
        "horizon"   => last(mm.horizons),
        "n_asym"    => length(mm.reg_names),
        "nreps"     => mm.nreps,
        "level"     => mm.level,
        "bootstrap" => mm.nreps > 0,
        "theta_pos" => join([round(Float64(t); digits=4) for t in mm.theta_pos], ", "),
        "theta_neg" => join([round(Float64(t); digits=4) for t in mm.theta_neg], ", "),
    ]; format=format, output=_per_var_output_path(output, "multipliers-summary"),
       title="NARDL Multipliers Summary", key="nardl_multipliers_summary")
    return mm
end
