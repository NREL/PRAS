# ResourceAdequacy

_Note: This package is still very much a work in progress and is subject to change. Email Gord for the latest status._

The Resource Adequacy Suite (RAS) provides a modular collection of data processing and system simulation tools to assess power system reliability and calculate the capacity value of individual or aggregated resources.

## Getting Started

RAS functionality is distributed across a range of different types of modules that can be mixed and matched to support the needs of a particular analysis. When assessing reliability or capacity value, one can define the modules to be used while passing along any associated parameters or options.

### Running an analysis
Analysis centers around the `assess` method with different arguments passed depending on the desired analysis to run. For a simple example, to run a copper plate reliability assessment on a single-period system distribution, one would run:

```julia
singleperiod_system # A single-period system distribution
assess(Copperplate(), singleperiod_system)
```

To run a network flow simulation instead with 100,000 Monte Carlo samples, the method call becomes:

```julia
assess(NetworkFlow(100_000), singleperiod_system)
```

Assessing a multi-period system requires specifying some way of decomposing time series data into individual single-period distributions. To use REPRA-style windowing (with a +/- 1-hour, +/- 10-day window):

```julia
multiperiod_system # A multi-period system specification
assess(REPRA(1, 10), NetworkFlow(100_000), multiperiod_system)
```

Finally, to assess the equivalent firm capacity a new resource added to the system in region 3:

```julia
multiperiod_system_new_resource # The previous system augmented with a new resource
assess(EFC(1000, 0.95, 1, Generic([3], [1.0])),
       LOLE, REPRA(1, 10), NetworkFlow(100_000),
	   multiperiod_system, multiperiod_system_new_resource)
```


## Single Period Reliability Assessment Components

### Simulation Method

Currently supported:

 - Non-chronological copper plate
 - Non-chronological network flow

Chronological simulation should be coming this summer.

## Multi-Period Reliability Assessment Components

Multi-period reliability assessment requires the same components as a single-period reliability assessment, as well as a time series decomposition method.

### Decomposition Method

Currently supported:
 - Deterministic backcasting
 - REPRA windowing

## Capacity Valuation Components

Capacity valuation requires specifying all of the components required for a single- or multi-period reliability assessment, as well as a reliability and capacity value metric to use:

### Capacity Value Metric

Currently supported:
 - EFC
 - ELCC (coming soon)

### Reliability Assessment / Comparison Metric

Currently supported:
 - LOLP (single-period assessment)
 - LOLE (multi-period assessment)
 - EUE
