# CliError taxonomy + stable exit codes (P1-4; F23, F24, F62)

"""
    CliError(code, message; hint="")

Typed CLI error. Exit class is derived from the code prefix:

| Prefix   | Exit code | Meaning        |
|----------|-----------|----------------|
| usage/*  | 2         | CLI usage      |
| data/*   | 3         | Input data     |
| config/* | 4         | Config/TOML    |
| model/*  | 5         | Model/domain   |
| env/*    | 6         | Environment    |
| other    | 1         | Internal/bug   |
"""
struct CliError <: Exception
    code::String
    message::String
    hint::String
end
CliError(code::String, message::String; hint::String="") = CliError(code, message, hint)

const _EXIT_CLASSES = Dict(
    "usage" => 2,
    "data" => 3,
    "config" => 4,
    "model" => 5,
    "env" => 6,
)

"""Map a CliError to its process exit code (2–6, or 1 for unprefixed)."""
function exit_class(e::CliError)
    prefix = first(split(e.code, '/'; limit=2))
    return get(_EXIT_CLASSES, prefix, 1)
end

function Base.showerror(io::IO, e::CliError)
    print(io, e.code, ": ", e.message)
    isempty(e.hint) || print(io, " (hint: ", e.hint, ")")
end
