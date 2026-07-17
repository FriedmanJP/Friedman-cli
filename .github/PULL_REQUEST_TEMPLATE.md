## Summary

<!-- What and why -->

## Checklist

- [ ] Tests added/updated for the change
- [ ] `julia --project docs/generate_cli_reference.jl --check` if `src/commands/` or `src/registry/` changed
- [ ] gitleaks + semgrep clean before push

## Handler / estimator changes

If this PR touches `src/commands/` adapters or estimation wiring:

- [ ] **T3 integration** is the real gate — run or rely on CI `integration-core`:
  ```bash
  julia --project=test/integration test/integration/runtests.jl
  ```
- [ ] Codecov command-layer patch target is **85%** (engine remains 95%); do not treat the old global 95% bar as the handler gate

## MEMs bump protocol (if bumping MacroEconometricModels)

1. Bump `[compat]` (and integration Project.toml); re-resolve Manifests from the **General registry**  
2. Run T3 integration core (+ full if risky)  
3. Read diffs / fix field renames  
4. Regen goldens: `julia --project test/tools/regen_golden.jl`  
5. Review mock surface: `julia --project test/tools/check_mock_surface.jl`
