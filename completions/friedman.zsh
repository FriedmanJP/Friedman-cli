#compdef friedman
# Friedman-cli zsh completion (generated)
_friedman() {
  local -a commands
  commands=(
    'completions'
    'data'
    'did'
    'dsge'
    'estimate'
    'fevd'
    'filter'
    'forecast'
    'hd'
    'irf'
    'model'
    'nowcast'
    'predict'
    'residuals'
    'spectral'
    'test'
    'repl'
  )
  _describe 'command' commands
}
_friedman "$@"
