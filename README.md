# Probabilistic Resource Adequacy Suite

The Probabilistic Resource Adequacy Suite (PRAS) is a collection of tools for
resource adequacy analysis of bulk power systems.

## Contents

This package simply defines dependencies on the constituent elements of the
suite, most notably:

 - [PRASBase.jl](https://github.com/NREL/PRASBase.jl) for core types and data structures
 - [ResourceAdequacy.jl](https://github.com/NREL/ResourceAdequacy.jl) for resource adequacy assessment (NEUE, LOLE, etc)
 - [CapacityCredit.jl](https://github.com/NREL/CapacityCredit.jl) for capacity valuation (EFC, etc)
 - [PLEXOS2PRAS.jl](https://github.com/NREL/PLEXOS2PRAS.jl) for importing PLEXOS databases into PRAS

The PRAS module reexports `ResourceAdequacy` and `CapacityCredit`, so installing
and using this package alone will be sufficient for most analyses.

