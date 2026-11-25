# Shared model & result introspection helpers ([STORAGE-W4] #308)
#
# Centralizes safe varnames/horizon/series-name extraction across every MEMs
# model & result type so downstream `--model` handlers never access raw
# `.varnames` or `.horizon` ad-hoc and crash with FieldError / UndefVarError.

"""Best-effort variable count for a MEMs model or result object (0 if unknown)."""
function _model_nvars(obj)::Int
    try
        if hasproperty(obj, :Y) && obj.Y isa AbstractMatrix
            return size(obj.Y, 2)
        elseif hasproperty(obj, :X) && obj.X isa AbstractMatrix
            return size(obj.X, 2)
        elseif hasproperty(obj, :irf)
            ir = getproperty(obj, :irf)
            if ir isa AbstractArray && ndims(ir) >= 2
                return size(ir, 2)
            elseif hasproperty(ir, :variables) && ir.variables isa AbstractVector
                return length(ir.variables)
            elseif hasproperty(ir, :values) && ir.values isa AbstractArray && ndims(ir.values) >= 2
                return size(ir.values, 2)
            end
        elseif hasproperty(obj, :vecm) && hasproperty(obj.vecm, :Y) && obj.vecm.Y isa AbstractMatrix
            return size(obj.vecm.Y, 2)
        elseif hasproperty(obj, :var_model) && hasproperty(obj.var_model, :Y) && obj.var_model.Y isa AbstractMatrix
            return size(obj.var_model.Y, 2)
        elseif hasproperty(obj, :data) && obj.data isa AbstractMatrix
            return size(obj.data, 2)
        elseif hasproperty(obj, :n) && obj.n isa Integer
            return Int(obj.n)
        elseif hasproperty(obj, :m) && obj.m isa Integer
            return Int(obj.m)
        elseif hasproperty(obj, :y) && obj.y isa AbstractVector
            return 1
        end
    catch
    end
    return 0
end

"""
    _model_varnames(obj, meta=nothing) → Vector{String}

Safely resolve variable names for any MEMs model or result handle:
1. Stored `meta["varnames"]` (from `_frdc_meta` or `FrdcJlsEnvelope`) when
   present and dimension-consistent with `obj`.
2. Model-specific struct fields (`varnames`, `var_model.varnames`,
   `irf.variables`, `vecm.varnames`, `variables`, `xnames`, `znames`,
   `spec.varnames`, `sectors`).
3. Univariate models (`y::AbstractVector` without `X`) → `["series"]`.
4. Fallback `["Y1", ..., "Yn"]` when dimension `n > 0` is known.
"""
function _model_varnames(obj, meta=nothing)::Vector{String}
    m = meta === nothing && isdefined(@__MODULE__, :_lookup_handle_meta) ?
        _lookup_handle_meta(obj) : meta
    n_expected = _model_nvars(obj)
    if m isa AbstractDict && haskey(m, "varnames")
        raw_vn = m["varnames"]
        if raw_vn isa AbstractVector && !isempty(raw_vn)
            mvn = String[string(x) for x in raw_vn]
            if n_expected == 0 || length(mvn) == n_expected
                return mvn
            end
        end
    end

    # Direct varnames field (VARModel, BVARPosterior, VECMModel, FactorModel,
    # GeneralizedDynamicFactorModel, StructuralDFM, FAVARModel, LPModel, PVARModel,
    # RegModel, LogitModel, ProbitModel, PanelRegModel, etc.)
    if hasproperty(obj, :varnames)
        v = getproperty(obj, :varnames)
        if v isa AbstractVector && !isempty(v)
            return String[string(x) for x in v]
        end
    end

    # StructuralLP: var_model.varnames or irf.variables
    if hasproperty(obj, :var_model)
        vm = getproperty(obj, :var_model)
        if vm !== nothing && hasproperty(vm, :varnames)
            v = getproperty(vm, :varnames)
            if v isa AbstractVector && !isempty(v)
                return String[string(x) for x in v]
            end
        end
    end
    if hasproperty(obj, :irf)
        ir = getproperty(obj, :irf)
        if ir !== nothing && hasproperty(ir, :variables)
            v = getproperty(ir, :variables)
            if v isa AbstractVector && !isempty(v)
                return String[string(x) for x in v]
            end
        end
    end

    # SVECResult: vecm.varnames
    if hasproperty(obj, :vecm)
        vm = getproperty(obj, :vecm)
        if vm !== nothing && hasproperty(vm, :varnames)
            v = getproperty(vm, :varnames)
            if v isa AbstractVector && !isempty(v)
                return String[string(x) for x in v]
            end
        end
    end

    # Result structs (ImpulseResponse, FEVD, HistoricalDecomposition, LPFEVD, ...)
    if hasproperty(obj, :variables)
        v = getproperty(obj, :variables)
        if v isa AbstractVector && !isempty(v)
            return String[string(x) for x in v]
        end
    end

    # Nonlinear / regime / DSGE / IO models
    for prop in (:xnames, :znames, :response_names, :sectors)
        if hasproperty(obj, prop)
            v = getproperty(obj, prop)
            if v isa AbstractVector && !isempty(v)
                return String[string(x) for x in v]
            end
        end
    end
    if hasproperty(obj, :spec)
        sp = getproperty(obj, :spec)
        if sp !== nothing && hasproperty(sp, :varnames)
            v = getproperty(sp, :varnames)
            if v isa AbstractVector && !isempty(v)
                return String[string(x) for x in v]
            end
        end
    end

    # Univariate models (ARIMA, SARIMA, ARFIMA, ARCH, GARCH, EGARCH, GJRGARCH, SV)
    if hasproperty(obj, :y) && obj.y isa AbstractVector && !hasproperty(obj, :X)
        return String[_model_series_name(obj, m)]
    end

    # Matrix fallback (e.g. DynamicFactorModel without stored _frdc_meta varnames)
    if n_expected > 0
        return String["Y$i" for i in 1:n_expected]
    end
    return String[]
end

"""
    _model_horizon(obj) → Int

Safely resolve horizon on `LPModel`, `StructuralLP`, `ImpulseResponse`,
`BayesianImpulseResponse`, `FEVD`, `LPFEVD`, `BayesianFEVD`,
`HistoricalDecomposition`, forecasts, etc.
"""
function _model_horizon(obj)::Int
    if hasproperty(obj, :horizon) && obj.horizon isa Integer
        return Int(obj.horizon)
    end
    if hasproperty(obj, :H) && obj.H isa Integer
        return Int(obj.H)
    end
    if hasproperty(obj, :irf)
        ir = getproperty(obj, :irf)
        if ir !== nothing
            if hasproperty(ir, :horizon) && ir.horizon isa Integer
                return Int(ir.horizon)
            elseif hasproperty(ir, :values) && ir.values isa AbstractArray
                return max(size(ir.values, 1), 1)
            elseif ir isa AbstractArray
                return max(size(ir, 1) - 1, 1)
            end
        end
    end
    if hasproperty(obj, :lp_models) && obj.lp_models isa AbstractVector && !isempty(obj.lp_models)
        m1 = obj.lp_models[1]
        if hasproperty(m1, :horizon) && m1.horizon isa Integer
            return Int(m1.horizon)
        end
    end
    if hasproperty(obj, :values) && obj.values isa AbstractArray
        return max(size(obj.values, 1), 1)
    end
    if hasproperty(obj, :point_estimate) && obj.point_estimate isa AbstractArray
        sz = size(obj.point_estimate)
        return length(sz) == 3 ? sz[3] : sz[1]
    end
    if hasproperty(obj, :proportions) && obj.proportions isa AbstractArray
        sz = size(obj.proportions)
        return length(sz) == 3 ? sz[3] : sz[1]
    end
    if hasproperty(obj, :forecast) && obj.forecast isa AbstractArray
        return size(obj.forecast, 1)
    end
    if hasproperty(obj, :T_eff) && obj.T_eff isa Integer
        return Int(obj.T_eff)
    end
    throw(CliError("model/unsupported",
        "cannot determine horizon for $(nameof(typeof(obj)))"))
end

"""
    _model_series_name(obj, meta=nothing) → String

Safely resolve the univariate series label for `ARIMAModel`, `SARIMAModel`,
`ARFIMAModel`, `ARCHModel`, `GARCHModel`, `EGARCHModel`, `GJRGARCHModel`,
`SVModel`, `MSRegModel`, etc.
"""
function _model_series_name(obj, meta=nothing)::String
    m = meta === nothing && isdefined(@__MODULE__, :_lookup_handle_meta) ?
        _lookup_handle_meta(obj) : meta
    if m isa AbstractDict && haskey(m, "varnames")
        raw_vn = m["varnames"]
        if raw_vn isa AbstractVector && !isempty(raw_vn)
            s = string(raw_vn[1])
            !isempty(s) && return s
        end
    end
    if hasproperty(obj, :yname)
        s = string(getproperty(obj, :yname))
        !isempty(s) && return s
    end
    if hasproperty(obj, :varname)
        s = string(getproperty(obj, :varname))
        !isempty(s) && return s
    end
    if hasproperty(obj, :varnames)
        v = getproperty(obj, :varnames)
        if v isa AbstractVector && !isempty(v)
            s = string(v[1])
            !isempty(s) && return s
        end
    end
    return "series"
end
