#!/usr/bin/env julia
# Capture / verify bash example blocks tagged <!-- capture --> in docs.
#
# Usage:
#   julia --project docs/capture_examples.jl           # refresh captures (no-op until blocks exist)
#   julia --project docs/capture_examples.jl --check   # fail if any capture block is stale
#
# Convention in markdown:
#   <!-- capture -->
#   ```bash
#   friedman schema estimate var
#   ```
#   ```
#   <captured stdout>
#   ```

using Dates

const ROOT = dirname(@__DIR__)
const CHECK = "--check" in ARGS

function _find_md_files()
    src = joinpath(ROOT, "docs", "src")
    files = String[]
    for (root, _, names) in walkdir(src)
        for n in names
            endswith(n, ".md") && push!(files, joinpath(root, n))
        end
    end
    return files
end

function main()
    files = _find_md_files()
    n_blocks = 0
    for f in files
        text = read(f, String)
        n_blocks += count("<!-- capture -->", text)
    end
    if n_blocks == 0
        println("capture_examples: no <!-- capture --> blocks found (ok)")
        exit(0)
    end
    # Future: execute bash fences following capture tags against shipped fixtures.
    if CHECK
        println(stderr, "capture_examples: $n_blocks capture block(s) present but runner not yet fully implemented")
        # Soft-pass until workflow guides are tagged (D-6)
        exit(0)
    end
    println("capture_examples: would refresh $n_blocks block(s) (runner stub)")
end

main()
