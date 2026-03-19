using Friedman
# Exercise build_app and help paths
app = Friedman.build_app()
Friedman.dispatch(app, ["--help"])
Friedman.dispatch(app, ["estimate", "--help"])
Friedman.dispatch(app, ["test", "--help"])
Friedman.dispatch(app, ["irf", "--help"])
Friedman.dispatch(app, ["forecast", "--help"])
Friedman.dispatch(app, ["--version"])
