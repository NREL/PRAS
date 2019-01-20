# Probabilistic Resource Adequacy Suite

The Probabilistic Resource Adequacy Suite (PRAS) is a collection of tools for
resource adequacy analysis of bulk power systems.

This package simply defines dependencies on the constituent elements of the
suite, most notably:

 - **ResourceAdequacy.jl**: Resource Adequacy Assessment
 - **CapacityValue.jl**: Capacity Valuation
 - **PLEXOS2PRAS.jl**: Tools for importing PLEXOS databases into PRAS

The `bin` directory contains command-line tools built on these packages:
adding it to your `PATH` will allow you to use those tools directly, in some
cases enabling you to avoid writing Julia code.
