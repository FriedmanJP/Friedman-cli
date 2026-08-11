# Envelope schema validation for integration tests — thin shim over the single
# shared validator (W1/#136; this file was previously a drifted copy of the
# test/support.jl validator, and both copies carried the same
# additionalProperties-without-properties blind spot).

using JSON3

include(joinpath(@__DIR__, "..", "schema_validator.jl"))

function validate_envelope_json(json_str::AbstractString; schema_path::String)
    schema = JSON3.read(read(schema_path, String))
    doc = JSON3.read(json_str)
    return validate_json_schema(doc, schema)
end
