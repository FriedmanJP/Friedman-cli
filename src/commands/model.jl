# Top-level `model` commands — inspect .fmod handles (C029 / P2-7)

function _model_info(; path::String="", data::String="",
                      output::String="", format::String="table")
    # positional may bind as `path` or (legacy) first free; accept either
    p = !isempty(path) ? path : data
    isempty(p) && throw(CliError("usage/missing-arg", "model info requires a .fmod path"))
    info = model_handle_info(p)
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
            summary="Inspect a .fmod model handle (type, versions, dimensions)",
            args=[ArgSpec(name="path", type=String, required=true, default=nothing,
                          description="Path to .fmod handle")],
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
    return build_node("model", specs; description="Model handles: inspect .fmod files")
end
