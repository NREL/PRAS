struct Minimal <: ResultSpec end

struct MinimalResult{
    N, # Number of timesteps simulated
    L, # Length of each timestep
    T <: Period, # Units of timestep duration
    E <: EnergyUnit, # Units for energy results
    V <: Real, # Numerical type of value data
    SS <: SimulationSpec
} <: Result{N,L,T,V,SS}

    lole::LOLE{N,L,T,V}
    eue::EUE{N,L,T,E,V}
    simulationspec::SS

    MinimalResult{}(
        lole::LOLE{N,L,T,V}, eue::EUE{N,L,T,E,V},
        simulationspec::SS) where {N,L,T,E,V,SS} =
        new{N,L,T,E,V,SS}(lole, eue, simulationspec)

end

LOLE(x::MinimalResult) = x.lole
EUE(x::MinimalResult) = x.eue

include("minimal_nonsequentialaccumulator.jl")
include("minimal_sequentialaccumulator.jl")
