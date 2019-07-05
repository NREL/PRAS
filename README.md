# CapacityCredit

To assess the equivalent firm capacity a new resource added
to the system in region 3:

```julia
using ResourceAdequacy, CapacityCredit, Distributions
system # The base system
system_new_resource # The base system augmented with a new variable resource
assess(EFC(1000, 0.95, 1, DiscreteNonParametric([3], [1.0])),
       EUE, Backcast(), NonSequentialNetworkFlow(100_000), Minimal(),
       system, system_new_resource)
```

## Capacity Valuation Components

Capacity valuation requires specifying all of the components required for a single- or multi-period reliability assessment, as well as a reliability and capacity value metric to use:

### Capacity Credit Metric

Currently supported:
 - EFC

ELCC coming soon, hopefully.

### Reliability Assessment / Comparison Metric

Currently supported:
 - LOLE
 - EUE
