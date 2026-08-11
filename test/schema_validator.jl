# ── Pure-Julia JSON Schema draft-07 subset validator (single source) ──
#
# Included by BOTH test/support.jl (T1/T2 + goldens) and
# test/integration/schema_validate.jl (T3) — W1/#136 deduplicated the two
# previously-drifted copies into this file. The includer must have JSON3 loaded.
#
# Supported keywords: type (incl. type arrays) · required · enum · const ·
# properties · additionalProperties (schema or false) · items · oneOf · pattern.
# `if`/`then` is deliberately absent: the envelope expresses its one conditional
# (status ↔ error co-occurrence) as a top-level oneOf over `const` statuses,
# which this subset already handles (#136 D-3 decision).
#
# History note (#136): until W1, the additionalProperties branch was nested
# INSIDE the `properties` loop, so a schema carrying only additionalProperties
# (the envelope's `data` and `meta`) was never validated at all — which is why
# the ambiguous pre-W1 `data` oneOf went unnoticed by every tier. The negative
# unit tests in test/runtests.jl pin both defects.

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

_schema_get(sch, key::String) =
    haskey(sch, key) ? sch[key] : (haskey(sch, Symbol(key)) ? sch[Symbol(key)] : nothing)
_schema_has(sch, key::String) = haskey(sch, key) || haskey(sch, Symbol(key))

"""Validate `doc` against a JSON Schema (draft-07 subset). Returns list of error strings (empty = ok)."""
function validate_json_schema(doc, schema; path::String="\$")
    errors = String[]
    _validate_schema!(errors, doc, schema, path)
    return errors
end

function _validate_schema!(errors, doc, schema, path)
    schema isa AbstractDict || schema isa JSON3.Object || return
    sch = schema

    if _schema_has(sch, "const")
        c = _schema_get(sch, "const")
        (doc == c || string(doc) == string(c)) ||
            push!(errors, "$path: expected const $c, got $doc")
    end

    if _schema_has(sch, "enum")
        vals = collect(_schema_get(sch, "enum"))
        ok = any(e -> e == doc || string(e) == string(doc), vals)
        ok || push!(errors, "$path: value $doc not in enum $vals")
    end

    if _schema_has(sch, "type")
        t = _schema_get(sch, "type")
        if t isa AbstractVector || t isa JSON3.Array
            _schema_type_ok(doc, collect(t)) || push!(errors, "$path: type mismatch, expected one of $t")
        else
            _schema_type_ok(doc, string(t)) || push!(errors, "$path: type mismatch, expected $t")
        end
    end

    # draft-07: `pattern` constrains strings only; other types ignore it.
    if _schema_has(sch, "pattern") && doc isa AbstractString
        pat = string(_schema_get(sch, "pattern"))
        occursin(Regex(pat), doc) ||
            push!(errors, "$path: string \"$doc\" does not match pattern $pat")
    end

    if _schema_has(sch, "required") && (doc isa AbstractDict || doc isa JSON3.Object)
        for r in _schema_get(sch, "required")
            rk = string(r)
            haskey(doc, rk) || haskey(doc, Symbol(rk)) ||
                push!(errors, "$path: missing required property '$rk'")
        end
    end

    # properties AND/OR additionalProperties — additionalProperties applies to
    # every key not matched by `properties`, whether or not `properties` exists.
    if doc isa AbstractDict || doc isa JSON3.Object
        has_props = _schema_has(sch, "properties")
        has_ap = _schema_has(sch, "additionalProperties")
        if has_props || has_ap
            props = has_props ? _schema_get(sch, "properties") : nothing
            for (k, v) in pairs(doc)
                ks = string(k)
                if props !== nothing && (haskey(props, ks) || haskey(props, Symbol(ks)))
                    sub = haskey(props, ks) ? props[ks] : props[Symbol(ks)]
                    _validate_schema!(errors, v, sub, "$path.$ks")
                elseif has_ap
                    ap = _schema_get(sch, "additionalProperties")
                    if ap === false
                        push!(errors, "$path: additional property '$ks' not allowed")
                    elseif ap isa AbstractDict || ap isa JSON3.Object
                        _validate_schema!(errors, v, ap, "$path.$ks")
                    end
                end
            end
        end
    end

    if _schema_has(sch, "items") && (doc isa AbstractVector || doc isa JSON3.Array)
        items = _schema_get(sch, "items")
        for (i, el) in enumerate(doc)
            _validate_schema!(errors, el, items, "$path[$i]")
        end
    end

    if _schema_has(sch, "oneOf")
        alts = _schema_get(sch, "oneOf")
        matched = 0
        for alt in alts
            sub_err = String[]
            _validate_schema!(sub_err, doc, alt, path)
            isempty(sub_err) && (matched += 1)
        end
        matched == 1 || push!(errors, "$path: oneOf matched $matched alternatives (want 1)")
    end
end
