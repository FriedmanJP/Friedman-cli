#compdef friedman
# Friedman-cli zsh completion (generated)
_friedman() {
  local -a commands
  commands=(
    'data'
    'did'
    'dsge'
    'estimate'
    'fevd'
    'filter'
    'forecast'
    'hd'
    'irf'
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
