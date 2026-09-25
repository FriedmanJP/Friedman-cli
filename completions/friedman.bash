# Friedman-cli bash completion (generated)
_friedman() {
  local cur prev words cword
  _init_completion || return
  if [[ $cword -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "completions data did dsge estimate fevd filter forecast hadsge hd io irf model nowcast policy predict residuals serve show spectral test repl" -- "$cur") )
    return
  fi
  case "${words[1]}" in
    completions) COMPREPLY=( $(compgen -W "bash fish zsh" -- "$cur") ) ;;
    data) COMPREPLY=( $(compgen -W "balance describe diagnose dropna export filter fix import keeprows list load simulate transform validate" -- "$cur") ) ;;
    did) COMPREPLY=( $(compgen -W "estimate event-study lp-did" -- "$cur") ) ;;
    dsge) COMPREPLY=( $(compgen -W "bank bayes ct dcegm determinacy-map estimate fevd firm hd irf lifecycle moments olg perfect-foresight simulate solve steady-state" -- "$cur") ) ;;
    estimate) COMPREPLY=( $(compgen -W "choice factor multivariate panel regime regression univariate volatility" -- "$cur") ) ;;
    fevd) COMPREPLY=( $(compgen -W "bvar favar lp pvar sdfm var vecm" -- "$cur") ) ;;
    filter) COMPREPLY=( $(compgen -W "bhp bk bn hamilton hp x13" -- "$cur") ) ;;
    forecast) COMPREPLY=( $(compgen -W "evaluate factor multivariate regime univariate volatility" -- "$cur") ) ;;
    hadsge) COMPREPLY=( $(compgen -W "accuracy distribution-irf estimate fevd hd inequality-irf irf simulate simulate-panel solve steady-state" -- "$cur") ) ;;
    hd) COMPREPLY=( $(compgen -W "bvar favar lp sdfm var vecm" -- "$cur") ) ;;
    io) COMPREPLY=( $(compgen -W "aggregate balance baqaee-farhi bf bilateral-trade download export-decomposition extract footprint ghosh impact key-sectors leontief linkages load multipliers network-stats price sda sources vertical-specialization" -- "$cur") ) ;;
    irf) COMPREPLY=( $(compgen -W "bvar favar lp pvar sdfm tvpvar var vecm" -- "$cur") ) ;;
    model) COMPREPLY=( $(compgen -W "info reproduce" -- "$cur") ) ;;
    nowcast) COMPREPLY=( $(compgen -W "bridge bvar dfm forecast news" -- "$cur") ) ;;
    policy) COMPREPLY=( $(compgen -W "counterfactual effects history jacobian moments news opp opp-sequence optimal spanning sufficiency" -- "$cur") ) ;;
    predict) COMPREPLY=( $(compgen -W "choice factor multivariate panel regime regression univariate volatility" -- "$cur") ) ;;
    residuals) COMPREPLY=( $(compgen -W "choice factor multivariate panel regime regression univariate volatility" -- "$cur") ) ;;
    serve) COMPREPLY=( $(compgen -W "" -- "$cur") ) ;;
    show) COMPREPLY=( $(compgen -W "" -- "$cur") ) ;;
    spectral) COMPREPLY=( $(compgen -W "acf cross density periodogram transfer" -- "$cur") ) ;;
    test) COMPREPLY=( $(compgen -W "brant coint did dispersion edf fisher gph hansen-linearity hausman-iia identifiability influence iv local-whittle multivariate nardl-symmetry normality panel park-added pvar serial stability star-linearity unit-root variance-ratio vecm vif" -- "$cur") ) ;;
  esac
}
complete -F _friedman friedman
