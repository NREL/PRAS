struct Network <: ResultSpec end

struct NetworkResult{
    N, # Number of timesteps simulated
    L, # Length of each timestep
    T <: Period, # Units of timestep duration
    E <: EnergyUnit, # Units for energy results
    P <: PowerUnit, # Units for power results
    V <: Real, # Numerical type of value data
    ES <: ExtractionSpec,
    SS <: SimulationSpec
} <: Result{N,L,T,V,ES,SS}

    regions::Vector{String}
    interfaces::Vector{Tuple{Int,Int}}
    timestamps::StepRange{DateTime,T}

    lole::LOLE{N,L,T,V}
    regionloles::Vector{LOLE{N,L,T,V}}
    periodlolps::Vector{LOLP{L,T,V}}
    regionalperiodlolps::Matrix{LOLP{L,T,V}}

    eue::EUE{N,L,T,E,V}
    regioneues::Vector{EUE{N,L,T,E,V}}
    periodeues::Vector{EUE{1,L,T,E,V}}
    regionalperiodeues::Matrix{EUE{1,L,T,E,V}}

    flows::Matrix{ExpectedInterfaceFlow{1,L,T,P,V}}
    utilizations::Matrix{ExpectedInterfaceUtilization{1,L,T,V}}

    extractionspec::ES
    simulationspec::SS

    function NetworkResult{}(
        regions::Vector{String}, interfaces::Vector{Tuple{Int,Int}},
        timestamps::StepRange{DateTime,T},
        lole::LOLE{N,L,T,V}, regionloles::Vector{LOLE{N,L,T,V}},
        periodlolps::Vector{LOLP{L,T,V}},
        regionalperiodlolps::Matrix{LOLP{L,T,V}},
        eue::EUE{N,L,T,E,V}, regioneues::Vector{EUE{N,L,T,E,V}},
        periodeues::Vector{EUE{1,L,T,E,V}},
        regionalperiodeues::Matrix{EUE{1,L,T,E,V}},
        flows::Matrix{ExpectedInterfaceFlow{1,L,T,P,V}},
        utilizations::Matrix{ExpectedInterfaceUtilization{1,L,T,V}},
        extractionspec::ES, simulationspec::SS) where {N,L,T,E,P,V,ES,SS}

        nregions = length(regions)
        ninterfaces = length(interfaces)
        ntimesteps = length(timestamps)

        @assert ntimesteps == N

        @assert length(regionloles) == nregions
        @assert length(periodlolps) == ntimesteps
        @assert size(regionalperiodlolps) == (nregions, ntimesteps)

        @assert length(regioneues) == nregions
        @assert length(periodeues) == ntimesteps
        @assert size(regionalperiodeues) == (nregions, ntimesteps)

        @assert size(flows) == (ninterfaces, ntimesteps)
        @assert size(utilizations) == (ninterfaces, ntimesteps)

        new{N,L,T,E,P,V,ES,SS}(
            regions, timestamps,
            lole, regionloles, periodlolps, regionalperiodlolps,
            eue, regioneues, periodeues, regionalperiodeues, flows,
            extractionspec, simulationspec)

    end

end

LOLE(x::NetworkResult) = x.lole
LOLP(x::NetworkResult, t::DateTime) =
    x.periodlolps[findfirstunique(x.timestamps, t)]
LOLE(x::NetworkResult, r::AbstractString) =
    x.regionloles[findfirstunique(x.regions, r)]
LOLP(x::NetworkResult, r::AbstractString, t::DateTime) =
    x.regionalperiodlolps[findfirstunique(x.regions, r),
                          findfirstunique(x.timestamps, t)]

EUE(x::NetworkResult) = x.eue
EUE(x::NetworkResult, t::DateTime) =
    x.periodeues[findfirstunique(x.timestamps, t)]
EUE(x::NetworkResult, r::AbstractString) =
    x.regioneues[findfirstunique(x.regions, r)]
EUE(x::NetworkResult, r::AbstractString, t::DateTime)  =
    x.regionalperiodeues[findfirstunique(x.regions, r),
                         findfirstunique(x.timestamps, t)]

function ExpectedInterfaceFlow(
    x::NetworkResult,
    r1::AbstractString,
    r2::AbstractString,
    t::DateTime
)
    r1_idx = findfirstunique(x.regions, r1)
    r2_idx = findfirstunique(x.regions, r2)
    return ExpectedInterfaceFlow(x, (r1_idx, r2_idx), t_idx)
end

function ExpectedInterfaceFlow(x::NetworkResult, i::Tuple{Int,Int}, t::DateTime)
    i_idx = findfirstunique(x.interfaces, i)
    t_idx = findfirstunique(x.timestamps, t) 
    return x.flows[i_idx, t_idx]
end

function ExpectedInterfaceUtilization(
    x::NetworkResult,
    r1::AbstractString,
    r2::AbstractString,
    t::DateTime
)
    r1_idx = findfirstunique(x.regions, r1)
    r2_idx = findfirstunique(x.regions, r2)
    return ExpectedInterfaceUtilization(x, (r1_idx, r2_idx), t_idx)
end

function ExpectedInterfaceUtilization(x::NetworkResult, i::Tuple{Int,Int}, t::DateTime)
    i_idx = findfirstunique(x.interfaces, i)
    t_idx = findfirstunique(x.timestamps, t) 
    return x.utilizations[i_idx, t_idx]
end

include("network_nonsequentialaccumulator.jl")
include("network_sequentialaccumulator.jl")
