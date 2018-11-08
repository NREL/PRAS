# CapacityValue

To assess the equivalent firm capacity a new resource added
to the system in region 3:

```julia
multiperiod_system_new_resource # The previous system augmented with a new resource
assess(EFC(1000, 0.95, 1, Generic([3], [1.0])),
       LOLE, REPRA(1, 10), NonSequentialNetworkFlow(100_000), MinimalResult(),
	   multiperiod_system, multiperiod_system_new_resource)
```

## Capacity Valuation Components

Capacity valuation requires specifying all of the components required for a single- or multi-period reliability assessment, as well as a reliability and capacity value metric to use:

### Capacity Value Metric

Currently supported:
 - EFC

ELCC coming soon, hopefully.

### Reliability Assessment / Comparison Metric

Currently supported:
 - LOLP (single-period assessment)
 - LOLE (multi-period assessment)
 - EUE
