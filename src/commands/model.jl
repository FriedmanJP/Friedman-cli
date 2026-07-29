# Top-level `model` commands — inspect .jld2 (native, C052) and .fmod (interim) handles

function _model_info(; path::String="", data::String="",
                      output::String="", format::String="table")
    # positional may bind as `path` or (legacy) first free; accept either
    p = !isempty(path) ? path : data
    isempty(p) && throw(CliError("usage/missing-arg", "model info requires a .jld2 or .fmod path"))
    info = endswith(lowercase(p), ".jld2") ? _native_model_info(p) : model_handle_info(p)
    rows = DataFrame(
        field = ["path", "magic", "model_type", "cli_version", "mems_version",
                 "runtime_cli", "runtime_mems", "dimensions"],
        value = [
            info.path,
            info.magic,
            info.model_type,
            info.cli_version,
            info.mems_version,
            info.runtime_cli,
            info.runtime_mems,
            string(info.dimensions),
        ],
    )
    output_result(rows; format=Symbol(format), output=output, title="Model Handle Info")
    return info
end

function model_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["model", "info"],
            summary="Inspect a model handle (.jld2 native or .fmod interim): type, versions, dimensions",
            args=[ArgSpec(name="path", type=String, required=true, default=nothing,
                          description="Path to .jld2 or .fmod handle")],
            options=[
                OptionSpec(name="output", short="o", type=String, default="",
                           description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           choices=["table", "csv", "json"], description="table|csv|json"),
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:model_info, description="Handle metadata")],
            category="model",
            handler=wrap_legacy(_model_info),
        ),
    ]
end

function register_model_commands!()
    specs = model_specs()
    register!(specs)
    return build_node("model", specs; description="Model handles: inspect .jld2 (native) and .fmod (interim) files")
end
