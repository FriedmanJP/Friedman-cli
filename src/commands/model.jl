# Top-level `model` commands — inspect, reproduce, convert, and list keys on
# .jld2 (native/plain), .jls (serialized), .fmod (legacy), and session URI handles.

function _model_info(; path::String="", data::String="",
                      deep::Bool=false, show_keys::Bool=false,
                      output::String="", format::String="table")
    # positional may bind as `path` or (legacy) first free; accept either
    p = !isempty(path) ? path : data
    isempty(p) && throw(CliError("usage/missing-arg",
        "model info requires a .jld2, .jls, .fmod, or session URI path"))
    if show_keys
        return _model_keys(; path=p, output=output, format=format)
    end
    info = if _is_session_uri(p)
        entry = session_store_get_entry(p)
        meta = entry.meta
        ukeys = entry.payload isa AbstractDict ? sort!(String[string(k) for k in keys(entry.payload)]) : String[]
        (path=p, magic="session ($(entry.namespace)://)",
         cli_version=string(get(meta, "cli_version", _cli_version_string())),
         mems_version=string(get(meta, "mems_version", _mems_version_string())),
         model_type=string(get(meta, "type_name", string(nameof(typeof(entry.payload))))),
         kind=string(get(meta, "kind", _storage_kind_tag(entry.payload))),
         runtime_cli=_cli_version_string(), runtime_mems=_mems_version_string(),
         dimensions=get(meta, "dims", _extract_dims(entry.payload)),
         note=string(get(meta, "note", "")),
         has_provenance=(entry.source_model !== nothing || !isempty(get(meta, "provenance", Dict()))),
         keys=ukeys)
    else
        p = resolve_stem(p; slot=:model)
        base_p, _ = _split_key_selector(p)
        lc = lowercase(base_p)
        endswith(lc, ".jld2") ? _native_model_info(p; deep=deep) :
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
    if :kind in propertynames(info) && !isempty(info.kind)
        push!(fields, "kind")
        push!(values, string(info.kind))
    end
    if :has_provenance in propertynames(info)
        push!(fields, "has_provenance")
        push!(values, string(info.has_provenance))
    end
    if :keys in propertynames(info) && !isempty(info.keys)
        push!(fields, "keys")
        push!(values, join(info.keys, ", "))
    end
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
    _model_keys(; path, output, format)

List selectable `#key` entries in a multi-key plain `.jld2` archive, MEMs
`ModelBundle`, `.jls` Dict handle, or session URI without loading unrelated
payloads (#309).
"""
function _model_keys(; path::String="", data::String="",
                      output::String="", format::String="table")
    p = !isempty(path) ? path : data
    isempty(p) && throw(CliError("usage/missing-arg",
        "model keys requires a .jld2, .jls, or session URI path"))
    entries = _inspect_handle_keys(p)
    df = DataFrame(
        key      = [e.key for e in entries],
        selector = [e.selector for e in entries],
        type     = [e.type for e in entries],
        dims     = [e.dims for e in entries],
    )
    output_result(df; format=Symbol(format), output=output,
                  title="Archive Keys", key="model_keys")
    return entries
end

"""
    _model_convert(; path, output, to, note, format)

Convert any loadable handle (legacy `.fmod`, `.jls`, `.jld2`, `archive.jld2#key`,
or session URI) atomically to canonical `.jld2` or `.jls`, preserving `note`,
`varnames`, `dims`, and `source_model` provenance (#309).
"""
function _model_convert(; path::String="", data::String="",
                         output::String="", to::String="",
                         note::String="", format::String="table")
    p = !isempty(path) ? path : data
    isempty(p) && throw(CliError("usage/missing-arg",
        "model convert requires a source handle path (.fmod, .jls, .jld2, or session URI)"))
    if !isempty(to) && !(lowercase(to) in ("jld2", "jls"))
        throw(CliError("usage/invalid",
            "model convert: --to must be jld2 or jls (got '$to')"))
    end
    src_resolved = _is_session_uri(p) ? p : resolve_stem(p; slot=:model)
    src_fmt = _detect_handle_format_label(src_resolved)

    # Read existing note and source_model provenance before loading
    existing_note = ""
    try
        info = if _is_session_uri(src_resolved)
            e = session_store_get_entry(src_resolved)
            (note=string(get(e.meta, "note", "")),)
        else
            base_s, _ = _split_key_selector(src_resolved)
            lc = lowercase(base_s)
            endswith(lc, ".jld2") ? _native_model_info(src_resolved) :
            endswith(lc, ".jls")  ? _jls_model_info(src_resolved) :
                                    (note="",)
        end
        existing_note = :note in propertynames(info) ? String(info.note) : ""
    catch
    end
    final_note = !isempty(note) ? note : existing_note

    obj = load_model_dispatch(src_resolved)
    src_model = load_source_model(src_resolved)
    meta = isdefined(@__MODULE__, :_lookup_handle_meta) ? _lookup_handle_meta(obj) : nothing
    if meta isa AbstractDict && haskey(meta, "varnames") && !isempty(meta["varnames"])
        _set_save_meta!(; varnames=meta["varnames"])
    end

    # Resolve target destination path
    dest_raw = if !isempty(output)
        d = String(output)
        if !isempty(to) && !_is_session_uri(d) && isempty(_known_ext(_expanduser(d)))
            d * "." * lowercase(to)
        else
            d
        end
    elseif !isempty(to)
        _is_session_uri(src_resolved) && throw(CliError("usage/missing-option",
            "model convert from a session URI requires -o <output-path>"))
        base_s, _ = _split_key_selector(src_resolved)
        stem = replace(base_s, r"\.(jld2|jls|fmod)$"i => "")
        stem * "." * lowercase(to)
    else
        throw(CliError("usage/missing-option",
            "model convert requires -o <output-path> or --to jld2|jls"))
    end

    dest_ref = resolve_write_ref(dest_raw; default_ext=(isempty(to) ? ".jld2" : "." * lowercase(to)),
                                 create_parents=true)
    written = save_handle!(dest_ref, obj; note=final_note, source_model=src_model)
    tgt_fmt = _detect_handle_format_label(written)

    summary = DataFrame(
        field = ["source", "destination", "source_format", "target_format",
                 "model_type", "note", "preserved_provenance"],
        value = [
            src_resolved,
            written,
            src_fmt,
            tgt_fmt,
            string(nameof(typeof(obj))),
            isempty(final_note) ? "(none)" : final_note,
            string(src_model !== nothing),
        ],
    )
    output_result(summary; format=Symbol(format), output="",
                  title="Model Handle Conversion", key="model_convert_summary")
    return written
end

"""
    _model_reproduce(; path, source_model, tol, format, output)

Verify a saved handle against a fresh re-run across `.jld2`, `.jls`, `.fmod`,
and session URIs (#309). Supports upstream `MacroEconometricModels.reproduce`
(1-arg and 2-arg) plus attached source-model reproduction for VAR, BVAR, LP,
StructuralLP, VECM, FEVD, HD, and Forecast handles.
"""
function _model_reproduce(; path::String="", data::String="", source_model::String="",
                            tol::Float64=1e-10,
                            output::String="", format::String="table")
    p = !isempty(path) ? path : data
    isempty(p) && throw(CliError("usage/missing-arg",
        "model reproduce requires a handle path (.jld2, .jls, .fmod, or model://)"))
    p = _is_session_uri(p) ? p : resolve_stem(p; slot=:model)
    obj = load_model_dispatch(p)
    rep = reproduce_handle(obj, p; source_model=source_model, tol=tol)
    verdict = if rep.matched === missing
        obj isa VARModel ? "deterministic (no RNG)" : "unverifiable (no recorded seed)"
    else
        string(rep.matched)
    end
    summary = DataFrame(
        field=["handle", "model_type", "format", "matched", "max_abs_diff",
               "seed", "source_command", "tol", "threads", "note"],
        value=[
            p,
            string(nameof(typeof(obj))),
            rep.format,
            verdict,
            string(rep.max_abs_diff),
            rep.seed === nothing ? "none recorded" : string(rep.seed),
            isempty(rep.source_command) ? "(none)" : rep.source_command,
            string(rep.tol),
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
            summary="Header-only handle inspection (.jld2 native/plain, .jls, .fmod, #key, session URIs): type, versions, dimensions, provenance",
            args=[ArgSpec(name="path", type=String, required=true, default=nothing,
                          description="Path to .jld2/.jls/.fmod handle (with optional #key) or session URI")],
            options=[
                OptionSpec(name="output", short="o", type=String, default="",
                           description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           choices=["table", "csv", "json"], description="table|csv|json"),
            ],
            flags=[
                FlagSpec(name="deep",
                         description="Opt into full deserialization to compute dimensions on legacy handles lacking _frdc_meta"),
                FlagSpec(name="keys", kwarg=:show_keys,
                         description="List selectable #key entries in multi-key .jld2 or bundle archives"),
            ],
            tables=[
                TableSpec(name=:model_handle_info,
                          description="Handle path, magic, model type, writing and runtime versions, dimensions, kind, provenance"),
                TableSpec(name=:model_keys,
                          description="Archive/bundle keys when --keys is passed"),
            ],
            category="model",
            handler=wrap_legacy(_model_info),
        ),
        CommandSpec(
            path=["model", "keys"],
            summary="List selectable #key entries in a multi-key .jld2 archive, MEMs bundle, .jls Dict, or session handle",
            args=[ArgSpec(name="path", type=String, required=true, default=nothing,
                          description="Path to .jld2/.jls handle or session URI")],
            options=[
                OptionSpec(name="output", short="o", type=String, default="",
                           description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           choices=["table", "csv", "json"], description="table|csv|json"),
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:model_keys,
                              description="Key name, #key selector, entry type and dimensions")],
            category="model",
            handler=wrap_legacy(_model_keys),
        ),
        CommandSpec(
            path=["model", "convert"],
            summary="Convert a handle between formats (.fmod/.jls/.jld2/archive#key/session URI -> .jld2 or .jls) preserving note & provenance",
            args=[ArgSpec(name="path", type=String, required=true, default=nothing,
                          description="Source handle path (.fmod, .jls, .jld2, archive.jld2#key, or session URI)")],
            options=[
                OptionSpec(name="output", short="o", type=String, default="",
                           description="Destination handle path (e.g. modern.jld2 or out.jls)"),
                OptionSpec(name="to", type=String, default="", choices=["", "jld2", "jls"],
                           description="Target format when deriving path or adding extension: jld2|jls"),
                OptionSpec(name="note", type=String, default="",
                           description="Optional note override (default: preserve source handle note)"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           choices=["table", "csv", "json"], description="table|csv|json"),
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:model_convert_summary,
                              description="Source, destination, formats, model type, note and provenance preservation status")],
            category="model",
            handler=wrap_legacy(_model_convert),
        ),
        CommandSpec(
            path=["model", "reproduce"],
            summary="Verify a saved handle by re-running its estimator from recorded seed/provenance across .jld2, .jls, .fmod, and session URIs",
            args=[ArgSpec(name="path", type=String, required=true, default=nothing,
                          description="Handle path (.jld2, .jls, .fmod, or session URI)")],
            options=[
                OptionSpec(name="model", type=String, default="", kwarg=:source_model,
                           description="Optional source model handle for two-argument reproduce (e.g. bootstrap ImpulseResponse)"),
                OptionSpec(name="tol", type=Float64, default=1e-10,
                           description="Numeric equality tolerance for CLI-derived comparisons"),
                OptionSpec(name="output", short="o", type=String, default="",
                           description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           choices=["table", "csv", "json"], description="table|csv|json"),
            ],
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:model_reproduce_summary,
                          description="Handle, model type, format, match verdict, max_abs_diff, recorded seed, source command, tolerance, thread counts, note"),
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
    return build_node("model", specs;
        description="Model handles: inspect, list keys, convert, and reproduce-verify .jld2, .jls, .fmod, and session handles")
end
