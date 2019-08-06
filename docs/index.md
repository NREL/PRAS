The Probabilistic Resource Adequacy Suite (PRAS) provides an open-source,
research-oriented collection of tools for analysing the resource adequacy of a
bulk power system. The simulation methods offered support everything from
classical convolution-based analytical techniques through to high-performance
sequential Monte Carlo methods supporting multi-region composite reliability
assessment, including simulation of energy-limited resources such as storage.

PRAS is developed and maintained at the US
[National Renewable Energy Laboratory](https://www.nrel.gov/) (NREL).

For help installing PRAS, see the [Installation](./installation) page. To get started using PRAS,
see the [Getting Started](./getting-started) page.

The functionality of PRAS is spread across multiple Julia packages.
Those packages include:

 - [PRASBase.jl](https://github.com/NREL/PRASBase.jl): Core data
   structures for holding power system information
 - [ResourceAdequacy.jl](https://github.com/NREL/ResourceAdequacy.jl):
   Calculates probabilistic resource adequacy metrics
 - [CapacityCredit.jl](https://github.com/NREL/CapacityCredit.jl):
   Computes the capacity credit of resources based on
   probabilistic risk metrics

The individual packages may provide additional documentation beyond that
available on this site.
