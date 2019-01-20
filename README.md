# Probabilistic Resource Adequacy Suite

The Probabilistic Resource Adequacy Suite (PRAS) is a collection of tools for
resource adequacy analysis of bulk power systems.

## Contents

This package simply defines dependencies on the constituent elements of the
suite, most notably:

 - [ResourceAdequacy.jl](https://github.com/NREL/ResourceAdequacy.jl) for resource adequacy assessment (NEUE, LOLE, etc)
 - [CapacityValue.jl](https://github.nrel.gov/PRAS/CapacityValue.jl) for capacity valuation (EFC, etc)
 - [PLEXOS2PRAS.jl](https://github.nrel.gov/PRAS/PLEXOS2PRAS) for importing PLEXOS databases into PRAS

The PRAS module itself provides no extra functionality, although it can be
imported as a shorthand for building/precompiling all its various dependencies
(constituent modules still need to be imported before use in scripts).

## Setup

*NREL Eagle users: Note that if you're using the PRAS environment module
(`module load pras`), these steps are taken care of automatically, so
you can launch Julia or use the command-line tools without any extra
configuration.*

To make use of these packages, launch Julia with active project defined
as the path to this repository:

```sh
julia --project=/path/to/PRAS.jl
```

The `bin` directory contains command-line tools built on these packages:
adding it to your `PATH` will allow you to use those tools directly, in some
cases enabling you to avoid writing Julia code:

```sh
export PATH=/path/to/PRAS.jl/bin:PATH
```

