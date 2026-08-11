# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Input-Output analysis (C049 / P5-4). Wraps the MEMs `io` module:
#   sources | download | load | leontief | ghosh | multipliers | linkages |
#   key-sectors | sda | extract | footprint | baqaee-farhi
#
# IO result types are NOT Tables.jl-registered in MEMs (no `DataFrame(result)` /
# `long_table(result)`), so io leaves render via hand-built tables — a documented
# C051 fallback path (like the Arias/Uhlig/volatility leaves). Square matrices
# (Leontief/Ghosh inverses, technical/allocation coefficients) render WIDE
# (sector×sector); vector-valued results render as per-sector row tables.
#
# Every non-download leaf runs offline: with no `--data`, the bundled
# `load_example(:wiot)` Miller & Blair 2-sector fixture (with employment + CO2
# satellite accounts) is used. `io download` is the only network-touching leaf.

# ── Shared option groups ─────────────────────────────────────

"Input options shared by every analysis leaf (CSV path / bundled example / labels)."
const IO_INPUT_OPTIONS = [
    OptionSpec(name="data", type=String, default="",
               description="IO table: CSV path, :wiot (bundled example, the default), or another :example"),
    OptionSpec(name="n-sectors", type=Int, default=0,
               description="Number of sectors (CSV: Z is the first n_sectors columns)"),
    OptionSpec(name="n-fd", type=Int, default=1,
               description="Number of final-demand columns (CSV)"),
    OptionSpec(name="sectors", type=String, default="",
               description="Comma-separated sector labels (CSV; default: sector1..sectorN)"),
]

function io_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["io", "sources"],
            summary="List downloadable IO/MRIO sources (offline catalog)",
            args=ArgSpec[],
            options=copy(OUTPUT_OPTIONS),
            tables=[TableSpec(name=:io_mrio_sources,
                              description="Known IO/MRIO sources with available versions and credential requirements")],
            category="io", handler=wrap_legacy(_io_sources),
        ),
        CommandSpec(
            path=["io", "download"],
            summary="Download an IO/MRIO table (network); respects --offline",
            args=ArgSpec[],
            options=[
                OptionSpec(name="source", type=String, default="",
                           choices=["oecd", "wiod", "exiobase3", "eora26", "gloria"],
                           description="oecd|wiod|exiobase3|eora26|gloria"),
                OptionSpec(name="storage", type=String, default="",
                           description="Destination folder for downloaded archives (required)"),
                # Named --source-version, NOT --version: that is a reserved
                # pre-dispatch global (#117) and the old spelling was swallowed
                # by it on every invocation (printed the CLI version, exit 0).
                OptionSpec(name="source-version", type=String, default="",
                           description="Source version (e.g. OECD v2023)"),
                OptionSpec(name="years", type=String, default="",
                           description="Comma-separated year filter (default: all)"),
                OptionSpec(name="system", type=String, default="pxp",
                           choices=["pxp", "ixi"],
                           description="EXIOBASE product-by-product|industry-by-industry"),
                OptionSpec(name="email", type=String, default="",
                           description="Account email (EORA26 only)"),
                OptionSpec(name="password", type=String, default="",
                           description="Account password (EORA26 only)"),
                OUTPUT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="offline", description="Refuse network access (exit 6 env/network)"),
                FlagSpec(name="overwrite", description="Re-download files that already exist"),
                FlagSpec(name="no-verify", description="Skip SHA-256 checksum verification"),
            ],
            tables=[
                TableSpec(name=:download_summary,
                          description="Source, resolved version and number of files fetched"),
                TableSpec(name=:download_log,
                          description="One row per fetched file: source URL and local filename"),
            ],
            category="io", handler=wrap_legacy(_io_download),
        ),
        CommandSpec(
            path=["io", "load"],
            summary="Parse/inspect an IO table: dimensions, balance, per-sector totals",
            args=ArgSpec[],
            options=[IO_INPUT_OPTIONS..., OUTPUT_OPTIONS...],
            tables=[TableSpec(name=:io_table_summary,
                              description="Sector/region/category counts, year, unit, source, extensions and total output"),
                    TableSpec(name=:sectors,
                              description="Per-sector gross output, final demand and value added")],
            category="io", handler=wrap_legacy(_io_load),
        ),
        CommandSpec(
            path=["io", "leontief"],
            summary="Leontief (demand-driven) representation: A and inverse L",
            args=ArgSpec[],
            options=[IO_INPUT_OPTIONS...,
                OptionSpec(name="matrix", type=String, default="L", choices=["L", "A", "both"],
                           description="L = Leontief inverse | A = technical coefficients | both"),
                OUTPUT_OPTIONS...],
            tables=[
                TableSpec(name=:technical_coefficients_a,
                          description="Technical coefficient matrix A, sector by sector (--matrix A|both)"),
                TableSpec(name=:leontief_inverse_l,
                          description="Leontief inverse L, sector by sector (--matrix L|both)"),
            ],
            category="io", handler=wrap_legacy(_io_leontief),
        ),
        CommandSpec(
            path=["io", "ghosh"],
            summary="Ghosh (supply-driven) representation: B and inverse G",
            args=ArgSpec[],
            options=[IO_INPUT_OPTIONS...,
                OptionSpec(name="matrix", type=String, default="G", choices=["G", "B", "both"],
                           description="G = Ghosh inverse | B = allocation coefficients | both"),
                OUTPUT_OPTIONS...],
            tables=[
                TableSpec(name=:allocation_coefficients_b,
                          description="Allocation coefficient matrix B, sector by sector (--matrix B|both)"),
                TableSpec(name=:ghosh_inverse_g,
                          description="Ghosh inverse G, sector by sector (--matrix G|both)"),
            ],
            category="io", handler=wrap_legacy(_io_ghosh),
        ),
        CommandSpec(
            path=["io", "multipliers"],
            summary="Sectoral output/income/employment multipliers (Type I & II)",
            args=ArgSpec[],
            options=[IO_INPUT_OPTIONS...,
                OptionSpec(name="kind", type=String, default="output",
                           choices=["output", "income", "employment"],
                           description="output|income|employment"),
                OptionSpec(name="type", type=String, default="I", choices=["I", "II"],
                           description="Type I (open) | Type II (household-closed)"),
                OUTPUT_OPTIONS...],
            tables=[TableSpec(name=:io_multipliers,
                              description="Per-sector multiplier of the requested kind and type")],
            category="io", handler=wrap_legacy(_io_multipliers),
        ),
        CommandSpec(
            path=["io", "linkages"],
            summary="Backward/forward linkages + Rasmussen dispersion indices",
            args=ArgSpec[],
            options=[IO_INPUT_OPTIONS...,
                OptionSpec(name="forward", type=String, default="ghosh",
                           choices=["ghosh", "leontief"],
                           description="Forward linkage basis: ghosh (row sums of G) | leontief"),
                OUTPUT_OPTIONS...],
            tables=[TableSpec(name=:linkages,
                              description="Per-sector backward and forward linkages, Rasmussen Ui/Uj and class")],
            category="io", handler=wrap_legacy(_io_linkages),
        ),
        CommandSpec(
            path=["io", "key-sectors"],
            summary="Key-sector classification (Rasmussen quadrants)",
            args=ArgSpec[],
            options=[IO_INPUT_OPTIONS...,
                OptionSpec(name="forward", type=String, default="ghosh",
                           choices=["ghosh", "leontief"],
                           description="Forward linkage basis: ghosh | leontief"),
                OUTPUT_OPTIONS...],
            tables=[TableSpec(name=:key_sectors,
                              description="Per-sector key/forward/backward/weak quadrant classification")],
            category="io", handler=wrap_legacy(_io_key_sectors),
        ),
        CommandSpec(
            path=["io", "sda"],
            summary="Structural decomposition of Δoutput between two periods",
            args=ArgSpec[],
            options=[IO_INPUT_OPTIONS...,
                OptionSpec(name="data2", type=String, default="",
                           description="Second-period IO table (CSV path / :example; default: same as --data)"),
                OptionSpec(name="method", type=String, default="additive",
                           choices=["additive", "multiplicative"],
                           description="additive (exact, zero residual) | multiplicative"),
                OUTPUT_OPTIONS...],
            tables=[TableSpec(name=:structural_decomposition,
                              description="Per-sector technology (L) and final-demand (Y) effects, total and residual")],
            category="io", handler=wrap_legacy(_io_sda),
        ),
        CommandSpec(
            path=["io", "extract"],
            summary="Hypothetical extraction: output loss from removing sector(s)",
            args=ArgSpec[],
            options=[IO_INPUT_OPTIONS...,
                OptionSpec(name="sectors-extract", type=String, default="",
                           description="Sector(s) to extract: names or 1-based indices, comma-separated (required)"),
                OUTPUT_OPTIONS...],
            tables=[TableSpec(name=:hypothetical_extraction_loss,
                              description="Per-sector output loss caused by extracting the target sector(s)")],
            category="io", handler=wrap_legacy(_io_extract),
        ),
        CommandSpec(
            path=["io", "footprint"],
            summary="Consumption-based footprint of a satellite (environmental) account",
            args=ArgSpec[],
            options=[IO_INPUT_OPTIONS...,
                OptionSpec(name="account", type=String, default="",
                           description="Satellite account name (default: first available, e.g. CO2)"),
                OUTPUT_OPTIONS...],
            flags=[FlagSpec(name="detail",
                            description="Also emit intensities (S) and emission multipliers (M=SL)")],
            tables=[TableSpec(name=:footprint,
                              description="Consumption-based footprint total per stressor"),
                    TableSpec(name=:footprint_by_sector,
                              description="Per-sector footprint contribution, one column per stressor"),
                    TableSpec(name=:intensities_s,
                              description="Direct stressor intensities S by sector (--detail only)"),
                    TableSpec(name=:emission_multipliers,
                              description="Total emission multipliers M=SL by sector (--detail only)")],
            category="io", handler=wrap_legacy(_io_footprint),
        ),
        CommandSpec(
            path=["io", "baqaee-farhi"],
            summary="Baqaee & Farhi (2019) nonlinear IO: Domar weights, centralities",
            args=ArgSpec[],
            options=[IO_INPUT_OPTIONS...,
                OptionSpec(name="theta", type=Float64, default=1.0,
                           description="Production substitution elasticity (1 = Cobb-Douglas ⇒ Hulten exact)"),
                OptionSpec(name="sigma", type=Float64, default=1.0,
                           description="Consumption substitution elasticity (1 = Cobb-Douglas)"),
                OUTPUT_OPTIONS...],
            flags=[FlagSpec(name="second-order",
                            description="Also emit the second-order 'beyond Hulten' Hessian (sector×sector)")],
            tables=[TableSpec(name=:baqaee_farhi_2019_decomposition,
                              description="Per-sector Domar weight, influence, upstreamness and downstreamness"),
                    TableSpec(name=:second_order_hessian_beyond_hulten,
                              description="Second-order 'beyond Hulten' Hessian, sector by sector (--second-order only)")],
            category="io", handler=wrap_legacy(_io_baqaee_farhi),
        ),
    ]
end

function register_io_commands!()
    specs = io_specs()
    register!(specs)
    return build_node("io", specs;
        description="Input-Output analysis: Leontief/Ghosh, multipliers, linkages, SDA, footprints")
end

# ── Shared helpers ───────────────────────────────────────────

"""
    _load_io(data; n_sectors, n_fd, sectors, delim) → IOData

Load an [`IOData`] table. Empty / `:wiot` → the bundled Miller & Blair example
(offline). Another `:name` → that example (must be IO-typed). A file path is
parsed with `parse_io`, which needs `--n-sectors` (and reads `Z` from the first
`n_sectors` columns, the next `n_fd` as final demand).
"""
function _load_io(data::String; n_sectors::Int=0, n_fd::Int=1,
                  sectors::String="", delim::String=",")
    if isempty(data) || data == ":wiot" || data == "wiot"
        return load_example(:wiot)
    end
    if startswith(data, ":")
        name = Symbol(replace(data[2:end], "-" => "_"))
        io = try
            load_example(name)
        catch e
            e isa ArgumentError && throw(CliError("usage/unknown-example", _err_message(e);
                hint="use :wiot for the bundled IO example, or a CSV path with --n-sectors"))
            rethrow()
        end
        io isa IOData || throw(CliError("data/not-io",
            "example :$name is not an Input-Output table";
            hint="use :wiot or an IO CSV via --data path --n-sectors N"))
        return io
    end
    isfile(data) || throw(CliError("data/file-not-found", "file not found: $data";
                                   hint="check the path, or omit --data to use the bundled :wiot example"))
    n_sectors > 0 || throw(CliError("usage/missing-option",
        "--n-sectors is required to parse an IO CSV";
        hint="Z is read from the first n_sectors columns, the next n_fd as final demand"))
    secs = _split_csv(sectors)
    dchar = isempty(delim) ? ',' : first(delim)
    return try
        parse_io(data; source=:csv, n_sectors=n_sectors, n_fd=n_fd,
                 sectors=secs, delim=dchar)
    catch e
        (e isa BoundsError || e isa ArgumentError) && throw(CliError("data/parse",
            "failed to parse IO CSV '$data': $(_err_message(e))";
            hint="check --n-sectors/--n-fd against the file: Z is the first n_sectors columns, then n_fd final-demand columns"))
        rethrow()
    end
end

"Split a comma-separated option into trimmed non-empty tokens."
_split_csv(s::AbstractString) = String[strip(t) for t in split(s, ",") if !isempty(strip(t))]

"""
    _io_matrix_df(M, rowlabels, collabels=rowlabels) → DataFrame

Render a matrix WIDE: first column `sector` holds the row labels, then one
numeric column per `collabels` entry (rounded). Columns are made unique if the
labels collide (real MRIO tables occasionally repeat sector names across regions).
"""
function _io_matrix_df(M::AbstractMatrix, rowlabels::Vector{String},
                       collabels::Vector{String}=rowlabels)
    df = DataFrame()
    df[!, :sector] = rowlabels
    used = Set{String}(["sector"])   # reserve the row-label column
    for (j, c) in enumerate(collabels)
        col = c; k = 1
        while col in used            # bump past collisions (dups, pre-suffixed, "sector")
            k += 1
            col = "$(c)_$(k)"
        end
        push!(used, col)
        df[!, Symbol(col)] = round.(M[:, j]; digits=6)
    end
    return df
end

# ── Handlers ─────────────────────────────────────────────────

function _io_sources(; format::String="table", output::String="")
    t = list_io_sources()
    src = String[]; nm = String[]; vers = String[]; cred = String[]; note = String[]
    for (k, v) in t.rows
        push!(src, string(k)); push!(nm, v.name)
        push!(vers, join(v.versions, ", "))
        push!(cred, v.needs_credentials ? "yes" : "no")
        push!(note, v.note)
    end
    df = DataFrame(source=src, name=nm, versions=vers, credentials=cred, note=note)
    output_result(df; format=Symbol(format), output=output, title="IO/MRIO Sources")
end

function _io_download(; source::String="", storage::String="", source_version::String="",
                      years::String="", system::String="pxp",
                      email::String="", password::String="",
                      offline::Bool=false, overwrite::Bool=false, no_verify::Bool=false,
                      format::String="table", output::String="")
    isempty(source) && throw(CliError("usage/missing-option",
        "--source is required"; hint="one of oecd|wiod|exiobase3|eora26|gloria (see `io sources`)"))
    isempty(storage) && throw(CliError("usage/missing-option",
        "--storage <folder> is required (download destination)"))

    if offline || _offline_env()
        throw(CliError("env/network",
            "network access disabled (--offline); refusing to download :$source";
            hint="drop --offline (and unset FRIEDMAN_OFFLINE) to allow the download"))
    end

    src = Symbol(source)
    yrs = _parse_years(years)
    ver = isempty(source_version) ? nothing : source_version

    _status("Downloading :$source → $storage" *
            (isempty(source_version) ? "" : " (version=$source_version)"))
    # Forward source-specific kwargs only where the per-source downloader accepts
    # them: `system` → exiobase3 only; `verify` → every source except eora26 (which
    # takes neither). download_io relays extras verbatim, so over-forwarding is a
    # MethodError, not a no-op.
    extra = src === :exiobase3 ? (; system=system, verify=!no_verify) :
            src === :eora26    ? NamedTuple() :
                                 (; verify=!no_verify)
    meta = try
        download_io(src; storage_folder=storage, years=yrs, version=ver,
                    email=email, password=password, overwrite_existing=overwrite, extra...)
    catch e
        throw(_map_download_error(e, source))
    end

    output_kv([
        "source" => meta.source,
        "version" => meta.version,
        "files" => string(length(meta.files)),
    ]; format=Symbol(format), output=output, title="Download Summary")

    if !isempty(meta.files)
        df = DataFrame(url=String[first(p) for p in meta.files],
                       filename=String[last(p) for p in meta.files])
        output_result(df; format=Symbol(format), output=output, title="Download Log")
    else
        for h in meta.history
            _status("  ", h)
        end
    end
    return meta
end

function _io_load(; data::String="", n_sectors::Int=0, n_fd::Int=1, sectors::String="",
                  format::String="table", output::String="")
    io = _load_io(data; n_sectors=n_sectors, n_fd=n_fd, sectors=sectors)
    # nsectors/nregions are internal (unexported) MEMs helpers — compute inline.
    n_reg = length(io.regions)
    n_sec = length(io.sectors) ÷ max(1, n_reg)

    output_kv([
        "sectors" => string(n_sec),
        "regions" => string(n_reg),
        "fd_categories" => string(length(io.fd_cats)),
        "va_categories" => string(length(io.va_cats)),
        "year" => io.year === nothing ? "—" : string(io.year),
        "unit" => isempty(io.unit) ? "—" : io.unit,
        "source" => isempty(io.source) ? "—" : io.source,
        "extensions" => isempty(io.extensions) ? "—" : join(sort(collect(keys(io.extensions))), ", "),
        "total_output" => string(round(sum(io.x); digits=4)),
    ]; format=Symbol(format), output=output, title="IO Table Summary")

    fd_tot = vec(sum(io.Y, dims=2))
    va_tot = vec(sum(io.va, dims=1))
    df = DataFrame(sector=io.sectors,
                   gross_output=round.(io.x; digits=6),
                   final_demand=round.(fd_tot; digits=6),
                   value_added=round.(va_tot; digits=6))
    output_result(df; format=Symbol(format), output=output, title="Sectors")
    return io
end

function _io_leontief(; data::String="", n_sectors::Int=0, n_fd::Int=1, sectors::String="",
                      matrix::String="L", format::String="table", output::String="")
    io = _load_io(data; n_sectors=n_sectors, n_fd=n_fd, sectors=sectors)
    m = leontief(io)
    if matrix in ("A", "both")
        output_result(_io_matrix_df(m.A, io.sectors);
                      format=Symbol(format), output=output, title="Technical Coefficients (A)")
    end
    if matrix in ("L", "both")
        output_result(_io_matrix_df(m.L, io.sectors);
                      format=Symbol(format), output=output, title="Leontief Inverse (L)")
    end
    return m
end

function _io_ghosh(; data::String="", n_sectors::Int=0, n_fd::Int=1, sectors::String="",
                   matrix::String="G", format::String="table", output::String="")
    io = _load_io(data; n_sectors=n_sectors, n_fd=n_fd, sectors=sectors)
    m = ghosh(io)
    if matrix in ("B", "both")
        output_result(_io_matrix_df(m.B, io.sectors);
                      format=Symbol(format), output=output, title="Allocation Coefficients (B)")
    end
    if matrix in ("G", "both")
        output_result(_io_matrix_df(m.G, io.sectors);
                      format=Symbol(format), output=output, title="Ghosh Inverse (G)")
    end
    return m
end

function _io_multipliers(; data::String="", n_sectors::Int=0, n_fd::Int=1, sectors::String="",
                         kind::String="output", type::String="I",
                         format::String="table", output::String="")
    io = _load_io(data; n_sectors=n_sectors, n_fd=n_fd, sectors=sectors)
    m = try
        multipliers(io; kind=Symbol(kind), type=Symbol(type))
    catch e
        e isa ArgumentError && throw(CliError("data/no-extension", _err_message(e);
            hint="employment multipliers need an 'employment' satellite account (present in :wiot; a plain CSV table has none)"))
        rethrow()
    end
    df = DataFrame(sector=m.sectors, multiplier=round.(m.values; digits=6))
    output_result(df; format=Symbol(format), output=output,
                  title="Type $(type) $(kind) multipliers", key="io_multipliers")
    return m
end

function _io_linkages(; data::String="", n_sectors::Int=0, n_fd::Int=1, sectors::String="",
                      forward::String="ghosh", format::String="table", output::String="")
    io = _load_io(data; n_sectors=n_sectors, n_fd=n_fd, sectors=sectors)
    lk = linkages(io; forward=Symbol(forward))
    df = DataFrame(sector=lk.sectors,
                   backward=round.(lk.backward; digits=6),
                   forward=round.(lk.forward; digits=6),
                   Ui=round.(lk.Ui; digits=6),
                   Uj=round.(lk.Uj; digits=6),
                   class=string.(lk.classification))
    output_result(df; format=Symbol(format), output=output,
                  title="Linkages (forward=$forward)", key="linkages")
    return lk
end

function _io_key_sectors(; data::String="", n_sectors::Int=0, n_fd::Int=1, sectors::String="",
                         forward::String="ghosh", format::String="table", output::String="")
    io = _load_io(data; n_sectors=n_sectors, n_fd=n_fd, sectors=sectors)
    lk = linkages(io; forward=Symbol(forward))
    df = DataFrame(sector=lk.sectors, class=string.(lk.classification))
    output_result(df; format=Symbol(format), output=output, title="Key Sectors")
    # Quadrant counts to stderr (diagnostic, not part of the data envelope).
    counts = Dict{Symbol,Int}()
    for c in lk.classification
        counts[c] = get(counts, c, 0) + 1
    end
    _status("Key-sector quadrants: " *
            join(["$(k)=$(get(counts, k, 0))" for k in (:key, :forward, :backward, :weak)], ", "))
    return lk
end

function _io_sda(; data::String="", data2::String="", n_sectors::Int=0, n_fd::Int=1,
                 sectors::String="", method::String="additive",
                 format::String="table", output::String="")
    io0 = _load_io(data; n_sectors=n_sectors, n_fd=n_fd, sectors=sectors)
    io1 = _load_io(isempty(data2) ? data : data2;
                   n_sectors=n_sectors, n_fd=n_fd, sectors=sectors)
    r = sda(io0, io1; method=Symbol(method))
    df = DataFrame(sector=io0.sectors,
                   L_effect=round.(r.effects[:L]; digits=6),
                   Y_effect=round.(r.effects[:Y]; digits=6),
                   total=round.(r.total; digits=6),
                   residual=round.(r.residual; digits=6))
    output_result(df; format=Symbol(format), output=output,
                  title="Structural Decomposition ($method)", key="structural_decomposition")
    return r
end

function _io_extract(; data::String="", n_sectors::Int=0, n_fd::Int=1, sectors::String="",
                     sectors_extract::String="", format::String="table", output::String="")
    io = _load_io(data; n_sectors=n_sectors, n_fd=n_fd, sectors=sectors)
    isempty(sectors_extract) && throw(CliError("usage/missing-option",
        "--sectors-extract is required (sector name(s) or 1-based index/indices, comma-separated)"))
    toks = _split_csv(sectors_extract)
    n = length(io.sectors)
    target = if all(t -> tryparse(Int, t) !== nothing, toks)
        idx = [parse(Int, t) for t in toks]
        for i in idx
            (1 <= i <= n) || throw(CliError("data/bad-sector",
                "sector index $i out of range (1:$n)";
                hint="valid indices 1:$n, or use sector names: $(join(io.sectors, ", "))"))
        end
        idx
    else
        toks
    end
    r = try
        hypothetical_extraction(io, target)
    catch e
        (e isa ArgumentError || e isa BoundsError) && throw(CliError("data/bad-sector",
            _err_message(e); hint="valid sectors: $(join(io.sectors, ", "))"))
        rethrow()
    end
    extracted_labels = [io.sectors[i] for i in r.extracted]
    _status("Extracted sector(s): $(join(extracted_labels, ", "))")
    _status("Total output loss: $(round(r.total_loss; digits=6))")
    _status()
    df = DataFrame(sector=io.sectors, output_loss=round.(r.sector_loss; digits=6))
    output_result(df; format=Symbol(format), output=output,
                  title="Hypothetical Extraction (loss)")
    return r
end

function _io_footprint(; data::String="", n_sectors::Int=0, n_fd::Int=1, sectors::String="",
                       account::String="", detail::Bool=false,
                       format::String="table", output::String="")
    io = _load_io(data; n_sectors=n_sectors, n_fd=n_fd, sectors=sectors)
    isempty(io.extensions) && throw(CliError("data/no-extension",
        "IO table has no satellite accounts; footprint needs an extension (e.g. CO2)";
        hint="the bundled :wiot example carries CO2 and employment accounts"))
    name = isempty(account) ? first(sort(collect(keys(io.extensions)))) : account
    haskey(io.extensions, name) || throw(CliError("data/no-extension",
        "no satellite account '$name'";
        hint="available: $(join(sort(collect(keys(io.extensions))), ", "))"))

    fp = footprint(io, name)
    # Total footprint per stressor (summed over final-demand categories).
    tot = vec(sum(fp.total; dims=2))
    output_result(DataFrame(stressor=fp.stressors, footprint=round.(tot; digits=6));
                  format=Symbol(format), output=output, title="Footprint ($name)", key="footprint")
    # Per-sector contribution: sector × stressor(s).
    output_result(_io_matrix_df(permutedims(fp.by_sector), io.sectors, fp.stressors);
                  format=Symbol(format), output=output, title="Footprint by Sector ($name)",
                  key="footprint_by_sector")

    if detail
        output_result(_io_matrix_df(permutedims(intensities(io, name)), io.sectors, fp.stressors);
                      format=Symbol(format), output=output, title="Intensities S ($name)",
                      key="intensities_s")
        output_result(_io_matrix_df(permutedims(emission_multipliers(io, name)), io.sectors, fp.stressors);
                      format=Symbol(format), output=output, title="Emission Multipliers M=SL ($name)",
                      key="emission_multipliers")
    end
    return fp
end

function _io_baqaee_farhi(; data::String="", n_sectors::Int=0, n_fd::Int=1, sectors::String="",
                          theta::Float64=1.0, sigma::Float64=1.0, second_order::Bool=false,
                          format::String="table", output::String="")
    io = _load_io(data; n_sectors=n_sectors, n_fd=n_fd, sectors=sectors)
    bf = baqaee_farhi(io; theta=theta, sigma=sigma)
    df = DataFrame(sector=bf.sectors,
                   domar=round.(bf.domar; digits=6),
                   influence=round.(bf.influence; digits=6),
                   upstreamness=round.(bf.upstreamness; digits=6),
                   downstreamness=round.(bf.downstreamness; digits=6))
    output_result(df; format=Symbol(format), output=output,
                  title="Baqaee & Farhi (2019) decomposition")
    if second_order
        output_result(_io_matrix_df(bf.second_order, io.sectors);
                      format=Symbol(format), output=output, title="Second-order Hessian (beyond Hulten)")
    end
    return bf
end

# ── Download support ─────────────────────────────────────────

"True when the environment forces offline mode (FRIEDMAN_OFFLINE=1|true)."
_offline_env() = lowercase(get(ENV, "FRIEDMAN_OFFLINE", "")) in ("1", "true", "yes")

"Parse a comma-separated year filter into a Vector{Int} (or nothing for 'all')."
function _parse_years(years::String)
    isempty(years) && return nothing
    toks = _split_csv(years)
    isempty(toks) && return nothing
    out = Int[]
    for t in toks
        y = tryparse(Int, t)
        y === nothing && throw(CliError("usage/bad-years",
            "invalid --years value '$t' (expected comma-separated integers, e.g. 2018,2019)"))
        push!(out, y)
    end
    return out
end

"""Map a download failure to a typed CliError: checksum mismatch → env/checksum-mismatch
(#250); unknown source/version/credentials → usage; anything else → env/network."""
function _map_download_error(e, source::String)
    e isa CliError && return e
    msg = _err_message(e)
    if occursin("checksum mismatch", lowercase(msg)) || occursin("has been substituted", msg)
        return CliError("env/checksum-mismatch",
            "downloaded archive failed SHA-256 verification: $msg";
            hint="the file is corrupt or substituted; retry, or --no-verify to bypass (unsafe)")
    elseif e isa ArgumentError
        return CliError("usage/bad-argument", msg; hint="see `io sources` for valid source/version")
    end
    return CliError("env/network", "download of :$source failed: $msg";
                    hint="check connectivity, the source URL set, or run later")
end
