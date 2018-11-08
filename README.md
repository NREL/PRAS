# ResourceAdequacy

_Note: This package is still very much a work in progress and is subject to change. Email Gord for the latest status._

The Probabilistic Resource Adequacy Suite (PRAS) provides a modular collection
of data processing and system simulation tools to assess power system reliability.

To use this functionality for capacity valuation, see [CapacityValue.jl](https://github.nrel.gov/PRAS/CapacityValue.jl). To import systems from PLEXOS, see the [PLEXOS2PRAS](https://github.nrel.gov/PRAS/PLEXOS2PRAS) collection of scripts. To save out detailed results to a file for postprocessing or visualization, see [PRAS2HDF5.jl](https://github.nrel.gov/PRAS/PRAS2HDF5.jl).

## Getting Started

RAS functionality is distributed across a range of different types of modules that can
be mixed and matched to support the needs of a particular analysis.
When assessing reliability or capacity value, one can define the modules to be used
while passing along any associated parameters or options.

### Running an analysis
Analysis centers around the `assess` method with different arguments passed
depending on the desired analysis to run.
For a simple example, to run a copper plate reliability assessment on a single-period
system distribution, with simple LOLP and EUE reporting, one would run:

```julia
singleperiod_system # A single-period system distribution
assess(NonSequentialCopperplate(), MinimalResult(), singleperiod_system)
```

To run a network flow simulation instead with 100,000 Monte Carlo samples,
the method call becomes:

```julia
assess(NonSequentialNetworkFlow(100_000), MinimalResult(), singleperiod_system)
```

Assessing a multi-period system requires specifying some way of decomposing
time series data into individual single-period distributions.
To use REPRA-style windowing (with a +/- 1-hour, +/- 10-day window):

```julia
multiperiod_system # A multi-period system specification
assess(REPRA(1, 10), NonSequentialNetworkFlow(100_000), MinimalResult(), multiperiod_system)
```

## Single Period Reliability Assessment Components

### Simulation Method

Currently supported:
 - Non-sequential copper plate (`NonSequentialCopperplate`)
 - Non-sequential network flow (`NonSequentialNetworkFlow`)
 - Sequential network flow under development

## Multi-Period Reliability Assessment Components

Multi-period reliability assessment requires the same components as a single-period reliability assessment, as well as a time series decomposition method.

### Decomposition Method

Currently supported:
 - Deterministic backcasting (`Backcast`)
 - REPRA windowing (`REPRA`)

## Results

Different result formats can be specified depending on the desired level of detail:

`MinimalResult`: just stores enough information to report LOLP/LOLE and EUE

`NetworkResult`: stores full network states from simulations, by default only
for cases with dropped load - use with `failuresonly=false` to save all data
(this will likely slow things down and require lots of memory).
Use [PRAS2HDF5](https://github.nrel.gov/PRAS/PRAS2HDF5.jl) to save network data
out to disk for post-processing and visualization.
