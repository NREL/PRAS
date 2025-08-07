# Basic PRAS Structure and Usage

As illustrated in Figure 1, PRAS maps a provided representation of a power system to a probabilistic description of operational outcomes of interest, using a particular choice of operations simulation. The input system representation is called a "system model", the choice of operational representation is referred to as a "simulation specification", and different types of operating outcomes of interest are described by "result specifications".

![PRAS model structure and corresponding assessment function arguments](../images/inputoutput.pdf)

*Figure 1: PRAS model structure and corresponding assessment function arguments*

PRAS is written in the Julia programming language, and is controlled through the use of Julia scripts. The three components of a PRAS resource adequacy assessment (a system model, a simulation specification, and result specifications) map directly to the Julia function arguments required to launch a PRAS run. A typical resource adequacy assessment with PRAS involves creating or loading a system model, then invoking PRAS' `assess` function to perform the analysis: 

```julia
using PRAS

sys = SystemModel("filepath/to/mysystem.pras")

shortfallresult, flowresult =
    assess(sys, SequentialMonteCarlo(), Shortfall(), Flow())

eue, lole = EUE(shortfallresult), LOLE(shortfallresult)
```

More details on running PRAS via Julia code will be provided throughout the remainder of this report. In particular, the [Inputs](inputs.md) section will detail the information contained in a system model input, the [Simulations](simulations.md) section will explain the built-in simulation specification options in PRAS and the various modelling assumptions associated with each, and the [Results](results.md) section will outline PRAS' available result specifications. The [Capacity Credit](capacity-credit.md) section will cover how PRAS can calculate the capacity credit of specific resources based on the results of resource adequacy assessments, and the [Extending](extending.md) section will provide information on extending PRAS beyond its built-in capabilities. 