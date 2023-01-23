# Shortfall

mutable struct SMCShortfallAccumulator <: ResultAccumulator{SequentialMonteCarlo,Shortfall}

    spec::Shortfall
    regionmapping::Vector{Int}
    periodmapping::Vector{Int}

    # Cross-simulation LOL period count mean/variances
    periodsdropped_total::MeanVariance
    periodsdropped_region::Vector{MeanVariance}
    periodsdropped_period::Vector{MeanVariance}
    periodsdropped_regionperiod::Matrix{MeanVariance}

    # Running LOL period counts for current simulation/timestep
    periodsdropped_total_currentsim::Int
    periodsdropped_region_currentsim::Vector{Int}
    dropped_region_currentperiod::Vector{Bool}

    # Cross-simulation UE mean/variances
    unservedload_total::MeanVariance
    unservedload_region::Vector{MeanVariance}
    unservedload_period::Vector{MeanVariance}
    unservedload_regionperiod::Matrix{MeanVariance}

    # Running UE totals for current simulation/timestep
    unservedload_total_currentsim::Int
    unservedload_region_currentsim::Vector{Int}
    unservedload_region_currentperiod::Vector{Int}

end

function merge!(
    x::SMCShortfallAccumulator, y::SMCShortfallAccumulator
)

    merge!(x.periodsdropped_total, y.periodsdropped_total)
    foreach(merge!, x.periodsdropped_region, y.periodsdropped_region)
    foreach(merge!, x.periodsdropped_period, y.periodsdropped_period)
    foreach(merge!, x.periodsdropped_regionperiod, y.periodsdropped_regionperiod)

    merge!(x.unservedload_total, y.unservedload_total)
    foreach(merge!, x.unservedload_region, y.unservedload_region)
    foreach(merge!, x.unservedload_period, y.unservedload_period)
    foreach(merge!, x.unservedload_regionperiod, y.unservedload_regionperiod)

    return

end

accumulatortype(::SequentialMonteCarlo, ::Shortfall) = SMCShortfallAccumulator

function accumulator(sys::SystemModel, ::SequentialMonteCarlo, sf::Shortfall)

    regionmapping = makemapping(sf.regionmap, sys.regions.names)
    nregions = maximum(regionmapping)

    periodmapping = makemapping(sf.periodmap, sys.timestamps)
    nperiods = maximum(periodmapping)

    periodsdropped_total = meanvariance()
    periodsdropped_region = [meanvariance() for _ in 1:nregions]
    periodsdropped_period = [meanvariance() for _ in 1:nperiods]
    periodsdropped_regionperiod =
        [meanvariance() for _ in 1:nregions, _ in 1:nperiods]

    periodsdropped_total_currentsim = 0
    periodsdropped_region_currentsim = zeros(Int, nregions)
    dropped_region_currentperiod = zeros(Bool, nregions)

    unservedload_total = meanvariance()
    unservedload_region = [meanvariance() for _ in 1:nregions]
    unservedload_period = [meanvariance() for _ in 1:nperiods]
    unservedload_regionperiod =
        [meanvariance() for _ in 1:nregions, _ in 1:nperiods]

    unservedload_total_currentsim = 0
    unservedload_region_currentsim = zeros(Int, nregions)
    unservedload_region_currentperiod = zeros(Int, nregions)

    return SMCShortfallAccumulator(
        sf, regionmapping, periodmapping,
        periodsdropped_total, periodsdropped_region,
        periodsdropped_period, periodsdropped_regionperiod,
        periodsdropped_total_currentsim, periodsdropped_region_currentsim,
        dropped_region_currentperiod,
        unservedload_total, unservedload_region,
        unservedload_period, unservedload_regionperiod,
        unservedload_total_currentsim, unservedload_region_currentsim,
        unservedload_region_currentperiod)

end

function record!(
    acc::SMCShortfallAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t_base::Int
) where {N,L,T,P,E}

    t = acc.periodmapping[t_base]

    totalshortfall = 0
    isshortfall = false

    edges = problem.fp.edges

    fill!(acc.dropped_region_currentperiod, false)
    fill!(acc.unservedload_region_currentperiod, 0)

    for r_base in problem.region_unserved_edges

        regionshortfall = edges[r_base].flow
        isregionshortfall = regionshortfall > 0

        r = acc.regionmapping[r_base]

        if isregionshortfall

            isshortfall = true
            totalshortfall += regionshortfall

            acc.dropped_region_currentperiod[r] |= true
            acc.unservedload_region_currentperiod[r] += regionshortfall

        end

    end

    acc.periodsdropped_region_currentsim .+=
        acc.dropped_region_currentperiod

    acc.unservedload_region_currentsim .+=
        acc.unservedload_region_currentperiod

    for r in eachindex(acc.dropped_region_currentperiod)
        fit!(acc.periodsdropped_regionperiod[r,t],
             acc.dropped_region_currentperiod[r])
        fit!(acc.unservedload_regionperiod[r,t],
             acc.unservedload_region_currentperiod[r])
    end

    fit!(acc.periodsdropped_period[t], isshortfall)
    fit!(acc.unservedload_period[t], totalshortfall)

    if isshortfall
        acc.periodsdropped_total_currentsim += 1
        acc.unservedload_total_currentsim += totalshortfall
    end

    return

end

function reset!(acc::SMCShortfallAccumulator, sampleid::Int)

    # Store regional / total sums for current simulation
    fit!(acc.periodsdropped_total, acc.periodsdropped_total_currentsim)
    fit!(acc.unservedload_total, acc.unservedload_total_currentsim)

    for r in eachindex(acc.periodsdropped_region)
        fit!(acc.periodsdropped_region[r], acc.periodsdropped_region_currentsim[r])
        fit!(acc.unservedload_region[r], acc.unservedload_region_currentsim[r])
    end

    # Reset for new simulation
    acc.periodsdropped_total_currentsim = 0
    fill!(acc.periodsdropped_region_currentsim, 0)
    acc.unservedload_total_currentsim = 0
    fill!(acc.unservedload_region_currentsim, 0)

    return

end

function finalize(
    acc::SMCShortfallAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    ep_total_mean, ep_total_std = mean_std(acc.periodsdropped_total)
    ep_region_mean, ep_region_std = mean_std(acc.periodsdropped_region)
    ep_period_mean, ep_period_std = mean_std(acc.periodsdropped_period)
    ep_regionperiod_mean, ep_regionperiod_std =
        mean_std(acc.periodsdropped_regionperiod)

    _, ue_total_std = mean_std(acc.unservedload_total)
    _, ue_region_std = mean_std(acc.unservedload_region)
    _, ue_period_std = mean_std(acc.unservedload_period)
    ue_regionperiod_mean, ue_regionperiod_std =
        mean_std(acc.unservedload_regionperiod)

    nsamples = first(acc.unservedload_total.stats).n
    p2e = conversionfactor(L,T,P,E)

    mapped_names = unique(acc.spec.regionmap.(system.regions.names))

    return ShortfallResult{N,L,T,E}(
        nsamples, mapped_names, system.timestamps,
        ep_total_mean, ep_total_std, ep_region_mean, ep_region_std,
        ep_period_mean, ep_period_std,
        ep_regionperiod_mean, ep_regionperiod_std,
        p2e*ue_regionperiod_mean, p2e*ue_total_std,
        p2e*ue_region_std, p2e*ue_period_std, p2e*ue_regionperiod_std)

end

# ShortfallSamples

struct SMCShortfallSamplesAccumulator <:
    ResultAccumulator{SequentialMonteCarlo,ShortfallSamples}

    shortfall::Array{Int,3}

end

function merge!(
    x::SMCShortfallSamplesAccumulator, y::SMCShortfallSamplesAccumulator
)

    x.shortfall .+= y.shortfall
    return

end

accumulatortype(::SequentialMonteCarlo, ::ShortfallSamples) = SMCShortfallSamplesAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::SequentialMonteCarlo, ::ShortfallSamples
) where {N}

    nregions = length(sys.regions)
    shortfall = zeros(Int, nregions, N, simspec.nsamples)

    return SMCShortfallSamplesAccumulator(shortfall)

end

function record!(
    acc::SMCShortfallSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    for (r, e) in enumerate(problem.region_unserved_edges)
        acc.shortfall[r, t, sampleid] = problem.fp.edges[e].flow
    end

    return

end

reset!(acc::SMCShortfallSamplesAccumulator, sampleid::Int) = nothing

function finalize(
    acc::SMCShortfallSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return ShortfallSamplesResult{N,L,T,P,E}(
        system.regions.names, system.timestamps, acc.shortfall)

end
