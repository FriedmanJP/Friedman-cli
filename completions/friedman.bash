# Friedman-cli bash completion (generated)
_friedman() {
  local cur prev words cword
  _init_completion || return
  if [[ $cword -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "completions data did dsge estimate fevd filter forecast hd io irf model nowcast predict residuals spectral test repl" -- "$cur") )
    return
  fi
  case "${words[1]}" in
    completions) COMPREPLY=( $(compgen -W "bash fish zsh" -- "$cur") ) ;;
    data) COMPREPLY=( $(compgen -W "balance describe diagnose dropna filter fix keeprows list load transform validate" -- "$cur") ) ;;
    did) COMPREPLY=( $(compgen -W "estimate event-study lp-did test" -- "$cur") ) ;;
    dsge) COMPREPLY=( $(compgen -W "bayes ct estimate fevd ha hd irf olg perfect-foresight simulate solve steady-state" -- "$cur") ) ;;
    estimate) COMPREPLY=( $(compgen -W "3sls aparch arch arfima arima bekk bvar ccc cgarch dcc dynamic egarch fastica favar fiegarch figarch garch garch-midas gdfm gjr-garch gmm igarch iv logit lp ml mlogit ologit oprobit piv plogit pprobit preg probit pvar reg sdfm smm static sur sv var vecm" -- "$cur") ) ;;
    fevd) COMPREPLY=( $(compgen -W "bvar favar lp pvar sdfm var vecm" -- "$cur") ) ;;
    filter) COMPREPLY=( $(compgen -W "bhp bk bn hamilton hp x13" -- "$cur") ) ;;
    forecast) COMPREPLY=( $(compgen -W "arch arima bvar dynamic egarch evaluate favar garch gdfm gjr-garch lp static sv var vecm" -- "$cur") ) ;;
    hd) COMPREPLY=( $(compgen -W "bvar favar lp var vecm" -- "$cur") ) ;;
    io) COMPREPLY=( $(compgen -W "baqaee-farhi download extract footprint ghosh key-sectors leontief linkages load multipliers sda sources" -- "$cur") ) ;;
    irf) COMPREPLY=( $(compgen -W "bvar favar lp pvar sdfm var vecm" -- "$cur") ) ;;
    model) COMPREPLY=( $(compgen -W "info" -- "$cur") ) ;;
    nowcast) COMPREPLY=( $(compgen -W "bridge bvar dfm forecast news" -- "$cur") ) ;;
    predict) COMPREPLY=( $(compgen -W "arch arima bvar dynamic egarch favar garch gdfm gjr-garch logit mlogit ologit oprobit piv plogit pprobit preg probit reg static sv var vecm" -- "$cur") ) ;;
    residuals) COMPREPLY=( $(compgen -W "arch arima bvar dynamic egarch favar garch gdfm gjr-garch logit mlogit ologit oprobit piv plogit pprobit preg probit reg static sv var vecm" -- "$cur") ) ;;
    spectral) COMPREPLY=( $(compgen -W "acf cross density periodogram transfer" -- "$cur") ) ;;
    test) COMPREPLY=( $(compgen -W "adf adf-2break andrews arch-lm bai-perron bartlett-wn box-pierce brant breusch-pagan cips dfgls durbin-watson f-fe factor-break fisher fourier-adf fourier-kpss gph granger gregory-hansen hausman hausman-iia heteroskedasticity identifiability johansen kpss ljung-box lm lm-unitroot local-whittle lr modified-wald moon-perron normality np nyblom panic pesaran-cd pp pvar sign-bias var vif wooldridge-ar za" -- "$cur") ) ;;
  esac
}
complete -F _friedman friedman
