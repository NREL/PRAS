struct Spatial <: ResultSpec end

struct SpatialResult{
    N, # Number of timesteps simulated
    L, # Length of each timestep
    T <: Period, # Units of timestep duration
    E <: EnergyUnit, # Units for energy results
    SS <: SimulationSpec
} <: Result{N,L,T,SS}

    regions::Vector{String}
    lole::LOLE{N,L,T}
    loles::Vector{LOLE{N,L,T}}
    eue::EUE{N,L,T,E}
    eues::Vector{EUE{N,L,T,E}}
    simulationspec::SS

    SpatialResult{}(
        regions::Vector{String},
        lole::LOLE{N,L,T}, loles::Vector{LOLE{N,L,T}},
        eue::EUE{N,L,T,E}, eues::Vector{EUE{N,L,T,E}},
        simulationspec::SS) where {N,L,T,E,SS} =
        new{N,L,T,E,SS}(regions, lole, loles, eue, eues, simulationspec)

end

LOLE(x::SpatialResult) = x.lole
LOLE(x::SpatialResult, r::Int) = x.loles[r]
LOLE(x::SpatialResult, r::AbstractString) =
    x.loles[findfirstunique(x.regions, r)]

EUE(x::SpatialResult) = x.eue
EUE(x::SpatialResult, r::Int) = x.eues[r]
EUE(x::SpatialResult, r::AbstractString) =
    x.eues[findfirstunique(x.regions, r)]

include("spatial_nonsequentialaccumulator.jl")
include("spatial_sequentialaccumulator.jl")
