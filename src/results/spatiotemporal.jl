struct SpatioTemporal <: ResultSpec end

struct SpatioTemporalResult{
    N, # Number of timesteps simulated
    L, # Length of each timestep
    T <: Period, # Units of timestep duration
    E <: EnergyUnit, # Units for energy results
    V <: Real, # Numerical type of value data
    ES <: ExtractionSpec,
    SS <: SimulationSpec
} <: Result{N,L,T,V,ES,SS}

    regions::Vector{String}
    timestamps::StepRange{DateTime,T}

    lole::LOLE{N,L,T,V}
    regionloles::Vector{LOLE{N,L,T,V}}
    periodlolps::Vector{LOLP{L,T,V}}
    regionalperiodlolps::Matrix{LOLP{L,T,V}}

    eue::EUE{N,L,T,E,V}
    regioneues::Vector{EUE{N,L,T,E,V}}
    periodeues::Vector{EUE{1,L,T,E,V}}
    regionalperiodeues::Matrix{EUE{1,L,T,E,V}}

    extractionspec::ES
    simulationspec::SS

    function SpatioTemporalResult{}(
        regions::Vector{String}, timestamps::StepRange{DateTime,T},
        lole::LOLE{N,L,T,V}, regionloles::Vector{LOLE{N,L,T,V}},
        periodlolps::Vector{LOLP{L,T,V}},
        regionalperiodlolps::Matrix{LOLP{L,T,V}},
        eue::EUE{N,L,T,E,V}, regioneues::Vector{EUE{N,L,T,E,V}},
        periodeues::Vector{EUE{1,L,T,E,V}},
        regionalperiodeues::Matrix{EUE{1,L,T,E,V}},
        extractionspec::ES, simulationspec::SS) where {N,L,T,E,V,ES,SS}

        nregions = length(regions)
        ntimesteps = length(timestamps)

        @assert ntimesteps == N

        @assert length(regionloles) == nregions
        @assert length(periodlolps) == ntimesteps
        @assert size(regionalperiodlolps) == (nregions, ntimesteps)

        @assert length(regioneues) == nregions
        @assert length(periodeues) == ntimesteps
        @assert size(regionalperiodeues) == (nregions, ntimesteps)

        new{N,L,T,E,V,ES,SS}(
            regions, timestamps,
            lole, regionloles, periodlolps, regionalperiodlolps,
            eue, regioneues, periodeues, regionalperiodeues,
            extractionspec, simulationspec)

    end

end

LOLE(x::SpatioTemporalResult) = x.lole
LOLP(x::SpatioTemporalResult, t::DateTime) =
    x.periodlolps[findfirstunique(x.timestamps, t)]
LOLE(x::SpatioTemporalResult, r::AbstractString) =
    x.regionloles[findfirstunique(x.regions, r)]
LOLP(x::SpatioTemporalResult, r::AbstractString, t::DateTime) =
    x.regionalperiodlolps[findfirstunique(x.regions, r),
                          findfirstunique(x.timestamps, t)]

EUE(x::SpatioTemporalResult) = x.eue
EUE(x::SpatioTemporalResult, t::DateTime) =
    x.periodeues[findfirstunique(x.timestamps, t)]
EUE(x::SpatioTemporalResult, r::AbstractString) =
    x.regioneues[findfirstunique(x.regions, r)]
EUE(x::SpatioTemporalResult, r::AbstractString, t::DateTime)  =
    x.regionalperiodeues[findfirstunique(x.regions, r),
                         findfirstunique(x.timestamps, t)]

include("spatiotemporal_nonsequentialaccumulator.jl")
include("spatiotemporal_sequentialaccumulator.jl")
