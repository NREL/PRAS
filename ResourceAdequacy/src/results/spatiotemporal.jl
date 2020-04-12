struct SpatioTemporal <: ResultSpec end

struct SpatioTemporalResult{
    N, # Number of timesteps simulated
    L, # Length of each timestep
    T <: Period, # Units of timestep duration
    E <: EnergyUnit, # Units for energy results
    SS <: SimulationSpec
} <: Result{N,L,T,SS}

    regions::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    lole::LOLE{N,L,T}
    regionloles::Vector{LOLE{N,L,T}}
    periodlolps::Vector{LOLP{L,T}}
    regionalperiodlolps::Matrix{LOLP{L,T}}

    eue::EUE{N,L,T,E}
    regioneues::Vector{EUE{N,L,T,E}}
    periodeues::Vector{EUE{1,L,T,E}}
    regionalperiodeues::Matrix{EUE{1,L,T,E}}

    simulationspec::SS

    function SpatioTemporalResult{}(
        regions::Vector{String}, timestamps::StepRange{ZonedDateTime,T},
        lole::LOLE{N,L,T}, regionloles::Vector{LOLE{N,L,T}},
        periodlolps::Vector{LOLP{L,T}},
        regionalperiodlolps::Matrix{LOLP{L,T}},
        eue::EUE{N,L,T,E}, regioneues::Vector{EUE{N,L,T,E}},
        periodeues::Vector{EUE{1,L,T,E}},
        regionalperiodeues::Matrix{EUE{1,L,T,E}},
        simulationspec::SS) where {N,L,T,E,SS}

        nregions = length(regions)
        ntimesteps = length(timestamps)

        @assert ntimesteps == N

        @assert length(regionloles) == nregions
        @assert length(periodlolps) == ntimesteps
        @assert size(regionalperiodlolps) == (nregions, ntimesteps)

        @assert length(regioneues) == nregions
        @assert length(periodeues) == ntimesteps
        @assert size(regionalperiodeues) == (nregions, ntimesteps)

        new{N,L,T,E,SS}(
            regions, timestamps,
            lole, regionloles, periodlolps, regionalperiodlolps,
            eue, regioneues, periodeues, regionalperiodeues,
            simulationspec)

    end

end

LOLE(x::SpatioTemporalResult) = x.lole
LOLP(x::SpatioTemporalResult, t::ZonedDateTime) =
    x.periodlolps[findfirstunique(x.timestamps, t)]
LOLE(x::SpatioTemporalResult, r::AbstractString) =
    x.regionloles[findfirstunique(x.regions, r)]
LOLP(x::SpatioTemporalResult, r::AbstractString, t::ZonedDateTime) =
    x.regionalperiodlolps[findfirstunique(x.regions, r),
                          findfirstunique(x.timestamps, t)]

EUE(x::SpatioTemporalResult) = x.eue
EUE(x::SpatioTemporalResult, t::ZonedDateTime) =
    x.periodeues[findfirstunique(x.timestamps, t)]
EUE(x::SpatioTemporalResult, r::AbstractString) =
    x.regioneues[findfirstunique(x.regions, r)]
EUE(x::SpatioTemporalResult, r::AbstractString, t::ZonedDateTime)  =
    x.regionalperiodeues[findfirstunique(x.regions, r),
                         findfirstunique(x.timestamps, t)]
