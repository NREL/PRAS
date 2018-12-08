struct Minimal <: ResultSpec end

struct MinimalResult{
    N, # Number of timesteps simulated
    L, # Length of each timestep
    T <: Period, # Units of timestep duration
    E <: EnergyUnit, # Units for energy results
    V <: Real, # Numerical type of value data
    ES <: ExtractionSpec,
    SS <: SimulationSpec
} <: Result{N,L,T,V,ES,SS}

    lole::LOLE{N,L,T,V}
    eue::EUE{N,L,T,E,V}
    extractionspec::ES
    simulationspec::SS

    MinimalResult{}(
        lole::LOLE{N,L,T,V}, eue::EUE{N,L,T,E,V},
        extractionspec::ES, simulationspec::SS) where {N,L,T,E,V,ES,SS} =
        new{N,L,T,E,V,ES,SS}(lole, eue, extractionspec, simulationspec)

end

LOLE(x::MinimalResult) = x.lole
EUE(x::MinimalResult) = x.eue

include("minimal_nonsequentialaccumulator.jl")
include("minimal_sequentialaccumulator.jl")
