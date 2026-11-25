#!/usr/bin/env julia
# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
# SPDX-License-Identifier: GPL-3.0-only
#
# Automated GPL-3.0-only license, Corresponding Source offer, and third-party
# SBOM bundler for standalone releases ([LICENSE-W4] #290, #291).
#
# Usage:
#   julia --project tools/gen_license_bundle.jl --app-dir <dir> [--manifest <path>] [--version <ver>] [--git-sha <sha>]

using Pkg
using JSON3
using Dates

const _REPO_ROOT = normpath(joinpath(@__DIR__, ".."))

function _detect_spdx(text::AbstractString)::String
    lt = lowercase(text)
    if occursin("gnu general public license", lt)
        if occursin("version 3", lt)
            return occursin("any later version", lt) ? "GPL-3.0-or-later" : "GPL-3.0-only"
        elseif occursin("version 2", lt)
            return occursin("any later version", lt) ? "GPL-2.0-or-later" : "GPL-2.0-only"
        end
        return "GPL"
    elseif occursin("gnu lesser general public license", lt) || occursin("gnu library general public license", lt)
        return occursin("version 3", lt) ? "LGPL-3.0-or-later" : "LGPL-2.1-or-later"
    elseif occursin("mozilla public license", lt)
        return occursin("2.0", lt) ? "MPL-2.0" : "MPL"
    elseif occursin("apache license", lt)
        return occursin("2.0", lt) ? "Apache-2.0" : "Apache"
    elseif occursin("permission is hereby granted, free of charge", lt)
        return "MIT"
    elseif occursin("permission to use, copy, modify, and/or distribute", lt)
        return "ISC"
    elseif occursin("redistribution and use in source and binary forms", lt)
        return occursin("neither the name of", lt) ? "BSD-3-Clause" : "BSD-2-Clause"
    elseif occursin("zlib", lt) && occursin("origin of this software must not be misrepresented", lt)
        return "Zlib"
    elseif occursin("unlicense", lt) || occursin("public domain", lt)
        return "Unlicense/Public-Domain"
    end
    return "See-License-Text"
end

function _find_pkg_dir(name::String, uuid_str::String, tree_sha::String)
    uuid = Base.UUID(uuid_str)
    slug = Base.version_slug(uuid, Base.SHA1(tree_sha))
    for depot in DEPOT_PATH
        d = joinpath(depot, "packages", name, slug)
        isdir(d) && return d
    end
    return nothing
end

function _collect_pkg_license_files(pkg_dir::String)::Vector{Pair{String,String}}
    hits = Pair{String,String}[]
    for fn in sort!(readdir(pkg_dir))
        p = joinpath(pkg_dir, fn)
        isfile(p) || continue
        if occursin(r"^(license|copying|notice)"i, fn)
            push!(hits, fn => read(p, String))
        end
    end
    return hits
end

function _resolve_git_sha(repo_root::String)::String
    try
        s = strip(read(pipeline(`git -C $repo_root rev-parse --short HEAD`; stderr=devnull), String))
        return isempty(s) ? "unknown" : String(s)
    catch
        return "unknown"
    end
end

function _resolve_version(repo_root::String)::String
    p = Pkg.TOML.parsefile(joinpath(repo_root, "Project.toml"))
    return string(get(p, "version", "0.0.0"))
end

function generate_license_bundle(;
    app_dir::String,
    manifest_path::String = joinpath(_REPO_ROOT, "Manifest.toml"),
    version::String = _resolve_version(_REPO_ROOT),
    git_sha::String = _resolve_git_sha(_REPO_ROOT),
    strict::Bool = true,
)
    isdir(app_dir) || mkpath(app_dir)
    lic_dir = joinpath(app_dir, "share", "licenses")
    jl_lic_dir = joinpath(lic_dir, "julia")
    mkpath(lic_dir)
    mkpath(jl_lic_dir)

    # 1. Root GPL-3.0 LICENSE
    root_lic = joinpath(_REPO_ROOT, "LICENSE")
    isfile(root_lic) || error("Missing root LICENSE at $root_lic")
    cp(root_lic, joinpath(app_dir, "LICENSE"); force=true)

    # 2. Comonicon license & DATA_LICENSES.md
    comonicon_lic = joinpath(_REPO_ROOT, "src", "cli", "COMONICON_LICENSE")
    isfile(comonicon_lic) || error("Missing COMONICON_LICENSE at $comonicon_lic")
    cp(comonicon_lic, joinpath(lic_dir, "COMONICON_LICENSE"); force=true)

    data_lic = joinpath(_REPO_ROOT, "DATA_LICENSES.md")
    isfile(data_lic) || error("Missing DATA_LICENSES.md at $data_lic")
    cp(data_lic, joinpath(lic_dir, "DATA_LICENSES.md"); force=true)

    # 3. Julia runtime LICENSE.md & THIRDPARTY.md
    jroot = normpath(joinpath(Sys.BINDIR, ".."))
    jl_lic_src = nothing
    for rel in ("LICENSE.md", joinpath("share", "doc", "julia", "LICENSE.md"))
        cand = joinpath(jroot, rel)
        if isfile(cand)
            jl_lic_src = cand
            break
        end
    end
    jl_lic_src === nothing && error("Could not locate Julia LICENSE.md under $jroot")
    cp(jl_lic_src, joinpath(jl_lic_dir, "LICENSE.md"); force=true)

    jl_tp_src = nothing
    for rel in ("THIRDPARTY.md", joinpath("share", "doc", "julia", "THIRDPARTY.md"))
        cand = joinpath(jroot, rel)
        if isfile(cand)
            jl_tp_src = cand
            break
        end
    end
    if jl_tp_src !== nothing
        cp(jl_tp_src, joinpath(jl_lic_dir, "THIRDPARTY.md"); force=true)
    else
        write(joinpath(jl_lic_dir, "THIRDPARTY.md"), """
# Julia $(VERSION) Third-Party Runtime Notices

Julia $(VERSION) consolidates its runtime third-party component license notices
(LLVM, OpenBLAS, LibUV, PCRE2, OpenLibm, GMP, MPFR, SuiteSparse, libgit2,
libcurl, libssh2, Zlib, etc.) inside `LICENSE.md` in this same directory
(`share/licenses/julia/LICENSE.md`).
""")
    end

    # 4. Walk Manifest.toml for all non-stdlib packages
    isfile(manifest_path) || error("Missing Manifest.toml at $manifest_path")
    manifest = Pkg.TOML.parsefile(manifest_path)
    deps_dict = get(manifest, "deps", Dict{String,Any}())
    pkg_sbom = Dict{String,Any}[]
    missing_pkgs = String[]
    pkg_texts = Tuple{String,String,String,String,Vector{Pair{String,String}}}[]

    for pkg_name in sort!(collect(keys(deps_dict)))
        for entry in deps_dict[pkg_name]
            tree_sha = get(entry, "git-tree-sha1", nothing)
            tree_sha === nothing && continue # Julia stdlib (covered by Julia LICENSE.md)
            ver = string(get(entry, "version", "unknown"))
            uuid_str = string(entry["uuid"])
            pdir = _find_pkg_dir(pkg_name, uuid_str, string(tree_sha))
            files = pdir === nothing ? Pair{String,String}[] : _collect_pkg_license_files(pdir)
            if isempty(files)
                push!(missing_pkgs, "$pkg_name@$ver ($uuid_str)")
                continue
            end
            spdx = _detect_spdx(files[1].second)
            push!(pkg_sbom, Dict{String,Any}(
                "name" => pkg_name,
                "version" => ver,
                "uuid" => uuid_str,
                "git_tree_sha1" => string(tree_sha),
                "license" => spdx,
                "license_files" => [first(f) for f in files],
            ))
            push!(pkg_texts, (pkg_name, ver, uuid_str, spdx, files))
        end
    end

    if strict && !isempty(missing_pkgs)
        error("Missing LICENSE files for Manifest package(s): $(join(missing_pkgs, ", "))")
    end

    # 5. Walk bundled JLL artifacts under <app_dir>/share/julia/artifacts/*/share/licenses/
    art_root = joinpath(app_dir, "share", "julia", "artifacts")
    art_sbom = Dict{String,Any}[]
    art_texts = Tuple{String,String,String,String}[] # (artifact_hash, component, filename, content)
    if isdir(art_root)
        for ah in sort!(readdir(art_root))
            lsub = joinpath(art_root, ah, "share", "licenses")
            isdir(lsub) || continue
            for (r, _, fs) in walkdir(lsub)
                for fn in sort!(fs)
                    fp = joinpath(r, fn)
                    rel = relpath(fp, lsub)
                    comp = first(splitpath(rel))
                    txt = read(fp, String)
                    spdx = _detect_spdx(txt)
                    push!(art_sbom, Dict{String,Any}(
                        "artifact_hash" => ah,
                        "component" => comp,
                        "file" => rel,
                        "license" => spdx,
                    ))
                    push!(art_texts, (ah, comp, rel, txt))
                end
            end
        end
    end

    # 6. Vendored components (in Friedman-cli and MacroEconometricModels.jl)
    vendored = [
        Dict{String,Any}(
            "name" => "Comonicon.jl (CLI help formatting excerpts)",
            "path" => "src/cli/COMONICON_LICENSE",
            "license" => "MIT",
            "upstream" => "https://github.com/comonicon/Comonicon.jl",
            "notice" => read(comonicon_lic, String),
        ),
        Dict{String,Any}(
            "name" => "PackageCompiler.jl embedding_wrapper.c (frdc_driver.c)",
            "path" => "packaging/c_driver/frdc_driver.c",
            "license" => "MIT",
            "upstream" => "https://github.com/JuliaLang/PackageCompiler.jl",
            "notice" => "Copyright (c) 2018-2026 Kristoffer Carlsson and contributors. MIT License.",
        ),
        Dict{String,Any}(
            "name" => "miniz 3.0.2 tinfl (single-header inflate)",
            "path" => "packaging/thin_wrapper/miniz_tinfl.h",
            "license" => "MIT",
            "upstream" => "https://github.com/richgel999/miniz",
            "notice" => "Copyright 2013-2014 RAD Game Tools and Valve Software; Copyright 2010-2014 Rich Geldreich and Tenacious Software LLC. MIT License.",
        ),
        Dict{String,Any}(
            "name" => "yyjson 0.11.1 (JSON-RPC 2.0 parser for lazy MCP proxy)",
            "path" => "packaging/thin_wrapper/yyjson.h, packaging/thin_wrapper/yyjson.c",
            "license" => "MIT",
            "upstream" => "https://github.com/ibireme/yyjson",
            "notice" => "Copyright (c) 2020 YaoYuan <ibireme@gmail.com>. MIT License.",
        ),
        Dict{String,Any}(
            "name" => "D3.js 7.8.5 (inlined HTML plot asset via MacroEconometricModels.jl)",
            "path" => "MacroEconometricModels/src/plotting/assets/d3.v7.min.js",
            "license" => "ISC",
            "upstream" => "https://d3js.org",
            "notice" => "Copyright 2010-2023 Mike Bostock. ISC License.",
        ),
        Dict{String,Any}(
            "name" => "X-13ARIMA-SEATS v1.1 Build 62 (pure-Julia port via MacroEconometricModels.jl)",
            "path" => "MacroEconometricModels/src/x13/",
            "license" => "Public-Domain-US-Gov",
            "upstream" => "https://www.census.gov/data/software/x13as.html",
            "notice" => "US Census Bureau (17 U.S.C. § 105 public domain in the US; royalty-free nonexclusive license worldwide).",
        ),
    ]

    # 7. Write share/licenses/THIRD_PARTY_LICENSES.md
    tp_path = joinpath(lic_dir, "THIRD_PARTY_LICENSES.md")
    open(tp_path, "w") do io
        println(io, "# Third-Party Licenses & Notices — Friedman-cli v$(version)")
        println(io)
        println(io, "`Friedman-cli` (`frdc`) is licensed under the **GNU General Public License v3.0 (`GPL-3.0-only`)**.")
        println(io, "See `LICENSE` (root), `SOURCE_OFFER.txt` (GPLv3 §6 / MPL-2.0 §3.2(b) Corresponding Source),")
        println(io, "`share/licenses/DATA_LICENSES.md` (bundled example datasets), and `share/licenses/julia/LICENSE.md`.")
        println(io)
        println(io, "---")
        println(io)
        println(io, "## 1. Vendored Source & Asset Notices")
        println(io)
        for v in vendored
            println(io, "### $(v["name"]) ($(v["license"]))")
            println(io)
            println(io, "- **Path:** `$(v["path"])`")
            println(io, "- **Upstream:** $(v["upstream"])")
            println(io)
            println(io, "```text")
            println(io, strip(v["notice"]))
            println(io, "```")
            println(io)
        end
        println(io, "---")
        println(io)
        println(io, "## 2. Julia Runtime")
        println(io)
        println(io, "- **Version:** Julia $(VERSION) (`$(Sys.MACHINE)`)")
        println(io, "- **Full runtime & stdlib notices:** `share/licenses/julia/LICENSE.md` and `share/licenses/julia/THIRDPARTY.md`")
        println(io)
        println(io, "---")
        println(io)
        println(io, "## 3. Resolved Julia Packages ($(length(pkg_texts)) non-stdlib packages from Manifest.toml)")
        println(io)
        println(io, "| Package | Version | Detected License | UUID |")
        println(io, "| :--- | :--- | :--- | :--- |")
        for (nm, ver, uuid_s, spdx, _) in pkg_texts
            println(io, "| `$(nm)` | `$(ver)` | `$(spdx)` | `$(uuid_s)` |")
        end
        println(io)
        for (nm, ver, uuid_s, spdx, files) in pkg_texts
            println(io, "### $(nm) v$(ver) (`$(spdx)`)")
            println(io)
            for (fn, txt) in files
                println(io, "**File:** `$(fn)`")
                println(io)
                println(io, "```text")
                println(io, strip(txt))
                println(io, "```")
                println(io)
            end
        end
        if !isempty(art_texts)
            println(io, "---")
            println(io)
            println(io, "## 4. Bundled Binary JLL Artifact Licenses ($(length(art_texts)) files)")
            println(io)
            for (ah, comp, rel, txt) in art_texts
                println(io, "### Artifact `$(comp)` (`$(rel)`, hash `$(ah[1:min(12, end)])`)")
                println(io)
                println(io, "```text")
                println(io, strip(txt))
                println(io, "```")
                println(io)
            end
        end
    end

    # 8. Write machine-readable share/licenses/sbom-licenses.json
    sbom_path = joinpath(lic_dir, "sbom-licenses.json")
    sbom = Dict{String,Any}(
        "schema" => "friedman-sbom-licenses-v1",
        "product" => "Friedman-cli",
        "binary" => "frdc",
        "version" => version,
        "git_sha" => git_sha,
        "license" => "GPL-3.0-only",
        "julia_version" => string(VERSION),
        "machine" => string(Sys.MACHINE),
        "vendored" => [Dict("name" => v["name"], "path" => v["path"],
                            "license" => v["license"], "upstream" => v["upstream"]) for v in vendored],
        "packages" => pkg_sbom,
        "artifacts" => art_sbom,
        "data_licenses" => "share/licenses/DATA_LICENSES.md",
        "source_offer" => "SOURCE_OFFER.txt",
    )
    open(sbom_path, "w") do io
        JSON3.pretty(io, sbom)
        println(io)
    end

    # 9. Write SOURCE_OFFER.txt (GPLv3 §6(b)/(d) + MPL-2.0 §3.2(b))
    offer_path = joinpath(app_dir, "SOURCE_OFFER.txt")
    mems_ver = let found = "1.1.1"
        for p in pkg_sbom
            p["name"] == "MacroEconometricModels" && (found = p["version"]; break)
        end
        found
    end
    write(offer_path, """
CORRESPONDING SOURCE OFFER — Friedman-cli (frdc) v$(version)
================================================================

License: GNU General Public License, version 3 (GPL-3.0-only)
Commit:  $(git_sha)
Julia:   $(VERSION) ($(Sys.MACHINE))
MEMs:    MacroEconometricModels.jl v$(mems_ver)

1. GPL-3.0 §6(d) Network Server Access to Corresponding Source
--------------------------------------------------------------
Complete Corresponding Source for this binary release — including the
Friedman-cli source tree, build scripts (build_release.jl, packaging/),
pure C99 thin wrapper (packaging/thin_wrapper/), exact resolved
Manifest.toml, and third-party license SBOM — is publicly hosted at:

  - Friedman-cli repository & release tag:
      https://github.com/FriedmanJP/Friedman-cli
      https://github.com/FriedmanJP/Friedman-cli/releases/tag/v$(version)
  - MacroEconometricModels.jl (GPL-3.0-only):
      https://github.com/FriedmanJP/MacroEconometricModels.jl/releases/tag/v$(mems_ver)
  - Julia runtime ($(VERSION)):
      https://github.com/JuliaLang/julia
  - Binary JLL build recipes & upstream source archives (Yggdrasil):
      https://github.com/JuliaPackaging/Yggdrasil
      (covers FFTW, Rmath-julia, SuiteSparse, NLopt, GMP, MPFR,
       OpenBLAS, OpenSpecFun, OpenSSL, LibGit2, libcurl, libssh2,
       PCRE2, p7zip, Zlib, Zstd, Bzip2, and GCC runtime libraries)

2. MPL-2.0 §3.2(b) Source Code Form Notice
------------------------------------------
This standalone distribution conveys executable code derived from
Mozilla Public License 2.0 (MPL-2.0) Julia packages (including JuMP,
NLPModels, SolverCore, LinearOperators, LDLFactorizations, AMD, Krylov,
and MutableArithmetics — all without Exhibit B incompatibilities).
Exact package versions, UUIDs, and git-tree-sha1 hashes are recorded in
the attached Manifest.toml and share/licenses/sbom-licenses.json; their
Source Code Form is publicly available via the Julia General Registry
(https://github.com/JuliaRegistries/General) and each package's upstream
repository listed in share/licenses/THIRD_PARTY_LICENSES.md.

3. GPL-3.0 §6(b) Written Offer (Valid for at Least Three Years)
---------------------------------------------------------------
If you received this binary without immediate network access to the
Corresponding Source above, FriedmanJP offers to provide anyone who
possesses this object code a complete machine-readable copy of the
Corresponding Source on a durable physical medium or via electronic
transfer for no more than the reasonable cost of physically performing
the conveyance. This offer is valid for at least three (3) years from
the date of distribution of this release (and for as long as FriedmanJP
offers spare parts or customer support for this release).

To request Corresponding Source, contact:
  Wookyung Chung <chung@friedman.jp>
  https://github.com/FriedmanJP/Friedman-cli/issues
""")

    return (
        app_dir = app_dir,
        n_packages = length(pkg_sbom),
        n_artifacts = length(art_sbom),
        tp_path = tp_path,
        sbom_path = sbom_path,
        offer_path = offer_path,
    )
end

function _parse_args(args::Vector{String})
    app_dir = joinpath(_REPO_ROOT, "build", "frdc")
    manifest = joinpath(_REPO_ROOT, "Manifest.toml")
    version = _resolve_version(_REPO_ROOT)
    git_sha = _resolve_git_sha(_REPO_ROOT)
    strict = true
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--app-dir" && i + 1 <= length(args)
            app_dir = abspath(args[i + 1]); i += 2
        elseif a == "--manifest" && i + 1 <= length(args)
            manifest = abspath(args[i + 1]); i += 2
        elseif a == "--version" && i + 1 <= length(args)
            version = args[i + 1]; i += 2
        elseif a == "--git-sha" && i + 1 <= length(args)
            git_sha = args[i + 1]; i += 2
        elseif a == "--no-strict"
            strict = false; i += 1
        else
            error("Unknown option: $a")
        end
    end
    return (; app_dir, manifest, version, git_sha, strict)
end

if abspath(PROGRAM_FILE) == @__FILE__
    opts = _parse_args(ARGS)
    res = generate_license_bundle(;
        app_dir = opts.app_dir,
        manifest_path = opts.manifest,
        version = opts.version,
        git_sha = opts.git_sha,
        strict = opts.strict,
    )
    println("Generated license bundle in $(res.app_dir): " *
            "$(res.n_packages) Manifest packages, $(res.n_artifacts) JLL artifact license files.")
end
