struct Debug <: ResultSpec end

struct DebugResult{
    N, # Number of timesteps simulated
    L, # Length of each timestep
    T <: Period, # Units of timestep duration
    P <: PowerUnit, # Units for power results
    E <: EnergyUnit, # Units for energy results
    SS <: SimulationSpec
} <: Result{N,L,T,SS}

    regions::Vector{String}
    interfaces::Vector{Tuple{Int,Int}}
    timestamps::StepRange{ZonedDateTime,T}

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

    gens_available::Array{Bool,3}
    lines_available::Array{Bool,3}
    stors_available::Array{Bool,3}
    genstors_available::Array{Bool,3}

    sample_ues::Vector{Float64}

    simulationspec::SS

    function DebugResult{}(
        regions::Vector{String}, interfaces::Vector{Tuple{Int,Int}},
        timestamps::StepRange{ZonedDateTime,T},
        lole::LOLE{N,L,T}, regionloles::Vector{LOLE{N,L,T}},
        periodlolps::Vector{LOLP{L,T}},
        regionalperiodlolps::Matrix{LOLP{L,T}},
        eue::EUE{N,L,T,E}, regioneues::Vector{EUE{N,L,T,E}},
        periodeues::Vector{EUE{1,L,T,E}},
        regionalperiodeues::Matrix{EUE{1,L,T,E}},
        flows::Matrix{ExpectedInterfaceFlow{1,L,T,P}},
        utilizations::Matrix{ExpectedInterfaceUtilization{1,L,T}},
        gens_available::Array{Bool,3}, lines_available::Array{Bool,3},
        stors_available::Array{Bool,3}, genstors_available::Array{Bool,3},
        sample_ues::Vector{Float64}, simulationspec::SS
) where {N,L,T,P,E,SS}

        nregions = length(regions)
        ninterfaces = length(interfaces)
        ntimesteps = length(timestamps)
        nsamples = simulationspec.nsamples

        @assert ntimesteps == N

        @assert length(regionloles) == nregions
        @assert length(periodlolps) == ntimesteps
        @assert size(regionalperiodlolps) == (nregions, ntimesteps)

        @assert length(regioneues) == nregions
        @assert length(periodeues) == ntimesteps
        @assert size(regionalperiodeues) == (nregions, ntimesteps)

        @assert size(flows) == (ninterfaces, ntimesteps)
        @assert size(utilizations) == (ninterfaces, ntimesteps)

        @assert size(gens_available, 3) == nsamples
        @assert size(gens_available, 2) == ntimesteps
        @assert size(lines_available, 3) == nsamples
        @assert size(lines_available, 2) == ntimesteps
        @assert size(stors_available, 3) == nsamples
        @assert size(stors_available, 2) == ntimesteps
        @assert size(genstors_available, 3) == nsamples
        @assert size(genstors_available, 2) == ntimesteps

        @assert length(sample_ues) == nsamples

        new{N,L,T,P,E,SS}(
            regions, interfaces, timestamps,
            lole, regionloles, periodlolps, regionalperiodlolps,
            eue, regioneues, periodeues, regionalperiodeues,
            flows, utilizations, gens_available, lines_available,
            stors_available, genstors_available,
            sample_ues, simulationspec)

    end

end

LOLE(x::DebugResult) = x.lole
LOLP(x::DebugResult, t::ZonedDateTime) =
    x.periodlolps[findfirstunique(x.timestamps, t)]
LOLE(x::DebugResult, r::AbstractString) =
    x.regionloles[findfirstunique(x.regions, r)]
LOLP(x::DebugResult, r::AbstractString, t::ZonedDateTime) =
    x.regionalperiodlolps[findfirstunique(x.regions, r),
                          findfirstunique(x.timestamps, t)]

EUE(x::DebugResult) = x.eue
EUE(x::DebugResult, t::ZonedDateTime) =
    x.periodeues[findfirstunique(x.timestamps, t)]
EUE(x::DebugResult, r::AbstractString) =
    x.regioneues[findfirstunique(x.regions, r)]
EUE(x::DebugResult, r::AbstractString, t::ZonedDateTime)  =
    x.regionalperiodeues[findfirstunique(x.regions, r),
                         findfirstunique(x.timestamps, t)]

function ExpectedInterfaceFlow(
    x::DebugResult,
    r1::AbstractString,
    r2::AbstractString,
    t::ZonedDateTime
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

function ExpectedInterfaceFlow(x::DebugResult, i::Tuple{Int,Int}, t::ZonedDateTime)
    i_idx = findfirstunique(x.interfaces, i)
    t_idx = findfirstunique(x.timestamps, t)
    return x.flows[i_idx, t_idx]
end

function ExpectedInterfaceUtilization(
    x::DebugResult,
    r1::AbstractString,
    r2::AbstractString,
    t::ZonedDateTime
)
    r1_idx = findfirstunique(x.regions, r1)
    r2_idx = findfirstunique(x.regions, r2)
    return ExpectedInterfaceUtilization(x, minmax(r1_idx, r2_idx), t)
end

function ExpectedInterfaceUtilization(x::DebugResult, i::Tuple{Int,Int}, t::ZonedDateTime)
    i_idx = findfirstunique(x.interfaces, i)
    t_idx = findfirstunique(x.timestamps, t)
    return x.utilizations[i_idx, t_idx]
end
