# Getting Started with PRAS

## Unleash your CPU cores

First, know that PRAS uses multi-threading, so be
sure to set the environment variable controlling the number of threads
available to Julia (36 in this Bash example, which is a good choice for
nodes on NREL's Eagle supercomputer - on a laptop you would probably only
want 4) before running scripts or launching the REPL:

```sh
export JULIA_NUM_THREADS=36
```

## Architecture Overview

PRAS functionality is distributed across a range of different types of
modules that can be mixed, matched, extended, or replaced to support the needs
of a particular analysis. When assessing reliability or capacity value, one can
define the modules to be used while passing along any associated parameters
or options.

The categories of modules are:

**Extractions**: How should VG or load data be extracted from historical
time-series data to create probability distributions at each timestep?
Options are `Backcast` or `REPRA`.

**Simulations**: How should power system operations be simulated?
Options are `NonSequentialCopperplate` or `NonSequentialNetworkFlow`.

**Results**: What level of detail should be saved out during simulations?
Options are `Minimal`, `Temporal`, `Spatial`, `SpatioTemporal`, and `Network`.

## Running an analysis

Analysis centers around the `assess` method with different arguments passed
depending on the desired analysis to run.
For example, to run a convolution-based reliability assessment
(`NonSequentialCopperplate`) with VG distributions derived from simple
backcasts (`Backcast`) and aggregate LOLE and EUE reporting (`Minimal`),
one would run:

```julia
assess(Backcast(), NonSequentialCopperplate(), Minimal(), mysystemmodel)
```

To run a network flow simulation instead with 100,000 Monte Carlo samples,
the method call becomes:

```julia
assess(Backcast(), NonSequentialNetworkFlow(100_000), Minimal(), mysystemmodel)
```

To use REPRA-style windowing (with a +/- 1-hour, +/- 10-day window)
to generate VG distributions, the call becomes:

```julia
assess(REPRA(1, 10), NonSequentialNetworkFlow(100_000), Minimal(), mysystemmodel)
```

To save regional results in a multi-area system, change `Minimal` to `Spatial`:
```julia
assess(REPRA(1, 10), NonSequentialNetworkFlow(100_000), Spatial(), mysystemmodel)
```

To save regional results for each simulation period, use the `SpatioTemporal`
result specification instead:
```julia
assess(REPRA(1, 10), NonSequentialNetworkFlow(100_000), SpatioTemporal(), mysystemmodel)
```

## Querying Results

After running an analysis, metrics of interest can be obtained by calling the
appropriate metric's constructor with the result object.

For example, to obtain the system-wide LOLE over the simulation period:

```julia
result = assess(Backcast(), NonSequentialNetworkFlow(100_000), SpatioTemporal(), mysystemmodel)
lole = LOLE(result)
```
Single-period metrics such as LOLP can also be extracted if the appropriate
information was saved (i.e. if `Temporal` or `SpatioTemporal` result
specifications were used). For example, to get system-wide LOLP for April 27th,
2024 at 1pm:

```julia
lolp = LOLP(result, DateTime(2024, 4, 27, 13))
```

Similarly, if per-region information was saved (i.e. if `Spatial` or
`SpatioTemporal` result specifications were used), region-specific metrics
can be extracted. For example, to obtain the EUE of Region A across the entire
simulation period:

```julia
eue_a = EUE(result, "Region A")
```

If the results specification supports it (i.e. `SpatioTemporal` or `Network`),
metrics can be obtained for both a specific region and time:

```julia
eue_a = EUE(result, "Region A", DateTime(2024, 4, 27, 13))
```

Finally, if using the `Network` result spec, information about interface flows
and utilization factors can be obtained as well:

```julia
# Average flow from Region A to Region B during the hour of interest
flow_ab = ExpectedInterfaceFlow(
    result, "Region A", "Region B", DateTime(2024, 4, 27, 13))
    
# Same magnitude as above, but different sign
flow_ba = ExpectedInterfaceFlow(
    result, "Region B", "Region A", DateTime(2024, 4, 27, 13))
    
# Average utilization (average ratio of absolute value of actual flow vs maximum possible after outages)
utilization_ab = ExpectedInterfaceUtilization(
    result, "Region A", "Region B", DateTime(2024, 4, 27, 13))
```
