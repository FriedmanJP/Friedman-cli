# Minimal envelope schema validator (subset of test/support.jl) for integration tests.

using JSON3

function _schema_type_ok(x, t::AbstractString)
    t == "object"  && return x isa AbstractDict || x isa JSON3.Object
    t == "array"   && return x isa AbstractVector || x isa JSON3.Array
    t == "string"  && return x isa AbstractString
    t == "integer" && return x isa Integer && !(x isa Bool)
    t == "number"  && return x isa Real && !(x isa Bool)
    t == "boolean" && return x isa Bool
    t == "null"    && return x === nothing
    return false
end

function _schema_type_ok(x, types::AbstractVector)
    return any(t -> _schema_type_ok(x, string(t)), types)
end

function validate_json_schema(doc, schema; path::String="\$")
    errors = String[]
    _validate_schema!(errors, doc, schema, path)
    return errors
end

function _validate_schema!(errors, doc, schema, path)
    schema isa AbstractDict || schema isa JSON3.Object || return
    sch = schema

    if haskey(sch, "const") || haskey(sch, :const)
        c = haskey(sch, "const") ? sch["const"] : sch[:const]
        (doc == c || string(doc) == string(c)) ||
            push!(errors, "$path: expected const $c, got $doc")
    end

    if haskey(sch, "enum") || haskey(sch, :enum)
        enum = haskey(sch, "enum") ? sch["enum"] : sch[:enum]
        vals = collect(enum)
        ok = any(e -> e == doc || string(e) == string(doc), vals)
        ok || push!(errors, "$path: value $doc not in enum $vals")
    end

    if haskey(sch, "type") || haskey(sch, :type)
        t = haskey(sch, "type") ? sch["type"] : sch[:type]
        if t isa AbstractVector || t isa JSON3.Array
            _schema_type_ok(doc, collect(t)) || push!(errors, "$path: type mismatch, expected one of $t")
        else
            _schema_type_ok(doc, string(t)) || push!(errors, "$path: type mismatch, expected $t")
        end
    end

    if (haskey(sch, "required") || haskey(sch, :required)) && (doc isa AbstractDict || doc isa JSON3.Object)
        req = haskey(sch, "required") ? sch["required"] : sch[:required]
        for r in req
            rk = string(r)
            haskey(doc, rk) || haskey(doc, Symbol(rk)) || push!(errors, "$path: missing required property '$rk'")
        end
    end

    if (haskey(sch, "properties") || haskey(sch, :properties)) && (doc isa AbstractDict || doc isa JSON3.Object)
        props = haskey(sch, "properties") ? sch["properties"] : sch[:properties]
        for (k, v) in pairs(doc)
            ks = string(k)
            if haskey(props, ks) || haskey(props, Symbol(ks))
                sub = haskey(props, ks) ? props[ks] : props[Symbol(ks)]
                _validate_schema!(errors, v, sub, "$path.$ks")
            elseif haskey(sch, "additionalProperties") || haskey(sch, :additionalProperties)
                ap = haskey(sch, "additionalProperties") ? sch["additionalProperties"] : sch[:additionalProperties]
                if ap === false
                    push!(errors, "$path: additional property '$ks' not allowed")
                elseif ap isa AbstractDict || ap isa JSON3.Object
                    _validate_schema!(errors, v, ap, "$path.$ks")
                end
            end
        end
    end

    if (haskey(sch, "items") || haskey(sch, :items)) && (doc isa AbstractVector || doc isa JSON3.Array)
        items = haskey(sch, "items") ? sch["items"] : sch[:items]
        for (i, el) in enumerate(doc)
            _validate_schema!(errors, el, items, "$path[$i]")
        end
    end

    if haskey(sch, "oneOf") || haskey(sch, :oneOf)
        alts = haskey(sch, "oneOf") ? sch["oneOf"] : sch[:oneOf]
        matched = 0
        for alt in alts
            sub_err = String[]
            _validate_schema!(sub_err, doc, alt, path)
            isempty(sub_err) && (matched += 1)
        end
        matched == 1 || push!(errors, "$path: oneOf matched $matched alternatives (want 1)")
    end
end

function validate_envelope_json(json_str::AbstractString; schema_path::String)
    schema = JSON3.read(read(schema_path, String))
    doc = JSON3.read(json_str)
    return validate_json_schema(doc, schema)
end
