# Model handles (.fmod) — interim Serialization format (P2-7 / C029)
# Replaced by MEMs save_model/load_model (#347) in C052 — keep the boundary local.

const FMOD_MAGIC = "FRIEDMAN_FMOD_v1"

"""Header stored ahead of the serialized model payload."""
struct ModelHandleHeader
    magic::String
    cli_version::String
    mems_version::String
    model_type::String
end

function _mems_version_string()::String
    try
        return string(pkgversion(MacroEconometricModels))
    catch
        return "unknown"
    end
end

function _cli_version_string()::String
    return string(FRIEDMAN_VERSION)
end

"""
    save_model_handle(path, model; model_type="")

Write a `.fmod` handle: header + serialized model.
"""
function save_model_handle(path::String, model; model_type::String="")
    isempty(path) && return nothing
    _validate_output_path(path)
    mtype = isempty(model_type) ? string(typeof(model)) : model_type
    header = ModelHandleHeader(
        FMOD_MAGIC,
        _cli_version_string(),
        _mems_version_string(),
        mtype,
    )
    open(path, "w") do io
        serialize(io, (header, model))
    end
    _status("Model handle written to $path ($mtype)")
    return path
end

"""
    load_model_handle(path) → model

Load a `.fmod` handle. Throws `CliError` with code `env/model-version` on
magic/version mismatch (exit class 6).
"""
function load_model_handle(path::String)
    isfile(path) || throw(CliError("data/file-not-found", "model handle not found: $path",
                                   hint="check --model path"))
    payload = try
        open(path, "r") do io
            deserialize(io)
        end
    catch e
        throw(CliError("env/model-corrupt", "failed to read model handle: $path",
                       hint=sprint(showerror, e)))
    end
    header, model = _unpack_fmod(payload, path)
    _check_handle_versions!(header, path)
    return model
end

function _unpack_fmod(payload, path::String)
    if payload isa Tuple && length(payload) == 2 && payload[1] isa ModelHandleHeader
        return payload[1], payload[2]
    end
    throw(CliError("env/model-version", "not a Friedman model handle: $path",
                   hint="expected $FMOD_MAGIC header"))
end

function _check_handle_versions!(header::ModelHandleHeader, path::String)
    header.magic == FMOD_MAGIC || throw(CliError(
        "env/model-version",
        "bad model handle magic in $path (got $(header.magic))",
        hint="re-estimate and --save-model with this CLI version",
    ))
    cli_now = _cli_version_string()
    mems_now = _mems_version_string()
    if header.cli_version != cli_now || header.mems_version != mems_now
        throw(CliError(
            "env/model-version",
            "model handle version mismatch for $path: " *
            "handle CLI=$(header.cli_version) MEMs=$(header.mems_version); " *
            "runtime CLI=$cli_now MEMs=$mems_now",
            hint="re-estimate with --save-model under the current versions",
        ))
    end
    return nothing
end

"""
    model_handle_info(path) → NamedTuple

Read header (and light model summary) without re-running estimation.
"""
function model_handle_info(path::String)
    isfile(path) || throw(CliError("data/file-not-found", "model handle not found: $path"))
    payload = open(deserialize, path)
    header, model = _unpack_fmod(payload, path)
    dims = _model_dims(model)
    return (
        path = path,
        magic = header.magic,
        cli_version = header.cli_version,
        mems_version = header.mems_version,
        model_type = header.model_type,
        runtime_cli = _cli_version_string(),
        runtime_mems = _mems_version_string(),
        dimensions = dims,
    )
end

function _model_dims(model)
    try
        if hasproperty(model, :Y)
            Y = model.Y
            return Dict("T" => size(Y, 1), "n" => size(Y, 2))
        elseif hasproperty(model, :p) && hasproperty(model, :n)
            return Dict("p" => model.p, "n" => model.n)
        end
    catch
    end
    return Dict{String,Any}()
end

# ─────────────────────────────────────────────────────────────────────────────
# Hybrid native/interim save+load (C052) + envelope reproducibility manifest
# ─────────────────────────────────────────────────────────────────────────────
# Native MEMs `save_model`/`load_model` (JLD2-backed, versioned, portable across a
# package upgrade) support only these result types; everything else falls back to
# the interim `.fmod` Serialization handle above. Dispatch is by suffix + type.
# The native set is DERIVED from upstream's own registry rather than hand-copied: MEMs#506
# grew it 6 → 56 types, 0.9.3 (RSER-02–14 / MEMs#758–#788) grew it to 350, and a
# hand-maintained mirror would silently rot at the next bump
# (the C038 protocol re-runs T3 against whatever this resolves to). `_SERIALIZABLE_TYPES`
# is upstream-private, so a rename must NOT stop the CLI from loading — fall back to the
# frozen 0.9.3 names, which only costs us newer types until the list is refreshed.
const _NATIVE_SAVE_TYPES_FALLBACK = Set([
    "ACFResult", "ADF2BreakResult", "ADFResult", "APARCHModel", "ARCHModel", "ARDLBoundsTest",
    "ARDLLongRun", "ARDLModel", "ARFIMAModel", "ARIMAForecast", "ARIMAModel",
    "ARIMAOrderSelection", "ARMAModel", "ARModel", "AmengualWatsonResult", "AndersonRubinCI",
    "AndersonRubinTest", "AndrewsResult", "AriasSVARResult", "BDSResult", "BFElasticities",
    "BFEquilibrium", "BFLocal", "BFMisallocation", "BFShockCurve", "BFWedgeDecomp", "BSplineBasis",
    "BVARForecast", "BVARPosterior", "BaconDecomposition", "BaiNgQResult", "BaiPerronResult",
    "BaqaeeFarhiResult", "BartlettWhiteNoiseResult", "BaselinePath", "BaxterKingResult",
    "BayesianDSGE", "BayesianDSGESimulation", "BayesianFAVAR", "BayesianFEVD",
    "BayesianHistoricalDecomposition", "BayesianImpulseResponse", "BayesianSetIdentifiedSVAR",
    "BeveridgeNelsonResult", "BlanchardOLG", "BlanchardOLGSolution", "BlanchardOLGSteadyState",
    "BoostedHPResult", "BoxPierceResult", "BreitungPanelResult", "BubbleResult", "CGARCHModel",
    "CTAiyagari", "CTPoissonIncome", "CTSteadyState", "CTTransition", "CTTwoAsset", "CTTwoAssetGE",
    "CTTwoAssetSolution", "CTTwoAssetTransition", "ClarkWestResult", "CointRegModel",
    "ConditionalForecast", "ContinuousHouseholdSystem", "CorTestResult", "CounterfactualHistory",
    "CounterfactualMoments", "CrossSectionData", "CrossSpectrumResult", "DCEGMDistribution",
    "DCEGMEquilibrium", "DCEGMFirm", "DCEGMProblem", "DCEGMSolution", "DCEGMSystem",
    "DCEGMTransition", "DFGLSResult", "DIDResult", "DMTestResult", "DSGEEstimation", "DSGEPrior",
    "DSGESolution", "DSGEStateSpace", "DataDiagnostic", "DataSummary", "DenHaanAccuracy",
    "DeterminacyMap", "DispersionTest", "DumitrescuHurlinResult", "DurbinWatsonResult",
    "DynamicFactorModel", "EDFTestResult", "EGARCHModel", "ERSResult", "EngleGrangerResult",
    "EqualityTestResult", "EventStudyLP", "ExportDecomposition", "ExternalVolatilitySVARResult",
    "ExtractionResult", "FAVARModel", "FEVD", "FIEGARCHModel", "FIGARCHModel", "FactorBreakResult",
    "FactorForecast", "FactorModel", "FirmSystem", "FisherJohansenResult", "FisherPanelResult",
    "FisherTestResult", "FootprintResult", "ForecastCombination", "ForecastCondition",
    "ForecastEncompassingResult", "ForecastEvaluation", "ForecastSufficiency", "FourierADFResult",
    "FourierKPSSResult", "FunctionConstraint", "GARCHModel", "GARCHSVARResult", "GJRGARCHModel",
    "GLPHyperparameters", "GMMModel", "GMMWeighting", "GPHResult", "GarchMidasModel",
    "GeneralizedDynamicFactorModel", "GrangerCausalityResult", "GregoryHansenResult",
    "HADSGESolution", "HAGrid", "HAGridDiagnostics", "HASteadyState", "HEGYResult",
    "HPFilterResult", "HadriResult", "HallinLiskaResult", "HamiltonFilterResult",
    "HansenInstabilityResult", "HansenLinearityTest", "HeckmanModel", "HetBlock",
    "HistoricalDecomposition", "HonestDiDResult", "HouseholdSystem", "ICASVARResult",
    "IGARCHModel", "IOData", "IOExtension", "IOMetaData", "IOMultipliers", "IPSResult", "IRDecl",
    "IREquation", "IdentifiabilityTestResult", "IdentificationDiagnostics", "ImpactResult",
    "ImpulseResponse", "IncomeProcess", "IndividualProblem", "InfluenceStats", "IntermediaryPE",
    "IntermediarySteadyState", "IntermediarySystem", "IntermediaryTransition", "JohansenResult",
    "KPSSResult", "KalmanSmootherResult", "KaoResult", "KernelDensity", "KernelRegression",
    "KhanThomasSteadyState", "KhanThomasTransition", "KrusellSmithSolution", "LLCResult",
    "LMTestResult", "LMUnitRootResult", "LPDiDResult", "LPFEVD", "LPForecast", "LPIVARBand",
    "LPIVModel", "LPImpulseResponse", "LPModel", "LRTestResult", "LearningRateCheck",
    "LifeCycleOLG", "LifeCycleSteadyState", "LifeCycleSystem", "LifeCycleTransition", "LinearDSGE",
    "LinkageResult", "LjungBoxResult", "LocalWhittleResult", "LogitModel", "LowessFit", "MAModel",
    "MCMCDiagnostics", "MFVARPosterior", "MGARCHModel", "MSForecast", "MSRegModel",
    "MarginalEffects", "MarkovSwitchingSVARResult", "MaxShareResult", "MidasForecast",
    "MidasModel", "MincerZarnowitzResult", "MinnesotaHyperparameters", "MitBlock",
    "ModelBankMember", "ModelIR", "ModelSpec", "MontielOleaPfluegerF", "MoonPerronResult",
    "MultinomialLogitModel", "MultinomialMarginalEffects", "NARDLModel", "NARDLMultipliers",
    "NARDLSymmetryTest", "NamedEquation", "NegBinModel", "NegativeWeightResult",
    "NetworkStatsResult", "NgPerronResult", "NonGaussianGMMResult", "NonGaussianMLResult",
    "NonlinearStateSpace", "NormalityTestResult", "NormalityTestSuite", "NowcastBVAR",
    "NowcastBridge", "NowcastDFM", "NowcastForecast", "NowcastNews", "NowcastResult", "OPPResult",
    "OPPSequence", "ObservationTrends", "OccBinConstraint", "OccBinIRF", "OccBinRegime",
    "OccBinSolution", "OddsRatio", "OrderedLogitModel", "OrderedProbitModel", "PANICResult",
    "PMGModel", "PPResult", "PVARModel", "PVARStability", "PVARTestResult", "PanelCointRegModel",
    "PanelData", "PanelIVModel", "PanelLogitModel", "PanelProbitModel", "PanelRegModel",
    "PanelTestResult", "PanelUnitRootSummary", "ParameterTransform", "ParkAddedResult",
    "PathFloorConstraint", "PedroniResult", "PenalizedRegModel", "PerfectForesightPath",
    "PerturbationSolution", "PesaranCIPSResult", "PhillipsOuliarisResult", "PoissonModel",
    "PolicyCausalEffects", "PolicyCounterfactual", "PolicyForecast", "PolicyLoss", "PolicyRule",
    "PosteriorMode", "PosteriorPredictiveCheck", "PrefilterSpec", "PretrendTestResult",
    "PriceModelResult", "PriorPosteriorOverlap", "PriorPredictiveResult", "ProbitModel",
    "ProductionNetwork", "ProjectionSolution", "ProjectionStateSpace", "PropensityLPModel",
    "PropensityScoreConfig", "ProxySVARResult", "PrunedStateSpace", "QuantileRegModel",
    "RASResult", "RDDResult", "RegDiagnosticResult", "RegModel", "RegionalFootprintResult",
    "RobustBayesResult", "RobustRegModel", "SARIMAModel", "SDAResult", "SMMModel", "SSJGEJacobian",
    "SSJImpulseResponse", "SSJModel", "STARForecast", "STARModel", "SURModel", "SVARModel",
    "SVECResult", "SVModel", "SelectionResult", "SignIdentifiedSet", "SimpleBlock",
    "SmoothLPModel", "SmoothTransitionSVARResult", "SpanningDiagnostic", "SpectralDensityResult",
    "StabilityResult", "StateLPModel", "StateSpaceModel", "StructuralDFM", "StructuralLP",
    "TVPVARPosterior", "ThreeSLSModel", "ThresholdForecast", "ThresholdModel", "TimeSeriesData",
    "TimingInfo", "TobitModel", "TransferFunctionResult", "TruncRegModel", "UhligSVARResult",
    "VARForecast", "VARModel", "VARStationarityResult", "VECMForecast", "VECMGrangerResult",
    "VECMModel", "VECMRestrictionTest", "VarianceRatioResult", "VerticalSpecialization",
    "VolatilityForecast", "WesterlundResult", "WildClusterBootstrap", "WinberryFamily",
    "WoldRepresentation", "X13FilterResult", "ZAResult",
])

const _NATIVE_SAVE_TYPES = if isdefined(MacroEconometricModels, :_SERIALIZABLE_TYPES)
    Set(String(k) for k in keys(getfield(MacroEconometricModels, :_SERIALIZABLE_TYPES)))
else
    _NATIVE_SAVE_TYPES_FALLBACK
end

_is_native_saveable(model) = string(nameof(typeof(model))) in _NATIVE_SAVE_TYPES

"""
    save_model_dispatch(path, model) → path

Hybrid save (C052, widened in W1/#106). `.jld2` → native MEMs `save_model` (portable,
versioned; the `_NATIVE_SAVE_TYPES` registry, 350 types at MEMs 0.9.3). `.fmod` → interim
Serialization handle (any type). No recognized suffix → native when supported, else interim.

Retired at MEMs 0.9.3 (W3/#167): the DSGE and heterogeneous-agent solution types
are now natively registered (their equations recompile at load under an AST allowlist;
only the `ss_fn`-style residual closures are load-time artifacts, never compared).
Per-type native round-trips proven on real MEMs: `DSGESolution` (all numerics equal,
reloaded solution computes IRFs), `SVARModel`, `HASteadyState`, `KrusellSmithSolution`
(incl. `manifest.seed`). `.fmod` remains for genuinely unregistered payloads (bundles
are explicit no-surface) and backward-compatible old handles.
"""
# W7/#142: in-memory model handles for `friedman serve --mcp`. Semantics match
# `.fmod` (any model type; no type registry), but the store lives exactly as
# long as the serve session (`_serve_loop` sets and clears it) — outside serve,
# a `model://` path is a typed usage error, never a filesystem access.
const _SERVE_MODEL_STORE = Ref{Union{Nothing,Dict{String,Any}}}(nothing)

function _serve_store_or_throw(path::String)
    store = _SERVE_MODEL_STORE[]
    store === nothing && throw(CliError("usage/invalid",
        "$path: model:// handles are only available inside `friedman serve --mcp`";
        hint="use a .jld2 or .fmod file path outside a serve session"))
    return store
end

function save_model_dispatch(path::String, model)
    isempty(path) && return nothing
    if startswith(path, "model://")
        store = _serve_store_or_throw(path)
        store[path] = model
        _status("Model stored in session as $path ($(nameof(typeof(model))))")
        return path
    end
    lc = lowercase(path)
    if endswith(lc, ".jld2")
        _is_native_saveable(model) || throw(CliError(
            "model/unsupported-save",
            "native .jld2 save does not support $(typeof(model))",
            # 350 supported types is far too many to list in an error; the actionable
            # half of the old hint was always "use .fmod".
            hint="re-run with a .fmod path — this type is outside the 350-type " *
                 "native registry, so it uses the interim handle format instead",
        ))
        _validate_output_path(path)
        MacroEconometricModels.save_model(model, path)
        _status("Model saved to $path (native jld2, $(nameof(typeof(model))))")
        return path
    else
        # `.fmod` or any other suffix → interim format. This keeps save/load
        # SYMMETRIC: load_model_dispatch routes only `.jld2` to the native loader,
        # so a non-`.jld2` path must be written in the interim format to reload.
        # Use a `.jld2` suffix to opt into the native, portable, versioned format.
        return save_model_handle(path, model)
    end
end

"""
    load_model_dispatch(path) → model

Hybrid load (C052). `.jld2` → native MEMs `load_model` (a bad/incompatible file
raises `SerializationError` → exit 3 via `_domain_error_class`). Any other handle
suffix → the interim `.fmod` loader (version mismatch → env/model-version, exit 6).
"""
function load_model_dispatch(path::String)
    if startswith(path, "model://")
        store = _serve_store_or_throw(path)
        haskey(store, path) || throw(CliError("data/file-not-found",
            "no session model stored at $path";
            hint="save one first with --save-model $path"))
        return store[path]
    end
    isfile(path) || throw(CliError("data/file-not-found", "model file not found: $path",
                                   hint="check --model path"))
    if endswith(lowercase(path), ".jld2")
        try
            return MacroEconometricModels.load_model(path)
        catch e
            # A MacroModelError (e.g. SerializationError: version/type mismatch) is
            # already typed — let _domain_error_class map it (→ data/serialization,
            # exit 3). Anything else (EOFError on non-JLD2 / garbage / a `.fmod`
            # renamed to `.jld2`) is still bad input, not a CLI bug: wrap it so it
            # never surfaces as internal/error (exit 1) — mirrors load_model_handle.
            _has_supertype_named(typeof(e), :MacroModelError) && rethrow()
            throw(CliError("data/serialization", "failed to read native model file: $path",
                           hint=sprint(showerror, e)))
        end
    end
    return load_model_handle(path)
end

"""
    _envelope_manifest() → Dict

Reproducibility manifest for the envelope `meta` (C052 / #345): MEMs
`capture_manifest` (cheap, always-on) tagged with the CLI's active `--seed`.
"""
function _envelope_manifest()
    m = MacroEconometricModels.capture_manifest(; seed=_SEED[])
    return Dict{String,Any}(
        "seed"                => m.seed,
        "n_threads"           => m.n_threads,
        "julia_version"       => m.julia_version,
        "package_version"     => m.package_version,
        "dependency_versions" => Dict{String,Any}(m.dependency_versions),
        "os"                  => m.os,
        "machine"             => m.machine,
        "timestamp"           => m.timestamp,
        "git_sha"             => m.git_sha,
        "git_dirty"           => m.git_dirty,
        "settings"            => Dict{String,Any}(m.settings),
    )
end

"""
    _native_model_info(path) → NamedTuple

`model info` for a native `.jld2` handle (C052, W3/#167). Reads the container
header via MEMs `model_info` — versions, note, bundle layout — WITHOUT
reconstructing the payload, so a corrupt payload still inspects; dimensions
stay best-effort (empty when reconstruction fails). Shares the field shape of
[`model_handle_info`](@ref) so the `model info` renderer is format-agnostic,
plus the header `note`.
"""
function _native_model_info(path::String)
    isfile(path) || throw(CliError("data/file-not-found", "model file not found: $path",
                                   hint="check the path"))
    header = try
        MacroEconometricModels.model_info(path)
    catch e
        _has_supertype_named(typeof(e), :MacroModelError) && rethrow()
        throw(CliError("data/serialization", "failed to read native model file: $path",
                       hint=sprint(showerror, e)))
    end
    is_bundle = get(header, "bundle", false) === true
    if is_bundle
        entries = get(header, "entries", Dict{String,Any}())
        model_type = "bundle($(length(entries)) entries: $(join(sort!(collect(keys(entries))), ", ")))"
    else
        model_type = string(get(header, "type", "unknown"))
    end
    dims = try
        _model_dims(load_model_dispatch(path))
    catch
        Dict{String,Any}()
    end
    return (
        path = path,
        magic = "MEMs native (jld2)",
        cli_version = "n/a",
        mems_version = string(get(header, "package_version", _mems_version_string())),
        model_type = model_type,
        runtime_cli = _cli_version_string(),
        runtime_mems = _mems_version_string(),
        dimensions = dims,
        note = string(get(header, "note", "")),
    )
end
