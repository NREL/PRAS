struct Minimal <: ResultSpec end

struct MinimalResult{
    N, # Number of timesteps simulated
    L, # Length of each timestep
    T <: Period, # Units of timestep duration
    E <: EnergyUnit, # Units for energy results
    SS <: SimulationSpec
} <: Result{N,L,T,SS}

    lole::LOLE{N,L,T}
    eue::EUE{N,L,T,E}
    simulationspec::SS

    MinimalResult{}(
        lole::LOLE{N,L,T}, eue::EUE{N,L,T,E},
        simulationspec::SS) where {N,L,T,E,SS} =
        new{N,L,T,E,SS}(lole, eue, simulationspec)

end

LOLE(x::MinimalResult) = x.lole
EUE(x::MinimalResult) = x.eue
