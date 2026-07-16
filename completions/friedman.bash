# Friedman-cli bash completion (generated)
_friedman() {
  local cur prev words cword
  _init_completion || return
  if [[ $cword -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "data did dsge estimate fevd filter forecast hd irf nowcast predict residuals spectral test repl" -- "$cur") )
    return
  fi
  case "${words[1]}" in
    data) COMPREPLY=( $(compgen -W "balance describe diagnose dropna filter fix keeprows list load transform validate" -- "$cur") ) ;;
    did) COMPREPLY=( $(compgen -W "estimate event-study lp-did test" -- "$cur") ) ;;
    dsge) COMPREPLY=( $(compgen -W "bayes estimate fevd hd irf perfect-foresight simulate solve steady-state" -- "$cur") ) ;;
    estimate) COMPREPLY=( $(compgen -W "arch arima bvar dynamic egarch fastica favar garch gdfm gjr_garch gmm iv logit lp ml mlogit ologit oprobit piv plogit pprobit preg probit pvar reg sdfm smm static sv var vecm" -- "$cur") ) ;;
    fevd) COMPREPLY=( $(compgen -W "bvar favar lp pvar sdfm var vecm" -- "$cur") ) ;;
    filter) COMPREPLY=( $(compgen -W "bhp bk bn hamilton hp" -- "$cur") ) ;;
    forecast) COMPREPLY=( $(compgen -W "arch arima bvar dynamic egarch favar garch gdfm gjr_garch lp static sv var vecm" -- "$cur") ) ;;
    hd) COMPREPLY=( $(compgen -W "bvar favar lp var vecm" -- "$cur") ) ;;
    irf) COMPREPLY=( $(compgen -W "bvar favar lp pvar sdfm var vecm" -- "$cur") ) ;;
    nowcast) COMPREPLY=( $(compgen -W "bridge bvar dfm forecast news" -- "$cur") ) ;;
    predict) COMPREPLY=( $(compgen -W "arch arima bvar dynamic egarch favar garch gdfm gjr_garch logit mlogit ologit oprobit piv plogit pprobit preg probit reg static sv var vecm" -- "$cur") ) ;;
    residuals) COMPREPLY=( $(compgen -W "arch arima bvar dynamic egarch favar garch gdfm gjr_garch logit mlogit ologit oprobit piv plogit pprobit preg probit reg static sv var vecm" -- "$cur") ) ;;
    spectral) COMPREPLY=( $(compgen -W "acf cross density periodogram transfer" -- "$cur") ) ;;
    test) COMPREPLY=( $(compgen -W "adf adf-2break andrews arch_lm bai-perron bartlett-wn box-pierce brant breusch-pagan cips dfgls durbin-watson f-fe factor-break fisher fourier-adf fourier-kpss granger gregory-hansen hausman hausman-iia heteroskedasticity identifiability johansen kpss ljung_box lm lm-unitroot lr modified-wald moon-perron normality np panic pesaran-cd pp pvar var vif wooldridge-ar za" -- "$cur") ) ;;
  esac
}
complete -F _friedman friedman
