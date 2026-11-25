# Top-level `model` commands — inspect .jld2 (native, C052) and .fmod (interim) handles

function _model_info(; path::String="", data::String="",
                      output::String="", format::String="table")
    # positional may bind as `path` or (legacy) first free; accept either
    p = !isempty(path) ? path : data
    isempty(p) && throw(CliError("usage/missing-arg", "model info requires a .jld2, .jls, .fmod, or session URI path"))
    info = if _is_session_uri(p)
        entry = session_store_get_entry(p)
        meta = entry.meta
        (path=p, magic="session ($(entry.namespace)://)",
         cli_version=string(get(meta, "cli_version", _cli_version_string())),
         mems_version=string(get(meta, "mems_version", _mems_version_string())),
         model_type=string(get(meta, "type_name", string(nameof(typeof(entry.payload))))),
         runtime_cli=_cli_version_string(), runtime_mems=_mems_version_string(),
         dimensions=get(meta, "dims", _model_dims(entry.payload)),
         note=string(get(meta, "note", "")))
    else
        p = resolve_stem(p; slot=:model)
        lc = lowercase(p)
        endswith(lc, ".jld2") ? _native_model_info(p) :
        endswith(lc, ".jls")  ? _jls_model_info(p) :
                                model_handle_info(p)
    end
    fields = ["path", "magic", "model_type", "cli_version", "mems_version",
              "runtime_cli", "runtime_mems", "dimensions"]
    values = [
        info.path,
        info.magic,
        info.model_type,
        info.cli_version,
        info.mems_version,
        info.runtime_cli,
        info.runtime_mems,
        string(info.dimensions),
    ]
    # W3/#167: the native header carries a free-form note (bundle label / vintage).
    # `.fmod` handles have no note — the row is native-only, never empty filler.
    if :note in propertynames(info) && !isempty(info.note)
        push!(fields, "note")
        push!(values, info.note)
    end
    rows = DataFrame(field=fields, value=values)
    output_result(rows; format=Symbol(format), output=output, title="Model Handle Info")
    return info
end

"""
    _model_reproduce(; model, format, output)

Verify a saved handle against a fresh re-run: `reproduce(model)` re-estimates
from the `ReproManifest` seed recorded by `--seed` and compares field-by-field
(W3/#167, MEMs#769/#786). `matched=true` is bit-for-bit equality;
`matched=missing` (no recorded seed, or a type upstream never implemented
`reproduce` for — MEMs 0.9.3 answers those with a universal missing-verdict
fallback instead of throwing) is an honest "cannot verify", not a pass.
Exit is 0 in all these cases; only an unloadable handle errors.
Works on any loadable handle — `.jld2`, `.fmod`, or a `model://` session handle.
"""
function _model_reproduce(; path::String="", data::String="", source_model::String="",
                            output::String="", format::String="table")
    # NB: the positional is `path`, not `model` — wrap_legacy reserves the
    # `model=` kwarg for its --model handle injection (a `.jld2` value there
    # would arrive as a loaded object and break the String binding).
    p = !isempty(path) ? path : data
    isempty(p) && throw(CliError("usage/missing-arg",
        "model reproduce requires a handle path (.jld2, .jls, .fmod, or model://)"))
    p = _is_session_uri(p) ? p : resolve_stem(p; slot=:model)
    obj = load_model_dispatch(p)
    rep = try
        if obj isa ImpulseResponse
            src = if !isempty(source_model)
                sp = _is_session_uri(source_model) ? source_model :
                     resolve_stem(source_model; slot=:model)
                m_obj = load_model_dispatch(sp)
                m_obj isa VARModel || throw(CliError("model/wrong-kind",
                    "source model must be a VARModel for ImpulseResponse reproduction (got $(nameof(typeof(m_obj))))"))
                m_obj
            else
                load_source_model(p)
            end
            src isa VARModel ? MacroEconometricModels.reproduce(obj, src) :
                              MacroEconometricModels.reproduce(obj)
        else
            MacroEconometricModels.reproduce(obj)
        end
    catch e
        e isa CliError && rethrow()
        # Defense-in-depth only: MEMs 0.9.3's universal reproduce(x) fallback
        # means this branch is unreachable there (unsupported types report a
        # missing verdict above). It guards a future upstream fallback removal.
        e isa MethodError && (e.f === MacroEconometricModels.reproduce) && throw(CliError(
            "model/unsupported",
            "reproduce is not defined for $(typeof(obj))";
            hint="only randomized results estimated with seed= carry a ReproManifest " *
                 "that reproduce can re-run — re-estimate with --seed"))
        rethrow()
    end
    verdict = if rep.matched === missing
        obj isa VARModel ? "deterministic (no RNG)" : "unverifiable (no recorded seed)"
    else
        string(rep.matched)
    end
    summary = DataFrame(
        field=["handle", "model_type", "matched", "seed", "threads", "note"],
        value=[
            p,
            string(nameof(typeof(obj))),
            verdict,
            rep.seed === nothing ? "none recorded" : string(rep.seed),
            "$(rep.threads_captured) → $(rep.threads_current)",
            isempty(rep.note) ? "(none)" : rep.note,
        ],
    )
    output_result(summary; format=Symbol(format), output=output,
                  title="Reproduce Verification",
                  key="model_reproduce_summary")
    if !isempty(rep.fields)
        diffs = DataFrame(
            field=[string(d.name) for d in rep.fields],
            matched=[d.matched for d in rep.fields],
            max_abs_diff=[d.max_abs_diff for d in rep.fields],
        )
        output_result(diffs; format=Symbol(format),
                      output=_per_var_output_path(output, "fields"),
                      title="Reproduce Field Comparison",
                      key="model_reproduce_fields")
    end
    return rep
end

function model_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["model", "info"],
            summary="Inspect a model handle (.jld2 native, .fmod interim, or model:// session handle): type, versions, dimensions",
            args=[ArgSpec(name="path", type=String, required=true, default=nothing,
                          description="Path to .jld2/.fmod handle or model:// session handle")],
            options=[
                OptionSpec(name="output", short="o", type=String, default="",
                           description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           choices=["table", "csv", "json"], description="table|csv|json"),
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:model_handle_info,
                              description="Handle path, magic, model type, writing and runtime versions, dimensions")],
            category="model",
            handler=wrap_legacy(_model_info),
        ),
        CommandSpec(
            path=["model", "reproduce"],
            summary="Verify a saved handle by re-running its estimator from the recorded seed (reports unverifiable when no seed is recorded)",
            args=[ArgSpec(name="path", type=String, required=true, default=nothing,
                          description="Handle path (.jld2, .jls, .fmod, or model:// session handle)")],
            options=[
                OptionSpec(name="model", type=String, default="", kwarg=:source_model,
                           description="Optional source VARModel handle for two-argument reproduce (e.g. bootstrap ImpulseResponse)"),
                OptionSpec(name="output", short="o", type=String, default="",
                           description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           choices=["table", "csv", "json"], description="table|csv|json"),
            ],
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:model_reproduce_summary,
                          description="Handle, model type, match verdict, recorded seed, thread counts, note"),
                TableSpec(name=:model_reproduce_fields,
                          description="Per-field re-run comparison (present when the report has field diffs)"),
            ],
            category="model",
            handler=wrap_legacy(_model_reproduce),
        ),
    ]
end

function register_model_commands!()
    specs = with_default_csv_kinds(model_specs())
    specs = register!(specs)
    return build_node("model", specs; description="Model handles: inspect and reproduce-verify .jld2, .jls, .fmod, and model:// session handles")
end
