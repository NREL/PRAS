# PRAS

The Probabilistic Resource Adequacy Suite (PRAS) provides an open-source, research-oriented collection of tools for analysing the [resource adequacy](@ref resourceadequacy) of a
bulk power system.  It allows the user to simulate power system operations under a wide range of operating conditions in order to study the risk of failing to meet demand (due to a lack of supply or deliverability), and identify the time periods and regions in which that risk occurs. It offers high-performance sequential Monte Carlo methods supporting multi-region composite reliability assessment, including simulation of energy-limited resources such as storage.

PRAS is developed and maintained at the US
[National Renewable Energy Laboratory](https://www.nrel.gov/) (NREL).

To get started on using PRAS, see the [installation](@ref Installation) and [quick start](@ref quickstart) pages.

## Basic usage

PRAS maps a provided representation of a power system to a probabilistic description of operational outcomes of interest, using a particular choice of operations simulation. The input system representation is called a "system model", the choice of operational representation is referred to as a "simulation specification", and different types of operating outcomes of interest are described by "result specifications".

```@raw html
<figure>
<img src="images/inputoutput.pdf" alt="PRAS model structure and corresponding assessment function arguments" style="max-width:2000px;  width:100%;"/>
<figcaption> PRAS model structure and corresponding assessment function arguments </figcaption>
</figure>
```

PRAS is written in the Julia programming language, and is controlled through the use of Julia scripts. The three components of a PRAS resource adequacy assessment (a system model, a simulation specification, and result specifications) map directly to the Julia function arguments required to launch a PRAS run. A typical resource adequacy assessment with PRAS involves creating or loading a system model, then invoking PRAS' `assess` function to perform the analysis: 

```julia
using PRAS

sys = SystemModel("filepath/to/mysystem.pras")

shortfallresult, flowresult =
    assess(sys, SequentialMonteCarlo(), Shortfall(), Flow())

eue, lole = EUE(shortfallresult), LOLE(shortfallresult)
```

More details on running PRAS via Julia code are available in this documentaion. The [System Model Specification](@ref system_specification) page details the information contained in a system model input, the [Simulations Specifications](@ref simulations) page explains the built-in simulation specification options in PRAS and the various modelling assumptions associated with each, and the [Results Specification](@ref results) page will outline PRAS' available result specifications. The [Capacity Credit](@ref capacitycredit) page covers how PRAS can calculate the capacity credit of specific resources based on the results of resource adequacy assessments, and the [Extending](@ref extending) page provides information on extending PRAS beyond its built-in capabilities. 
