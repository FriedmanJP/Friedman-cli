# TEMPORARY diagnostic for PR #205 (`data simulate ct` fails in T3 on Linux,
# passes on macOS). Prints the full error envelope + upstream stacktrace.
# DELETE AFTER DIAGNOSIS (do not merge).
using Friedman
using JSON3
using LinearAlgebra
import MacroEconometricModels

println("=== environment ===")
println("julia: ", VERSION)
println("threads: ", Threads.nthreads())
println("cpu: ", Sys.CPU_NAME)
println("blas: ", LinearAlgebra.BLAS.get_config())
println("mems: ", pkgversion(MacroEconometricModels))
println("friedman: ", Friedman.FRIEDMAN_VERSION)
flush(stdout)

println("=== upstream direct calls (no CLI) ===")
try
    m = MacroEconometricModels.CTAiyagari(; alpha=0.36, rho=0.05, sigma=2.0,
        delta=0.05, Z=1.0, a_min=0.0, a_max=30.0, I=12)
    ss = MacroEconometricModels.ct_steady_state(m; max_iter=40, tol=1e-5)
    println("ss: converged=$(ss.converged) r=$(ss.r) K=$(ss.K)")
    Z_path = fill(1.0, 4)
    Z_path[1] = 0.95
    tr = MacroEconometricModels.ct_mit_shock(m, ss, Z_path; dt=0.25,
        max_iter=40, tol=1e-5)
    println("tr: converged=$(tr.converged) iters=$(tr.iterations)")
catch e
    println("UPSTREAM THREW: ", typeof(e))
    showerror(stdout, e, catch_backtrace())
    println()
end
flush(stdout)

function run_once(tag)
    println("=== $tag: CLI data simulate ct ===")
    out_path, err_path = tempname(), tempname()
    code = try
        open(out_path, "w") do out_io
            open(err_path, "w") do err_io
                redirect_stdout(out_io) do
                    redirect_stderr(err_io) do
                        Friedman.run_cli(["--quiet", "data", "simulate", "ct",
                            "--grid-size", "12", "--periods", "4",
                            "--max-iter", "40", "--seed", "1", "--format", "json"])
                    end
                end
            end
        end
    catch e
        println("CLI THREW: ", typeof(e))
        showerror(stdout, e, catch_backtrace())
        println()
        Cint(1)
    end
    println("code: ", code)
    println("--- stdout (envelope) ---")
    println(read(out_path, String))
    println("--- stderr ---")
    println(read(err_path, String))
    rm(out_path; force=true)
    rm(err_path; force=true)
    flush(stdout)
    return Int(code)
end

codes = Int[]
for i in 1:3
    push!(codes, run_once("iter $i"))
end
println("=== codes: $codes ===")
