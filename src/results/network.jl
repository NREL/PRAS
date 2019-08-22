struct Network <: ResultSpec end

struct NetworkResult{
    N, # Number of timesteps simulated
    L, # Length of each timestep
    T <: Period, # Units of timestep duration
    P <: PowerUnit, # Units for power results
    E <: EnergyUnit, # Units for energy results
    SS <: SimulationSpec
} <: Result{N,L,T,SS}

    regions::Vector{String}
    interfaces::Vector{Tuple{Int,Int}}
    timestamps::StepRange{DateTime,T}

    lole::LOLE{N,L,T}
    regionloles::Vector{LOLE{N,L,T}}
    periodlolps::Vector{LOLP{L,T}}
    regionalperiodlolps::Matrix{LOLP{L,T}}

    eue::EUE{N,L,T,E}
    regioneues::Vector{EUE{N,L,T,E}}
    periodeues::Vector{EUE{1,L,T,E}}
    regionalperiodeues::Matrix{EUE{1,L,T,E}}

    flows::Matrix{ExpectedInterfaceFlow{1,L,T,P}}
    utilizations::Matrix{ExpectedInterfaceUtilization{1,L,T}}

    simulationspec::SS

    function NetworkResult{}(
        regions::Vector{String}, interfaces::Vector{Tuple{Int,Int}},
        timestamps::StepRange{DateTime,T},
        lole::LOLE{N,L,T}, regionloles::Vector{LOLE{N,L,T}},
        periodlolps::Vector{LOLP{L,T}},
        regionalperiodlolps::Matrix{LOLP{L,T}},
        eue::EUE{N,L,T,E}, regioneues::Vector{EUE{N,L,T,E}},
        periodeues::Vector{EUE{1,L,T,E}},
        regionalperiodeues::Matrix{EUE{1,L,T,E}},
        flows::Matrix{ExpectedInterfaceFlow{1,L,T,P}},
        utilizations::Matrix{ExpectedInterfaceUtilization{1,L,T}},
        simulationspec::SS) where {N,L,T,P,E,SS}

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

        new{N,L,T,P,E,SS}(
            regions, interfaces, timestamps,
            lole, regionloles, periodlolps, regionalperiodlolps,
            eue, regioneues, periodeues, regionalperiodeues,
            flows, utilizations, simulationspec)

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

    if r1_idx < r2_idx
        flow = ExpectedInterfaceFlow(x, (r1_idx, r2_idx), t)
    else
        flow = -ExpectedInterfaceFlow(x, (r2_idx, r1_idx), t)
    end

    return flow

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
    return ExpectedInterfaceUtilization(x, minmax(r1_idx, r2_idx), t)
end

function ExpectedInterfaceUtilization(x::NetworkResult, i::Tuple{Int,Int}, t::DateTime)
    i_idx = findfirstunique(x.interfaces, i)
    t_idx = findfirstunique(x.timestamps, t) 
    return x.utilizations[i_idx, t_idx]
end

include("network_nonsequentialaccumulator.jl")
include("network_sequentialaccumulator.jl")
