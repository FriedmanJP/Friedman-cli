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

# Spectral analysis — registry pilot (P2-1 / C021)

function spectral_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", description="Path to data file or handle stem (.csv, .jld2, .jls)")]
    plot_opts = [OUTPUT_OPTIONS; PLOT_OPTIONS]
    plot_flags = copy(PLOT_FLAGS)

    log_scale_flag = FlagSpec(
        name="log-scale",
        description="Plot spectral density on a log10 vertical axis (default: linear)",
    )

    return [
        CommandSpec(
            path=["spectral", "acf"],
            summary="Autocorrelation / partial autocorrelation / cross-correlation",
            args=data_arg,
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1,
                           description="Column index (1-based)"),
                OptionSpec(name="max-lag", type=Int, default=nothing,
                           description="Maximum lag (default: automatic, capped at min(T-1, 10*log10(T)))"),
                OptionSpec(name="ccf-with", type=Int, default=nothing,
                           description="Column index for cross-correlation"),
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[
                TableSpec(name=:acf_pacf,
                          description="Autocorrelation, partial autocorrelation, Ljung-Box Q and p-value by lag"),
                TableSpec(name=:cross_correlation,
                          description="Cross-correlation by lag against --ccf-with (only with that option)"),
            ],
            category="spectral",
            handler=wrap_legacy(_spectral_acf),
        ),
        CommandSpec(
            path=["spectral", "periodogram"],
            summary="Raw periodogram",
            args=data_arg,
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1,
                           description="Column index (1-based)"),
                plot_opts...,
            ],
            flags=[plot_flags; log_scale_flag],
            tables=[TableSpec(name=:periodogram,
                              description="Raw periodogram power by Fourier frequency")],
            category="spectral",
            handler=wrap_legacy(_spectral_periodogram),
        ),
        CommandSpec(
            path=["spectral", "density"],
            summary="Spectral density estimation",
            args=data_arg,
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1,
                           description="Column index (1-based)"),
                OptionSpec(name="method", short="m", type=String, default="welch",
                           choices=["periodogram", "welch", "smoothed", "ar"],
                           description="periodogram|welch|smoothed|ar"),
                OptionSpec(name="bandwidth", type=Float64, default=nothing,
                           description="Smoothing bandwidth"),
                plot_opts...,
            ],
            flags=[plot_flags; log_scale_flag],
            tables=[TableSpec(name=:spectral_density,
                              description="Estimated spectral density with confidence band by frequency")],
            category="spectral",
            handler=wrap_legacy(_spectral_density),
        ),
        CommandSpec(
            path=["spectral", "cross"],
            summary="Cross-spectral analysis (coherence, phase, gain)",
            args=data_arg,
            options=[
                OptionSpec(name="var1", type=Int, default=1,
                           description="First variable column index"),
                OptionSpec(name="var2", type=Int, default=2,
                           description="Second variable column index"),
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[TableSpec(name=:cross_spectral_analysis,
                              description="Co-/quadrature spectrum, coherence, phase and gain by frequency")],
            category="spectral",
            handler=wrap_legacy(_spectral_cross),
        ),
        CommandSpec(
            path=["spectral", "transfer"],
            summary="Filter transfer function (theoretical frequency response)",
            args=ArgSpec[],
            options=[
                OptionSpec(name="filter", type=String, default="hp",
                           choices=["hp", "bk", "hamilton"],
                           description="hp|bk|hamilton"),
                OptionSpec(name="lambda", type=Float64, default=1600.0,
                           description="Filter parameter (e.g. HP lambda)"),
                OptionSpec(name="n-freq", aliases=["nobs"], kwarg=:n_freq, type=Int, default=256,
                           description="Number of frequency grid points (≥ 2)"),
                plot_opts...,
            ],
            flags=plot_flags,
            tables=[TableSpec(name=:filter_transfer_function,
                              description="Theoretical filter gain and phase by frequency")],
            category="spectral",
            handler=wrap_legacy(_spectral_transfer),
        ),
    ]
end

const _SPECTRAL_RESULT_TYPES = Dict{Vector{String},Vector{Symbol}}(
    ["spectral", "acf"]         => [:ACFResult],
    ["spectral", "periodogram"] => [:SpectralDensityResult],
    ["spectral", "density"]     => [:SpectralDensityResult],
    ["spectral", "cross"]       => [:CrossSpectrumResult],
    ["spectral", "transfer"]    => [:TransferFunctionResult],
)

function _rerender_spectral_result(result; format::String="table", output::String="",
                                   title::String="", key::String="",
                                   plot::Bool=false, plot_save::String="")
    tn = nameof(typeof(result))
    if tn === :ACFResult
        acf_df = DataFrame(
            Lag     = result.lags,
            ACF     = result.acf,
            PACF    = result.pacf,
            Q_stat  = result.q_stats,
            p_value = result.q_pvalues,
        )
        output_result(acf_df; format=Symbol(format), output=output, title="ACF / PACF")
    elseif tn === :SpectralDensityResult
        if key == "periodogram" || !hasproperty(result, :ci_lower) || result.ci_lower === nothing
            peri_df = DataFrame(
                Frequency = result.freq,
                Power     = result.density,
            )
            output_result(peri_df; format=Symbol(format), output=output, title="Periodogram")
        else
            sd_df = DataFrame(
                Frequency = result.freq,
                Density   = result.density,
                CI_Lower  = result.ci_lower,
                CI_Upper  = result.ci_upper,
            )
            output_result(sd_df; format=Symbol(format), output=output, title="Spectral Density")
        end
    elseif tn === :CrossSpectrumResult
        cs_df = DataFrame(
            Frequency     = result.freq,
            Co_spectrum   = result.co_spectrum,
            Quad_spectrum = result.quad_spectrum,
            Coherence     = result.coherence,
            Phase         = result.phase,
            Gain          = result.gain,
        )
        output_result(cs_df; format=Symbol(format), output=output, title="Cross-Spectral Analysis")
    elseif tn === :TransferFunctionResult
        tf_df = DataFrame(
            Frequency = result.freq,
            Gain      = result.gain,
            Phase     = result.phase,
        )
        output_result(tf_df; format=Symbol(format), output=output, title="Filter Transfer Function")
    else
        _rerender_kv(result; format=format, output=output, title=title, key=key)
    end
    _maybe_plot(result; plot=plot, plot_save=plot_save)
    return result
end

function register_spectral_commands!()
    raw_handlers = Dict(
        ["spectral", "acf"]         => _spectral_acf,
        ["spectral", "periodogram"] => _spectral_periodogram,
        ["spectral", "density"]     => _spectral_density,
        ["spectral", "cross"]       => _spectral_cross,
        ["spectral", "transfer"]    => _spectral_transfer,
    )
    specs = CommandSpec[]
    for s in spectral_specs()
        rt = get(_SPECTRAL_RESULT_TYPES, s.path, Symbol[])
        key = isempty(s.tables) ? "" : string(s.tables[1].name)
        raw_fn = raw_handlers[s.path]
        h = wrap_legacy(_with_result(raw_fn, join(s.path, " "); key=key,
                                     render_fn=_rerender_spectral_result))
        push!(specs, _copy_spec(s; handler=h, result_types=rt))
    end
    specs = with_result_handles(with_default_csv_kinds(with_data_kinds(specs, [:timeseries, :csv])))
    append!(specs, w2_spectral_specs())
    specs = register!(specs)
    return build_node("spectral", specs;
        description="Spectral analysis: ACF/PACF, periodogram, spectral density, cross-spectrum, transfer function")
end

# --------------------------------------------------------------------------
# Handlers (legacy kwargs — wrapped via wrap_legacy for the registry pilot)
# --------------------------------------------------------------------------

function _spectral_acf(; data::String, column::Int=1,
                        max_lag::Union{Int,Nothing}=nothing,
                        ccf_with::Union{Int,Nothing}=nothing,
                        output::String="", format::String="table",
                        plot::Bool=false, plot_save::String="")
    df = load_data(data)
    vnames = variable_names(df)
    Y = df_to_matrix(df)
    y = Y[:, column]

    kwargs = isnothing(max_lag) ? (;) : (; lags=max_lag)
    result = acf(y; kwargs...)

    _status("ACF/PACF: $(vnames[column])  (T = $(length(y)))")
    _status()

    acf_df = DataFrame(
        Lag     = result.lags,
        ACF     = result.acf,
        PACF    = result.pacf,
        Q_stat  = result.q_stats,
        p_value = result.q_pvalues,
    )
    output_result(acf_df; format=Symbol(format), output=output, title="ACF / PACF")

    if !isnothing(ccf_with)
        z = Y[:, ccf_with]
        ccf_result = ccf(y, z; kwargs...)
        ccf_df = DataFrame(
            Lag = ccf_result.lags,
            CCF = ccf_result.ccf,
        )
        _status()
        output_result(ccf_df; format=Symbol(format),
                      output=_per_var_output_path(output, "ccf"),
                      title="CCF: $(vnames[column]) x $(vnames[ccf_with])", key="cross_correlation")
    end

    _maybe_plot(result; plot=plot, plot_save=plot_save)
    return result
end

function _spectral_periodogram(; data::String, column::Int=1,
                                output::String="", format::String="table",
                                plot::Bool=false, plot_save::String="",
                                log_scale::Bool=false)
    df = load_data(data)
    vnames = variable_names(df)
    y = df_to_matrix(df)[:, column]

    result = periodogram(y)

    _status("Periodogram: $(vnames[column])  (T = $(length(y)))")
    _status()

    peri_df = DataFrame(
        Frequency = result.freq,
        Power     = result.density,
    )
    output_result(peri_df; format=Symbol(format), output=output, title="Periodogram")
    plot_kw = log_scale ? (; log_scale=true) : NamedTuple()
    _maybe_plot(result; plot=plot, plot_save=plot_save, plot_kw...)
    return result
end

function _spectral_density(; data::String, column::Int=1,
                            method::String="welch",
                            bandwidth::Union{Float64,Nothing}=nothing,
                            output::String="", format::String="table",
                            plot::Bool=false, plot_save::String="",
                            log_scale::Bool=false)
    df = load_data(data)
    vnames = variable_names(df)
    y = df_to_matrix(df)[:, column]

    kwargs = Dict{Symbol,Any}(:method => Symbol(method))
    !isnothing(bandwidth) && (kwargs[:bandwidth] = bandwidth)
    result = spectral_density(y; kwargs...)

    _status("Spectral Density ($(method)): $(vnames[column])  (T = $(length(y)))")
    _status()

    sd_df = DataFrame(
        Frequency = result.freq,
        Density   = result.density,
        CI_Lower  = result.ci_lower,
        CI_Upper  = result.ci_upper,
    )
    output_result(sd_df; format=Symbol(format), output=output, title="Spectral Density")
    plot_kw = log_scale ? (; log_scale=true) : NamedTuple()
    _maybe_plot(result; plot=plot, plot_save=plot_save, plot_kw...)
    return result
end

function _spectral_cross(; data::String, var1::Int=1, var2::Int=2,
                          output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="")
    df = load_data(data)
    vnames = variable_names(df)
    Y = df_to_matrix(df)
    y = Y[:, var1]; z = Y[:, var2]

    result = cross_spectrum(y, z)

    _status("Cross-Spectrum: $(vnames[var1]) x $(vnames[var2])  (T = $(length(y)))")
    _status()

    cs_df = DataFrame(
        Frequency     = result.freq,
        Co_spectrum   = result.co_spectrum,
        Quad_spectrum = result.quad_spectrum,
        Coherence     = result.coherence,
        Phase         = result.phase,
        Gain          = result.gain,
    )
    output_result(cs_df; format=Symbol(format), output=output, title="Cross-Spectral Analysis")
    _maybe_plot(result; plot=plot, plot_save=plot_save)
    return result
end

function _spectral_transfer(; filter::String="hp", lambda::Float64=1600.0,
                             n_freq::Int=256,
                             output::String="", format::String="table",
                             plot::Bool=false, plot_save::String="")
    n_freq >= 2 || throw(CliError("usage/invalid", "--n-freq must be ≥ 2 (got $n_freq)"))
    result = try
        transfer_function(Symbol(filter); lambda=lambda, n_freq=n_freq)
    catch e
        throw(_domain_or_data_error(e, "spectral transfer"))
    end

    _status("Transfer Function: $(filter) filter  (lambda = $lambda, n_freq = $n_freq)")
    _status()

    tf_df = DataFrame(
        Frequency = result.freq,
        Gain      = result.gain,
        Phase     = result.phase,
    )
    output_result(tf_df; format=Symbol(format), output=output, title="Filter Transfer Function")
    _maybe_plot(result; plot=plot, plot_save=plot_save)
    return result
end
