# Model handles (.fmod) — interim Serialization format (P2-7 / C029)
# Replaced by MEMs save_model/load_model (#347) in C052 — keep the boundary local.

import JLD2

const FMOD_MAGIC = "FRIEDMAN_FMOD_v1"
const _HDF5_MAGIC = UInt8[0x89, 0x48, 0x44, 0x46, 0x0d, 0x0a, 0x1a, 0x0a]
const _JLD2_MAGIC = Vector{UInt8}(codeunits("HDF5-based Julia Data Format"))

function _is_hdf5_file(path::String)::Bool
    isfile(path) || return false
    return try
        open(path, "r") do io
            hdr = read(io, 32)
            (length(hdr) >= 8 && @view(hdr[1:8]) == _HDF5_MAGIC) ||
                (length(hdr) >= length(_JLD2_MAGIC) && @view(hdr[1:length(_JLD2_MAGIC)]) == _JLD2_MAGIC)
        end
    catch
        false
    end
end

function _is_mems_jld2_dict(d::AbstractDict)::Bool
    (haskey(d, "__format__") || haskey(d, "__type__") ||
     haskey(d, "format_version") || haskey(d, "package_version")) && return true
    if haskey(d, "container") && d["container"] isa AbstractDict
        c = d["container"]
        return haskey(c, "format_version") || haskey(c, "type") ||
               haskey(c, "package_version") || haskey(c, "bundle")
    end
    return false
end

"""Header stored ahead of the serialized model payload."""
struct ModelHandleHeader
    magic::String
    cli_version::String
    mems_version::String
    model_type::String
end

function _mems_version_string()::String
    isdefined(@__MODULE__, :_cached_mems_version) && return _cached_mems_version()
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

Write a `.fmod` handle atomically: header + serialized model.
"""
function save_model_handle(path::String, model; model_type::String="")
    isempty(path) && return nothing
    dest = _validate_output_path(path; create_parents=true)
    mtype = isempty(model_type) ? string(typeof(model)) : model_type
    header = ModelHandleHeader(
        FMOD_MAGIC,
        _cli_version_string(),
        _mems_version_string(),
        mtype,
    )
    _atomic_write(dest, tmp -> begin
        open(tmp, "w") do io
            serialize(io, (header, model))
        end
    end)
    _status("Model handle written to $dest ($mtype)")
    return dest
end

"""
    load_model_handle(path) → model

Load a `.fmod` handle. Throws `CliError` with code `env/model-version` on
magic/version mismatch (exit class 6) or `data/corrupt-handle` (exit class 3)
on empty/corrupt input.
"""
function load_model_handle(path::String)
    path = _validate_input_path(path)
    isfile(path) || throw(CliError("data/file-not-found", "model handle not found: $path",
                                   hint="check --model path"))
    magic = sniff_handle_format(path)
    magic === :empty && throw(CliError("data/corrupt-handle",
        "model handle is empty or truncated: $path";
        hint="re-create the handle"))
    magic === :hdf5 && throw(CliError("data/corrupt-handle",
        "format mismatch: '$path' contains HDF5/JLD2 data, not .fmod";
        hint="rename to .jld2"))
    magic === :unknown && throw(CliError("data/corrupt-handle",
        "corrupt or unrecognized model handle: $path"))
    payload = try
        open(path, "r") do io
            deserialize(io)
        end
    catch e
        throw(CliError("data/corrupt-handle", "failed to read model handle: $path",
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
    path = _validate_input_path(path)
    isfile(path) || throw(CliError("data/file-not-found", "model handle not found: $path"))
    magic = sniff_handle_format(path)
    (magic === :empty || magic === :unknown) && throw(CliError("data/corrupt-handle",
        "corrupt or empty model handle: $path"))
    payload = try
        open(deserialize, path)
    catch e
        throw(CliError("data/corrupt-handle", "failed to read model handle: $path",
                       hint=sprint(showerror, e)))
    end
    header, model = _unpack_fmod(payload, path)
    dims = _extract_dims(model)
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

function _jls_model_info(path::String)
    path = _validate_input_path(path)
    isfile(path) || throw(CliError("data/file-not-found", "model handle not found: $path",
                                   hint="check handle path"))
    magic = sniff_handle_format(path)
    if magic === :empty || magic === :unknown
        throw(CliError("data/corrupt-handle", "corrupt or empty .jls file: $path"))
    elseif magic === :hdf5
        throw(CliError("data/corrupt-handle",
            "format mismatch: '$path' has .jls extension but contains HDF5/JLD2 data";
            hint="rename to .jld2"))
    end
    payload = try
        open(deserialize, path)
    catch e
        throw(CliError("data/corrupt-handle", "failed to read serialized .jls file: $path",
                       hint=sprint(showerror, e)))
    end
    if payload isa FrdcJlsEnvelope
        return (
            path = path,
            magic = "Julia Serialization (jls)",
            cli_version = payload.cli_version,
            mems_version = payload.mems_version,
            model_type = payload.type_name,
            runtime_cli = _cli_version_string(),
            runtime_mems = _mems_version_string(),
            dimensions = payload.dims,
            note = payload.note,
        )
    elseif payload isa Tuple && length(payload) == 2 && payload[1] isa ModelHandleHeader
        header, model = payload
        return (
            path = path,
            magic = "Julia Serialization (jls)",
            cli_version = header.cli_version,
            mems_version = header.mems_version,
            model_type = header.model_type,
            runtime_cli = _cli_version_string(),
            runtime_mems = _mems_version_string(),
            dimensions = _extract_dims(model),
            note = "",
        )
    end
    return (
        path = path,
        magic = "Julia Serialization (jls)",
        cli_version = "n/a",
        mems_version = "n/a",
        model_type = string(nameof(typeof(payload))),
        runtime_cli = _cli_version_string(),
        runtime_mems = _mems_version_string(),
        dimensions = _extract_dims(payload),
        note = "",
    )
end

_model_dims(model) = _extract_dims(model)

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
    "ABCDSystem", "ACFResult", "ADF2BreakResult", "ADFResult", "APARCHModel", "ARCHModel",
    "ARDLBoundsTest", "ARDLLongRun", "ARDLModel", "ARFIMAModel", "ARIMAForecast", "ARIMAModel",
    "ARIMAOrderSelection", "ARMAModel", "ARModel", "AhnHorensteinResult", "AmengualWatsonResult",
    "AndersonRubinCI", "AndersonRubinTest", "AndrewsResult", "AriasSVARResult", "BDSResult",
    "BFElasticities", "BFEquilibrium", "BFLocal", "BFMisallocation", "BFShockCurve",
    "BFWedgeDecomp", "BSplineBasis", "BVARForecast", "BVARPosterior", "BaconDecomposition",
    "BaiNgQResult", "BaiPerronResult", "BandPassGDFMResult", "BaqaeeFarhiResult",
    "BartlettWhiteNoiseResult", "BaselinePath", "BaxterKingResult", "BayesianDSGE",
    "BayesianDSGESimulation", "BayesianFAVAR", "BayesianFEVD", "BayesianHistoricalDecomposition",
    "BayesianImpulseResponse", "BayesianSetIdentifiedSVAR", "BeveridgeNelsonResult",
    "BlanchardOLG", "BlanchardOLGSolution", "BlanchardOLGSteadyState", "BoostedHPResult",
    "BoxPierceResult", "BreitungPanelResult", "BubbleResult", "CGARCHModel", "CGTestResult",
    "CTAiyagari", "CTPoissonIncome", "CTSteadyState", "CTTransition", "CTTwoAsset", "CTTwoAssetGE",
    "CTTwoAssetSolution", "CTTwoAssetTransition", "ClarkWestResult", "CointRegModel",
    "CointegratedGDFM", "ConditionalForecast", "ContinuousHouseholdSystem", "CorTestResult",
    "CounterfactualHistory", "CounterfactualMoments", "CrossSectionData", "CrossSpectrumResult",
    "DCEGMDistribution", "DCEGMEquilibrium", "DCEGMFirm", "DCEGMProblem", "DCEGMSolution",
    "DCEGMSystem", "DCEGMTransition", "DFGLSResult", "DIDResult", "DMTestResult", "DSGEEstimation",
    "DSGEPrior", "DSGESolution", "DSGEStateSpace", "DSGEVARIRFAudit", "DSGEVARLambdaProfile",
    "DSGEVARPosterior", "DSGEVARPrior", "DataDiagnostic", "DataSummary", "DenHaanAccuracy",
    "DeterminacyMap", "DispersionTest", "DumitrescuHurlinResult", "DurbinWatsonResult",
    "DynamicFactorModel", "DynamicRISolution", "EDFTestResult", "EGARCHModel", "ERSResult",
    "EngleGrangerResult", "EqualityTestResult", "EurocoinResult", "EventStudyLP",
    "ExportDecomposition", "ExternalVolatilitySVARResult", "ExtractionResult", "FAVARModel",
    "FEVD", "FHLZModel", "FIEGARCHModel", "FIGARCHModel", "FactorBreakResult", "FactorForecast",
    "FactorModel", "FirmSystem", "FisherJohansenResult", "FisherPanelResult", "FisherTestResult",
    "FootprintResult", "ForecastCombination", "ForecastCondition", "ForecastEncompassingResult",
    "ForecastEvaluation", "ForecastSufficiency", "FourierADFResult", "FourierKPSSResult",
    "FunctionConstraint", "FundamentalnessTestResult", "GARCHModel", "GARCHSVARResult",
    "GDFMNowcastResult", "GJRGARCHModel", "GLPHyperparameters", "GMMModel",
    "GMMMomentSelectionResult", "GMMWeighting", "GPHResult", "GarchMidasModel",
    "GeneralizedDynamicFactorModel", "GrangerCausalityResult", "GregoryHansenResult",
    "GrowthAtRiskResult", "HADSGESolution", "HAGrid", "HAGridDiagnostics", "HASteadyState",
    "HEGYResult", "HPFilterResult", "HadriResult", "HallinLiskaResult", "HamiltonFilterResult",
    "HansenInstabilityResult", "HansenLinearityTest", "HeckmanModel", "HetBlock",
    "HistoricalDecomposition", "HonestDiDResult", "HouseholdSystem", "ICASVARResult",
    "IGARCHModel", "IOData", "IOExtension", "IOMetaData", "IOMultipliers", "IPSResult", "IRDecl",
    "IREquation", "IdentifiabilityTestResult", "IdentificationDiagnostics", "ImpactResult",
    "ImpulseResponse", "IncomeProcess", "IndividualProblem", "InfluenceStats",
    "InnovationsRepresentation", "IntermediaryPE", "IntermediarySteadyState", "IntermediarySystem",
    "IntermediaryTransition", "InvertibilityResult", "JohansenResult", "KPSSResult",
    "KalmanSmootherResult", "KaoResult", "KernelDensity", "KernelRegression",
    "KhanThomasSteadyState", "KhanThomasTransition", "KrusellSmithSolution", "LLCResult",
    "LMSSVARResult", "LMTestResult", "LMUnitRootResult", "LPDiDResult", "LPFEVD", "LPForecast",
    "LPIVARBand", "LPIVModel", "LPImpulseResponse", "LPModel", "LRTestResult",
    "LanneLuotoGMMResult", "LearningRateCheck", "LewisTVVResult", "LifeCycleOLG",
    "LifeCycleSteadyState", "LifeCycleSystem", "LifeCycleTransition", "LinearDSGE",
    "LinkageResult", "LjungBoxResult", "LocalWhittleResult", "LogitModel", "LowessFit", "MAModel",
    "MCMCDiagnostics", "MFVARPosterior", "MGARCHModel", "MSForecast", "MSRegModel",
    "MWAttentionResult", "MarginalEffects", "MarkovSwitchingSVARResult", "MaxShareResult",
    "MidasForecast", "MidasModel", "MincerZarnowitzResult", "MinnesotaHyperparameters", "MitBlock",
    "ModelBankMember", "ModelIR", "ModelSpec", "MontielOleaPfluegerF", "MoonPerronResult",
    "MultinomialLogitModel", "MultinomialMarginalEffects", "NARDLModel", "NARDLMultipliers",
    "NARDLSymmetryTest", "NamedEquation", "NegBinModel", "NegativeWeightResult",
    "NetworkStatsResult", "NgPerronResult", "NonGaussianDiagnostics", "NonGaussianGMMResult",
    "NonGaussianMLResult", "NonlinearStateSpace", "NormalityTestResult", "NormalityTestSuite",
    "NowcastBVAR", "NowcastBridge", "NowcastDFM", "NowcastForecast", "NowcastNews",
    "NowcastResult", "OPPResult", "OPPSequence", "ObservableSearchResult", "ObservationTrends",
    "OccBinConstraint", "OccBinIRF", "OccBinRegime", "OccBinSolution", "OddsRatio",
    "OnatskiEDResult", "OnatskiQTestResult", "OrderedLogitModel", "OrderedProbitModel",
    "PANICResult", "PMGModel", "PPResult", "PVARModel", "PVARStability", "PVARTestResult",
    "PanelCointRegModel", "PanelData", "PanelIVModel", "PanelLogitModel", "PanelProbitModel",
    "PanelRegModel", "PanelTestResult", "PanelUnitRootSummary", "ParameterTransform",
    "ParkAddedResult", "PathFloorConstraint", "PedroniResult", "PenalizedRegModel",
    "PerfectForesightPath", "PerturbationSolution", "PesaranCIPSResult", "PhillipsOuliarisResult",
    "PoissonModel", "PolicyCausalEffects", "PolicyCounterfactual", "PolicyForecast", "PolicyLoss",
    "PolicyRule", "PosteriorMode", "PosteriorPredictiveCheck", "PrefilterSpec",
    "PretrendTestResult", "PriceModelResult", "PriorPosteriorOverlap", "PriorPredictiveResult",
    "ProbitModel", "ProductionNetwork", "ProjectionSolution", "ProjectionStateSpace",
    "PropensityLPModel", "PropensityScoreConfig", "ProxySVARResult", "PrunedStateSpace",
    "QFMICResult", "QFMLoadingConstancyTest", "QFMSpanningResult", "QuantileFAVAR",
    "QuantileFactorGrid", "QuantileFactorModel", "QuantileFactorPanelModel",
    "QuantileImpulseResponse", "QuantileRegModel", "QuantileVARModel", "RASResult", "RDDResult",
    "RIDiscreteChoiceSolution", "RIEstimationResult", "RIIIADiagnostic", "RILogitModel",
    "RationalInattentionProblem", "RegDiagnosticResult", "RegModel", "RegionalFootprintResult",
    "RobustBayesResult", "RobustRegModel", "SARIMAModel", "SDAResult", "SMMModel", "SSJGEJacobian",
    "SSJImpulseResponse", "SSJModel", "STARForecast", "STARModel", "SURModel",
    "SVARHypothesisTest", "SVARMAModel", "SVARModel", "SVECResult", "SVModel", "SVSVARResult",
    "SelectionResult", "ShockRecoverabilityResult", "SignIdentifiedSet", "SimpleBlock",
    "SimsKalmanSolution", "SmoothLPModel", "SmoothTransitionSVARResult", "SpanningDiagnostic",
    "SpectralDensityResult", "SpectralFEVDResult", "StabilityResult", "StateLPModel",
    "StateSpaceModel", "SteadyStateKalman", "StructuralDFM", "StructuralLP",
    "SufficientInformationTestResult", "TVPVARPosterior", "ThreeSLSModel", "ThresholdForecast",
    "ThresholdModel", "TimeSeriesData", "TimeVaryingGDFM", "TimingInfo", "TobitModel",
    "TransferFunctionResult", "TruncRegModel", "UhligSVARResult", "VARForecast", "VARModel",
    "VARStationarityResult", "VBQuantileFAVAR", "VECMForecast", "VECMGrangerResult", "VECMModel",
    "VECMRestrictionTest", "VarianceRatioResult", "VerticalSpecialization", "VolatilityForecast",
    "WesterlundResult", "WildClusterBootstrap", "WinberryFamily", "WoldRepresentation",
    "X13FilterResult", "ZAResult",
])

const _NATIVE_SAVE_TYPES = if isdefined(MacroEconometricModels, :_SERIALIZABLE_TYPES)
    Set(String(k) for k in keys(getfield(MacroEconometricModels, :_SERIALIZABLE_TYPES)))
else
    _NATIVE_SAVE_TYPES_FALLBACK
end

include("storage/ref.jl")
include("storage/codec.jl")
include("storage/session.jl")
include("storage/cache.jl")

_is_native_saveable(model) = is_mems_serializable(model)

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
const _SERVE_SOURCE_MODELS = Ref{Union{Nothing,Dict{String,Any}}}(nothing)

function attach_source_model!(path::String, model)
    isempty(path) && return nothing
    if _is_session_uri(path)
        session_store_set_source_model!(path, model)
        return nothing
    end
    lc = lowercase(path)
    endswith(lc, ".jld2") || return nothing
    if _is_hdf5_file(path)
        if _is_native_saveable(model) && isdefined(MacroEconometricModels, :_build_container)
            try
                container = MacroEconometricModels._build_container(model)
                _with_quiet_jld2() do
                    JLD2.jldopen(path, "r+") do f
                        f["_friedman_source_model"] = container
                    end
                end
            catch
            end
        end
    else
        # Mock `.jld2` uses Serialization Dict container
        try
            d = open(deserialize, path)
            if d isa AbstractDict
                d["_friedman_source_model"] = model
                open(io -> serialize(io, d), path, "w")
            end
        catch
        end
    end
    return nothing
end

function load_source_model(path::String)
    isempty(path) && return nothing
    if _is_session_uri(path)
        return session_store_source_model(path)
    end
    isfile(path) || return nothing
    lc = lowercase(path)
    if endswith(lc, ".jls")
        return try
            payload = open(deserialize, path)
            payload isa FrdcJlsEnvelope ? payload.source_model : nothing
        catch
            nothing
        end
    end
    endswith(lc, ".jld2") || return nothing
    if _is_hdf5_file(path)
        isdefined(MacroEconometricModels, :_reconstruct_from_container) || return nothing
        return try
            _with_quiet_jld2() do
                JLD2.jldopen(path, "r") do f
                    haskey(f, "_friedman_source_model") ?
                        MacroEconometricModels._reconstruct_from_container(f["_friedman_source_model"]) :
                        nothing
                end
            end
        catch
            nothing
        end
    else
        return try
            d = open(deserialize, path)
            (d isa AbstractDict && haskey(d, "_friedman_source_model")) ? d["_friedman_source_model"] : nothing
        catch
            nothing
        end
    end
end

function _serve_store_or_throw(path::String)
    _require_session_store!(path)
    return _SERVE_MODEL_STORE[]
end

function save_model_dispatch(path::String, model; note::String="", source_model=nothing,
                             source_model_path::String="", compress::Bool=false,
                             artifact_kind::String="")
    isempty(path) && return nothing
    ref = resolve_write_ref(path; default_ext="", create_parents=true)
    return save_handle!(ref, model; note=note, source_model=source_model,
                        source_model_path=source_model_path, compress=compress,
                        artifact_kind=artifact_kind)
end

"""
    load_model_dispatch(path) → model

Unified handle load delegating to `src/storage/cache.jl` + `codec.jl`
(`HandleRef` + request-scoped cache + magic-byte dispatch + `#key` extraction +
`FRDC_DATA_ROOT` confinement).
"""
function load_model_dispatch(path::String)
    ref = parse_handle_ref(path)
    return load_handle_cached(ref)
end

"""
    _envelope_manifest() → Dict

Reproducibility manifest for the envelope `meta` (C052 / #345): MEMs
`capture_manifest` (cheap, always-on) tagged with the CLI's active `--seed`.
"""
const _BAKED_CLI_GIT_SHA = isdefined(@__MODULE__, :_BUNDLED_CLI_GIT_SHA) ?
    _BUNDLED_CLI_GIT_SHA : "unknown"
const _BAKED_GIT_SHA = (isdefined(@__MODULE__, :_BUNDLED_MANIFEST_STATIC) &&
    _BUNDLED_MANIFEST_STATIC.git_sha != "unknown") ? _BUNDLED_MANIFEST_STATIC.git_sha : _BAKED_CLI_GIT_SHA
const _BAKED_DEP_VERSIONS = let d = Dict{String,String}()
    if isdefined(@__MODULE__, :_BUNDLED_MANIFEST_STATIC)
        for (k, v) in _BUNDLED_MANIFEST_STATIC.deps
            d[String(k)] = String(v)
        end
    end
    d
end

function _envelope_manifest()
    m = MacroEconometricModels.capture_manifest(; seed=_SEED[])
    pkg_ver = (isempty(m.package_version) || m.package_version == "unknown") ?
        _cached_mems_version() : m.package_version
    deps = Dict{String,Any}()
    for (k, v) in m.dependency_versions
        ks = String(k)
        vs = String(v)
        if (isempty(vs) || vs == "unknown") && haskey(_BAKED_DEP_VERSIONS, ks)
            vs = _BAKED_DEP_VERSIONS[ks]
        end
        deps[ks] = vs
    end
    for (k, v) in _BAKED_DEP_VERSIONS
        get(deps, k, "unknown") in ("", "unknown") && (deps[k] = v)
    end
    git_sha = (isempty(m.git_sha) || m.git_sha == "unknown") ? _BAKED_GIT_SHA : m.git_sha
    return Dict{String,Any}(
        "seed"                => m.seed,
        "n_threads"           => m.n_threads,
        "julia_version"       => m.julia_version,
        "package_version"     => pkg_ver,
        "dependency_versions" => deps,
        "os"                  => m.os,
        "machine"             => m.machine,
        "timestamp"           => m.timestamp,
        "git_sha"             => git_sha,
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
    path = _validate_input_path(path)
    isfile(path) || throw(CliError("data/file-not-found", "model file not found: $path",
                                   hint="check the path"))
    magic = sniff_handle_format(path)
    if magic === :empty || magic === :unknown
        throw(CliError("data/corrupt-handle", "corrupt or empty .jld2 file: $path"))
    end
    # Check _frdc_meta header directly if HDF5 so we stay strictly header-only
    frdc_meta = if magic === :hdf5
        try
            _with_quiet_jld2() do
                JLD2.jldopen(path, "r") do f
                    haskey(f, "_frdc_meta") ? f["_frdc_meta"] : nothing
                end
            end
        catch
            nothing
        end
    else
        try
            d = open(deserialize, path)
            (d isa AbstractDict && haskey(d, "_frdc_meta")) ? d["_frdc_meta"] : nothing
        catch
            nothing
        end
    end
    header = try
        _with_quiet_jld2() do
            MacroEconometricModels.model_info(path)
        end
    catch e
        _has_supertype_named(typeof(e), :MacroModelError) && rethrow()
        throw(CliError("data/corrupt-handle", "failed to read native model file: $path",
                       hint=sprint(showerror, e)))
    end
    is_bundle = get(header, "bundle", false) === true
    if is_bundle
        entries = get(header, "entries", Dict{String,Any}())
        model_type = "bundle($(length(entries)) entries: $(join(sort!(collect(keys(entries))), ", ")))"
    else
        model_type = string(get(header, "type", "unknown"))
    end
    dims = if frdc_meta isa AbstractDict && haskey(frdc_meta, "dims")
        Dict{String,Any}(string(k) => v for (k, v) in frdc_meta["dims"])
    else
        try
            _extract_dims(load_model_dispatch(path))
        catch
            Dict{String,Any}()
        end
    end
    cli_ver = if frdc_meta isa AbstractDict && haskey(frdc_meta, "cli_version")
        string(frdc_meta["cli_version"])
    elseif magic === :hdf5
        try
            _with_quiet_jld2() do
                JLD2.jldopen(path, "r") do f
                    haskey(f, "_friedman_cli_version") ? string(f["_friedman_cli_version"]) : "n/a"
                end
            end
        catch
            "n/a"
        end
    else
        try
            d = open(deserialize, path)
            (d isa AbstractDict && haskey(d, "_friedman_cli_version")) ?
                string(d["_friedman_cli_version"]) : "n/a"
        catch
            "n/a"
        end
    end
    raw_pv = string(get(header, "package_version", ""))
    mems_ver = (isempty(raw_pv) || raw_pv == "unknown") ? _mems_version_string() : raw_pv
    note_str = string(get(header, "note", ""))
    if isempty(note_str) && frdc_meta isa AbstractDict && haskey(frdc_meta, "note")
        note_str = string(frdc_meta["note"])
    end
    return (
        path = path,
        magic = "MEMs native (jld2)",
        cli_version = cli_ver,
        mems_version = mems_ver,
        model_type = model_type,
        runtime_cli = _cli_version_string(),
        runtime_mems = _mems_version_string(),
        dimensions = dims,
        note = note_str,
    )
end
