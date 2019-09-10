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
 
 ### Descripton of arguments 
 
assess(EFC(UB,CI,MW range,DisreteNonParametric([list A],[list b])), EUE or LOLE, Backcast(),NonSequentialNetworkFlow(1000),Minimal(),original system,new system)

UB = the upper bound on the capacity value, often the nameplate capacity of the new unit

CI = the first of two conditions that stop the iterative calculation. Sets the confidence interval. If the reliability metrics (EUE or LOLE) calculated for both the upper and lower firm capacity bound are statistically identical within the confidence interval, the calculation stops.

MW range = the second of two conditions that stop the iterative calculation. Sets an absolute MW difference. If the reliability metrics calculated for both the upper and lower firm capacity bound are within this difference, the calculation stops.

list A = the list of regions in which the calculation places equivalent firm capacity

list B = the proportion of firm capacity the calculation places in each region. Must add up to 1.
