struct Temporal <: ResultSpec end

struct TemporalResult{
    N, # Number of timesteps simulated
    L, # Length of each timestep
    T <: Period, # Units of timestep duration
    E <: EnergyUnit, # Units for energy results
    V <: Real, # Numerical type of value data
    SS <: SimulationSpec
} <: Result{N,L,T,V,SS}

    timestamps::StepRange{DateTime,T}
    lole::LOLE{N,L,T,V}
    lolps::Vector{LOLP{L,T,V}}
    eue::EUE{N,L,T,E,V}
    eues::Vector{EUE{1,L,T,E,V}}
    simulationspec::SS

    TemporalResult{}(
        timestamps::StepRange{DateTime,T},
        lole::LOLE{N,L,T,V}, lolps::Vector{LOLP{L,T,V}},
        eue::EUE{N,L,T,E,V}, eues::Vector{EUE{1,L,T,E,V}},
        simulationspec::SS) where {N,L,T,E,V,SS} =
        new{N,L,T,E,V,SS}(timestamps, lole, lolps, eue, eues, simulationspec)

end

LOLE(x::TemporalResult) = x.lole
LOLP(x::TemporalResult, t::Int) = x.lolps[t]
LOLP(x::TemporalResult, dt::DateTime) =
    x.lolps[findfirstunique(x.timestamps, dt)]

EUE(x::TemporalResult) = x.eue
EUE(x::TemporalResult, t::Int) = x.eues[t]
EUE(x::TemporalResult, dt::DateTime) =
    x.eues[findfirstunique(x.timestamps, dt)]

include("temporal_nonsequentialaccumulator.jl")
include("temporal_sequentialaccumulator.jl")
