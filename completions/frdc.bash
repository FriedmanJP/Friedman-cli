# Friedman-cli (frdc) bash completion (generated from APP)
_frdc() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev=""
  if [[ $COMP_CWORD -gt 0 ]]; then
    prev="${COMP_WORDS[COMP_CWORD-1]}"
  fi

  local path=""
  local is_leaf=0
  local expect_val=0
  local i=1
  while [[ $i -lt $COMP_CWORD ]]; do
    local w="${COMP_WORDS[$i]}"
    if [[ $expect_val -eq 1 ]]; then
      expect_val=0
      ((i++))
      continue
    fi
    case "$w" in
      --seed|--digits) expect_val=1; ((i++)); continue ;;
      --*=*|-*=*) ((i++)); continue ;;
      --*|-*) ((i++)); continue ;;
    esac
    if [[ $is_leaf -eq 0 ]]; then
      case "$path|$w" in
        "|comp") w="completions" ;;
        "|d") w="data" ;;
        "|e") w="estimate" ;;
        "|est") w="estimate" ;;
        "|fc") w="forecast" ;;
        "|fcst") w="forecast" ;;
        "|flt") w="filter" ;;
        "|ha") w="hadsge" ;;
        "|m") w="model" ;;
        "|mod") w="model" ;;
        "|nc") w="nowcast" ;;
        "|pol") w="policy" ;;
        "|pr") w="predict" ;;
        "|pred") w="predict" ;;
        "|res") w="residuals" ;;
        "|resid") w="residuals" ;;
        "|sch") w="schema" ;;
        "|sh") w="show" ;;
        "|sp") w="spectral" ;;
        "|spec") w="spectral" ;;
        "|srv") w="serve" ;;
        "|t") w="test" ;;
        "data|bal") w="balance" ;;
        "data|desc") w="describe" ;;
        "data|diag") w="diagnose" ;;
        "data|exp") w="export" ;;
        "data|imp") w="import" ;;
        "data|ls") w="list" ;;
        "data|sim") w="simulate" ;;
        "data|tr") w="transform" ;;
        "data|val") w="validate" ;;
        "data simulate|cs") w="cross-section" ;;
        "data simulate|gdfm-inf") w="gdfm-infinite" ;;
        "data simulate|het-var") w="heteroskedastic-var" ;;
        "did|es") w="event-study" ;;
        "did|est") w="estimate" ;;
        "did|lp") w="lp-did" ;;
        "dsge|b") w="bayes" ;;
        "dsge|detmap") w="determinacy-map" ;;
        "dsge|est") w="estimate" ;;
        "dsge|lc") w="lifecycle" ;;
        "dsge|pf") w="perfect-foresight" ;;
        "dsge|sim") w="simulate" ;;
        "dsge|ss") w="steady-state" ;;
        "dsge abcd|innov") w="innovations" ;;
        "dsge abcd|inv") w="invertibility" ;;
        "dsge abcd|pop-var") w="population-var" ;;
        "dsge abcd|rec") w="recoverability" ;;
        "dsge abcd|search") w="search-observables" ;;
        "dsge bank|ss") w="steady-state" ;;
        "dsge bank|tr") w="transition" ;;
        "dsge bayes|id") w="identification" ;;
        "dsge bayes|lr") w="learning-rate" ;;
        "dsge bayes|mlik") w="marginal-lik" ;;
        "dsge bayes|mode") w="posterior-mode" ;;
        "dsge bayes|pred") w="predictive" ;;
        "dsge bayes|prior-pred") w="prior-predictive" ;;
        "dsge ct|tr") w="transition" ;;
        "dsge dcegm|ss") w="steady-state" ;;
        "dsge dcegm|tr") w="transition" ;;
        "dsge firm|ss") w="steady-state" ;;
        "dsge firm|tr") w="transition" ;;
        "dsge lifecycle|ss") w="steady-state" ;;
        "dsge lifecycle|tr") w="transition" ;;
        "estimate|ch") w="choice" ;;
        "estimate|fac") w="factor" ;;
        "estimate|mv") w="multivariate" ;;
        "estimate|pan") w="panel" ;;
        "estimate|regr") w="regression" ;;
        "estimate|rgm") w="regime" ;;
        "estimate|uv") w="univariate" ;;
        "estimate|vol") w="volatility" ;;
        "estimate multivariate|ll") w="lanne-luoto" ;;
        "estimate panel|xtcr") w="xtcointreg" ;;
        "estimate regression|enet") w="elastic-net" ;;
        "estimate regression|kreg") w="kernel-reg" ;;
        "estimate regression|ss") w="statespace" ;;
        "estimate volatility|gm") w="garch-midas" ;;
        "filter|bp-gdfm") w="bandpass-gdfm" ;;
        "forecast|eval") w="evaluate" ;;
        "forecast|fac") w="factor" ;;
        "forecast|mv") w="multivariate" ;;
        "forecast|rgm") w="regime" ;;
        "forecast|uv") w="univariate" ;;
        "forecast|vol") w="volatility" ;;
        "forecast evaluate|cw") w="clark-west" ;;
        "forecast evaluate|enc") w="encompassing" ;;
        "forecast evaluate|mz") w="mincer-zarnowitz" ;;
        "forecast factor|gar") w="growth-at-risk" ;;
        "forecast volatility|gm") w="garch-midas" ;;
        "hadsge|acc") w="accuracy" ;;
        "hadsge|dist-irf") w="distribution-irf" ;;
        "hadsge|est") w="estimate" ;;
        "hadsge|ineq-irf") w="inequality-irf" ;;
        "hadsge|sim") w="simulate" ;;
        "hadsge|sim-panel") w="simulate-panel" ;;
        "hadsge|ss") w="steady-state" ;;
        "io|agg") w="aggregate" ;;
        "io|bf-full") w="baqaee-farhi" ;;
        "io|bilat") w="bilateral-trade" ;;
        "io|dl") w="download" ;;
        "io|exp-decomp") w="export-decomposition" ;;
        "io|ext") w="extract" ;;
        "io|fp") w="footprint" ;;
        "io|keys") w="key-sectors" ;;
        "io|link") w="linkages" ;;
        "io|mult") w="multipliers" ;;
        "io|net") w="network-stats" ;;
        "io|vs") w="vertical-specialization" ;;
        "io bf|elast") w="elasticities" ;;
        "io bf|eq") w="equilibrium" ;;
        "io bf|misalloc") w="misallocation" ;;
        "io bf|scurve") w="shock-curve" ;;
        "model|conv") w="convert" ;;
        "model|repro") w="reproduce" ;;
        "policy|cf") w="counterfactual" ;;
        "policy|eff") w="effects" ;;
        "policy|hist") w="history" ;;
        "policy|jac") w="jacobian" ;;
        "policy|mom") w="moments" ;;
        "policy|opp-seq") w="opp-sequence" ;;
        "policy|opt") w="optimal" ;;
        "policy|span") w="spanning" ;;
        "policy|suff") w="sufficiency" ;;
        "predict|ch") w="choice" ;;
        "predict|fac") w="factor" ;;
        "predict|mv") w="multivariate" ;;
        "predict|pan") w="panel" ;;
        "predict|regr") w="regression" ;;
        "predict|rgm") w="regime" ;;
        "predict|uv") w="univariate" ;;
        "predict|vol") w="volatility" ;;
        "predict regression|ss") w="statespace" ;;
        "predict volatility|gm") w="garch-midas" ;;
        "residuals|ch") w="choice" ;;
        "residuals|fac") w="factor" ;;
        "residuals|mv") w="multivariate" ;;
        "residuals|pan") w="panel" ;;
        "residuals|regr") w="regression" ;;
        "residuals|rgm") w="regime" ;;
        "residuals|uv") w="univariate" ;;
        "residuals|vol") w="volatility" ;;
        "residuals multivariate|ll") w="lanne-luoto" ;;
        "residuals regression|ss") w="statespace" ;;
        "residuals volatility|gm") w="garch-midas" ;;
        "ri|disc") w="discrete" ;;
        "ri|est") w="estimate" ;;
        "ri|sim") w="simulate" ;;
        "ri|ss") w="statespace" ;;
        "ri|trans") w="transition" ;;
        "spectral|dens") w="density" ;;
        "spectral|pgram") w="periodogram" ;;
        "spectral|tf") w="transfer" ;;
        "test|ci") w="coint" ;;
        "test|fac") w="factor" ;;
        "test|mv") w="multivariate" ;;
        "test|pan") w="panel" ;;
        "test|ser") w="serial" ;;
        "test|stab") w="stability" ;;
        "test|ur") w="unit-root" ;;
        "test coint|bounds") w="ardl-bounds" ;;
        "test coint|eg") w="engle-granger" ;;
        "test coint|fj") w="fisher-johansen" ;;
        "test coint|gh") w="gregory-hansen" ;;
        "test coint|po") w="phillips-ouliaris" ;;
        "test coint|west") w="westerlund" ;;
        "test factor|ah") w="ahn-horenstein" ;;
        "test factor|oed") w="onatski-ed" ;;
        "test factor|qconst") w="qfm-constancy" ;;
        "test factor|qspan") w="qfm-spanning" ;;
        "test iv|ar") w="anderson-rubin" ;;
        "test iv|wc") w="wild-cluster" ;;
        "test iv|weak-iv") w="weak-instrument" ;;
        "test multivariate|fund") w="fundamentalness" ;;
        "test multivariate|gmm-mom") w="gmm-moments" ;;
        "test multivariate|ng-diag") w="nongaussian-diag" ;;
        "test multivariate|suff-info") w="sufficient-info" ;;
        "test multivariate|svar-hyp") w="svar-hypothesis" ;;
        "test panel|dh") w="dh-causality" ;;
        "test panel|mwald") w="modified-wald" ;;
        "test panel|pcd") w="pesaran-cd" ;;
        "test panel|pmgh") w="pmg-hausman" ;;
        "test panel|war") w="wooldridge-ar" ;;
        "test serial|boxp") w="box-pierce" ;;
        "test serial|bp") w="breusch-pagan" ;;
        "test serial|bwn") w="bartlett-wn" ;;
        "test serial|dw") w="durbin-watson" ;;
        "test serial|het") w="heteroskedasticity" ;;
        "test serial|lb") w="ljung-box" ;;
        "test stability|bp") w="bai-perron" ;;
        "test stability|fbreak") w="factor-break" ;;
        "test stability|hansen") w="hansen-instability" ;;
        "test stability|rec-resid") w="recursive-residuals" ;;
        "test unit-root|adf2") w="adf-2break" ;;
        "test unit-root|fadf") w="fourier-adf" ;;
        "test unit-root|fkpss") w="fourier-kpss" ;;
        "test unit-root|lm") w="lm-unitroot" ;;
        "test unit-root|mp") w="moon-perron" ;;
        "test vecm|kbeta") w="known-beta" ;;
      esac
      local cand=""
      if [[ -z "$path" ]]; then cand="$w"; else cand="$path $w"; fi
      case "$cand" in
        "completions") path="completions" ;;
        "data") path="data" ;;
        "data simulate") path="data simulate" ;;
        "did") path="did" ;;
        "dsge") path="dsge" ;;
        "dsge abcd") path="dsge abcd" ;;
        "dsge bank") path="dsge bank" ;;
        "dsge bayes") path="dsge bayes" ;;
        "dsge ct") path="dsge ct" ;;
        "dsge dcegm") path="dsge dcegm" ;;
        "dsge firm") path="dsge firm" ;;
        "dsge lifecycle") path="dsge lifecycle" ;;
        "dsge olg") path="dsge olg" ;;
        "dsge var") path="dsge var" ;;
        "estimate") path="estimate" ;;
        "estimate choice") path="estimate choice" ;;
        "estimate factor") path="estimate factor" ;;
        "estimate multivariate") path="estimate multivariate" ;;
        "estimate panel") path="estimate panel" ;;
        "estimate regime") path="estimate regime" ;;
        "estimate regression") path="estimate regression" ;;
        "estimate univariate") path="estimate univariate" ;;
        "estimate volatility") path="estimate volatility" ;;
        "fevd") path="fevd" ;;
        "filter") path="filter" ;;
        "forecast") path="forecast" ;;
        "forecast evaluate") path="forecast evaluate" ;;
        "forecast factor") path="forecast factor" ;;
        "forecast multivariate") path="forecast multivariate" ;;
        "forecast regime") path="forecast regime" ;;
        "forecast univariate") path="forecast univariate" ;;
        "forecast volatility") path="forecast volatility" ;;
        "hadsge") path="hadsge" ;;
        "hd") path="hd" ;;
        "io") path="io" ;;
        "io bf") path="io bf" ;;
        "irf") path="irf" ;;
        "model") path="model" ;;
        "nowcast") path="nowcast" ;;
        "policy") path="policy" ;;
        "policy counterfactual") path="policy counterfactual" ;;
        "policy effects") path="policy effects" ;;
        "policy history") path="policy history" ;;
        "policy jacobian") path="policy jacobian" ;;
        "policy moments") path="policy moments" ;;
        "policy news") path="policy news" ;;
        "policy opp") path="policy opp" ;;
        "policy opp-sequence") path="policy opp-sequence" ;;
        "policy optimal") path="policy optimal" ;;
        "policy spanning") path="policy spanning" ;;
        "policy sufficiency") path="policy sufficiency" ;;
        "predict") path="predict" ;;
        "predict choice") path="predict choice" ;;
        "predict factor") path="predict factor" ;;
        "predict multivariate") path="predict multivariate" ;;
        "predict panel") path="predict panel" ;;
        "predict regime") path="predict regime" ;;
        "predict regression") path="predict regression" ;;
        "predict univariate") path="predict univariate" ;;
        "predict volatility") path="predict volatility" ;;
        "residuals") path="residuals" ;;
        "residuals choice") path="residuals choice" ;;
        "residuals factor") path="residuals factor" ;;
        "residuals multivariate") path="residuals multivariate" ;;
        "residuals panel") path="residuals panel" ;;
        "residuals regime") path="residuals regime" ;;
        "residuals regression") path="residuals regression" ;;
        "residuals univariate") path="residuals univariate" ;;
        "residuals volatility") path="residuals volatility" ;;
        "ri") path="ri" ;;
        "spectral") path="spectral" ;;
        "test") path="test" ;;
        "test coint") path="test coint" ;;
        "test did") path="test did" ;;
        "test factor") path="test factor" ;;
        "test iv") path="test iv" ;;
        "test multivariate") path="test multivariate" ;;
        "test panel") path="test panel" ;;
        "test pvar") path="test pvar" ;;
        "test serial") path="test serial" ;;
        "test stability") path="test stability" ;;
        "test unit-root") path="test unit-root" ;;
        "test vecm") path="test vecm" ;;
        "completions bash") path="completions bash"; is_leaf=1 ;;
        "completions fish") path="completions fish"; is_leaf=1 ;;
        "completions zsh") path="completions zsh"; is_leaf=1 ;;
        "data balance") path="data balance"; is_leaf=1 ;;
        "data describe") path="data describe"; is_leaf=1 ;;
        "data diagnose") path="data diagnose"; is_leaf=1 ;;
        "data dropna") path="data dropna"; is_leaf=1 ;;
        "data export") path="data export"; is_leaf=1 ;;
        "data filter") path="data filter"; is_leaf=1 ;;
        "data fix") path="data fix"; is_leaf=1 ;;
        "data import") path="data import"; is_leaf=1 ;;
        "data keeprows") path="data keeprows"; is_leaf=1 ;;
        "data list") path="data list"; is_leaf=1 ;;
        "data load") path="data load"; is_leaf=1 ;;
        "data simulate ardl") path="data simulate ardl"; is_leaf=1 ;;
        "data simulate arima") path="data simulate arima"; is_leaf=1 ;;
        "data simulate cointreg") path="data simulate cointreg"; is_leaf=1 ;;
        "data simulate cross-section") path="data simulate cross-section"; is_leaf=1 ;;
        "data simulate ct") path="data simulate ct"; is_leaf=1 ;;
        "data simulate did") path="data simulate did"; is_leaf=1 ;;
        "data simulate dsge") path="data simulate dsge"; is_leaf=1 ;;
        "data simulate factors") path="data simulate factors"; is_leaf=1 ;;
        "data simulate garch") path="data simulate garch"; is_leaf=1 ;;
        "data simulate gdfm-infinite") path="data simulate gdfm-infinite"; is_leaf=1 ;;
        "data simulate gmm") path="data simulate gmm"; is_leaf=1 ;;
        "data simulate ha") path="data simulate ha"; is_leaf=1 ;;
        "data simulate heteroskedastic-var") path="data simulate heteroskedastic-var"; is_leaf=1 ;;
        "data simulate lp-iv") path="data simulate lp-iv"; is_leaf=1 ;;
        "data simulate olg") path="data simulate olg"; is_leaf=1 ;;
        "data simulate panel") path="data simulate panel"; is_leaf=1 ;;
        "data simulate pvar") path="data simulate pvar"; is_leaf=1 ;;
        "data simulate qfavar") path="data simulate qfavar"; is_leaf=1 ;;
        "data simulate qfm") path="data simulate qfm"; is_leaf=1 ;;
        "data simulate regime") path="data simulate regime"; is_leaf=1 ;;
        "data simulate ssvarma") path="data simulate ssvarma"; is_leaf=1 ;;
        "data simulate sv") path="data simulate sv"; is_leaf=1 ;;
        "data simulate svar") path="data simulate svar"; is_leaf=1 ;;
        "data simulate var") path="data simulate var"; is_leaf=1 ;;
        "data simulate vecm") path="data simulate vecm"; is_leaf=1 ;;
        "data transform") path="data transform"; is_leaf=1 ;;
        "data validate") path="data validate"; is_leaf=1 ;;
        "did estimate") path="did estimate"; is_leaf=1 ;;
        "did event-study") path="did event-study"; is_leaf=1 ;;
        "did lp-did") path="did lp-did"; is_leaf=1 ;;
        "dsge abcd audit-irf") path="dsge abcd audit-irf"; is_leaf=1 ;;
        "dsge abcd extract") path="dsge abcd extract"; is_leaf=1 ;;
        "dsge abcd innovations") path="dsge abcd innovations"; is_leaf=1 ;;
        "dsge abcd invertibility") path="dsge abcd invertibility"; is_leaf=1 ;;
        "dsge abcd population-var") path="dsge abcd population-var"; is_leaf=1 ;;
        "dsge abcd recoverability") path="dsge abcd recoverability"; is_leaf=1 ;;
        "dsge abcd search-observables") path="dsge abcd search-observables"; is_leaf=1 ;;
        "dsge bank irf") path="dsge bank irf"; is_leaf=1 ;;
        "dsge bank pe") path="dsge bank pe"; is_leaf=1 ;;
        "dsge bank steady-state") path="dsge bank steady-state"; is_leaf=1 ;;
        "dsge bank transition") path="dsge bank transition"; is_leaf=1 ;;
        "dsge bayes compare") path="dsge bayes compare"; is_leaf=1 ;;
        "dsge bayes estimate") path="dsge bayes estimate"; is_leaf=1 ;;
        "dsge bayes fevd") path="dsge bayes fevd"; is_leaf=1 ;;
        "dsge bayes hd") path="dsge bayes hd"; is_leaf=1 ;;
        "dsge bayes identification") path="dsge bayes identification"; is_leaf=1 ;;
        "dsge bayes irf") path="dsge bayes irf"; is_leaf=1 ;;
        "dsge bayes learning-rate") path="dsge bayes learning-rate"; is_leaf=1 ;;
        "dsge bayes marginal-lik") path="dsge bayes marginal-lik"; is_leaf=1 ;;
        "dsge bayes mcmc-diag") path="dsge bayes mcmc-diag"; is_leaf=1 ;;
        "dsge bayes overlap") path="dsge bayes overlap"; is_leaf=1 ;;
        "dsge bayes posterior-mode") path="dsge bayes posterior-mode"; is_leaf=1 ;;
        "dsge bayes predictive") path="dsge bayes predictive"; is_leaf=1 ;;
        "dsge bayes prior-predictive") path="dsge bayes prior-predictive"; is_leaf=1 ;;
        "dsge bayes simulate") path="dsge bayes simulate"; is_leaf=1 ;;
        "dsge bayes summary") path="dsge bayes summary"; is_leaf=1 ;;
        "dsge ct fevd") path="dsge ct fevd"; is_leaf=1 ;;
        "dsge ct irf") path="dsge ct irf"; is_leaf=1 ;;
        "dsge ct solve") path="dsge ct solve"; is_leaf=1 ;;
        "dsge ct transition") path="dsge ct transition"; is_leaf=1 ;;
        "dsge dcegm fevd") path="dsge dcegm fevd"; is_leaf=1 ;;
        "dsge dcegm irf") path="dsge dcegm irf"; is_leaf=1 ;;
        "dsge dcegm simulate") path="dsge dcegm simulate"; is_leaf=1 ;;
        "dsge dcegm solve") path="dsge dcegm solve"; is_leaf=1 ;;
        "dsge dcegm steady-state") path="dsge dcegm steady-state"; is_leaf=1 ;;
        "dsge dcegm transition") path="dsge dcegm transition"; is_leaf=1 ;;
        "dsge determinacy-map") path="dsge determinacy-map"; is_leaf=1 ;;
        "dsge estimate") path="dsge estimate"; is_leaf=1 ;;
        "dsge fevd") path="dsge fevd"; is_leaf=1 ;;
        "dsge firm irf") path="dsge firm irf"; is_leaf=1 ;;
        "dsge firm steady-state") path="dsge firm steady-state"; is_leaf=1 ;;
        "dsge firm transition") path="dsge firm transition"; is_leaf=1 ;;
        "dsge hd") path="dsge hd"; is_leaf=1 ;;
        "dsge irf") path="dsge irf"; is_leaf=1 ;;
        "dsge lifecycle fevd") path="dsge lifecycle fevd"; is_leaf=1 ;;
        "dsge lifecycle irf") path="dsge lifecycle irf"; is_leaf=1 ;;
        "dsge lifecycle simulate") path="dsge lifecycle simulate"; is_leaf=1 ;;
        "dsge lifecycle steady-state") path="dsge lifecycle steady-state"; is_leaf=1 ;;
        "dsge lifecycle transition") path="dsge lifecycle transition"; is_leaf=1 ;;
        "dsge moments") path="dsge moments"; is_leaf=1 ;;
        "dsge olg fevd") path="dsge olg fevd"; is_leaf=1 ;;
        "dsge olg irf") path="dsge olg irf"; is_leaf=1 ;;
        "dsge olg simulate") path="dsge olg simulate"; is_leaf=1 ;;
        "dsge olg solve") path="dsge olg solve"; is_leaf=1 ;;
        "dsge perfect-foresight") path="dsge perfect-foresight"; is_leaf=1 ;;
        "dsge simulate") path="dsge simulate"; is_leaf=1 ;;
        "dsge solve") path="dsge solve"; is_leaf=1 ;;
        "dsge steady-state") path="dsge steady-state"; is_leaf=1 ;;
        "dsge var estimate") path="dsge var estimate"; is_leaf=1 ;;
        "dsge var fevd") path="dsge var fevd"; is_leaf=1 ;;
        "dsge var forecast") path="dsge var forecast"; is_leaf=1 ;;
        "dsge var hd") path="dsge var hd"; is_leaf=1 ;;
        "dsge var irf") path="dsge var irf"; is_leaf=1 ;;
        "dsge var lambda") path="dsge var lambda"; is_leaf=1 ;;
        "dsge var prior") path="dsge var prior"; is_leaf=1 ;;
        "estimate choice logit") path="estimate choice logit"; is_leaf=1 ;;
        "estimate choice mlogit") path="estimate choice mlogit"; is_leaf=1 ;;
        "estimate choice nbreg") path="estimate choice nbreg"; is_leaf=1 ;;
        "estimate choice ologit") path="estimate choice ologit"; is_leaf=1 ;;
        "estimate choice oprobit") path="estimate choice oprobit"; is_leaf=1 ;;
        "estimate choice poisson") path="estimate choice poisson"; is_leaf=1 ;;
        "estimate choice probit") path="estimate choice probit"; is_leaf=1 ;;
        "estimate choice ri-logit") path="estimate choice ri-logit"; is_leaf=1 ;;
        "estimate factor dynamic") path="estimate factor dynamic"; is_leaf=1 ;;
        "estimate factor fastica") path="estimate factor fastica"; is_leaf=1 ;;
        "estimate factor fhlz") path="estimate factor fhlz"; is_leaf=1 ;;
        "estimate factor gdfm") path="estimate factor gdfm"; is_leaf=1 ;;
        "estimate factor gdfm-i1") path="estimate factor gdfm-i1"; is_leaf=1 ;;
        "estimate factor qfm") path="estimate factor qfm"; is_leaf=1 ;;
        "estimate factor sdfm") path="estimate factor sdfm"; is_leaf=1 ;;
        "estimate factor static") path="estimate factor static"; is_leaf=1 ;;
        "estimate factor tv-gdfm") path="estimate factor tv-gdfm"; is_leaf=1 ;;
        "estimate multivariate bvar") path="estimate multivariate bvar"; is_leaf=1 ;;
        "estimate multivariate favar") path="estimate multivariate favar"; is_leaf=1 ;;
        "estimate multivariate lanne-luoto") path="estimate multivariate lanne-luoto"; is_leaf=1 ;;
        "estimate multivariate lms-svar") path="estimate multivariate lms-svar"; is_leaf=1 ;;
        "estimate multivariate lp") path="estimate multivariate lp"; is_leaf=1 ;;
        "estimate multivariate mfvar") path="estimate multivariate mfvar"; is_leaf=1 ;;
        "estimate multivariate qfavar") path="estimate multivariate qfavar"; is_leaf=1 ;;
        "estimate multivariate qvar") path="estimate multivariate qvar"; is_leaf=1 ;;
        "estimate multivariate ssvarma") path="estimate multivariate ssvarma"; is_leaf=1 ;;
        "estimate multivariate svar") path="estimate multivariate svar"; is_leaf=1 ;;
        "estimate multivariate svec") path="estimate multivariate svec"; is_leaf=1 ;;
        "estimate multivariate tvpvar") path="estimate multivariate tvpvar"; is_leaf=1 ;;
        "estimate multivariate var") path="estimate multivariate var"; is_leaf=1 ;;
        "estimate multivariate vecm") path="estimate multivariate vecm"; is_leaf=1 ;;
        "estimate panel piv") path="estimate panel piv"; is_leaf=1 ;;
        "estimate panel plogit") path="estimate panel plogit"; is_leaf=1 ;;
        "estimate panel pmg") path="estimate panel pmg"; is_leaf=1 ;;
        "estimate panel pprobit") path="estimate panel pprobit"; is_leaf=1 ;;
        "estimate panel preg") path="estimate panel preg"; is_leaf=1 ;;
        "estimate panel pvar") path="estimate panel pvar"; is_leaf=1 ;;
        "estimate panel xtcointreg") path="estimate panel xtcointreg"; is_leaf=1 ;;
        "estimate panel xtqreg") path="estimate panel xtqreg"; is_leaf=1 ;;
        "estimate regime ms") path="estimate regime ms"; is_leaf=1 ;;
        "estimate regime ms-ar") path="estimate regime ms-ar"; is_leaf=1 ;;
        "estimate regime setar") path="estimate regime setar"; is_leaf=1 ;;
        "estimate regime star") path="estimate regime star"; is_leaf=1 ;;
        "estimate regime threshold") path="estimate regime threshold"; is_leaf=1 ;;
        "estimate regime tvp") path="estimate regime tvp"; is_leaf=1 ;;
        "estimate regression 3sls") path="estimate regression 3sls"; is_leaf=1 ;;
        "estimate regression cointreg") path="estimate regression cointreg"; is_leaf=1 ;;
        "estimate regression elastic-net") path="estimate regression elastic-net"; is_leaf=1 ;;
        "estimate regression gmm") path="estimate regression gmm"; is_leaf=1 ;;
        "estimate regression heckman") path="estimate regression heckman"; is_leaf=1 ;;
        "estimate regression iv") path="estimate regression iv"; is_leaf=1 ;;
        "estimate regression kde") path="estimate regression kde"; is_leaf=1 ;;
        "estimate regression kernel-reg") path="estimate regression kernel-reg"; is_leaf=1 ;;
        "estimate regression lasso") path="estimate regression lasso"; is_leaf=1 ;;
        "estimate regression lowess") path="estimate regression lowess"; is_leaf=1 ;;
        "estimate regression ml") path="estimate regression ml"; is_leaf=1 ;;
        "estimate regression qreg") path="estimate regression qreg"; is_leaf=1 ;;
        "estimate regression rdd") path="estimate regression rdd"; is_leaf=1 ;;
        "estimate regression reg") path="estimate regression reg"; is_leaf=1 ;;
        "estimate regression ridge") path="estimate regression ridge"; is_leaf=1 ;;
        "estimate regression robust") path="estimate regression robust"; is_leaf=1 ;;
        "estimate regression select") path="estimate regression select"; is_leaf=1 ;;
        "estimate regression smm") path="estimate regression smm"; is_leaf=1 ;;
        "estimate regression statespace") path="estimate regression statespace"; is_leaf=1 ;;
        "estimate regression sur") path="estimate regression sur"; is_leaf=1 ;;
        "estimate regression tobit") path="estimate regression tobit"; is_leaf=1 ;;
        "estimate regression truncreg") path="estimate regression truncreg"; is_leaf=1 ;;
        "estimate univariate ardl") path="estimate univariate ardl"; is_leaf=1 ;;
        "estimate univariate arfima") path="estimate univariate arfima"; is_leaf=1 ;;
        "estimate univariate arima") path="estimate univariate arima"; is_leaf=1 ;;
        "estimate univariate midas") path="estimate univariate midas"; is_leaf=1 ;;
        "estimate univariate nardl") path="estimate univariate nardl"; is_leaf=1 ;;
        "estimate univariate sarima") path="estimate univariate sarima"; is_leaf=1 ;;
        "estimate volatility aparch") path="estimate volatility aparch"; is_leaf=1 ;;
        "estimate volatility arch") path="estimate volatility arch"; is_leaf=1 ;;
        "estimate volatility bekk") path="estimate volatility bekk"; is_leaf=1 ;;
        "estimate volatility ccc") path="estimate volatility ccc"; is_leaf=1 ;;
        "estimate volatility cgarch") path="estimate volatility cgarch"; is_leaf=1 ;;
        "estimate volatility dcc") path="estimate volatility dcc"; is_leaf=1 ;;
        "estimate volatility egarch") path="estimate volatility egarch"; is_leaf=1 ;;
        "estimate volatility fiegarch") path="estimate volatility fiegarch"; is_leaf=1 ;;
        "estimate volatility figarch") path="estimate volatility figarch"; is_leaf=1 ;;
        "estimate volatility garch") path="estimate volatility garch"; is_leaf=1 ;;
        "estimate volatility garch-midas") path="estimate volatility garch-midas"; is_leaf=1 ;;
        "estimate volatility gjr-garch") path="estimate volatility gjr-garch"; is_leaf=1 ;;
        "estimate volatility igarch") path="estimate volatility igarch"; is_leaf=1 ;;
        "estimate volatility sv") path="estimate volatility sv"; is_leaf=1 ;;
        "fevd bvar") path="fevd bvar"; is_leaf=1 ;;
        "fevd favar") path="fevd favar"; is_leaf=1 ;;
        "fevd gdfm-i1") path="fevd gdfm-i1"; is_leaf=1 ;;
        "fevd lp") path="fevd lp"; is_leaf=1 ;;
        "fevd pvar") path="fevd pvar"; is_leaf=1 ;;
        "fevd sdfm") path="fevd sdfm"; is_leaf=1 ;;
        "fevd ssvarma") path="fevd ssvarma"; is_leaf=1 ;;
        "fevd var") path="fevd var"; is_leaf=1 ;;
        "fevd vecm") path="fevd vecm"; is_leaf=1 ;;
        "filter bandpass-gdfm") path="filter bandpass-gdfm"; is_leaf=1 ;;
        "filter bhp") path="filter bhp"; is_leaf=1 ;;
        "filter bk") path="filter bk"; is_leaf=1 ;;
        "filter bn") path="filter bn"; is_leaf=1 ;;
        "filter eurocoin") path="filter eurocoin"; is_leaf=1 ;;
        "filter hamilton") path="filter hamilton"; is_leaf=1 ;;
        "filter hp") path="filter hp"; is_leaf=1 ;;
        "filter x13") path="filter x13"; is_leaf=1 ;;
        "forecast evaluate clark-west") path="forecast evaluate clark-west"; is_leaf=1 ;;
        "forecast evaluate combine") path="forecast evaluate combine"; is_leaf=1 ;;
        "forecast evaluate dm") path="forecast evaluate dm"; is_leaf=1 ;;
        "forecast evaluate encompassing") path="forecast evaluate encompassing"; is_leaf=1 ;;
        "forecast evaluate metrics") path="forecast evaluate metrics"; is_leaf=1 ;;
        "forecast evaluate mincer-zarnowitz") path="forecast evaluate mincer-zarnowitz"; is_leaf=1 ;;
        "forecast factor dynamic") path="forecast factor dynamic"; is_leaf=1 ;;
        "forecast factor gdfm") path="forecast factor gdfm"; is_leaf=1 ;;
        "forecast factor gdfm-i1") path="forecast factor gdfm-i1"; is_leaf=1 ;;
        "forecast factor growth-at-risk") path="forecast factor growth-at-risk"; is_leaf=1 ;;
        "forecast factor qfm") path="forecast factor qfm"; is_leaf=1 ;;
        "forecast factor sdfm") path="forecast factor sdfm"; is_leaf=1 ;;
        "forecast factor static") path="forecast factor static"; is_leaf=1 ;;
        "forecast multivariate bvar") path="forecast multivariate bvar"; is_leaf=1 ;;
        "forecast multivariate favar") path="forecast multivariate favar"; is_leaf=1 ;;
        "forecast multivariate lp") path="forecast multivariate lp"; is_leaf=1 ;;
        "forecast multivariate qfavar") path="forecast multivariate qfavar"; is_leaf=1 ;;
        "forecast multivariate scenario") path="forecast multivariate scenario"; is_leaf=1 ;;
        "forecast multivariate var") path="forecast multivariate var"; is_leaf=1 ;;
        "forecast multivariate vecm") path="forecast multivariate vecm"; is_leaf=1 ;;
        "forecast regime ms") path="forecast regime ms"; is_leaf=1 ;;
        "forecast regime ms-ar") path="forecast regime ms-ar"; is_leaf=1 ;;
        "forecast regime setar") path="forecast regime setar"; is_leaf=1 ;;
        "forecast regime star") path="forecast regime star"; is_leaf=1 ;;
        "forecast univariate arfima") path="forecast univariate arfima"; is_leaf=1 ;;
        "forecast univariate arima") path="forecast univariate arima"; is_leaf=1 ;;
        "forecast univariate midas") path="forecast univariate midas"; is_leaf=1 ;;
        "forecast univariate sarima") path="forecast univariate sarima"; is_leaf=1 ;;
        "forecast volatility aparch") path="forecast volatility aparch"; is_leaf=1 ;;
        "forecast volatility arch") path="forecast volatility arch"; is_leaf=1 ;;
        "forecast volatility cgarch") path="forecast volatility cgarch"; is_leaf=1 ;;
        "forecast volatility egarch") path="forecast volatility egarch"; is_leaf=1 ;;
        "forecast volatility fiegarch") path="forecast volatility fiegarch"; is_leaf=1 ;;
        "forecast volatility figarch") path="forecast volatility figarch"; is_leaf=1 ;;
        "forecast volatility garch") path="forecast volatility garch"; is_leaf=1 ;;
        "forecast volatility garch-midas") path="forecast volatility garch-midas"; is_leaf=1 ;;
        "forecast volatility gjr-garch") path="forecast volatility gjr-garch"; is_leaf=1 ;;
        "forecast volatility igarch") path="forecast volatility igarch"; is_leaf=1 ;;
        "forecast volatility sv") path="forecast volatility sv"; is_leaf=1 ;;
        "hadsge accuracy") path="hadsge accuracy"; is_leaf=1 ;;
        "hadsge distribution-irf") path="hadsge distribution-irf"; is_leaf=1 ;;
        "hadsge estimate") path="hadsge estimate"; is_leaf=1 ;;
        "hadsge fevd") path="hadsge fevd"; is_leaf=1 ;;
        "hadsge hd") path="hadsge hd"; is_leaf=1 ;;
        "hadsge inequality-irf") path="hadsge inequality-irf"; is_leaf=1 ;;
        "hadsge irf") path="hadsge irf"; is_leaf=1 ;;
        "hadsge simulate") path="hadsge simulate"; is_leaf=1 ;;
        "hadsge simulate-panel") path="hadsge simulate-panel"; is_leaf=1 ;;
        "hadsge solve") path="hadsge solve"; is_leaf=1 ;;
        "hadsge steady-state") path="hadsge steady-state"; is_leaf=1 ;;
        "hd bvar") path="hd bvar"; is_leaf=1 ;;
        "hd favar") path="hd favar"; is_leaf=1 ;;
        "hd gdfm-i1") path="hd gdfm-i1"; is_leaf=1 ;;
        "hd lp") path="hd lp"; is_leaf=1 ;;
        "hd sdfm") path="hd sdfm"; is_leaf=1 ;;
        "hd var") path="hd var"; is_leaf=1 ;;
        "hd vecm") path="hd vecm"; is_leaf=1 ;;
        "io aggregate") path="io aggregate"; is_leaf=1 ;;
        "io balance") path="io balance"; is_leaf=1 ;;
        "io baqaee-farhi") path="io baqaee-farhi"; is_leaf=1 ;;
        "io bf elasticities") path="io bf elasticities"; is_leaf=1 ;;
        "io bf equilibrium") path="io bf equilibrium"; is_leaf=1 ;;
        "io bf local") path="io bf local"; is_leaf=1 ;;
        "io bf misallocation") path="io bf misallocation"; is_leaf=1 ;;
        "io bf network") path="io bf network"; is_leaf=1 ;;
        "io bf shock-curve") path="io bf shock-curve"; is_leaf=1 ;;
        "io bf wedges") path="io bf wedges"; is_leaf=1 ;;
        "io bilateral-trade") path="io bilateral-trade"; is_leaf=1 ;;
        "io download") path="io download"; is_leaf=1 ;;
        "io export-decomposition") path="io export-decomposition"; is_leaf=1 ;;
        "io extract") path="io extract"; is_leaf=1 ;;
        "io footprint") path="io footprint"; is_leaf=1 ;;
        "io ghosh") path="io ghosh"; is_leaf=1 ;;
        "io impact") path="io impact"; is_leaf=1 ;;
        "io key-sectors") path="io key-sectors"; is_leaf=1 ;;
        "io leontief") path="io leontief"; is_leaf=1 ;;
        "io linkages") path="io linkages"; is_leaf=1 ;;
        "io load") path="io load"; is_leaf=1 ;;
        "io multipliers") path="io multipliers"; is_leaf=1 ;;
        "io network-stats") path="io network-stats"; is_leaf=1 ;;
        "io price") path="io price"; is_leaf=1 ;;
        "io sda") path="io sda"; is_leaf=1 ;;
        "io sources") path="io sources"; is_leaf=1 ;;
        "io vertical-specialization") path="io vertical-specialization"; is_leaf=1 ;;
        "irf bvar") path="irf bvar"; is_leaf=1 ;;
        "irf favar") path="irf favar"; is_leaf=1 ;;
        "irf gdfm-i1") path="irf gdfm-i1"; is_leaf=1 ;;
        "irf lp") path="irf lp"; is_leaf=1 ;;
        "irf pvar") path="irf pvar"; is_leaf=1 ;;
        "irf qfavar") path="irf qfavar"; is_leaf=1 ;;
        "irf qvar") path="irf qvar"; is_leaf=1 ;;
        "irf sdfm") path="irf sdfm"; is_leaf=1 ;;
        "irf ssvarma") path="irf ssvarma"; is_leaf=1 ;;
        "irf tvpvar") path="irf tvpvar"; is_leaf=1 ;;
        "irf var") path="irf var"; is_leaf=1 ;;
        "irf vecm") path="irf vecm"; is_leaf=1 ;;
        "model convert") path="model convert"; is_leaf=1 ;;
        "model info") path="model info"; is_leaf=1 ;;
        "model keys") path="model keys"; is_leaf=1 ;;
        "model reproduce") path="model reproduce"; is_leaf=1 ;;
        "nowcast bridge") path="nowcast bridge"; is_leaf=1 ;;
        "nowcast bvar") path="nowcast bvar"; is_leaf=1 ;;
        "nowcast dfm") path="nowcast dfm"; is_leaf=1 ;;
        "nowcast forecast") path="nowcast forecast"; is_leaf=1 ;;
        "nowcast gdfm") path="nowcast gdfm"; is_leaf=1 ;;
        "nowcast news") path="nowcast news"; is_leaf=1 ;;
        "policy counterfactual bvar") path="policy counterfactual bvar"; is_leaf=1 ;;
        "policy counterfactual lp") path="policy counterfactual lp"; is_leaf=1 ;;
        "policy counterfactual var") path="policy counterfactual var"; is_leaf=1 ;;
        "policy effects bvar") path="policy effects bvar"; is_leaf=1 ;;
        "policy effects lp") path="policy effects lp"; is_leaf=1 ;;
        "policy effects sign") path="policy effects sign"; is_leaf=1 ;;
        "policy effects var") path="policy effects var"; is_leaf=1 ;;
        "policy history bvar") path="policy history bvar"; is_leaf=1 ;;
        "policy history var") path="policy history var"; is_leaf=1 ;;
        "policy jacobian ha") path="policy jacobian ha"; is_leaf=1 ;;
        "policy moments bvar") path="policy moments bvar"; is_leaf=1 ;;
        "policy moments var") path="policy moments var"; is_leaf=1 ;;
        "policy news dsge") path="policy news dsge"; is_leaf=1 ;;
        "policy news ha") path="policy news ha"; is_leaf=1 ;;
        "policy opp bvar") path="policy opp bvar"; is_leaf=1 ;;
        "policy opp var") path="policy opp var"; is_leaf=1 ;;
        "policy opp-sequence bvar") path="policy opp-sequence bvar"; is_leaf=1 ;;
        "policy opp-sequence var") path="policy opp-sequence var"; is_leaf=1 ;;
        "policy optimal bvar") path="policy optimal bvar"; is_leaf=1 ;;
        "policy optimal lp") path="policy optimal lp"; is_leaf=1 ;;
        "policy optimal var") path="policy optimal var"; is_leaf=1 ;;
        "policy spanning var") path="policy spanning var"; is_leaf=1 ;;
        "policy sufficiency dsge") path="policy sufficiency dsge"; is_leaf=1 ;;
        "predict choice logit") path="predict choice logit"; is_leaf=1 ;;
        "predict choice mlogit") path="predict choice mlogit"; is_leaf=1 ;;
        "predict choice nbreg") path="predict choice nbreg"; is_leaf=1 ;;
        "predict choice ologit") path="predict choice ologit"; is_leaf=1 ;;
        "predict choice oprobit") path="predict choice oprobit"; is_leaf=1 ;;
        "predict choice poisson") path="predict choice poisson"; is_leaf=1 ;;
        "predict choice probit") path="predict choice probit"; is_leaf=1 ;;
        "predict choice ri-logit") path="predict choice ri-logit"; is_leaf=1 ;;
        "predict factor dynamic") path="predict factor dynamic"; is_leaf=1 ;;
        "predict factor fhlz") path="predict factor fhlz"; is_leaf=1 ;;
        "predict factor gdfm") path="predict factor gdfm"; is_leaf=1 ;;
        "predict factor gdfm-i1") path="predict factor gdfm-i1"; is_leaf=1 ;;
        "predict factor qfm") path="predict factor qfm"; is_leaf=1 ;;
        "predict factor static") path="predict factor static"; is_leaf=1 ;;
        "predict factor tv-gdfm") path="predict factor tv-gdfm"; is_leaf=1 ;;
        "predict multivariate bvar") path="predict multivariate bvar"; is_leaf=1 ;;
        "predict multivariate favar") path="predict multivariate favar"; is_leaf=1 ;;
        "predict multivariate var") path="predict multivariate var"; is_leaf=1 ;;
        "predict multivariate vecm") path="predict multivariate vecm"; is_leaf=1 ;;
        "predict panel piv") path="predict panel piv"; is_leaf=1 ;;
        "predict panel plogit") path="predict panel plogit"; is_leaf=1 ;;
        "predict panel pprobit") path="predict panel pprobit"; is_leaf=1 ;;
        "predict panel preg") path="predict panel preg"; is_leaf=1 ;;
        "predict panel xtqreg") path="predict panel xtqreg"; is_leaf=1 ;;
        "predict regime ms") path="predict regime ms"; is_leaf=1 ;;
        "predict regime ms-ar") path="predict regime ms-ar"; is_leaf=1 ;;
        "predict regression 3sls") path="predict regression 3sls"; is_leaf=1 ;;
        "predict regression reg") path="predict regression reg"; is_leaf=1 ;;
        "predict regression statespace") path="predict regression statespace"; is_leaf=1 ;;
        "predict regression sur") path="predict regression sur"; is_leaf=1 ;;
        "predict univariate arfima") path="predict univariate arfima"; is_leaf=1 ;;
        "predict univariate arima") path="predict univariate arima"; is_leaf=1 ;;
        "predict univariate sarima") path="predict univariate sarima"; is_leaf=1 ;;
        "predict volatility aparch") path="predict volatility aparch"; is_leaf=1 ;;
        "predict volatility arch") path="predict volatility arch"; is_leaf=1 ;;
        "predict volatility cgarch") path="predict volatility cgarch"; is_leaf=1 ;;
        "predict volatility egarch") path="predict volatility egarch"; is_leaf=1 ;;
        "predict volatility fiegarch") path="predict volatility fiegarch"; is_leaf=1 ;;
        "predict volatility figarch") path="predict volatility figarch"; is_leaf=1 ;;
        "predict volatility garch") path="predict volatility garch"; is_leaf=1 ;;
        "predict volatility garch-midas") path="predict volatility garch-midas"; is_leaf=1 ;;
        "predict volatility gjr-garch") path="predict volatility gjr-garch"; is_leaf=1 ;;
        "predict volatility igarch") path="predict volatility igarch"; is_leaf=1 ;;
        "predict volatility sv") path="predict volatility sv"; is_leaf=1 ;;
        "residuals choice logit") path="residuals choice logit"; is_leaf=1 ;;
        "residuals choice mlogit") path="residuals choice mlogit"; is_leaf=1 ;;
        "residuals choice nbreg") path="residuals choice nbreg"; is_leaf=1 ;;
        "residuals choice ologit") path="residuals choice ologit"; is_leaf=1 ;;
        "residuals choice oprobit") path="residuals choice oprobit"; is_leaf=1 ;;
        "residuals choice poisson") path="residuals choice poisson"; is_leaf=1 ;;
        "residuals choice probit") path="residuals choice probit"; is_leaf=1 ;;
        "residuals factor dynamic") path="residuals factor dynamic"; is_leaf=1 ;;
        "residuals factor fhlz") path="residuals factor fhlz"; is_leaf=1 ;;
        "residuals factor gdfm") path="residuals factor gdfm"; is_leaf=1 ;;
        "residuals factor gdfm-i1") path="residuals factor gdfm-i1"; is_leaf=1 ;;
        "residuals factor qfm") path="residuals factor qfm"; is_leaf=1 ;;
        "residuals factor static") path="residuals factor static"; is_leaf=1 ;;
        "residuals factor tv-gdfm") path="residuals factor tv-gdfm"; is_leaf=1 ;;
        "residuals multivariate bvar") path="residuals multivariate bvar"; is_leaf=1 ;;
        "residuals multivariate favar") path="residuals multivariate favar"; is_leaf=1 ;;
        "residuals multivariate lanne-luoto") path="residuals multivariate lanne-luoto"; is_leaf=1 ;;
        "residuals multivariate lms-svar") path="residuals multivariate lms-svar"; is_leaf=1 ;;
        "residuals multivariate qvar") path="residuals multivariate qvar"; is_leaf=1 ;;
        "residuals multivariate ssvarma") path="residuals multivariate ssvarma"; is_leaf=1 ;;
        "residuals multivariate var") path="residuals multivariate var"; is_leaf=1 ;;
        "residuals multivariate vecm") path="residuals multivariate vecm"; is_leaf=1 ;;
        "residuals panel piv") path="residuals panel piv"; is_leaf=1 ;;
        "residuals panel plogit") path="residuals panel plogit"; is_leaf=1 ;;
        "residuals panel pprobit") path="residuals panel pprobit"; is_leaf=1 ;;
        "residuals panel preg") path="residuals panel preg"; is_leaf=1 ;;
        "residuals panel xtqreg") path="residuals panel xtqreg"; is_leaf=1 ;;
        "residuals regime ms") path="residuals regime ms"; is_leaf=1 ;;
        "residuals regime ms-ar") path="residuals regime ms-ar"; is_leaf=1 ;;
        "residuals regime setar") path="residuals regime setar"; is_leaf=1 ;;
        "residuals regime star") path="residuals regime star"; is_leaf=1 ;;
        "residuals regression 3sls") path="residuals regression 3sls"; is_leaf=1 ;;
        "residuals regression reg") path="residuals regression reg"; is_leaf=1 ;;
        "residuals regression statespace") path="residuals regression statespace"; is_leaf=1 ;;
        "residuals regression sur") path="residuals regression sur"; is_leaf=1 ;;
        "residuals univariate arfima") path="residuals univariate arfima"; is_leaf=1 ;;
        "residuals univariate arima") path="residuals univariate arima"; is_leaf=1 ;;
        "residuals univariate sarima") path="residuals univariate sarima"; is_leaf=1 ;;
        "residuals volatility aparch") path="residuals volatility aparch"; is_leaf=1 ;;
        "residuals volatility arch") path="residuals volatility arch"; is_leaf=1 ;;
        "residuals volatility cgarch") path="residuals volatility cgarch"; is_leaf=1 ;;
        "residuals volatility egarch") path="residuals volatility egarch"; is_leaf=1 ;;
        "residuals volatility fiegarch") path="residuals volatility fiegarch"; is_leaf=1 ;;
        "residuals volatility figarch") path="residuals volatility figarch"; is_leaf=1 ;;
        "residuals volatility garch") path="residuals volatility garch"; is_leaf=1 ;;
        "residuals volatility garch-midas") path="residuals volatility garch-midas"; is_leaf=1 ;;
        "residuals volatility gjr-garch") path="residuals volatility gjr-garch"; is_leaf=1 ;;
        "residuals volatility igarch") path="residuals volatility igarch"; is_leaf=1 ;;
        "residuals volatility sv") path="residuals volatility sv"; is_leaf=1 ;;
        "ri cg-test") path="ri cg-test"; is_leaf=1 ;;
        "ri discrete") path="ri discrete"; is_leaf=1 ;;
        "ri estimate") path="ri estimate"; is_leaf=1 ;;
        "ri fevd") path="ri fevd"; is_leaf=1 ;;
        "ri iia-test") path="ri iia-test"; is_leaf=1 ;;
        "ri irf") path="ri irf"; is_leaf=1 ;;
        "ri mw") path="ri mw"; is_leaf=1 ;;
        "ri simulate") path="ri simulate"; is_leaf=1 ;;
        "ri solve") path="ri solve"; is_leaf=1 ;;
        "ri statespace") path="ri statespace"; is_leaf=1 ;;
        "ri transition") path="ri transition"; is_leaf=1 ;;
        "schema") path="schema"; is_leaf=1 ;;
        "serve") path="serve"; is_leaf=1 ;;
        "show") path="show"; is_leaf=1 ;;
        "spectral acf") path="spectral acf"; is_leaf=1 ;;
        "spectral cross") path="spectral cross"; is_leaf=1 ;;
        "spectral density") path="spectral density"; is_leaf=1 ;;
        "spectral fevd") path="spectral fevd"; is_leaf=1 ;;
        "spectral periodogram") path="spectral periodogram"; is_leaf=1 ;;
        "spectral transfer") path="spectral transfer"; is_leaf=1 ;;
        "test brant") path="test brant"; is_leaf=1 ;;
        "test coint ardl-bounds") path="test coint ardl-bounds"; is_leaf=1 ;;
        "test coint engle-granger") path="test coint engle-granger"; is_leaf=1 ;;
        "test coint fisher-johansen") path="test coint fisher-johansen"; is_leaf=1 ;;
        "test coint gregory-hansen") path="test coint gregory-hansen"; is_leaf=1 ;;
        "test coint johansen") path="test coint johansen"; is_leaf=1 ;;
        "test coint kao") path="test coint kao"; is_leaf=1 ;;
        "test coint pedroni") path="test coint pedroni"; is_leaf=1 ;;
        "test coint phillips-ouliaris") path="test coint phillips-ouliaris"; is_leaf=1 ;;
        "test coint westerlund") path="test coint westerlund"; is_leaf=1 ;;
        "test did bacon") path="test did bacon"; is_leaf=1 ;;
        "test did honest") path="test did honest"; is_leaf=1 ;;
        "test did negweight") path="test did negweight"; is_leaf=1 ;;
        "test did pretrend") path="test did pretrend"; is_leaf=1 ;;
        "test dispersion") path="test dispersion"; is_leaf=1 ;;
        "test edf") path="test edf"; is_leaf=1 ;;
        "test factor ahn-horenstein") path="test factor ahn-horenstein"; is_leaf=1 ;;
        "test factor onatski-ed") path="test factor onatski-ed"; is_leaf=1 ;;
        "test factor onatski-q") path="test factor onatski-q"; is_leaf=1 ;;
        "test factor qfm-constancy") path="test factor qfm-constancy"; is_leaf=1 ;;
        "test factor qfm-spanning") path="test factor qfm-spanning"; is_leaf=1 ;;
        "test fisher") path="test fisher"; is_leaf=1 ;;
        "test gph") path="test gph"; is_leaf=1 ;;
        "test hansen-linearity") path="test hansen-linearity"; is_leaf=1 ;;
        "test hausman-iia") path="test hausman-iia"; is_leaf=1 ;;
        "test identifiability") path="test identifiability"; is_leaf=1 ;;
        "test influence") path="test influence"; is_leaf=1 ;;
        "test iv anderson-rubin") path="test iv anderson-rubin"; is_leaf=1 ;;
        "test iv weak-instrument") path="test iv weak-instrument"; is_leaf=1 ;;
        "test iv wild-cluster") path="test iv wild-cluster"; is_leaf=1 ;;
        "test local-whittle") path="test local-whittle"; is_leaf=1 ;;
        "test multivariate fundamentalness") path="test multivariate fundamentalness"; is_leaf=1 ;;
        "test multivariate gmm-moments") path="test multivariate gmm-moments"; is_leaf=1 ;;
        "test multivariate granger") path="test multivariate granger"; is_leaf=1 ;;
        "test multivariate lagselect") path="test multivariate lagselect"; is_leaf=1 ;;
        "test multivariate lm") path="test multivariate lm"; is_leaf=1 ;;
        "test multivariate lr") path="test multivariate lr"; is_leaf=1 ;;
        "test multivariate nongaussian-diag") path="test multivariate nongaussian-diag"; is_leaf=1 ;;
        "test multivariate stability") path="test multivariate stability"; is_leaf=1 ;;
        "test multivariate sufficient-info") path="test multivariate sufficient-info"; is_leaf=1 ;;
        "test multivariate svar-hypothesis") path="test multivariate svar-hypothesis"; is_leaf=1 ;;
        "test nardl-symmetry") path="test nardl-symmetry"; is_leaf=1 ;;
        "test normality") path="test normality"; is_leaf=1 ;;
        "test panel dh-causality") path="test panel dh-causality"; is_leaf=1 ;;
        "test panel f-fe") path="test panel f-fe"; is_leaf=1 ;;
        "test panel hausman") path="test panel hausman"; is_leaf=1 ;;
        "test panel modified-wald") path="test panel modified-wald"; is_leaf=1 ;;
        "test panel panic") path="test panel panic"; is_leaf=1 ;;
        "test panel pesaran-cd") path="test panel pesaran-cd"; is_leaf=1 ;;
        "test panel pmg-hausman") path="test panel pmg-hausman"; is_leaf=1 ;;
        "test panel wooldridge-ar") path="test panel wooldridge-ar"; is_leaf=1 ;;
        "test park-added") path="test park-added"; is_leaf=1 ;;
        "test pvar hansen-j") path="test pvar hansen-j"; is_leaf=1 ;;
        "test pvar lagselect") path="test pvar lagselect"; is_leaf=1 ;;
        "test pvar mmsc") path="test pvar mmsc"; is_leaf=1 ;;
        "test pvar stability") path="test pvar stability"; is_leaf=1 ;;
        "test serial arch-lm") path="test serial arch-lm"; is_leaf=1 ;;
        "test serial bartlett-wn") path="test serial bartlett-wn"; is_leaf=1 ;;
        "test serial bds") path="test serial bds"; is_leaf=1 ;;
        "test serial box-pierce") path="test serial box-pierce"; is_leaf=1 ;;
        "test serial breusch-pagan") path="test serial breusch-pagan"; is_leaf=1 ;;
        "test serial durbin-watson") path="test serial durbin-watson"; is_leaf=1 ;;
        "test serial glejser") path="test serial glejser"; is_leaf=1 ;;
        "test serial harvey") path="test serial harvey"; is_leaf=1 ;;
        "test serial heteroskedasticity") path="test serial heteroskedasticity"; is_leaf=1 ;;
        "test serial ljung-box") path="test serial ljung-box"; is_leaf=1 ;;
        "test serial sign-bias") path="test serial sign-bias"; is_leaf=1 ;;
        "test serial white") path="test serial white"; is_leaf=1 ;;
        "test stability andrews") path="test stability andrews"; is_leaf=1 ;;
        "test stability bai-perron") path="test stability bai-perron"; is_leaf=1 ;;
        "test stability chow") path="test stability chow"; is_leaf=1 ;;
        "test stability cusum") path="test stability cusum"; is_leaf=1 ;;
        "test stability cusumsq") path="test stability cusumsq"; is_leaf=1 ;;
        "test stability factor-break") path="test stability factor-break"; is_leaf=1 ;;
        "test stability gsadf") path="test stability gsadf"; is_leaf=1 ;;
        "test stability hansen-instability") path="test stability hansen-instability"; is_leaf=1 ;;
        "test stability nyblom") path="test stability nyblom"; is_leaf=1 ;;
        "test stability recursive-residuals") path="test stability recursive-residuals"; is_leaf=1 ;;
        "test stability sadf") path="test stability sadf"; is_leaf=1 ;;
        "test star-linearity") path="test star-linearity"; is_leaf=1 ;;
        "test unit-root adf") path="test unit-root adf"; is_leaf=1 ;;
        "test unit-root adf-2break") path="test unit-root adf-2break"; is_leaf=1 ;;
        "test unit-root breitung") path="test unit-root breitung"; is_leaf=1 ;;
        "test unit-root cips") path="test unit-root cips"; is_leaf=1 ;;
        "test unit-root dfgls") path="test unit-root dfgls"; is_leaf=1 ;;
        "test unit-root ers") path="test unit-root ers"; is_leaf=1 ;;
        "test unit-root fourier-adf") path="test unit-root fourier-adf"; is_leaf=1 ;;
        "test unit-root fourier-kpss") path="test unit-root fourier-kpss"; is_leaf=1 ;;
        "test unit-root hadri") path="test unit-root hadri"; is_leaf=1 ;;
        "test unit-root hegy") path="test unit-root hegy"; is_leaf=1 ;;
        "test unit-root ips") path="test unit-root ips"; is_leaf=1 ;;
        "test unit-root kpss") path="test unit-root kpss"; is_leaf=1 ;;
        "test unit-root llc") path="test unit-root llc"; is_leaf=1 ;;
        "test unit-root lm-unitroot") path="test unit-root lm-unitroot"; is_leaf=1 ;;
        "test unit-root moon-perron") path="test unit-root moon-perron"; is_leaf=1 ;;
        "test unit-root np") path="test unit-root np"; is_leaf=1 ;;
        "test unit-root pp") path="test unit-root pp"; is_leaf=1 ;;
        "test unit-root za") path="test unit-root za"; is_leaf=1 ;;
        "test variance-ratio") path="test variance-ratio"; is_leaf=1 ;;
        "test vecm alpha") path="test vecm alpha"; is_leaf=1 ;;
        "test vecm beta") path="test vecm beta"; is_leaf=1 ;;
        "test vecm joint") path="test vecm joint"; is_leaf=1 ;;
        "test vecm known-beta") path="test vecm known-beta"; is_leaf=1 ;;
        "test vecm weak-exog") path="test vecm weak-exog"; is_leaf=1 ;;
        "test vif") path="test vif"; is_leaf=1 ;;
        "repl") path="repl"; is_leaf=1 ;;
      esac
    fi
    ((i++))
  done

  case "$path" in
    "")
      if [[ "$prev" == "--digits" ]]; then
        COMPREPLY=( $(compgen -W "0 1 2 3 4 6 full" -- "$cur") )
      elif [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h --version -V --warranty --conditions --quiet -q --no-color --json -J --compact --seed --digits" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "completions data did dsge estimate fevd filter forecast hadsge hd io irf model nowcast policy predict repl residuals ri schema serve show spectral test" -- "$cur") )
      fi ;;
    "completions")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bash fish zsh" -- "$cur") )
      fi ;;
    "data")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "balance describe diagnose dropna export filter fix import keeprows list load simulate transform validate" -- "$cur") )
      fi ;;
    "data simulate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "ardl arima cointreg cross-section ct did dsge factors garch gdfm-infinite gmm ha heteroskedastic-var lp-iv olg panel pvar qfavar qfm regime ssvarma sv svar var vecm" -- "$cur") )
      fi ;;
    "did")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "estimate event-study lp-did" -- "$cur") )
      fi ;;
    "dsge")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "abcd bank bayes ct dcegm determinacy-map estimate fevd firm hd irf lifecycle moments olg perfect-foresight simulate solve steady-state var" -- "$cur") )
      fi ;;
    "dsge abcd")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "audit-irf extract innovations invertibility population-var recoverability search-observables" -- "$cur") )
      fi ;;
    "dsge bank")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "irf pe steady-state transition" -- "$cur") )
      fi ;;
    "dsge bayes")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "compare estimate fevd hd identification irf learning-rate marginal-lik mcmc-diag overlap posterior-mode predictive prior-predictive simulate summary" -- "$cur") )
      fi ;;
    "dsge ct")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "fevd irf solve transition" -- "$cur") )
      fi ;;
    "dsge dcegm")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "fevd irf simulate solve steady-state transition" -- "$cur") )
      fi ;;
    "dsge firm")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "irf steady-state transition" -- "$cur") )
      fi ;;
    "dsge lifecycle")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "fevd irf simulate steady-state transition" -- "$cur") )
      fi ;;
    "dsge olg")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "fevd irf simulate solve" -- "$cur") )
      fi ;;
    "dsge var")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "estimate fevd forecast hd irf lambda prior" -- "$cur") )
      fi ;;
    "estimate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "choice factor multivariate panel regime regression univariate volatility" -- "$cur") )
      fi ;;
    "estimate choice")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "logit mlogit nbreg ologit oprobit poisson probit ri-logit" -- "$cur") )
      fi ;;
    "estimate factor")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "dynamic fastica fhlz gdfm gdfm-i1 qfm sdfm static tv-gdfm" -- "$cur") )
      fi ;;
    "estimate multivariate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar favar lanne-luoto lms-svar lp mfvar qfavar qvar ssvarma svar svec tvpvar var vecm" -- "$cur") )
      fi ;;
    "estimate panel")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "piv plogit pmg pprobit preg pvar xtcointreg xtqreg" -- "$cur") )
      fi ;;
    "estimate regime")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "ms ms-ar setar star threshold tvp" -- "$cur") )
      fi ;;
    "estimate regression")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "3sls cointreg elastic-net gmm heckman iv kde kernel-reg lasso lowess ml qreg rdd reg ridge robust select smm statespace sur tobit truncreg" -- "$cur") )
      fi ;;
    "estimate univariate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "ardl arfima arima midas nardl sarima" -- "$cur") )
      fi ;;
    "estimate volatility")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "aparch arch bekk ccc cgarch dcc egarch fiegarch figarch garch garch-midas gjr-garch igarch sv" -- "$cur") )
      fi ;;
    "fevd")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar favar gdfm-i1 lp pvar sdfm ssvarma var vecm" -- "$cur") )
      fi ;;
    "filter")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bandpass-gdfm bhp bk bn eurocoin hamilton hp x13" -- "$cur") )
      fi ;;
    "forecast")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "evaluate factor multivariate regime univariate volatility" -- "$cur") )
      fi ;;
    "forecast evaluate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "clark-west combine dm encompassing metrics mincer-zarnowitz" -- "$cur") )
      fi ;;
    "forecast factor")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "dynamic gdfm gdfm-i1 growth-at-risk qfm sdfm static" -- "$cur") )
      fi ;;
    "forecast multivariate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar favar lp qfavar scenario var vecm" -- "$cur") )
      fi ;;
    "forecast regime")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "ms ms-ar setar star" -- "$cur") )
      fi ;;
    "forecast univariate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "arfima arima midas sarima" -- "$cur") )
      fi ;;
    "forecast volatility")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "aparch arch cgarch egarch fiegarch figarch garch garch-midas gjr-garch igarch sv" -- "$cur") )
      fi ;;
    "hadsge")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "accuracy distribution-irf estimate fevd hd inequality-irf irf simulate simulate-panel solve steady-state" -- "$cur") )
      fi ;;
    "hd")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar favar gdfm-i1 lp sdfm var vecm" -- "$cur") )
      fi ;;
    "io")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "aggregate balance baqaee-farhi bf bilateral-trade download export-decomposition extract footprint ghosh impact key-sectors leontief linkages load multipliers network-stats price sda sources vertical-specialization" -- "$cur") )
      fi ;;
    "io bf")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "elasticities equilibrium local misallocation network shock-curve wedges" -- "$cur") )
      fi ;;
    "irf")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar favar gdfm-i1 lp pvar qfavar qvar sdfm ssvarma tvpvar var vecm" -- "$cur") )
      fi ;;
    "model")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "convert info keys reproduce" -- "$cur") )
      fi ;;
    "nowcast")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bridge bvar dfm forecast gdfm news" -- "$cur") )
      fi ;;
    "policy")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "counterfactual effects history jacobian moments news opp opp-sequence optimal spanning sufficiency" -- "$cur") )
      fi ;;
    "policy counterfactual")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar lp var" -- "$cur") )
      fi ;;
    "policy effects")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar lp sign var" -- "$cur") )
      fi ;;
    "policy history")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar var" -- "$cur") )
      fi ;;
    "policy jacobian")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "ha" -- "$cur") )
      fi ;;
    "policy moments")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar var" -- "$cur") )
      fi ;;
    "policy news")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "dsge ha" -- "$cur") )
      fi ;;
    "policy opp")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar var" -- "$cur") )
      fi ;;
    "policy opp-sequence")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar var" -- "$cur") )
      fi ;;
    "policy optimal")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar lp var" -- "$cur") )
      fi ;;
    "policy spanning")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "var" -- "$cur") )
      fi ;;
    "policy sufficiency")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "dsge" -- "$cur") )
      fi ;;
    "predict")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "choice factor multivariate panel regime regression univariate volatility" -- "$cur") )
      fi ;;
    "predict choice")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "logit mlogit nbreg ologit oprobit poisson probit ri-logit" -- "$cur") )
      fi ;;
    "predict factor")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "dynamic fhlz gdfm gdfm-i1 qfm static tv-gdfm" -- "$cur") )
      fi ;;
    "predict multivariate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar favar var vecm" -- "$cur") )
      fi ;;
    "predict panel")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "piv plogit pprobit preg xtqreg" -- "$cur") )
      fi ;;
    "predict regime")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "ms ms-ar" -- "$cur") )
      fi ;;
    "predict regression")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "3sls reg statespace sur" -- "$cur") )
      fi ;;
    "predict univariate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "arfima arima sarima" -- "$cur") )
      fi ;;
    "predict volatility")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "aparch arch cgarch egarch fiegarch figarch garch garch-midas gjr-garch igarch sv" -- "$cur") )
      fi ;;
    "residuals")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "choice factor multivariate panel regime regression univariate volatility" -- "$cur") )
      fi ;;
    "residuals choice")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "logit mlogit nbreg ologit oprobit poisson probit" -- "$cur") )
      fi ;;
    "residuals factor")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "dynamic fhlz gdfm gdfm-i1 qfm static tv-gdfm" -- "$cur") )
      fi ;;
    "residuals multivariate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bvar favar lanne-luoto lms-svar qvar ssvarma var vecm" -- "$cur") )
      fi ;;
    "residuals panel")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "piv plogit pprobit preg xtqreg" -- "$cur") )
      fi ;;
    "residuals regime")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "ms ms-ar setar star" -- "$cur") )
      fi ;;
    "residuals regression")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "3sls reg statespace sur" -- "$cur") )
      fi ;;
    "residuals univariate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "arfima arima sarima" -- "$cur") )
      fi ;;
    "residuals volatility")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "aparch arch cgarch egarch fiegarch figarch garch garch-midas gjr-garch igarch sv" -- "$cur") )
      fi ;;
    "ri")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "cg-test discrete estimate fevd iia-test irf mw simulate solve statespace transition" -- "$cur") )
      fi ;;
    "spectral")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "acf cross density fevd periodogram transfer" -- "$cur") )
      fi ;;
    "test")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "brant coint did dispersion edf factor fisher gph hansen-linearity hausman-iia identifiability influence iv local-whittle multivariate nardl-symmetry normality panel park-added pvar serial stability star-linearity unit-root variance-ratio vecm vif" -- "$cur") )
      fi ;;
    "test coint")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "ardl-bounds engle-granger fisher-johansen gregory-hansen johansen kao pedroni phillips-ouliaris westerlund" -- "$cur") )
      fi ;;
    "test did")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "bacon honest negweight pretrend" -- "$cur") )
      fi ;;
    "test factor")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "ahn-horenstein onatski-ed onatski-q qfm-constancy qfm-spanning" -- "$cur") )
      fi ;;
    "test iv")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "anderson-rubin weak-instrument wild-cluster" -- "$cur") )
      fi ;;
    "test multivariate")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "fundamentalness gmm-moments granger lagselect lm lr nongaussian-diag stability sufficient-info svar-hypothesis" -- "$cur") )
      fi ;;
    "test panel")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "dh-causality f-fe hausman modified-wald panic pesaran-cd pmg-hausman wooldridge-ar" -- "$cur") )
      fi ;;
    "test pvar")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "hansen-j lagselect mmsc stability" -- "$cur") )
      fi ;;
    "test serial")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "arch-lm bartlett-wn bds box-pierce breusch-pagan durbin-watson glejser harvey heteroskedasticity ljung-box sign-bias white" -- "$cur") )
      fi ;;
    "test stability")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "andrews bai-perron chow cusum cusumsq factor-break gsadf hansen-instability nyblom recursive-residuals sadf" -- "$cur") )
      fi ;;
    "test unit-root")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "adf adf-2break breitung cips dfgls ers fourier-adf fourier-kpss hadri hegy ips kpss llc lm-unitroot moon-perron np pp za" -- "$cur") )
      fi ;;
    "test vecm")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "alpha beta joint known-beta weak-exog" -- "$cur") )
      fi ;;
    "completions bash")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "completions fish")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "completions zsh")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data balance")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "dfm" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --factors -q --lags -p --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data describe")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data diagnose")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data dropna")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--vars --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data export")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--output -o --format -f --no-dates --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data filter")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "hp hamilton bn bk bhp" -- "$cur") ); return ;;
        --component) COMPREPLY=( $(compgen -W "cycle trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --component --lambda -l --horizons -H --lags -p --columns --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data fix")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "listwise interpolate mean" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data import")
      case "$prev" in
        --kind) COMPREPLY=( $(compgen -W "timeseries panel cross-section" -- "$cur") ); return ;;
        --frequency) COMPREPLY=( $(compgen -W "daily monthly quarterly annual mixed other" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--kind --frequency --dates --id-col -u --time-col -t --vars --tcodes --note --output -o --format -f --strict-missing --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data keeprows")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--rows --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data list")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data load")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --kind) COMPREPLY=( $(compgen -W "timeseries panel cross-section" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--output -o --format -f --vars --country --dates --path --kind --transform -t --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate ardl")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--phi --beta0 --beta1 --periods -N --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate arima")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--phi --theta --diff --sigma --drift --periods -N --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate cointreg")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--endog-rho --sigma-u --periods -N --seed --save-data --format -f --output -o --spurious --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate cross-section")
      case "$prev" in
        --kind) COMPREPLY=( $(compgen -W "ols hc cluster iv logit probit ordered mlogit poisson nb tobit truncreg heckman qreg rdd" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--kind --n --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate ct")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--alpha --rho --sigma --delta --z --shock-size --grid-size --a-max --max-iter -I --tol -T --dt --periods -N --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate did")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--n --periods -N --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate dsge")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "gensys klein perturbation projection pfi vfi blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --order -O --meas-sd --periods -N --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate factors")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--series --periods -N --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate garch")
      case "$prev" in
        --kind) COMPREPLY=( $(compgen -W "arch garch egarch gjr aparch igarch cgarch figarch fiegarch" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--kind --periods -N --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate gdfm-infinite")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--periods -N --series --dynamic-rank --a-coef --b-coef --n-permanent --signal-share --idio-ar --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate gmm")
      case "$prev" in
        --kind) COMPREPLY=( $(compgen -W "ols iv" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--kind --n --pi1 --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate ha")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "ssj reiter krusell-smith" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --n-reduced --distribution --hh-solver --periods -N --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate heteroskedastic-var")
      case "$prev" in
        --kind) COMPREPLY=( $(compgen -W "markov garch smooth external" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--kind --periods -N --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate lp-iv")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--pi1 --theta --periods -N --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate olg")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--alpha --beta --delta --gamma --z --debt --k0 --periods -N --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate panel")
      case "$prev" in
        --kind) COMPREPLY=( $(compgen -W "linear logit probit" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--kind --n --periods -N --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate pvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--n --periods -N --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate qfavar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--periods -N --series --factors -q --lags -p --n-key --df-idio --tail-amplification --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate qfm")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--periods -N --series --location-factors --scale-factors --asym-factors --df-idio --idio-scale --loadings-scale --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate regime")
      case "$prev" in
        --kind) COMPREPLY=( $(compgen -W "ms setar lstar estr" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--kind --periods -N --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate ssvarma")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "student-t t laplace mixture mixture-normal-asym skew skew-normal ged gauss" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--periods -N --dist --nu --skew --burn -B --config -C --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate sv")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--mu --phi --sigma-eta --periods -N --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate svar")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "gauss t laplace mixture skew" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dist --nu --periods -N --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--periods -N --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data simulate vecm")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--periods -N --burn -B --seed --save-data --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data transform")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--tcodes --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "data validate")
      case "$prev" in
        --model|-M) COMPREPLY=( $(compgen -W "var bvar vecm arima garch sv lp gmm factor arch egarch gjr-garch gjr_garch static dynamic gdfm" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "did estimate")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "twfe cs sa bjs dcdh" -- "$cur") ); return ;;
        --control-group) COMPREPLY=( $(compgen -W "never_treated not_yet_treated" -- "$cur") ); return ;;
        --cluster) COMPREPLY=( $(compgen -W "unit time twoway" -- "$cur") ); return ;;
        --base-period) COMPREPLY=( $(compgen -W "varying universal" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--outcome --treatment --method -m --id-col -u --time-col -t --leads --horizons -H --covariates --control-group --cluster --conf-level -L --n-boot --base-period --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "did event-study")
      case "$prev" in
        --cluster) COMPREPLY=( $(compgen -W "unit time twoway" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--outcome --treatment --id-col -u --time-col -t --leads --horizons -H --lags -p --covariates --cluster --conf-level -L --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "did lp-did")
      case "$prev" in
        --cluster) COMPREPLY=( $(compgen -W "unit time twoway" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--outcome --treatment --id-col -u --time-col -t --horizons -H --pre-window --post-window --ylags --dylags --covariates --cluster --conf-level -L --pmd --nonabsorbing --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --reweight --nocomp --notyet --nevertreated --firsttreat --oneoff --only-pooled --only-event --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge abcd audit-irf")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "best-rotation cholesky long-run sign" -- "$cur") ); return ;;
        --reduction) COMPREPLY=( $(compgen -W "minimal predetermined none" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --lags -p --horizons -H --id -i --config -C --observables --n-obs-effective --unit-root-damping --rcond-tol --max-draws --reduction --measurement-error --solver -s --order -O --result -R --save-result -W --format -f --output -o --plot-save -G --config-json --set --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge abcd extract")
      case "$prev" in
        --reduction) COMPREPLY=( $(compgen -W "predetermined minimal none" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --observables --reduction --measurement-error --tol -T --solver -s --order -O --save-model -S --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge abcd innovations")
      case "$prev" in
        --reduction) COMPREPLY=( $(compgen -W "predetermined minimal none" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --observables --reduction --measurement-error --rcond-tol --solver -s --order -O --save-model -S --format -f --output -o --plot-save -G --as-abcd --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge abcd invertibility")
      case "$prev" in
        --reduction) COMPREPLY=( $(compgen -W "predetermined minimal none" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --observables --reduction --measurement-error --tol -T --max-var-lags --solver -s --order -O --result -R --save-result -W --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge abcd population-var")
      case "$prev" in
        --reduction) COMPREPLY=( $(compgen -W "minimal predetermined none" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --lags -p --observables --n-obs-effective --unit-root-damping --reduction --measurement-error --solver -s --order -O --save-model -S --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge abcd recoverability")
      case "$prev" in
        --reduction) COMPREPLY=( $(compgen -W "minimal predetermined none" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --observables --max-lead --reduction --measurement-error --rcond-tol --solver -s --order -O --result -R --save-result -W --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge abcd search-observables")
      case "$prev" in
        --reduction) COMPREPLY=( $(compgen -W "minimal predetermined none" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --k --candidates --must-include --target-shocks --max-combinations --measurement-error --reduction --tol -T --rcond-tol --solver -s --order -O --result -R --save-result -W --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bank irf")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shock-size --persist --n-n --n-xi --z --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bank pe")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--n-n --n-xi --n-min --n-max --beta --sigma --lambda -l --zeta1 --zeta2 --r --rk --z --alpha --max-iter -I --tol -T --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bank steady-state")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--n-n --n-xi --n-min --n-max --beta --sigma --lambda -l --r --z --alpha --r-lo --r-hi --tol -T --max-iter -I --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bank transition")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--z-path --n-n --n-xi --z --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes compare")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --observables --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --model2 --params2 --priors2 --delayed-acceptance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes estimate")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --observables --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --conf-level -L --quantiles -Q --save-model -S --delayed-acceptance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes fevd")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --observables --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --horizons -H --conf-level -L --quantiles -Q --plot-save -G --delayed-acceptance --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes hd")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --observables --n-hd-draws --conf-level -L --quantiles -Q --horizons -H --plot-save -G --mode-only --delayed-acceptance --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes identification")
      case "$prev" in
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--params --observables --solver -s --order -O --n-lags --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes irf")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --observables --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --horizons -H --conf-level -L --quantiles -Q --plot-save -G --delayed-acceptance --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes learning-rate")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --observables --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --fractions --threshold --refit-n-smc --delayed-acceptance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes marginal-lik")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --proposal) COMPREPLY=( $(compgen -W "normal t" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --observables --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --proposal --df --delayed-acceptance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes mcmc-diag")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --observables --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --delayed-acceptance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes overlap")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --observables --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --threshold --n-grid --delayed-acceptance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes posterior-mode")
      case "$prev" in
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --observables --solver -s --order -O --constraint-solver --measurement-error --output -o --format -f --max-iter -I --f-reltol --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes predictive")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --observables --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --n-sim --periods -N --plot-save -G --delayed-acceptance --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes prior-predictive")
      case "$prev" in
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--params --priors --prior --observables --solver -s --order -O --constraint-solver --draws -n --output -o --format -f --periods -N --conf-level -L --quantiles -Q --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes simulate")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --observables --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --periods -N --conf-level -L --quantiles -Q --plot-save -G --delayed-acceptance --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge bayes summary")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "smc smc2 mh" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --prefilter) COMPREPLY=( $(compgen -W "none demean first-difference linear-detrend hp" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --params --priors --prior --sampler --n-smc --n-particles --draws -n --burnin -B --ess-target --observables --solver -s --order -O --constraint-solver --prefilter --hp-lambda --measurement-error --output -o --format -f --conf-level -L --quantiles -Q --delayed-acceptance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge ct fevd")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--alpha --rho --sigma --delta --z --horizons -H --shock-size --persist --dt --grid-size --output -o --format -f --plot-save -G --result -R --save-result -W --two-asset --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge ct irf")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--alpha --rho --sigma --delta --z --horizons -H --shock-size --persist --dt --grid-size --output -o --format -f --plot-save -G --result -R --save-result -W --two-asset --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge ct solve")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--alpha --rho --sigma --delta --z --a-min --a-max --grid-size --max-iter -I --tol -T --output -o --format -f --save-model -S --two-asset --ge --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge ct transition")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--alpha --rho --sigma --delta --z --shock-size --periods -N --dt --a-max --grid-size --max-iter -I --tol -T --output -o --format -f --z-path --plot-save -G --result -R --save-result -W --plot -g --two-asset --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge dcegm fevd")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--n-periods --beta --wage --n-a --a-max --alpha --delta --z --horizons -H --shock-size --persist --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge dcegm irf")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--n-periods --beta --wage --n-a --a-max --alpha --delta --z --horizons -H --shock-size --persist --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge dcegm simulate")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--n-periods --beta --wage --n-a --a-max --alpha --delta --z --periods -N --shock-size --persist --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge dcegm solve")
      case "$prev" in
        --view) COMPREPLY=( $(compgen -W "policy threshold" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--n-periods --beta --r --wage --disutility --sigma --n-shocks --taste-shock-scale --a-max --n-a --pension --credit-limit --curvature --max-iter -I --tol -T --period --income --view --output -o --format -f --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge dcegm steady-state")
      case "$prev" in
        --labor) COMPREPLY=( $(compgen -W "exogenous measured" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--n-periods --beta --r --wage --disutility --sigma --n-shocks --taste-shock-scale --a-max --n-a --pension --credit-limit --curvature --alpha --delta --z --l --r-lo --r-hi --labor --work-option --n-sim --tol -T --max-iter -I --output -o --format -f --save-model -S --reprice-wage --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge dcegm transition")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--z-path --n-periods --beta --wage --n-a --a-max --alpha --delta --z --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge determinacy-map")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --rank-rtol --output -o --format -f --plot-save -G --result -R --save-result -W --threaded --verbose-solver --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge estimate")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "irf_matching euler_gmm smm analytical_gmm" -- "$cur") ); return ;;
        --weighting|-w) COMPREPLY=( $(compgen -W "identity optimal diagonal two_step efficient cee" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --method -m --params --solve-method --solve-order --weighting -w --irf-horizon --var-lags --sim-ratio --bounds --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge fevd")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "gensys klein perturbation projection pfi vfi blanchard-kahn" -- "$cur") ); return ;;
        --grid) COMPREPLY=( $(compgen -W "auto chebyshev smolyak tensor" -- "$cur") ); return ;;
        --next-state) COMPREPLY=( $(compgen -W "auto linear residual policy nonlinear" -- "$cur") ); return ;;
        --optimizer) COMPREPLY=( $(compgen -W "auto grid1d fminbox-nm fminbox-lbfgs" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --order -O --degree --grid --next-state --howard-steps --n-grid --n-choice --optimizer --smolyak-mu --n-quad --scale --tol -T --max-iter -I --damping --anderson-m --horizons -H --output -o --format -f --plot-save -G --result -R --save-result -W --unconditional --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge firm irf")
      case "$prev" in
        --prices) COMPREPLY=( $(compgen -W "ss ge" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shock-size --persist --prices --n-k --n-eps --z --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge firm steady-state")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--n-k --n-eps --alpha --nu --delta --beta --gamma --xi-bar --b --phi --rho-z --sigma-z --rho-e --sigma-e --z --tol -T --max-iter -I --dampen --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge firm transition")
      case "$prev" in
        --prices) COMPREPLY=( $(compgen -W "ss ge" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--z-path --prices --n-k --n-eps --z --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge hd")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "gensys klein perturbation projection pfi vfi blanchard-kahn" -- "$cur") ); return ;;
        --grid) COMPREPLY=( $(compgen -W "auto chebyshev smolyak tensor" -- "$cur") ); return ;;
        --next-state) COMPREPLY=( $(compgen -W "auto linear residual policy nonlinear" -- "$cur") ); return ;;
        --optimizer) COMPREPLY=( $(compgen -W "auto grid1d fminbox-nm fminbox-lbfgs" -- "$cur") ); return ;;
        --states) COMPREPLY=( $(compgen -W "observables all" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --order -O --grid --next-state --howard-steps --n-grid --n-choice --optimizer --smolyak-mu --n-quad --scale --tol -T --max-iter -I --damping --anderson-m --data -d --observables --states --measurement-error --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge irf")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "gensys klein perturbation projection pfi vfi blanchard-kahn" -- "$cur") ); return ;;
        --grid) COMPREPLY=( $(compgen -W "auto chebyshev smolyak tensor" -- "$cur") ); return ;;
        --next-state) COMPREPLY=( $(compgen -W "auto linear residual policy nonlinear" -- "$cur") ); return ;;
        --optimizer) COMPREPLY=( $(compgen -W "auto grid1d fminbox-nm fminbox-lbfgs" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --order -O --degree --grid --next-state --howard-steps --n-grid --n-choice --optimizer --smolyak-mu --n-quad --scale --tol -T --max-iter -I --damping --anderson-m --horizons -H --shock-size --n-sim --constraints --constraint --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge lifecycle fevd")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--j --j-retire --n-a --income-states --horizons -H --shock-size --persist --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge lifecycle irf")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--j --j-retire --n-a --income-states --horizons -H --shock-size --persist --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge lifecycle simulate")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--j --j-retire --n-a --income-states --periods -N --shock-size --persist --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge lifecycle steady-state")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--j --j-retire --survival --a-max --n-a --beta --sigma --alpha --delta --z --n-pop --replacement --credit-limit --income-rho --income-sigma --income-states --config -C --r-lo --r-hi --tol -T --max-iter -I --bequest-iter --output -o --format -f --plot-save -G --save-model -S --no-annuities --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge lifecycle transition")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--j --j-retire --survival --a-max --n-a --beta --sigma --alpha --delta --z --income-rho --income-sigma --income-states --config -C --k0 --z-path --horizons -H --tol -T --max-iter -I --relax --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge moments")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --order -O --lags -p --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge olg fevd")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--alpha --beta --delta --gamma --z --debt --rho-z --sigma-z --horizons -H --kappa --phi-pi --phi-y --rho-i --sigma-i --omega --output -o --format -f --plot-save -G --result -R --save-result -W --nk --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge olg irf")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--alpha --beta --delta --gamma --z --debt --rho-z --sigma-z --horizons -H --shock-size --kappa --phi-pi --phi-y --rho-i --sigma-i --omega --output -o --format -f --plot-save -G --result -R --save-result -W --nk --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge olg simulate")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--alpha --beta --delta --gamma --z --debt --k0 --horizons -H --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge olg solve")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--alpha --beta --delta --gamma --z --debt --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge perfect-foresight")
      case "$prev" in
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --sparsity) COMPREPLY=( $(compgen -W "auto dense" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--shocks --constraints --constraint --constraint-solver --periods -N --sparsity --max-iter -I --tol -T --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge simulate")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "gensys klein perturbation projection pfi vfi blanchard-kahn" -- "$cur") ); return ;;
        --grid) COMPREPLY=( $(compgen -W "auto chebyshev smolyak tensor" -- "$cur") ); return ;;
        --next-state) COMPREPLY=( $(compgen -W "auto linear residual policy nonlinear" -- "$cur") ); return ;;
        --optimizer) COMPREPLY=( $(compgen -W "auto grid1d fminbox-nm fminbox-lbfgs" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --order -O --degree --grid --next-state --howard-steps --n-grid --n-choice --optimizer --smolyak-mu --n-quad --scale --tol -T --max-iter -I --damping --anderson-m --periods -N --burn -B --seed --output -o --format -f --plot-save -G --antithetic --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge solve")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "gensys klein perturbation projection pfi vfi blanchard-kahn" -- "$cur") ); return ;;
        --grid) COMPREPLY=( $(compgen -W "auto chebyshev smolyak tensor" -- "$cur") ); return ;;
        --next-state) COMPREPLY=( $(compgen -W "auto linear residual policy nonlinear" -- "$cur") ); return ;;
        --optimizer) COMPREPLY=( $(compgen -W "auto grid1d fminbox-nm fminbox-lbfgs" -- "$cur") ); return ;;
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --order -O --degree --grid --next-state --howard-steps --n-grid --n-choice --optimizer --smolyak-mu --n-quad --scale --tol -T --max-iter -I --damping --anderson-m --evaluate-at --constraints --constraint --constraint-solver --periods -N --output -o --format -f --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge steady-state")
      case "$prev" in
        --constraint-solver) COMPREPLY=( $(compgen -W "nonlinearsolve optim nlopt madnlp ipopt path" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--constraints --constraint --constraint-solver --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge var estimate")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "rwmh smc" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --data -d --lags -p --lambda -l --draws -n --priors --prior --method -m --burnin -B --n-particles --step-scale --observables --measurement-jitter --solver -s --order -O --conf-level -L --save-model -S --format -f --output -o --plot-save -G --no-intercept --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge var fevd")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "dsge-qr cholesky long-run" -- "$cur") ); return ;;
        --point-estimate) COMPREPLY=( $(compgen -W "mean median" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "rwmh smc" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --id -i --horizons -H --conf-level -L --quantiles -Q --point-estimate --data -d --lags -p --lambda -l --draws -n --priors --prior --method -m --burnin -B --n-particles --step-scale --observables --measurement-jitter --solver -s --order -O --result -R --save-result -W --format -f --output -o --plot-save -G --no-intercept --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge var forecast")
      case "$prev" in
        --point-estimate) COMPREPLY=( $(compgen -W "mean median" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "rwmh smc" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --horizons -H --conf-level -L --quantiles -Q --point-estimate --data -d --lags -p --lambda -l --draws -n --priors --prior --method -m --burnin -B --n-particles --step-scale --observables --measurement-jitter --solver -s --order -O --result -R --save-result -W --format -f --output -o --plot-save -G --no-intercept --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge var hd")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "dsge-qr cholesky long-run" -- "$cur") ); return ;;
        --point-estimate) COMPREPLY=( $(compgen -W "mean median" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "rwmh smc" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --id -i --horizons -H --conf-level -L --quantiles -Q --point-estimate --data -d --lags -p --lambda -l --draws -n --priors --prior --method -m --burnin -B --n-particles --step-scale --observables --measurement-jitter --solver -s --order -O --result -R --save-result -W --format -f --output -o --plot-save -G --no-intercept --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge var irf")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "dsge-qr cholesky long-run" -- "$cur") ); return ;;
        --point-estimate) COMPREPLY=( $(compgen -W "mean median" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "rwmh smc" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --id -i --horizons -H --shock -K --conf-level -L --quantiles -Q --point-estimate --data -d --lags -p --lambda -l --draws -n --priors --prior --method -m --burnin -B --n-particles --step-scale --observables --measurement-jitter --solver -s --order -O --result -R --save-result -W --format -f --output -o --plot-save -G --no-intercept --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge var lambda")
      case "$prev" in
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --data -d --lags -p --lambda -l --lambda-grid --observables --measurement-jitter --solver -s --order -O --result -R --save-result -W --format -f --output -o --plot-save -G --no-refine --no-intercept --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "dsge var prior")
      case "$prev" in
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein perturbation blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --lags -p --lambda -l --t-obs --observables --measurement-jitter --solver -s --order -O --save-model -S --format -f --output -o --plot-save -G --no-intercept --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate choice logit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --max-iter -I --tol -T --conf-level -L --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate choice mlogit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate choice nbreg")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --offset --exposure --max-iter -I --tol -T --conf-level -L --output -o --format -f --save-model -S --irr --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate choice ologit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --conf-level -L --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate choice oprobit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --conf-level -L --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate choice poisson")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "robust mle hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --offset --exposure --cov-type -v --clusters -U --max-iter -I --tol -T --conf-level -L --output -o --format -f --save-model -S --irr --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate choice probit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --max-iter -I --tol -T --conf-level -L --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate choice ri-logit")
      case "$prev" in
        --normalize) COMPREPLY=( $(compgen -W "auto omega-one none first-coef" -- "$cur") ); return ;;
        --cov-type|-v) COMPREPLY=( $(compgen -W "hessian sandwich" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--env-col --choice-col --alt-col --state-col --obs-col --attr-cols --config -C --priors --normalize --cov-type -v --tol -T --max-iter -I --conf-level -L --format -f --output -o --plot-save -G --save-model -S --config-json --set --unobserved-state --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate factor dynamic")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "twostep em" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --factor-lags --method -m --output -o --format -f --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate factor fastica")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "fastica jade sobi dcov hsic cvm" -- "$cur") ); return ;;
        --contrast) COMPREPLY=( $(compgen -W "logcosh exp kurtosis" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --method -m --contrast --n-starts --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate factor fhlz")
      case "$prev" in
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --lag-criterion) COMPREPLY=( $(compgen -W "bic aic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --bandwidth -b --kernel -k --p-max --lag-criterion --n-perm --irf-horizon --em-max-iter --em-tol --seed --format -f --output -o --plot-save -G --save-model -S --allow-missing --no-standardize --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate factor gdfm")
      case "$prev" in
        --spectral) COMPREPLY=( $(compgen -W "lag-window smoothed-periodogram" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --dynamic-rank --spectral --bandwidth -b --kernel -k --em-max-iter --em-tol --n-lags-proj --output -o --format -f --plot-save -G --save-model -S --allow-missing --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate factor gdfm-i1")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "permanent-transitory cholesky longrun sign proxy" -- "$cur") ); return ;;
        --det-trend) COMPREPLY=( $(compgen -W "none constant linear trend" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --lag-criterion) COMPREPLY=( $(compgen -W "bic aic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --n-permanent --id -i --det-trend --p-max --n-perm --bandwidth -b --kernel -k --lag-criterion --irf-horizon --config -C --instrument --seed --format -f --output -o --plot-save -G --save-model -S --config-json --set --no-standardize --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate factor qfm")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "rank ic1 ic2 ic3" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "iqr smoothed" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "gaussian epanechnikov logistic" -- "$cur") ); return ;;
        --se) COMPREPLY=( $(compgen -W "none asymptotic bootstrap" -- "$cur") ); return ;;
        --init) COMPREPLY=( $(compgen -W "pca quantile-svd random" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--tau --taus --factors -q --r-max --criterion --threshold-scale --method -m --bandwidth -b --kernel -k --se --hac-bandwidth --n-boot --init --n-starts --max-iter -I --tol -T --format -f --output -o --plot-save -G --save-model -S --standardize --no-robust-scale --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate factor sdfm")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign longrun max-share proxy lewis-tvv sv-em gmm-moments" -- "$cur") ); return ;;
        --q-method) COMPREPLY=( $(compgen -W "hallin-liska bai-ng amengual-watson" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "fglr fhlz gdfm-var" -- "$cur") ); return ;;
        --spectral) COMPREPLY=( $(compgen -W "lag-window smoothed-periodogram" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --id -i --q-method --method -m --spectral --instrument --var-lags --n-perm --p-max --target --horizons -H --config -C --bandwidth -b --kernel -k --output -o --format -f --plot-save -G --save-model -S --config-json --set --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate factor static")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "ic1 ic2 ic3" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --criterion --output -o --format -f --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate factor tv-gdfm")
      case "$prev" in
        --time-kernel) COMPREPLY=( $(compgen -W "epanechnikov gaussian uniform" -- "$cur") ); return ;;
        --lag-kernel) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --time-bandwidth --lag-bandwidth --time-kernel --lag-kernel --n-grid --format -f --output -o --plot-save -G --save-model -S --no-standardize --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate bvar")
      case "$prev" in
        --prior) COMPREPLY=( $(compgen -W "minnesota normal" -- "$cur") ); return ;;
        --sampler) COMPREPLY=( $(compgen -W "direct gibbs" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "mean median" -- "$cur") ); return ;;
        --hyperopt) COMPREPLY=( $(compgen -W "glp grid" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --prior --draws -n --sampler --method -m --hyperopt --config -C --conf-level -L --output -o --format -f --save-model -S --config-json --set --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate favar")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "two_step bayesian" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --lags -p --key-vars --method -m --draws -n --conf-level -L --output -o --format -f --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate lanne-luoto")
      case "$prev" in
        --form) COMPREPLY=( $(compgen -W "b-model a-model" -- "$cur") ); return ;;
        --weighting|-w) COMPREPLY=( $(compgen -W "two-step iterated cue" -- "$cur") ); return ;;
        --moment-selection) COMPREPLY=( $(compgen -W "msc-rmsc rmsc-seq none" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen qs quadratic-spectral tukey-hanning" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --form --weighting -w --moment-selection --kernel -k --bandwidth -b --max-iter -I --tol -T --n-starts --shock-names --conf-level -L --format -f --output -o --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate lms-svar")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "three-step one-step full-ml" -- "$cur") ); return ;;
        --se) COMPREPLY=( $(compgen -W "hessian sandwich opg" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --distributions --method -m --se --n-starts --max-iter -I --tol -T --shock-names --conf-level -L --format -f --output -o --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate lp")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "standard iv smooth state propensity robust" -- "$cur") ); return ;;
        --vcov) COMPREPLY=( $(compgen -W "newey_west white driscoll_kraay" -- "$cur") ); return ;;
        --transition) COMPREPLY=( $(compgen -W "logistic" -- "$cur") ); return ;;
        --score-method) COMPREPLY=( $(compgen -W "logit probit" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --shock -K --horizons -H --control-lags --vcov --instruments -Z --knots --lambda -l --state-var --gamma --transition --treatment --score-method --mop-tau --mop-bandwidth --ar-level --ar-grid --ar-span --conf-level -L --output -o --format -f --save-model -S --mop-f --ar-bands --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate mfvar")
      case "$prev" in
        --prior) COMPREPLY=( $(compgen -W "minnesota diffuse" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --low-freq --freq-ratio --aggregation --draws -n --burnin -B --prior --conf-level -L --quantiles -Q --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate qfavar")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "twostep vb" -- "$cur") ); return ;;
        --se) COMPREPLY=( $(compgen -W "none asymptotic bootstrap" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --lags -p --key-vars --taus --method -m --se --vb-maxiter --vb-tol --n-draws --conf-level -L --format -f --output -o --save-model -S --no-standardize --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate qvar")
      case "$prev" in
        --se) COMPREPLY=( $(compgen -W "asymptotic bootstrap none" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --taus --ordering --se --n-boot --conf-level -L --format -f --output -o --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate ssvarma")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "pml ml gmm gmm-2sls" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "student-t mixture-normal mixture-normal-asym pearson-iv skew-normal" -- "$cur") ); return ;;
        --se) COMPREPLY=( $(compgen -W "auto hessian sandwich opg" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--ar-lags --ma-lags --method -m --distribution --k-iv --se --n-starts --max-iter -I --tol -T --shock-names --conf-level -L --format -f --output -o --plot-save -G --save-model -S --blaschke --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate svar")
      case "$prev" in
        --pattern) COMPREPLY=( $(compgen -W "recursive blanchard-quah a-model b-model ab-model" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --pattern --config -C --n-starts --max-iter -I --conf-level -L --output -o --format -f --plot-save -G --save-model -S --config-json --set --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate svec")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "johansen engle_granger" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --rank -r --deterministic --method -m --significance --config -C --n-starts --max-iter -I --conf-level -L --output -o --format -f --plot-save -G --save-model -S --config-json --set --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate tvpvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --draws -n --burnin -B --thin --n-train --k-q --k-s --k-w --conf-level -L --quantiles -Q --output -o --format -f --save-model -S --no-tvp --no-sv --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate multivariate vecm")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "johansen engle_granger" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --rank -r --deterministic --method -m --significance --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate panel piv")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "fe re fd hausman-taylor" -- "$cur") ); return ;;
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster twoway driscoll-kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --exog --endog --instruments -Z --method -m --cov-type -v --id-col -u --time-col -t --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate panel plogit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --cov-type -v --method -m --output -o --format -f --conf-level -L --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate panel pmg")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "pmg mg dfe" -- "$cur") ); return ;;
        --trend|-e) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --dep -y --indep -x --method -m --trend -e --p --q --max-iter -I --tol -T --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate panel pprobit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "pooled re cre" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --cov-type -v --method -m --output -o --format -f --conf-level -L --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate panel preg")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster twoway driscoll-kraay pcse" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --ar1) COMPREPLY=( $(compgen -W "none common panel-specific" -- "$cur") ); return ;;
        --pcse-unbalanced) COMPREPLY=( $(compgen -W "casewise pairwise" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --cov-type -v --method -m --output -o --format -f --ar1 --pcse-unbalanced --absorb --hdfe-tol --hdfe-maxiter --min-lag-endo --max-lag-endo --conf-level -L --save-model -S --twoway --collapse --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate panel pvar")
      case "$prev" in
        --transformation) COMPREPLY=( $(compgen -W "fd fod" -- "$cur") ); return ;;
        --steps) COMPREPLY=( $(compgen -W "onestep twostep" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "gmm feols" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --lags -p --dependent --predet --exog --transformation --steps --method -m --min-lag-endo --max-lag-endo --conf-level -L --output -o --format -f --save-model -S --system --collapse --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate panel xtcointreg")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "fmols dols" -- "$cur") ); return ;;
        --pooling) COMPREPLY=( $(compgen -W "group pooled" -- "$cur") ); return ;;
        --trend|-e) COMPREPLY=( $(compgen -W "none const linear" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen qs tukey-hanning" -- "$cur") ); return ;;
        --ic) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --dols-se) COMPREPLY=( $(compgen -W "lrv robust" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --dep -y --indep -x --method -m --pooling --trend -e --kernel -k --bandwidth -b --leads --lags -p --ic --dols-se --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate panel xtqreg")
      case "$prev" in
        --slope) COMPREPLY=( $(compgen -W "homogeneous heterogeneous" -- "$cur") ); return ;;
        --se) COMPREPLY=( $(compgen -W "asymptotic bootstrap" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --factors -q --tau --slope --se --n-boot --r-max --max-iter -I --tol -T --conf-level -L --format -f --output -o --plot-save -G --save-model -S --no-bias-correct --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regime ms")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --k-regimes --max-iter -I --tol -T --output -o --format -f --plot-save -G --save-model -S --switching-variance --no-switching-variance --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regime ms-ar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --k-regimes --max-iter -I --output -o --format -f --plot-save -G --save-model -S --switching-variance --no-switching-variance --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regime setar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --trim --draws -n --conf-level -L --output -o --format -f --plot-save -G --save-model -S --het --no-linearity --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regime star")
      case "$prev" in
        --type) COMPREPLY=( $(compgen -W "lstr1 lstr2 estr auto" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --type --n-gamma --n-c --transition-col --output -o --format -f --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regime threshold")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --threshold-col --trim --draws -n --conf-level -L --output -o --format -f --plot-save -G --save-model -S --het --no-linearity --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regime tvp")
      case "$prev" in
        --init-mode) COMPREPLY=( $(compgen -W "kappa diffuse" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --init-mode --kappa --output -o --format -f --save-model -S --no-intercept --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression 3sls")
      case "$prev" in
        --instruments|-Z) COMPREPLY=( $(compgen -W "common perequation" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --instruments -Z --conf-level -L --output -o --format -f --save-model -S --config-json --set --no-intercept --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression cointreg")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "fmols ccr dols" -- "$cur") ); return ;;
        --trend|-e) COMPREPLY=( $(compgen -W "none const linear" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen qs tukey-hanning" -- "$cur") ); return ;;
        --ic) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --dols-se) COMPREPLY=( $(compgen -W "lrv robust" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --method -m --trend -e --kernel -k --bandwidth -b --leads --lags -p --ic --dols-se --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression elastic-net")
      case "$prev" in
        --select) COMPREPLY=( $(compgen -W "cv aic bic ebic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --alpha --lambda -l --select --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression gmm")
      case "$prev" in
        --weighting|-w) COMPREPLY=( $(compgen -W "identity optimal twostep iterated cue" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --weighting -w --conf-level -L --output -o --format -f --save-model -S --config-json --set --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression heckman")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "twostep mle" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --select --outcome-vars --select-vars --method -m --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression iv")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "tsls liml fuller kclass" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --endogenous --instruments -Z --cov-type -v --method -m --k --fuller-a --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression kde")
      case "$prev" in
        --kernel|-k) COMPREPLY=( $(compgen -W "gaussian epanechnikov triangular uniform" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --kernel -k --bw --npoints --cut --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression kernel-reg")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "nw ll lp" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "gaussian epanechnikov triangular uniform" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --method -m --degree --bw --kernel -k --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression lasso")
      case "$prev" in
        --select) COMPREPLY=( $(compgen -W "cv aic bic ebic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --lambda -l --select --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression lowess")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --frac --iter --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression ml")
      case "$prev" in
        --distribution) COMPREPLY=( $(compgen -W "student_t mixture_normal pml skew_normal" -- "$cur") ); return ;;
        --vcov-type) COMPREPLY=( $(compgen -W "auto hessian sandwich opg information" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --distribution --vcov-type --n-starts --max-iter -I --tol -T --output -o --format -f --save-model -S --asymmetric --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression qreg")
      case "$prev" in
        --se) COMPREPLY=( $(compgen -W "iid robust boot" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "ipm irls" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --tau --se --solver -s --n-boot --conf-level -L --alpha --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression rdd")
      case "$prev" in
        --kernel|-k) COMPREPLY=( $(compgen -W "triangular epanechnikov uniform" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--outcome --running --fuzzy --cutoff --bandwidth -b --bias-bandwidth --kernel -k --order -O --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression reg")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster conley" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --conley-kernel) COMPREPLY=( $(compgen -W "bartlett uniform" -- "$cur") ); return ;;
        --conley-metric) COMPREPLY=( $(compgen -W "euclidean haversine" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --weights --lat --lon --dist-cutoff --conley-kernel --conley-metric --time-col -t --time-cutoff --conf-level -L --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression ridge")
      case "$prev" in
        --select) COMPREPLY=( $(compgen -W "cv aic bic ebic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --lambda -l --select --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression robust")
      case "$prev" in
        --psi) COMPREPLY=( $(compgen -W "huber bisquare" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "m mm" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --psi --method -m --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression select")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "forward backward bidirectional best-subset gets" -- "$cur") ); return ;;
        --criterion) COMPREPLY=( $(compgen -W "pvalue aic bic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --method -m --criterion --p-enter --p-remove --keep --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression smm")
      case "$prev" in
        --weighting|-w) COMPREPLY=( $(compgen -W "identity two_step optimal iterated twostep" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --weighting -w --sim-ratio --burn -B --conf-level -L --output -o --format -f --save-model -S --config-json --set --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression statespace")
      case "$prev" in
        --model|-M) COMPREPLY=( $(compgen -W "local-level local-linear-trend" -- "$cur") ); return ;;
        --init-mode) COMPREPLY=( $(compgen -W "kappa diffuse" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --model -M --init-mode --kappa --config -C --output -o --format -f --plot-save -G --save-model -S --config-json --set --steady-state --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression sur")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --conf-level -L --output -o --format -f --save-model -S --config-json --set --iterate --no-intercept --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression tobit")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --lower --upper --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate regression truncreg")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --lower --upper --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate univariate ardl")
      case "$prev" in
        --ic) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --trend|-e) COMPREPLY=( $(compgen -W "none const trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --p --q --max-p --max-q --ic --case --trend -e --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate univariate arfima")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "css mle" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --method -m --d0 --max-iter -I --conf-level -L --format -f --output -o --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate univariate arima")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "ols css mle css_mle" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --q --max-p --max-d --max-q --criterion --method -m --conf-level -L --format -f --output -o --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate univariate midas")
      case "$prev" in
        --weights) COMPREPLY=( $(compgen -W "expalmon beta2 beta3 almon umidas" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --hf-data --hf-column --m --k --weights --p-ar --poly-degree --horizons -H --max-iter -I --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate univariate nardl")
      case "$prev" in
        --ic) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --asymmetric --p --q --max-p --max-q --ic --case --horizons -H --nreps --conf-level -L --plot-save -G --output -o --format -f --save-model -S --no-bootstrap --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate univariate sarima")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "css_mle mle css" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --q --P --D --Q --s --max-p --max-q --max-P --max-Q --criterion --method -m --max-iter -I --conf-level -L --output -o --format -f --plot-save -G --save-model -S --auto --no-intercept --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility aparch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --fix-delta --fix-gamma --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility arch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --q --conf-level -L --output -o --format -f --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility bekk")
      case "$prev" in
        --kind) COMPREPLY=( $(compgen -W "scalar diagonal" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--kind --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility ccc")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--p --q --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility cgarch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility dcc")
      case "$prev" in
        --correction) COMPREPLY=( $(compgen -W "none aielli" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--p --q --correction --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility egarch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal student ged" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --dist --conf-level -L --output -o --format -f --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility fiegarch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --d0 --truncation --dist --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility figarch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --d0 --truncation --dist --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility garch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal student ged" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --dist --conf-level -L --output -o --format -f --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility garch-midas")
      case "$prev" in
        --rv) COMPREPLY=( $(compgen -W "realized macro" -- "$cur") ); return ;;
        --span) COMPREPLY=( $(compgen -W "fixed rolling" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --m-freq --k --rv --span --config -C --conf-level -L --output -o --format -f --save-model -S --config-json --set --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility gjr-garch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal student ged" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --dist --conf-level -L --output -o --format -f --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility igarch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --conf-level -L --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "estimate volatility sv")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --draws -n --conf-level -L --output -o --format -f --plot-save -G --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "fevd bvar")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em" -- "$cur") ); return ;;
        --sampler) COMPREPLY=( $(compgen -W "direct gibbs" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --horizons -H --id -i --draws -n --sampler --conf-level -L --quantiles -Q --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "fevd favar")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --lags -p --key-vars --horizons -H --id -i --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "fevd gdfm-i1")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "permanent-transitory cholesky longrun sign proxy" -- "$cur") ); return ;;
        --det-trend) COMPREPLY=( $(compgen -W "none constant linear trend" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --lag-criterion) COMPREPLY=( $(compgen -W "bic aic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --n-permanent --id -i --det-trend --p-max --n-perm --bandwidth -b --kernel -k --lag-criterion --irf-horizon --config -C --instrument --seed --horizons -H --format -f --output -o --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --no-standardize --include-idiosyncratic --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "fevd lp")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em" -- "$cur") ); return ;;
        --vcov) COMPREPLY=( $(compgen -W "newey_west white driscoll_kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --lags -p --var-lags --id -i --vcov --conf-level -L --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "fevd pvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --lags -p --horizons -H --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "fevd sdfm")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign longrun max-share proxy lewis-tvv sv-em gmm-moments" -- "$cur") ); return ;;
        --q-method) COMPREPLY=( $(compgen -W "hallin-liska bai-ng amengual-watson" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "fglr fhlz gdfm-var" -- "$cur") ); return ;;
        --spectral) COMPREPLY=( $(compgen -W "lag-window smoothed-periodogram" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --id -i --q-method --method -m --spectral --instrument --var-lags --n-perm --p-max --target --horizons -H --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "fevd ssvarma")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "pml ml gmm gmm-2sls" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "student-t mixture-normal mixture-normal-asym pearson-iv skew-normal" -- "$cur") ); return ;;
        --se) COMPREPLY=( $(compgen -W "auto hessian sandwich opg" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--ar-lags --ma-lags --method -m --distribution --k-iv --se --n-starts --max-iter -I --tol -T --horizons -H --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "fevd var")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun arias uhlig proxy max-share gmm-moments narrative-adrr lewis-tvv sv-em fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --horizons -H --id -i --config -C --instrument --target-var --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --generalized --normalize --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "fevd vecm")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em svec" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --rank -r --deterministic --horizons -H --id -i --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "filter bandpass-gdfm")
      case "$prev" in
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --spectral) COMPREPLY=( $(compgen -W "lag-window smoothed-periodogram" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --nfactors --pl --pu --band-low --band-high --bandwidth -b --kernel -k --spectral --format -f --output -o --plot-save -G --result -R --save-result -W --model -M --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "filter bhp")
      case "$prev" in
        --stopping) COMPREPLY=( $(compgen -W "BIC ADF fixed" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lambda -l --stopping --max-iter -I --sig-p --columns --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "filter bk")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--pl --pu --K --columns --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "filter bn")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "arima statespace" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--method -m --p --q --columns --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "filter eurocoin")
      case "$prev" in
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--target --dynamic-rank --nfactors --cutoff --bandwidth -b --kernel -k --format -f --output -o --plot-save -G --result -R --save-result -W --no-standardize --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "filter hamilton")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --lags -p --columns --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "filter hp")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lambda -l --columns --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "filter x13")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "seats x11" -- "$cur") ); return ;;
        --transform) COMPREPLY=( $(compgen -W "auto log none" -- "$cur") ); return ;;
        --outliers) COMPREPLY=( $(compgen -W "true false" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--frequency --method -m --transform --critical-value --outliers --columns --format -f --output -o --plot-save -G --result -R --save-result -W --trading-day --easter --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast evaluate clark-west")
      case "$prev" in
        --alternative) COMPREPLY=( $(compgen -W "two-sided less greater" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--actual --forecasts --result -R --horizons -H --alternative --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast evaluate combine")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "equal bates-granger granger-ramanathan" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--actual --forecasts --result -R --method -m --format -f --output -o --emit-series --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast evaluate dm")
      case "$prev" in
        --loss) COMPREPLY=( $(compgen -W "se ad" -- "$cur") ); return ;;
        --alternative) COMPREPLY=( $(compgen -W "two-sided less greater" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--actual --forecasts --result -R --loss --horizons -H --alternative --format -f --output -o --no-hln --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast evaluate encompassing")
      case "$prev" in
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen quadratic_spectral tukey_hanning" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--actual --forecasts --result -R --lags -p --kernel -k --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast evaluate metrics")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--actual --forecasts --result -R --seasonal-period --plot-save -G --format -f --output -o --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast evaluate mincer-zarnowitz")
      case "$prev" in
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen quadratic_spectral tukey_hanning" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--actual --forecasts --result -R --lags -p --kernel -k --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast factor dynamic")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "twostep em" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --horizons -H --factor-lags --method -m --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast factor gdfm")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "ar one-sided spectral" -- "$cur") ); return ;;
        --spectral) COMPREPLY=( $(compgen -W "lag-window smoothed-periodogram" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --dynamic-rank --horizons -H --method -m --spectral --n-lags-proj --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast factor gdfm-i1")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "permanent-transitory cholesky longrun sign proxy" -- "$cur") ); return ;;
        --det-trend) COMPREPLY=( $(compgen -W "none constant linear trend" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --lag-criterion) COMPREPLY=( $(compgen -W "bic aic" -- "$cur") ); return ;;
        --ci) COMPREPLY=( $(compgen -W "none theoretical bootstrap" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --n-permanent --id -i --det-trend --p-max --n-perm --bandwidth -b --kernel -k --lag-criterion --irf-horizon --config -C --instrument --seed --horizons -H --ci --draws -n --conf-level -L --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --config-json --set --save-model -S --no-standardize --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast factor growth-at-risk")
      case "$prev" in
        --density) COMPREPLY=( $(compgen -W "skewed-t normal none" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--target --horizons -H --factors -q --taus --lags -p --alpha --density --oos-split --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --save-model -S --no-rearrange --no-standardize --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast factor qfm")
      case "$prev" in
        --ci-method) COMPREPLY=( $(compgen -W "none bootstrap" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--tau --taus --factors -q --horizons -H --lags -p --ci-method --n-boot --conf-level -L --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --save-model -S --no-rearrange --standardize --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast factor sdfm")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign longrun max-share proxy lewis-tvv sv-em gmm-moments" -- "$cur") ); return ;;
        --q-method) COMPREPLY=( $(compgen -W "hallin-liska bai-ng amengual-watson" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "fglr fhlz gdfm-var" -- "$cur") ); return ;;
        --spectral) COMPREPLY=( $(compgen -W "lag-window smoothed-periodogram" -- "$cur") ); return ;;
        --ci) COMPREPLY=( $(compgen -W "none bootstrap" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --id -i --q-method --method -m --spectral --instrument --var-lags --n-perm --p-max --target --horizons -H --config -C --ci --draws -n --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --config-json --set --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast factor static")
      case "$prev" in
        --ci-method) COMPREPLY=( $(compgen -W "none bootstrap parametric" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --horizons -H --ci-method --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast multivariate bvar")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "direct gibbs" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --horizons -H --draws -n --sampler --conf-level -L --config -C --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --config-json --set --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast multivariate favar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --lags -p --key-vars --horizons -H --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --panel-forecast --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast multivariate lp")
      case "$prev" in
        --vcov) COMPREPLY=( $(compgen -W "newey_west white driscoll_kraay" -- "$cur") ); return ;;
        --ci-method) COMPREPLY=( $(compgen -W "analytical bootstrap none" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--shock -K --horizons -H --shock-size --lags -p --vcov --ci-method --conf-level -L --n-boot --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast multivariate qfavar")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "twostep vb" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --lags -p --key-vars --taus --method -m --horizons -H --format -f --output -o --model -M --result -R --save-result -W --save-model -S --no-rearrange --no-standardize --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast multivariate scenario")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "var bvar" -- "$cur") ); return ;;
        --sampler) COMPREPLY=( $(compgen -W "direct gibbs" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--conditions-file --method -m --lags -p --horizons -H --replications --conf-level -L --draws -n --sampler --config -C --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --config-json --set --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast multivariate var")
      case "$prev" in
        --ci-method) COMPREPLY=( $(compgen -W "analytical bootstrap none" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --horizons -H --conf-level -L --ci-method --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast multivariate vecm")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --ci-method) COMPREPLY=( $(compgen -W "none bootstrap parametric" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --rank -r --deterministic --horizons -H --ci-method --draws -n --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast regime ms")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --k-regimes --max-iter -I --tol -T --horizons -H --x-future --draws -n --conf-level -L --output -o --format -f --model -M --result -R --save-result -W --save-model -S --switching-variance --no-switching-variance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast regime ms-ar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --k-regimes --max-iter -I --horizons -H --draws -n --conf-level -L --output -o --format -f --model -M --result -R --save-result -W --save-model -S --switching-variance --no-switching-variance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast regime setar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --horizons -H --draws -n --conf-level -L --output -o --format -f --model -M --result -R --save-result -W --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast regime star")
      case "$prev" in
        --type) COMPREPLY=( $(compgen -W "lstr1 lstr2 estr auto" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --type --horizons -H --draws -n --conf-level -L --output -o --format -f --model -M --result -R --save-result -W --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast univariate arfima")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "css mle" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --method -m --d0 --max-iter -I --horizons -H --conf-level -L --trunc-lag --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast univariate arima")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "ols css mle css_mle" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --q --max-p --max-d --max-q --criterion --horizons -H --conf-level -L --method -m --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast univariate midas")
      case "$prev" in
        --weights) COMPREPLY=( $(compgen -W "expalmon beta2 beta3 almon umidas" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --hf-data --hf-column --m --k --weights --p-ar --poly-degree --horizons -H --max-iter -I --conf-level -L --output -o --format -f --model -M --result -R --save-result -W --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast univariate sarima")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "css_mle mle css" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --q --P --D --Q --s --max-p --max-q --max-P --max-Q --criterion --method -m --max-iter -I --horizons -H --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --auto --no-intercept --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast volatility aparch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --fix-delta --fix-gamma --horizons -H --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast volatility arch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --q --horizons -H --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast volatility cgarch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --horizons -H --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast volatility egarch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal student ged" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --horizons -H --conf-level -L --dist --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast volatility fiegarch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --d0 --truncation --dist --horizons -H --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast volatility figarch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --d0 --truncation --dist --horizons -H --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast volatility garch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal student ged" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --horizons -H --conf-level -L --dist --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast volatility garch-midas")
      case "$prev" in
        --rv) COMPREPLY=( $(compgen -W "realized macro" -- "$cur") ); return ;;
        --span) COMPREPLY=( $(compgen -W "fixed rolling" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --m-freq --k --rv --span --config -C --horizons -H --output -o --format -f --model -M --config-json --set --save-model -S --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast volatility gjr-garch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal student ged" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --horizons -H --conf-level -L --dist --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast volatility igarch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --horizons -H --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "forecast volatility sv")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --draws -n --horizons -H --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hadsge accuracy")
      case "$prev" in
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "krusell-smith ssj reiter" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--hh-solver --distribution --method -m --n-reduced --t-sim --t-burn --t-fit --rho-z --sigma-z --seed --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hadsge distribution-irf")
      case "$prev" in
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "reiter" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--hh-solver --distribution --method -m --horizons -H --shock-index --shock-size --n-reduced --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hadsge estimate")
      case "$prev" in
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "ssj reiter" -- "$cur") ); return ;;
        --sampler) COMPREPLY=( $(compgen -W "mh smc" -- "$cur") ); return ;;
        --measurement-error) COMPREPLY=( $(compgen -W "none auto" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--hh-solver --distribution --data -d --priors --prior --observables --method -m --sampler --draws -n --burnin -B --n-smc --n-mh-steps --ess-target --t-horizon --n-reduced --proposal-scale --adapt-interval --measurement-error --seed --conf-level -L --quantiles -Q --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hadsge fevd")
      case "$prev" in
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "ssj reiter" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--hh-solver --distribution --method -m --horizons -H --n-reduced --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hadsge hd")
      case "$prev" in
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "ssj reiter" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--hh-solver --distribution --method -m --data -d --observables --measurement-error --n-reduced --t-horizon --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hadsge inequality-irf")
      case "$prev" in
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "reiter" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--hh-solver --distribution --method -m --horizons -H --shock-index --shock-size --n-reduced --output -o --format -f --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hadsge irf")
      case "$prev" in
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "ssj reiter" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--hh-solver --distribution --method -m --horizons -H --n-reduced --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hadsge simulate")
      case "$prev" in
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "ssj reiter" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--hh-solver --distribution --method -m --periods -N --seed --n-reduced --output -o --format -f --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hadsge simulate-panel")
      case "$prev" in
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--hh-solver --distribution --n-agents --periods -N --seed --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hadsge solve")
      case "$prev" in
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "ssj reiter krusell-smith" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--hh-solver --distribution --method -m --n-reduced --t-horizon --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hadsge steady-state")
      case "$prev" in
        --hh-solver) COMPREPLY=( $(compgen -W "egm vfi" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "young winberry" -- "$cur") ); return ;;
        --euler-points) COMPREPLY=( $(compgen -W "midpoints nodes" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--hh-solver --distribution --euler-points --max-iter -I --tol -T --output -o --format -f --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hd bvar")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em" -- "$cur") ); return ;;
        --sampler) COMPREPLY=( $(compgen -W "direct gibbs" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --id -i --draws -n --sampler --conf-level -L --quantiles -Q --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hd favar")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --lags -p --key-vars --horizons -H --id -i --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hd gdfm-i1")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "permanent-transitory cholesky longrun sign proxy" -- "$cur") ); return ;;
        --det-trend) COMPREPLY=( $(compgen -W "none constant linear trend" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --lag-criterion) COMPREPLY=( $(compgen -W "bic aic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --n-permanent --id -i --det-trend --p-max --n-perm --bandwidth -b --kernel -k --lag-criterion --irf-horizon --config -C --instrument --seed --horizons -H --format -f --output -o --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --no-standardize --include-idiosyncratic --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hd lp")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em" -- "$cur") ); return ;;
        --vcov) COMPREPLY=( $(compgen -W "newey_west white driscoll_kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --var-lags --id -i --vcov --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hd sdfm")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign longrun max-share proxy lewis-tvv sv-em gmm-moments" -- "$cur") ); return ;;
        --q-method) COMPREPLY=( $(compgen -W "hallin-liska bai-ng amengual-watson" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "fglr fhlz gdfm-var" -- "$cur") ); return ;;
        --spectral) COMPREPLY=( $(compgen -W "lag-window smoothed-periodogram" -- "$cur") ); return ;;
        --space) COMPREPLY=( $(compgen -W "panel factor" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --id -i --q-method --method -m --spectral --instrument --var-lags --n-perm --p-max --target --horizons -H --config -C --space --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --no-idiosyncratic --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hd var")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun proxy max-share gmm-moments lewis-tvv sv-em fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --id -i --config -C --instrument --target-var --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "hd vecm")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em svec" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --rank -r --deterministic --id -i --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io aggregate")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --region-map --sector-map --format -f --output -o --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io balance")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "ras gras" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --method -m --tol -T --max-iter -I --format -f --output -o --save-model -S --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io baqaee-farhi")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --theta --sigma --format -f --output -o --second-order --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io bf elasticities")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --nests) COMPREPLY=( $(compgen -W "single two" -- "$cur") ); return ;;
        --factors|-q) COMPREPLY=( $(compgen -W "single va-cats" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --theta --sigma --epsilon --eta --nests --factors -q --mu --format -f --output -o --plot-save -G --model -M --no-check --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io bf equilibrium")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --nests) COMPREPLY=( $(compgen -W "single two" -- "$cur") ); return ;;
        --factors|-q) COMPREPLY=( $(compgen -W "single va-cats" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "newton fixedpoint" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --theta --sigma --epsilon --eta --nests --factors -q --mu --dlog-a --dlog-l --dlog-mu --method -m --tol -T --max-iter -I --damping --format -f --output -o --plot-save -G --model -M --no-check --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io bf local")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --nests) COMPREPLY=( $(compgen -W "single two" -- "$cur") ); return ;;
        --factors|-q) COMPREPLY=( $(compgen -W "single va-cats" -- "$cur") ); return ;;
        --hessian) COMPREPLY=( $(compgen -W "auto full none" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --theta --sigma --epsilon --eta --nests --factors -q --mu --hessian --format -f --output -o --plot-save -G --model -M --no-check --no-elasticities --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io bf misallocation")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --nests) COMPREPLY=( $(compgen -W "single two" -- "$cur") ); return ;;
        --factors|-q) COMPREPLY=( $(compgen -W "single va-cats" -- "$cur") ); return ;;
        --point) COMPREPLY=( $(compgen -W "efficient observed" -- "$cur") ); return ;;
        --hessian) COMPREPLY=( $(compgen -W "auto full none" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --theta --sigma --epsilon --eta --nests --factors -q --mu --point --hessian --format -f --output -o --plot-save -G --model -M --no-check --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io bf network")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --nests) COMPREPLY=( $(compgen -W "single two" -- "$cur") ); return ;;
        --factors|-q) COMPREPLY=( $(compgen -W "single va-cats" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --theta --sigma --epsilon --eta --nests --factors -q --mu --format -f --output -o --plot-save -G --save-model -S --no-check --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io bf shock-curve")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --nests) COMPREPLY=( $(compgen -W "single two" -- "$cur") ); return ;;
        --factors|-q) COMPREPLY=( $(compgen -W "single va-cats" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --theta --sigma --epsilon --eta --nests --factors -q --mu --sector --range --points --format -f --output -o --plot-save -G --model -M --no-check --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io bf wedges")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --nests) COMPREPLY=( $(compgen -W "single two" -- "$cur") ); return ;;
        --factors|-q) COMPREPLY=( $(compgen -W "single va-cats" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --theta --sigma --epsilon --eta --nests --factors -q --mu --dlog-a --dlog-l --dlog-mu --format -f --output -o --plot-save -G --model -M --no-check --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io bilateral-trade")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --kind) COMPREPLY=( $(compgen -W "total intermediate final" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --exporter --importer --kind --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io download")
      case "$prev" in
        --source) COMPREPLY=( $(compgen -W "oecd wiod exiobase3 eora26 gloria" -- "$cur") ); return ;;
        --system) COMPREPLY=( $(compgen -W "pxp ixi" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--source --storage --source-version --years --system --email --password --format -f --output -o --offline --overwrite --no-verify --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io export-decomposition")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --region --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io extract")
      case "$prev" in
        --mode) COMPREPLY=( $(compgen -W "complete backward forward partial" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --sectors-extract --mode --share --region --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io footprint")
      case "$prev" in
        --by) COMPREPLY=( $(compgen -W "sector region" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --account --by --format -f --output -o --detail --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io ghosh")
      case "$prev" in
        --matrix) COMPREPLY=( $(compgen -W "G B both" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --matrix --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io impact")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --type) COMPREPLY=( $(compgen -W "I II" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --dy --kind --type --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io key-sectors")
      case "$prev" in
        --forward) COMPREPLY=( $(compgen -W "ghosh leontief" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --forward --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io leontief")
      case "$prev" in
        --matrix) COMPREPLY=( $(compgen -W "L A both" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --matrix --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io linkages")
      case "$prev" in
        --forward) COMPREPLY=( $(compgen -W "ghosh leontief" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --forward --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io load")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --year --member --format -f --output -o --save-model -S --no-aggregate-cn-mx --check --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io multipliers")
      case "$prev" in
        --kind) COMPREPLY=( $(compgen -W "output income employment" -- "$cur") ); return ;;
        --type) COMPREPLY=( $(compgen -W "I II" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --kind --type --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io network-stats")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io price")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --mode) COMPREPLY=( $(compgen -W "leontief ghosh" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --dva --dtax --mode --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io sda")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "additive multiplicative" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --data2 --method -m --factors -q --on --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io sources")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "io vertical-specialization")
      case "$prev" in
        --parser) COMPREPLY=( $(compgen -W "csv icio" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data -d --n-sectors --n-fd --sectors --parser --region --format -f --output -o --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf bvar")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em robust-bayes" -- "$cur") ); return ;;
        --sampler) COMPREPLY=( $(compgen -W "direct gibbs" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --shock -K --horizons -H --id -i --draws -n --sampler --conf-level -L --quantiles -Q --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --cumulative --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf favar")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --lags -p --key-vars --horizons -H --id -i --conf-level -L --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --panel-irf --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf gdfm-i1")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "permanent-transitory cholesky longrun sign proxy" -- "$cur") ); return ;;
        --det-trend) COMPREPLY=( $(compgen -W "none constant linear trend" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --lag-criterion) COMPREPLY=( $(compgen -W "bic aic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --n-permanent --id -i --det-trend --p-max --n-perm --bandwidth -b --kernel -k --lag-criterion --irf-horizon --config -C --instrument --seed --horizons -H --format -f --output -o --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --no-standardize --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf lp")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em" -- "$cur") ); return ;;
        --ci) COMPREPLY=( $(compgen -W "none bootstrap" -- "$cur") ); return ;;
        --vcov) COMPREPLY=( $(compgen -W "newey_west white driscoll_kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--shock -K --shocks --horizons -H --lags -p --var-lags --id -i --ci --draws -n --conf-level -L --vcov --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --cumulative --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf pvar")
      case "$prev" in
        --irf-type) COMPREPLY=( $(compgen -W "oirf girf" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --lags -p --horizons -H --irf-type --draws -n --conf-level -L --output -o --format -f --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf qfavar")
      case "$prev" in
        --est-method) COMPREPLY=( $(compgen -W "twostep vb" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "analytical simulation monte-carlo" -- "$cur") ); return ;;
        --ci-type) COMPREPLY=( $(compgen -W "none bootstrap credible" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --lags -p --key-vars --taus --est-method --horizons -H --shock -K --shock-size --tau-profile --baseline-tau --method -m --ci-type --n-boot --conf-level -L --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --save-model -S --no-standardize --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf qvar")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "analytical simulation monte-carlo" -- "$cur") ); return ;;
        --ci-type) COMPREPLY=( $(compgen -W "none bootstrap" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --taus --ordering --horizons -H --shock -K --shock-size --tau-profile --baseline-tau --method -m --ci-type --n-boot --conf-level -L --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf sdfm")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign longrun max-share proxy lewis-tvv sv-em gmm-moments" -- "$cur") ); return ;;
        --q-method) COMPREPLY=( $(compgen -W "hallin-liska bai-ng amengual-watson" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "fglr fhlz gdfm-var" -- "$cur") ); return ;;
        --spectral) COMPREPLY=( $(compgen -W "lag-window smoothed-periodogram" -- "$cur") ); return ;;
        --ci) COMPREPLY=( $(compgen -W "none bootstrap" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --id -i --q-method --method -m --spectral --instrument --var-lags --n-perm --p-max --target --horizons -H --config -C --ci --draws -n --conf-level -L --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf ssvarma")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "pml ml gmm gmm-2sls" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "student-t mixture-normal mixture-normal-asym pearson-iv skew-normal" -- "$cur") ); return ;;
        --se) COMPREPLY=( $(compgen -W "auto hessian sandwich opg" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--ar-lags --ma-lags --method -m --distribution --k-iv --se --n-starts --max-iter -I --tol -T --shock -K --horizons -H --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --save-model -S --cumulative --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf tvpvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--date --horizons -H --shock -K --lags -p --draws -n --burnin -B --thin --n-train --k-q --k-s --k-w --irf-draws --conf-level -L --quantiles -Q --output -o --format -f --model -M --result -R --save-result -W --save-model -S --no-tvp --no-sv --no-stationary-only --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf var")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun arias uhlig proxy max-share gmm-moments narrative-adrr lewis-tvv sv-em fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id" -- "$cur") ); return ;;
        --ci) COMPREPLY=( $(compgen -W "none bootstrap theoretical" -- "$cur") ); return ;;
        --bootstrap) COMPREPLY=( $(compgen -W "iid wild block" -- "$cur") ); return ;;
        --wild-dist) COMPREPLY=( $(compgen -W "rademacher mammen" -- "$cur") ); return ;;
        --summary) COMPREPLY=( $(compgen -W "none median-target modal-model joint-band sup-t-band" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --shock -K --horizons -H --id -i --ci --draws -n --conf-level -L --instrument --target-var --bootstrap --block-length --wild-dist --bias-reps --config -C --summary --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --cumulative --identified-set --stationary-only --bias-correct --bootstrap-across-rotations --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "irf vecm")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign narrative longrun fastica jade sobi dcov hsic cvm student-t mixture-normal mixture-normal-asym pml skew-normal lms markov-switching garch-id uhlig lewis-tvv sv-em svec" -- "$cur") ); return ;;
        --ci) COMPREPLY=( $(compgen -W "none bootstrap theoretical" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --rank -r --deterministic --shock -K --horizons -H --id -i --ci --draws -n --conf-level -L --config -C --output -o --format -f --plot-save -G --model -M --config-json --set --result -R --save-result -W --save-model -S --plot -g --bootstrap-across-rotations --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "model convert")
      case "$prev" in
        --to) COMPREPLY=( $(compgen -W " jld2 jls" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--output -o --to --note --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "model info")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--output -o --format -f --deep --keys --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "model keys")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "model reproduce")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --tol -T --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "nowcast bridge")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--monthly-vars --quarterly-vars --lag-m --lag-q --lag-y --target-var --output -o --format -f --save-model -S --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "nowcast bvar")
      case "$prev" in
        --prior) COMPREPLY=( $(compgen -W "conjugate litterman" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--monthly-vars --quarterly-vars --lags -p --target-var --prior --theta-cross --lambda0 --theta0 --miu0 --alpha0 --output -o --format -f --save-model -S --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "nowcast dfm")
      case "$prev" in
        --idio) COMPREPLY=( $(compgen -W "ar1 iid" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--monthly-vars --quarterly-vars --factors -q --lags -p --idio --max-iter -I --target-var --output -o --format -f --plot-save -G --save-model -S --model -M --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "nowcast forecast")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "dfm bvar bridge" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--monthly-vars --quarterly-vars --method -m --factors -q --lags -p --horizons -H --target-var --output -o --format -f --plot-save -G --save-model -S --model -M --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "nowcast gdfm")
      case "$prev" in
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --spectral) COMPREPLY=( $(compgen -W "lag-window smoothed-periodogram" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --nfactors --horizons -H --n-lags --bandwidth -b --kernel -k --spectral --em-max-iter --em-tol --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --save-model -S --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "nowcast news")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "dfm bvar" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--data-new --data-old --monthly-vars --quarterly-vars --method -m --factors -q --lags -p --target-period --target-var --output -o --format -f --plot-save -G --save-model -S --model -M --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy counterfactual bvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --rule) COMPREPLY=( $(compgen -W "rate-peg inflation-target output-gap ngdp taylor" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "auto ls exact" -- "$cur") ); return ;;
        --use-draws) COMPREPLY=( $(compgen -W "auto on off" -- "$cur") ); return ;;
        --baseline-draws) COMPREPLY=( $(compgen -W "fixed match" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --config -C --nonpolicy-shock --rule --rule-config --method -m --use-draws --baseline-draws --conf-level -L --quantiles -Q --spanned-tol --normalize --plot-save -G --model -M --result -R --save-result -W --negate --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy counterfactual lp")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --rule) COMPREPLY=( $(compgen -W "rate-peg inflation-target output-gap ngdp taylor" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "auto ls exact" -- "$cur") ); return ;;
        --use-draws) COMPREPLY=( $(compgen -W "auto on off" -- "$cur") ); return ;;
        --baseline-draws) COMPREPLY=( $(compgen -W "fixed match" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --config -C --nonpolicy-shock --rule --rule-config --method -m --use-draws --baseline-draws --conf-level -L --quantiles -Q --spanned-tol --normalize --plot-save -G --model -M --result -R --save-result -W --negate --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy counterfactual var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --rule) COMPREPLY=( $(compgen -W "rate-peg inflation-target output-gap ngdp taylor" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "auto ls exact" -- "$cur") ); return ;;
        --use-draws) COMPREPLY=( $(compgen -W "auto on off" -- "$cur") ); return ;;
        --baseline-draws) COMPREPLY=( $(compgen -W "fixed match" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --nonpolicy-shock --rule --rule-config --method -m --use-draws --baseline-draws --conf-level -L --quantiles -Q --spanned-tol --normalize --plot-save -G --model -M --result -R --save-result -W --negate --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy effects bvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --config -C --normalize --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy effects lp")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --config -C --normalize --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy effects sign")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --config -C --normalize --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy effects var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --normalize --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy history bvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --use-draws) COMPREPLY=( $(compgen -W "auto on off" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --config -C --t-range --rule --rule-config --loss-config --use-draws --conf-level -L --quantiles -Q --normalize --plot-save -G --model -M --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy history var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --use-draws) COMPREPLY=( $(compgen -W "auto on off" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --t-range --rule --rule-config --loss-config --use-draws --conf-level -L --quantiles -Q --normalize --plot-save -G --model -M --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy jacobian ha")
      case "$prev" in
        --input) COMPREPLY=( $(compgen -W "r w" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--input --jac-output --t-horizon --dx --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy moments bvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --use-draws) COMPREPLY=( $(compgen -W "auto on off" -- "$cur") ); return ;;
        --draw-source) COMPREPLY=( $(compgen -W "ce wold both" -- "$cur") ); return ;;
        --plot-view) COMPREPLY=( $(compgen -W "sd corr" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --config -C --rule --rule-config --loss-config --use-draws --draw-source --conf-level -L --quantiles -Q --frequencies --plot-view --plot-save -G --model -M --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy moments var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --use-draws) COMPREPLY=( $(compgen -W "auto on off" -- "$cur") ); return ;;
        --draw-source) COMPREPLY=( $(compgen -W "ce wold both" -- "$cur") ); return ;;
        --plot-view) COMPREPLY=( $(compgen -W "sd corr" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --rule --rule-config --loss-config --use-draws --draw-source --conf-level -L --quantiles -Q --frequencies --plot-view --plot-save -G --model -M --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy news dsge")
      case "$prev" in
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein blanchard-kahn" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--policy-shock --outcomes --instruments -Z --horizons -H --solver -s --chunk --behavioral-m --behavioral-theta --behavioral-ri-gain --behavioral-ri-rho --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy news ha")
      case "$prev" in
        --rule-closure) COMPREPLY=( $(compgen -W "administered market" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--outcomes --instruments -Z --horizons -H --t-horizon --rule-closure --dx --behavioral-m --behavioral-theta --behavioral-ri-gain --behavioral-ri-rho --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy opp bvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "auto slsqp projection" -- "$cur") ); return ;;
        --plot-view) COMPREPLY=( $(compgen -W "delta paths" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --config -C --loss-config --n-sim --levels --normalize --targets --values-file --sd --rho --cross-corr-file --min-sd --origin --instrument-path --constraints-file --method -m --plot-view --plot-save -G --model -M --result -R --save-result -W --matched-draws --interp-quarterly --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy opp var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "auto slsqp projection" -- "$cur") ); return ;;
        --plot-view) COMPREPLY=( $(compgen -W "delta paths" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --loss-config --n-sim --levels --normalize --targets --values-file --sd --rho --cross-corr-file --min-sd --origin --instrument-path --constraints-file --method -m --plot-view --plot-save -G --model -M --result -R --save-result -W --matched-draws --interp-quarterly --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy opp-sequence bvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
        --plot-view) COMPREPLY=( $(compgen -W "fan decomposition" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --config -C --loss-config --forecasts-dir --sd --rho --n-sim --levels --normalize --plot-view --plot-save -G --model -M --result -R --save-result -W --matched-draws --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy opp-sequence var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
        --plot-view) COMPREPLY=( $(compgen -W "fan decomposition" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --loss-config --forecasts-dir --sd --rho --n-sim --levels --normalize --plot-view --plot-save -G --model -M --result -R --save-result -W --matched-draws --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy optimal bvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --use-draws) COMPREPLY=( $(compgen -W "auto on off" -- "$cur") ); return ;;
        --baseline-draws) COMPREPLY=( $(compgen -W "fixed match" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --config -C --nonpolicy-shock --loss-config --use-draws --baseline-draws --conf-level -L --quantiles -Q --normalize --plot-save -G --model -M --result -R --save-result -W --negate --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy optimal lp")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --use-draws) COMPREPLY=( $(compgen -W "auto on off" -- "$cur") ); return ;;
        --baseline-draws) COMPREPLY=( $(compgen -W "fixed match" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --config -C --nonpolicy-shock --loss-config --use-draws --baseline-draws --conf-level -L --quantiles -Q --normalize --plot-save -G --model -M --result -R --save-result -W --negate --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy optimal var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --use-draws) COMPREPLY=( $(compgen -W "auto on off" -- "$cur") ); return ;;
        --baseline-draws) COMPREPLY=( $(compgen -W "fixed match" -- "$cur") ); return ;;
        --normalize) COMPREPLY=( $(compgen -W "none instrument-impact" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --nonpolicy-shock --loss-config --use-draws --baseline-draws --conf-level -L --quantiles -Q --normalize --plot-save -G --model -M --result -R --save-result -W --negate --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy spanning var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --solver|-s) COMPREPLY=( $(compgen -W "gensys klein blanchard-kahn" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--horizons -H --shocks --outcomes --instruments -Z --output -o --format -f --lags -p --draws -n --nonpolicy-shock --model-outcomes --model-instruments --policy-shock --solver -s --rule --rule-config --tol -T --n-sim --conf-level -L --quantiles -Q --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "policy sufficiency dsge")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--observables --horizons -H --method -m --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict choice logit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --threshold --conf-level -L --model -M --marginal-effects --odds-ratio --classification-table --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict choice mlogit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --conf-level -L --model -M --marginal-effects --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict choice nbreg")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --offset --exposure --max-iter -I --tol -T --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict choice ologit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --conf-level -L --model -M --marginal-effects --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict choice oprobit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --conf-level -L --model -M --marginal-effects --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict choice poisson")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "robust mle hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --offset --exposure --cov-type -v --clusters -U --max-iter -I --tol -T --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict choice probit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --threshold --conf-level -L --model -M --marginal-effects --classification-table --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict choice ri-logit")
      case "$prev" in
        --normalize) COMPREPLY=( $(compgen -W "auto omega-one none first-coef" -- "$cur") ); return ;;
        --cov-type|-v) COMPREPLY=( $(compgen -W "hessian sandwich" -- "$cur") ); return ;;
        --kind) COMPREPLY=( $(compgen -W "auto conditional unconditional" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--env-col --choice-col --alt-col --state-col --obs-col --attr-cols --config -C --priors --normalize --cov-type -v --tol -T --max-iter -I --kind --format -f --output -o --model -M --config-json --set --unobserved-state --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict factor dynamic")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "twostep qml" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --factor-lags --method -m --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict factor fhlz")
      case "$prev" in
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --lag-criterion) COMPREPLY=( $(compgen -W "bic aic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --bandwidth -b --kernel -k --p-max --lag-criterion --n-perm --irf-horizon --em-max-iter --em-tol --seed --format -f --output -o --model -M --allow-missing --no-standardize --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict factor gdfm")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --dynamic-rank --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict factor gdfm-i1")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "permanent-transitory cholesky longrun sign proxy" -- "$cur") ); return ;;
        --det-trend) COMPREPLY=( $(compgen -W "none constant linear trend" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --lag-criterion) COMPREPLY=( $(compgen -W "bic aic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --n-permanent --id -i --det-trend --p-max --n-perm --bandwidth -b --kernel -k --lag-criterion --irf-horizon --config -C --instrument --seed --format -f --output -o --model -M --config-json --set --no-standardize --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict factor qfm")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "iqr smoothed" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--tau --factors -q --method -m --format -f --output -o --model -M --standardize --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict factor static")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict factor tv-gdfm")
      case "$prev" in
        --time-kernel) COMPREPLY=( $(compgen -W "epanechnikov gaussian uniform" -- "$cur") ); return ;;
        --lag-kernel) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --time-bandwidth --lag-bandwidth --time-kernel --lag-kernel --n-grid --format -f --output -o --model -M --no-standardize --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict multivariate bvar")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "direct gibbs" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --draws -n --sampler --config -C --format -f --output -o --model -M --config-json --set --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict multivariate favar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --lags -p --key-vars --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict multivariate var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict multivariate vecm")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --rank -r --deterministic --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict panel piv")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "fe re fd hausman-taylor" -- "$cur") ); return ;;
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster twoway driscoll-kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --exog --endog --instruments -Z --method -m --cov-type -v --id-col -u --time-col -t --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict panel plogit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster twoway driscoll-kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --cov-type -v --method -m --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict panel pprobit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster twoway driscoll-kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --cov-type -v --method -m --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict panel preg")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster twoway driscoll-kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --cov-type -v --method -m --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict panel xtqreg")
      case "$prev" in
        --slope) COMPREPLY=( $(compgen -W "homogeneous heterogeneous" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --factors -q --tau --slope --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict regime ms")
      case "$prev" in
        --probs) COMPREPLY=( $(compgen -W "smoothed filtered" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --k-regimes --max-iter -I --tol -T --probs --output -o --format -f --model -M --switching-variance --no-switching-variance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict regime ms-ar")
      case "$prev" in
        --probs) COMPREPLY=( $(compgen -W "smoothed filtered" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --k-regimes --max-iter -I --probs --output -o --format -f --model -M --switching-variance --no-switching-variance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict regression 3sls")
      case "$prev" in
        --instruments|-Z) COMPREPLY=( $(compgen -W "common perequation" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --instruments -Z --output -o --format -f --model -M --config-json --set --no-intercept --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict regression reg")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --weights --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict regression statespace")
      case "$prev" in
        --kind) COMPREPLY=( $(compgen -W "local-level local-linear-trend" -- "$cur") ); return ;;
        --init-mode) COMPREPLY=( $(compgen -W "kappa diffuse" -- "$cur") ); return ;;
        --state) COMPREPLY=( $(compgen -W "filtered smoothed both" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --kind --init-mode --kappa --state --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict regression sur")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --output -o --format -f --model -M --config-json --set --iterate --no-intercept --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict univariate arfima")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "css mle" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --method -m --d0 --max-iter -I --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict univariate arima")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "ols css mle css_mle" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --q --method -m --format -f --output -o --model -M --auto --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict univariate sarima")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "css_mle mle css" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --q --P --D --Q --s --max-p --max-q --max-P --max-Q --criterion --method -m --max-iter -I --format -f --output -o --model -M --auto --no-intercept --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict volatility aparch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --fix-delta --fix-gamma --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict volatility arch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --q --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict volatility cgarch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict volatility egarch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict volatility fiegarch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --d0 --truncation --dist --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict volatility figarch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --d0 --truncation --dist --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict volatility garch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict volatility garch-midas")
      case "$prev" in
        --rv) COMPREPLY=( $(compgen -W "realized macro" -- "$cur") ); return ;;
        --span) COMPREPLY=( $(compgen -W "fixed rolling" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --m-freq --k --rv --span --config -C --output -o --format -f --model -M --config-json --set --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict volatility gjr-garch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict volatility igarch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "predict volatility sv")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --draws -n --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals choice logit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals choice mlogit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --kind) COMPREPLY=( $(compgen -W "response pearson deviance" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --kind --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals choice nbreg")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --offset --exposure --max-iter -I --tol -T --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals choice ologit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --kind) COMPREPLY=( $(compgen -W "response pearson deviance" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --kind --model -M --generalized --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals choice oprobit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
        --kind) COMPREPLY=( $(compgen -W "response pearson deviance" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --kind --model -M --generalized --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals choice poisson")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "robust mle hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --offset --exposure --cov-type -v --clusters -U --max-iter -I --tol -T --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals choice probit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals factor dynamic")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "twostep qml" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --factor-lags --method -m --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals factor fhlz")
      case "$prev" in
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --lag-criterion) COMPREPLY=( $(compgen -W "bic aic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --bandwidth -b --kernel -k --p-max --lag-criterion --n-perm --irf-horizon --em-max-iter --em-tol --seed --format -f --output -o --model -M --allow-missing --no-standardize --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals factor gdfm")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --dynamic-rank --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals factor gdfm-i1")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "permanent-transitory cholesky longrun sign proxy" -- "$cur") ); return ;;
        --det-trend) COMPREPLY=( $(compgen -W "none constant linear trend" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --lag-criterion) COMPREPLY=( $(compgen -W "bic aic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --n-permanent --id -i --det-trend --p-max --n-perm --bandwidth -b --kernel -k --lag-criterion --irf-horizon --config -C --instrument --seed --format -f --output -o --model -M --config-json --set --no-standardize --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals factor qfm")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "iqr smoothed" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--tau --factors -q --method -m --format -f --output -o --model -M --standardize --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals factor static")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--nfactors --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals factor tv-gdfm")
      case "$prev" in
        --time-kernel) COMPREPLY=( $(compgen -W "epanechnikov gaussian uniform" -- "$cur") ); return ;;
        --lag-kernel) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dynamic-rank --time-bandwidth --lag-bandwidth --time-kernel --lag-kernel --n-grid --format -f --output -o --model -M --no-standardize --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals multivariate bvar")
      case "$prev" in
        --sampler) COMPREPLY=( $(compgen -W "direct gibbs" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --draws -n --sampler --config -C --format -f --output -o --model -M --config-json --set --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals multivariate favar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --lags -p --key-vars --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals multivariate lanne-luoto")
      case "$prev" in
        --form) COMPREPLY=( $(compgen -W "b-model a-model" -- "$cur") ); return ;;
        --weighting|-w) COMPREPLY=( $(compgen -W "two-step iterated cue" -- "$cur") ); return ;;
        --moment-selection) COMPREPLY=( $(compgen -W "msc-rmsc rmsc-seq none" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen qs quadratic-spectral tukey-hanning" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --form --weighting -w --moment-selection --kernel -k --bandwidth -b --max-iter -I --tol -T --n-starts --shock-names --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals multivariate lms-svar")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "three-step one-step full-ml" -- "$cur") ); return ;;
        --se) COMPREPLY=( $(compgen -W "hessian sandwich opg" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --distributions --method -m --se --n-starts --max-iter -I --tol -T --shock-names --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals multivariate qvar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --taus --ordering --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals multivariate ssvarma")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "pml ml gmm gmm-2sls" -- "$cur") ); return ;;
        --distribution) COMPREPLY=( $(compgen -W "student-t mixture-normal mixture-normal-asym pearson-iv skew-normal" -- "$cur") ); return ;;
        --se) COMPREPLY=( $(compgen -W "auto hessian sandwich opg" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--ar-lags --ma-lags --method -m --distribution --k-iv --se --n-starts --max-iter -I --tol -T --shock-names --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals multivariate var")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals multivariate vecm")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --rank -r --deterministic --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals panel piv")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "fe re fd hausman-taylor" -- "$cur") ); return ;;
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster twoway driscoll-kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --exog --endog --instruments -Z --method -m --cov-type -v --id-col -u --time-col -t --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals panel plogit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster twoway driscoll-kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --cov-type -v --method -m --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals panel pprobit")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster twoway driscoll-kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --cov-type -v --method -m --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals panel preg")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols cluster twoway driscoll-kraay" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --cov-type -v --method -m --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals panel xtqreg")
      case "$prev" in
        --slope) COMPREPLY=( $(compgen -W "homogeneous heterogeneous" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --factors -q --tau --slope --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals regime ms")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --k-regimes --max-iter -I --tol -T --output -o --format -f --model -M --switching-variance --no-switching-variance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals regime ms-ar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --k-regimes --max-iter -I --output -o --format -f --model -M --switching-variance --no-switching-variance --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals regime setar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --trim --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals regime star")
      case "$prev" in
        --type) COMPREPLY=( $(compgen -W "lstr1 lstr2 estr auto" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --type --n-gamma --n-c --transition-col --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals regression 3sls")
      case "$prev" in
        --instruments|-Z) COMPREPLY=( $(compgen -W "common perequation" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --instruments -Z --output -o --format -f --model -M --config-json --set --no-intercept --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals regression reg")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --clusters -U --output -o --format -f --weights --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals regression statespace")
      case "$prev" in
        --kind) COMPREPLY=( $(compgen -W "local-level local-linear-trend" -- "$cur") ); return ;;
        --init-mode) COMPREPLY=( $(compgen -W "kappa diffuse" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --kind --init-mode --kappa --output -o --format -f --model -M --standardized --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals regression sur")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --output -o --format -f --model -M --config-json --set --iterate --no-intercept --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals univariate arfima")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "css mle" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --method -m --d0 --max-iter -I --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals univariate arima")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "ols css mle css_mle" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --q --method -m --format -f --output -o --model -M --auto --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals univariate sarima")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "css_mle mle css" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --q --P --D --Q --s --max-p --max-q --max-P --max-Q --criterion --method -m --max-iter -I --format -f --output -o --model -M --auto --no-intercept --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals volatility aparch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --fix-delta --fix-gamma --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals volatility arch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --q --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals volatility cgarch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals volatility egarch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals volatility fiegarch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --d0 --truncation --dist --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals volatility figarch")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --d0 --truncation --dist --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals volatility garch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals volatility garch-midas")
      case "$prev" in
        --rv) COMPREPLY=( $(compgen -W "realized macro" -- "$cur") ); return ;;
        --span) COMPREPLY=( $(compgen -W "fixed rolling" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --m-freq --k --rv --span --config -C --output -o --format -f --model -M --config-json --set --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals volatility gjr-garch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals volatility igarch")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --q --output -o --format -f --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "residuals volatility sv")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --draws -n --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "ri cg-test")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--realized --forecast-now --forecast-lag --hac-lags --horizon -H --conf-level -L --model -M --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "ri discrete")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --omega --capacity --units --tol -T --max-iter -I --format -f --output -o --plot-save -G --save-model -S --config-json --set --result -R --save-result -W --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "ri estimate")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "mle bayes" -- "$cur") ); return ;;
        --estimate-param) COMPREPLY=( $(compgen -W "capacity omega" -- "$cur") ); return ;;
        --cov-type|-v) COMPREPLY=( $(compgen -W "hessian sandwich" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --model -M --method -m --estimate-param --cov-type -v --observables --init-param --measurement-error --draws -n --burnin -B --step-scale --conf-level -L --format -f --output -o --plot-save -G --save-model -S --config-json --set --result -R --save-result -W --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "ri fevd")
      case "$prev" in
        --observables) COMPREPLY=( $(compgen -W "all actions actions-and-states states" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --model -M --horizons -H --observables --format -f --output -o --plot-save -G --config-json --set --result -R --save-result -W --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "ri iia-test")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --omega --capacity --units --tol -T --format -f --output -o --plot-save -G --config-json --set --result -R --save-result -W --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "ri irf")
      case "$prev" in
        --observables) COMPREPLY=( $(compgen -W "all actions actions-and-states states" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --model -M --horizons -H --observables --format -f --output -o --plot-save -G --config-json --set --result -R --save-result -W --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "ri mw")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --capacity --omega --strategic-complementarity --horizons -H --tol -T --max-iter -I --format -f --output -o --plot-save -G --save-model -S --config-json --set --result -R --save-result -W --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "ri simulate")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --model -M --periods -N --burn -B --seed --save-data --format -f --output -o --config-json --set --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "ri solve")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "water-filling logdet-barrier" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --method -m --capacity --omega --units --tol -T --max-iter -I --format -f --output -o --plot-save -G --save-model -S --config-json --set --result -R --save-result -W --problem-only --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "ri statespace")
      case "$prev" in
        --observables) COMPREPLY=( $(compgen -W "all actions actions-and-states states" -- "$cur") ); return ;;
        --as) COMPREPLY=( $(compgen -W "statespace abcd steady-kalman" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --model -M --observables --as --init-mode --kappa --format -f --output -o --plot-save -G --save-model -S --config-json --set --result -R --save-result -W --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "ri transition")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --model -M --t-path --damping --tol -T --max-iter -I --capacity --omega --format -f --output -o --plot-save -G --save-model -S --config-json --set --result -R --save-result -W --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "schema")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--format -f --output -o --docs --help -h" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "completions data did dsge estimate fevd filter forecast hadsge hd io irf model nowcast policy predict repl residuals ri schema serve show spectral test" -- "$cur") )
      fi ;;
    "serve")
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--families --tools --mcp --compact --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "show")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--max-rows --max-cols --output -o --format -f --plot-save -G --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "spectral acf")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --max-lag --ccf-with --conf-level -L --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "spectral cross")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--var1 --var2 --conf-level -L --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "spectral density")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "periodogram welch smoothed ar" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --method -m --bandwidth -b --conf-level -L --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --log-scale --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "spectral fevd")
      case "$prev" in
        --id|-i) COMPREPLY=( $(compgen -W "cholesky sign longrun max-share proxy lewis-tvv sv-em gmm-moments" -- "$cur") ); return ;;
        --q-method) COMPREPLY=( $(compgen -W "hallin-liska bai-ng amengual-watson" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "fglr fhlz gdfm-var" -- "$cur") ); return ;;
        --spectral) COMPREPLY=( $(compgen -W "lag-window smoothed-periodogram" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --id -i --q-method --method -m --spectral --instrument --var-lags --n-perm --p-max --target --horizons -H --config -C --bandwidth -b --kernel -k --pl --pu --band-low --band-high --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --config-json --set --save-model -S --include-idiosyncratic --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "spectral periodogram")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --conf-level -L --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --log-scale --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "spectral transfer")
      case "$prev" in
        --filter) COMPREPLY=( $(compgen -W "hp bk hamilton" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--filter --lambda -l --n-freq --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test brant")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test coint ardl-bounds")
      case "$prev" in
        --ic) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --trend|-e) COMPREPLY=( $(compgen -W "none const trend" -- "$cur") ); return ;;
        --cv-source) COMPREPLY=( $(compgen -W "pss" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --p --q --max-p --max-q --ic --trend -e --case --level --cv-source --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test coint engle-granger")
      case "$prev" in
        --trend|-e) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --trend -e --lags -p --max-lags --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test coint fisher-johansen")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --combine) COMPREPLY=( $(compgen -W "mw choi" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --vars --deterministic --lags -p --combine --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test coint gregory-hansen")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--model -M --lags -p --max-lags --trim --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test coint johansen")
      case "$prev" in
        --trend|-e) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --trend -e --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test coint kao")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --dep -y --indep -x --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test coint pedroni")
      case "$prev" in
        --trend|-e) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --dep -y --indep -x --trend -e --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test coint phillips-ouliaris")
      case "$prev" in
        --trend|-e) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen qs tukey-hanning" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --trend -e --kernel -k --bandwidth -b --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test coint westerlund")
      case "$prev" in
        --trend|-e) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --dep -y --indep -x --trend -e --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test did bacon")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--outcome --treatment --id-col -u --time-col -t --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test did honest")
      case "$prev" in
        --cluster) COMPREPLY=( $(compgen -W "unit time twoway" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "did event-study" -- "$cur") ); return ;;
        --did-method) COMPREPLY=( $(compgen -W "twfe cs sa bjs dcdh" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--outcome --treatment --id-col -u --time-col -t --mbar --leads --horizons -H --lags -p --cluster --conf-level -L --method -m --did-method --output -o --format -f --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test did negweight")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--treatment --id-col -u --time-col -t --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test did pretrend")
      case "$prev" in
        --cluster) COMPREPLY=( $(compgen -W "unit time twoway" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "did event-study" -- "$cur") ); return ;;
        --did-method) COMPREPLY=( $(compgen -W "twfe cs sa bjs dcdh" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--outcome --treatment --id-col -u --time-col -t --leads --horizons -H --lags -p --cluster --conf-level -L --method -m --did-method --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test dispersion")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "robust mle hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --offset --exposure --cov-type -v --clusters -U --max-iter -I --tol -T --alpha --format -f --output -o --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test edf")
      case "$prev" in
        --dist) COMPREPLY=( $(compgen -W "normal exponential logistic gumbel gamma weibull chisq" -- "$cur") ); return ;;
        --test) COMPREPLY=( $(compgen -W "ks lilliefors cvm ad watson" -- "$cur") ); return ;;
        --params) COMPREPLY=( $(compgen -W "estimate specified" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --dist --test --params --theta --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test factor ahn-horenstein")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--k-max --format -f --output -o --plot-save -G --result -R --save-result -W --no-demean --no-standardize --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test factor onatski-ed")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--k-max --max-iter -I --format -f --output -o --plot-save -G --result -R --save-result -W --no-standardize --no-demean --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test factor onatski-q")
      case "$prev" in
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen tukey-hanning" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--k0 --k1 --k-max --alpha --bandwidth -b --n-blocks --kernel -k --freq --n-sim --seed --format -f --output -o --plot-save -G --result -R --save-result -W --select --no-standardize --no-demean --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test factor qfm-constancy")
      case "$prev" in
        --bootstrap) COMPREPLY=( $(compgen -W "block wild" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--tau1 --tau2 --factors -q --n-boot --block-length --bootstrap --max-iter -I --tol -T --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --standardize --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test factor qfm-spanning")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "ic1 ic2 ic3" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--tau --taus --factors -q --r-pca --r-max --criterion --threshold --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --standardize --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test fisher")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test gph")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --bandwidth -b --trim --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test hansen-linearity")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --trim --draws -n --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test hausman-iia")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --omit-category --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test identifiability")
      case "$prev" in
        --test) COMPREPLY=( $(compgen -W "strength gaussianity independence overidentification lambda-distinct gaussian-count label-stability all" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "fastica jade sobi dcov hsic cvm" -- "$cur") ); return ;;
        --contrast) COMPREPLY=( $(compgen -W "logcosh exp kurtosis" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --test --method -m --contrast --n-starts --n-bootstrap --output -o --format -f --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test influence")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test iv anderson-rubin")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3 cluster" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --endogenous --instruments -Z --cov-type -v --clusters -U --beta0 --conf-level -L --n-grid --span --format -f --output -o --result -R --save-result -W --no-ci --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test iv weak-instrument")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --endogenous --instruments -Z --cov-type -v --threshold --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test iv wild-cluster")
      case "$prev" in
        --boot-weights) COMPREPLY=( $(compgen -W "rademacher webb" -- "$cur") ); return ;;
        --enumerate-signs) COMPREPLY=( $(compgen -W "auto yes no" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --clusters -U --coefficient --null --boot-reps --boot-weights --conf-level -L --ci-gridpoints --enumerate-signs --format -f --output -o --result -R --save-result -W --no-impose-null --no-ci --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test local-whittle")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --bandwidth -b --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test multivariate fundamentalness")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --max-lag --moments --n-boot --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test multivariate gmm-moments")
      case "$prev" in
        --form) COMPREPLY=( $(compgen -W "b-model a-model" -- "$cur") ); return ;;
        --weighting|-w) COMPREPLY=( $(compgen -W "two-step iterated cue" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "msc-rmsc rmsc-seq" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen qs quadratic-spectral tukey-hanning" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --form --weighting -w --method -m --kernel -k --bandwidth -b --alpha --max-iter -I --tol -T --n-starts --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test multivariate granger")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--cause --effect --lags -p --rank -r --deterministic --model -M --format -f --output -o --result -R --save-result -W --all --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test multivariate lagselect")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "aic bic hqc" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--max-lags --criterion --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test multivariate lm")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags1 --lags2 --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test multivariate lr")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags1 --lags2 --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test multivariate nongaussian-diag")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --distributions --diag-lags --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test multivariate stability")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test multivariate sufficient-info")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --panel --factors -q --r-max --p-f --format -f --output -o --plot-save -G --model -M --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test multivariate svar-hypothesis")
      case "$prev" in
        --estimator) COMPREPLY=( $(compgen -W "lms lanne-luoto" -- "$cur") ); return ;;
        --type) COMPREPLY=( $(compgen -W "recursiveness impact-zero impact-linear long-run horizon-irf mixed" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "wald lr lm gmm-lr" -- "$cur") ); return ;;
        --bootstrap) COMPREPLY=( $(compgen -W "none wild iid" -- "$cur") ); return ;;
        --vcov-type) COMPREPLY=( $(compgen -W "hessian sandwich opg" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --estimator --distributions --type --config -C --method -m --bootstrap --n-boot --max-iter -I --tol -T --vcov-type --format -f --output -o --plot-save -G --model -M --config-json --set --result -R --save-result -W --plot -g --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test nardl-symmetry")
      case "$prev" in
        --ic) COMPREPLY=( $(compgen -W "aic bic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --asymmetric --p --q --max-p --max-q --ic --case --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test normality")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --output -o --format -f --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test panel dh-causality")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --cause --effect --p --bootstrap --seed --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test panel f-fe")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test panel hausman")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test panel modified-wald")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test panel panic")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "pooled individual" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --method -m --id-col -u --time-col -t --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test panel pesaran-cd")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test panel pmg-hausman")
      case "$prev" in
        --efficient) COMPREPLY=( $(compgen -W "pmg dfe" -- "$cur") ); return ;;
        --trend|-e) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --dep -y --indep -x --efficient --trend -e --p --q --max-iter -I --tol -T --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test panel wooldridge-ar")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test park-added")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "fmols ccr dols" -- "$cur") ); return ;;
        --trend|-e) COMPREPLY=( $(compgen -W "none const linear" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen qs tukey-hanning" -- "$cur") ); return ;;
        --hac-kernel) COMPREPLY=( $(compgen -W "bartlett parzen qs tukey-hanning" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --method -m --trend -e --kernel -k --bandwidth -b --leads --lags -p --q-add --hac-kernel --hac-bandwidth --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test pvar hansen-j")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --lags -p --format -f --output -o --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test pvar lagselect")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "bic aic hqic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --max-lags --criterion --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test pvar mmsc")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "bic aic hqic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --max-lags --criterion --format -f --output -o --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test pvar stability")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--id-col -u --time-col -t --lags -p --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial arch-lm")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --lags -p --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial bartlett-wn")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --format -f --output -o --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial bds")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --max-dim --eps-frac --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial box-pierce")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --lags -p --format -f --output -o --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial breusch-pagan")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --indep -x --id-col -u --time-col -t --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial durbin-watson")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --format -f --output -o --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial glejser")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial harvey")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial heteroskedasticity")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "markov garch smooth_transition external" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --method -m --config -C --regimes --output -o --format -f --config-json --set --result -R --save-result -W --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial ljung-box")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --lags -p --format -f --output -o --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial sign-bias")
      case "$prev" in
        --model|-M) COMPREPLY=( $(compgen -W "garch egarch gjr-garch" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --model -M --p --q --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test serial white")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --format -f --output -o --result -R --save-result -W --no-cross-terms --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test stability andrews")
      case "$prev" in
        --test) COMPREPLY=( $(compgen -W "supwald suplr suplm expwald explr explm meanwald meanlr meanlm" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--response --test --trimming --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test stability bai-perron")
      case "$prev" in
        --criterion) COMPREPLY=( $(compgen -W "bic lwz" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--response --max-breaks --trimming --criterion --conf-level -L --format -f --output -o --plot-save -G --result -R --save-result -W --plot -g --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test stability chow")
      case "$prev" in
        --type) COMPREPLY=( $(compgen -W "breakpoint forecast" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --break-at --type --level --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test stability cusum")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --level --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test stability cusumsq")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --level --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test stability factor-break")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "breitung_eickmeier chen_dolado_gonzalo han_inoue" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --method -m --id-col -u --time-col -t --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test stability gsadf")
      case "$prev" in
        --cv) COMPREPLY=( $(compgen -W "asymptotic wildboot" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --r0 --adflag --draws -n --cv --seed --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test stability hansen-instability")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "fmols ccr dols" -- "$cur") ); return ;;
        --trend|-e) COMPREPLY=( $(compgen -W "none const linear" -- "$cur") ); return ;;
        --kernel|-k) COMPREPLY=( $(compgen -W "bartlett parzen qs tukey-hanning" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --method -m --trend -e --kernel -k --bandwidth -b --leads --lags -p --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test stability nyblom")
      case "$prev" in
        --model|-M) COMPREPLY=( $(compgen -W "garch egarch gjr-garch" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --model -M --p --q --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test stability recursive-residuals")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --format -f --output -o --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test stability sadf")
      case "$prev" in
        --cv) COMPREPLY=( $(compgen -W "asymptotic wildboot" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --r0 --adflag --draws -n --cv --seed --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test star-linearity")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --p --d --transition-col --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root adf")
      case "$prev" in
        --trend|-e) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --max-lags --trend -e --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root adf-2break")
      case "$prev" in
        --model|-M) COMPREPLY=( $(compgen -W "level both" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --model -M --lags -p --max-lags --trim --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root breitung")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--deterministic --lags -p --format -f --output -o --result -R --save-result -W --cs-demean --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root cips")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--lags -p --deterministic --id-col -u --time-col -t --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root dfgls")
      case "$prev" in
        --regression) COMPREPLY=( $(compgen -W "constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --regression --lags -p --max-lags --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root ers")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --format -f --output -o --result -R --save-result -W --trend --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root fourier-adf")
      case "$prev" in
        --regression) COMPREPLY=( $(compgen -W "constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --regression --fmax --lags -p --max-lags --trim --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root fourier-kpss")
      case "$prev" in
        --regression) COMPREPLY=( $(compgen -W "constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --regression --fmax --bandwidth -b --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root hadri")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--deterministic --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root hegy")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none const const-seas const-trend const-trend-seas" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --frequency --deterministic --lags -p --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root ips")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "constant trend" -- "$cur") ); return ;;
        --criterion) COMPREPLY=( $(compgen -W "aic bic hqic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--deterministic --lags -p --max-lags --criterion --format -f --output -o --result -R --save-result -W --cs-demean --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root kpss")
      case "$prev" in
        --trend|-e) COMPREPLY=( $(compgen -W "constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --trend -e --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root llc")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --criterion) COMPREPLY=( $(compgen -W "aic bic hqic" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--deterministic --lags -p --max-lags --criterion --format -f --output -o --result -R --save-result -W --cs-demean --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root lm-unitroot")
      case "$prev" in
        --regression) COMPREPLY=( $(compgen -W "level both" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --breaks --regression --lags -p --max-lags --trim --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root moon-perron")
      case "$prev" in
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--factors -q --id-col -u --time-col -t --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root np")
      case "$prev" in
        --trend|-e) COMPREPLY=( $(compgen -W "constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --trend -e --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root pp")
      case "$prev" in
        --trend|-e) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --trend -e --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test unit-root za")
      case "$prev" in
        --trend|-e) COMPREPLY=( $(compgen -W "constant trend both" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --trend -e --trim --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test variance-ratio")
      case "$prev" in
        --method|-m) COMPREPLY=( $(compgen -W "lomackinlay wright" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--column -c --horizons -H --method -m --format -f --output -o --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test vecm alpha")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "johansen engle_granger" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --lags -p --rank -r --deterministic --method -m --significance --format -f --output -o --model -M --config-json --set --result -R --save-result -W --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test vecm beta")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "johansen engle_granger" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --lags -p --rank -r --deterministic --method -m --significance --format -f --output -o --model -M --config-json --set --result -R --save-result -W --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test vecm joint")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "johansen engle_granger" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --lags -p --rank -r --deterministic --method -m --significance --format -f --output -o --model -M --config-json --set --result -R --save-result -W --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test vecm known-beta")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "johansen engle_granger" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--config -C --lags -p --rank -r --deterministic --method -m --significance --format -f --output -o --model -M --config-json --set --result -R --save-result -W --strict -X --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test vecm weak-exog")
      case "$prev" in
        --deterministic) COMPREPLY=( $(compgen -W "none constant trend" -- "$cur") ); return ;;
        --method|-m) COMPREPLY=( $(compgen -W "johansen engle_granger" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--vars --lags -p --rank -r --deterministic --method -m --significance --format -f --output -o --model -M --result -R --save-result -W --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "test vif")
      case "$prev" in
        --cov-type|-v) COMPREPLY=( $(compgen -W "ols hc0 hc1 hc2 hc3" -- "$cur") ); return ;;
        --format|-f) COMPREPLY=( $(compgen -W "table csv json" -- "$cur") ); return ;;
      esac
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--dep -y --cov-type -v --format -f --output -o --model -M --help -h" -- "$cur") )
      elif [[ "$cur" == :* ]]; then
        COMPREPLY=( $(compgen -W ":ddcg :denmark :fred_md :fred_qd :gnp_hamilton :grunfeld :mp_shocks :mpdta :mroz :nile :pwt :stackloss" -- "$cur") )
      else
        COMPREPLY=( $(compgen -f -- "$cur") )
      fi ;;
    "repl")
      COMPREPLY=( $(compgen -W "--help -h --no-color" -- "$cur") ) ;;
  esac
}
complete -F _frdc frdc
