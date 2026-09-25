# TEMPORARY diagnostic for PR #205 (`data simulate ct` fails in T3 on Linux,
# passes on macOS). Round 2: isolate the trigger (grid vs leaf) and find a
# robust operating point. DELETE AFTER DIAGNOSIS (do not merge).
using Friedman
using LinearAlgebra
import MacroEconometricModels

println("julia $(VERSION) threads=$(Threads.nthreads()) cpu=$(Sys.CPU_NAME)")
println("mems $(pkgversion(MacroEconometricModels))")
flush(stdout)

function run_cli(argv)
    out_path, err_path = tempname(), tempname()
    code = try
        open(out_path, "w") do out_io
            open(err_path, "w") do err_io
                redirect_stdout(out_io) do
                    redirect_stderr(err_io) do
                        Friedman.run_cli(argv)
                    end
                end
            end
        end
    catch e
        println("THREW $(typeof(e)): $e")
        Cint(1)
    end
    raw = read(out_path, String)
    rm(out_path; force=true)
    rm(err_path; force=true)
    return Int(code), raw
end

# 1. Same upstream call, existing leaf: is I=12 fatal regardless of leaf?
for (tag, argv) in (
    ("solve I=12", ["--quiet", "dsge", "ct", "solve", "--grid-size", "12",
        "--max-iter", "40", "--tol", "1e-5", "--format", "json"]),
    ("solve I=40", ["--quiet", "dsge", "ct", "solve", "--grid-size", "40",
        "--max-iter", "40", "--tol", "1e-5", "--format", "json"]),
    ("simct I=40 p=4", ["--quiet", "data", "simulate", "ct", "--grid-size", "40",
        "--periods", "4", "--max-iter", "40", "--seed", "1", "--format", "json"]),
    ("simct I=40 p=12", ["--quiet", "data", "simulate", "ct", "--grid-size", "40",
        "--periods", "12", "--max-iter", "40", "--seed", "1", "--format", "json"]),
)
    code, raw = run_cli(argv)
    errcode = match(r"\"code\":\"([^\"]+)\"", raw)
    println("$tag => exit $code error=$(errcode === nothing ? "-" : errcode[1])")
    flush(stdout)
end

# 2. Upstream steady-state sweep: where is the grid floor on this platform?
println("--- upstream ct_steady_state grid sweep (max_iter=40, tol=1e-5) ---")
for I in (12, 16, 20, 24, 32, 40)
    try
        m = MacroEconometricModels.CTAiyagari(; alpha=0.36, rho=0.05, sigma=2.0,
            delta=0.05, Z=1.0, a_min=0.0, a_max=30.0, I=I)
        ss = MacroEconometricModels.ct_steady_state(m; max_iter=40, tol=1e-5)
        println("I=$I ok converged=$(ss.converged) r=$(round(ss.r; digits=6))")
    catch e
        println("I=$I THREW $(typeof(e)): $(first(sprint(showerror, e), 100))")
    end
    flush(stdout)
end

# 3. Same sweep on mit_shock (short horizon Np1=4), only where ss works.
println("--- upstream ct_mit_shock Np1=4 sweep ---")
for I in (20, 24, 32, 40)
    try
        m = MacroEconometricModels.CTAiyagari(; alpha=0.36, rho=0.05, sigma=2.0,
            delta=0.05, Z=1.0, a_min=0.0, a_max=30.0, I=I)
        ss = MacroEconometricModels.ct_steady_state(m; max_iter=40, tol=1e-5)
        Z_path = fill(1.0, 4)
        Z_path[1] = 0.95
        tr = MacroEconometricModels.ct_mit_shock(m, ss, Z_path; dt=0.25,
            max_iter=40, tol=1e-5)
        println("I=$I ok converged=$(tr.converged) iters=$(tr.iterations)")
    catch e
        println("I=$I THREW $(typeof(e)): $(first(sprint(showerror, e), 100))")
    end
    flush(stdout)
end
println("=== done ===")
