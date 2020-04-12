struct Temporal <: ResultSpec end

struct TemporalResult{
    N, # Number of timesteps simulated
    L, # Length of each timestep
    T <: Period, # Units of timestep duration
    E <: EnergyUnit, # Units for energy results
    SS <: SimulationSpec
} <: Result{N,L,T,SS}

    timestamps::StepRange{ZonedDateTime,T}
    lole::LOLE{N,L,T}
    lolps::Vector{LOLP{L,T}}
    eue::EUE{N,L,T,E}
    eues::Vector{EUE{1,L,T,E}}
    simulationspec::SS

    TemporalResult{}(
        timestamps::StepRange{ZonedDateTime,T},
        lole::LOLE{N,L,T}, lolps::Vector{LOLP{L,T}},
        eue::EUE{N,L,T,E}, eues::Vector{EUE{1,L,T,E}},
        simulationspec::SS) where {N,L,T,E,SS} =
        new{N,L,T,E,SS}(timestamps, lole, lolps, eue, eues, simulationspec)

end

LOLE(x::TemporalResult) = x.lole
LOLP(x::TemporalResult, t::Int) = x.lolps[t]
LOLP(x::TemporalResult, dt::DateTime) =
    x.lolps[findfirstunique(x.timestamps, dt)]

EUE(x::TemporalResult) = x.eue
EUE(x::TemporalResult, t::Int) = x.eues[t]
EUE(x::TemporalResult, dt::DateTime) =
    x.eues[findfirstunique(x.timestamps, dt)]
