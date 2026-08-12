#!/usr/bin/env python3
"""Conformant draft-07 validation of Friedman envelopes (W1/#136).

The in-repo pure-Julia validator is a deliberately small subset — and its
additionalProperties blind spot let a broken schema and unvalidated envelopes
coexist for the repo's whole life. This script is the independent second
implementation: it metaschema-checks the schema document itself, then validates
golden envelopes and (optionally) a directory of raw envelopes dumped by the T3
suite (FRIEDMAN_T3_DUMP_ENVELOPES).

Usage:
    python3 test/tools/validate_envelopes.py [--schema schema/envelope-v1.json]
        [--goldens test/golden] [--dump <dir>] [--input-schemas <dir>]

--input-schemas (W5/#140): metaschema-check every emitted per-leaf input_schema
(dumped by test/tools/dump_input_schemas.jl) as a valid draft-07 schema.

Exit non-zero on any failure, printing per-file JSON-pointer paths.
Requires: pip install jsonschema
"""

import argparse
import json
import pathlib
import sys

try:
    import jsonschema
    from jsonschema import Draft7Validator
except ImportError:  # pragma: no cover
    sys.exit("validate_envelopes.py requires the 'jsonschema' package (pip install jsonschema)")


def fail(msg: str) -> None:
    print(f"FAIL {msg}")


def validate_file(validator: Draft7Validator, path: pathlib.Path) -> int:
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        fail(f"{path}: not valid JSON: {e}")
        return 1
    errors = sorted(validator.iter_errors(doc), key=lambda e: list(e.absolute_path))
    for err in errors:
        pointer = "$" + "".join(
            f"[{p}]" if isinstance(p, int) else f".{p}" for p in err.absolute_path
        )
        fail(f"{path}: {pointer}: {err.message}")
    return len(errors)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--schema", default="schema/envelope-v1.json")
    ap.add_argument("--goldens", default="test/golden")
    ap.add_argument("--dump", default=None, help="directory of raw envelope dumps (optional)")
    ap.add_argument("--input-schemas", default=None,
                    help="directory of per-leaf input_schema dumps to metaschema-check (optional)")
    args = ap.parse_args()

    schema_path = pathlib.Path(args.schema)
    schema = json.loads(schema_path.read_text(encoding="utf-8"))

    # 1. The schema document itself must be a valid draft-07 schema.
    try:
        Draft7Validator.check_schema(schema)
    except jsonschema.SchemaError as e:
        fail(f"{schema_path}: not a valid draft-07 schema: {e.message}")
        return 1
    print(f"ok   {schema_path}: valid draft-07 schema")

    validator = Draft7Validator(schema)
    n_files = 0
    n_errors = 0

    # 2. Golden envelopes. Renderer text goldens (*.txt) are not envelopes.
    goldens = sorted(pathlib.Path(args.goldens).glob("*.json"))
    for path in goldens:
        n_files += 1
        n_errors += validate_file(validator, path)

    # 3. Raw envelope dump from the T3 suite, when provided.
    if args.dump:
        dump_dir = pathlib.Path(args.dump)
        dumped = sorted(dump_dir.glob("*.json")) if dump_dir.is_dir() else []
        if not dumped:
            # An empty dump means the hook did not fire — that is a harness
            # defect, not a pass. Silence must not look like success.
            fail(f"{dump_dir}: no dumped envelopes found")
            return 1
        for path in dumped:
            n_files += 1
            n_errors += validate_file(validator, path)

    # 4. Per-leaf input schemas (W5/#140): each must itself be a valid draft-07
    # schema. An empty directory is a harness defect, not a pass.
    if args.input_schemas:
        is_dir = pathlib.Path(args.input_schemas)
        schemas = sorted(is_dir.glob("*.json")) if is_dir.is_dir() else []
        if not schemas:
            fail(f"{is_dir}: no input schemas found")
            return 1
        for path in schemas:
            n_files += 1
            try:
                doc = json.loads(path.read_text(encoding="utf-8"))
                Draft7Validator.check_schema(doc)
            except json.JSONDecodeError as e:
                fail(f"{path}: not valid JSON: {e}")
                n_errors += 1
            except jsonschema.SchemaError as e:
                fail(f"{path}: not a valid draft-07 schema: {e.message}")
                n_errors += 1
        print(f"ok   {len(schemas)} input schema(s) metaschema-checked")

    print(f"validated {n_files} file(s): {n_errors} error(s)")
    return 1 if n_errors else 0


if __name__ == "__main__":
    sys.exit(main())
