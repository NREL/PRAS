mutable struct SequentialMonteCarloSpatioTemporalAccumulator{N,L,T,P,E} <:
    ResultAccumulator{SpatioTemporal}

    # Cross-simulation LOL period count mean/variances
    periodsdropped_total::MeanVariance
    periodsdropped_region::Vector{MeanVariance}
    periodsdropped_period::Vector{MeanVariance}
    periodsdropped_region_period::Matrix{MeanVariance}

    # Running LOL period counts for current simulation
    periodsdropped_total_currentsim::Int
    periodsdropped_region_currentsim::Vector{Int}

    # Cross-simulation UE mean/variances
    unservedload_total::MeanVariance
    unservedload_region::Vector{MeanVariance}
    unservedload_period::Vector{MeanVariance}
    unservedload_region_period::Matrix{MeanVariance}

    # Running UE totals for current simulation
    unservedload_total_currentsim::Int
    unservedload_region_currentsim::Vector{Int}

end

accumulatortype(::SequentialMonteCarlo, ::SpatioTemporal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    SequentialMonteCarloSpatioTemporalAccumulator{N,L,T,P,E}

function accumulator(::SequentialMonteCarlo, ::SpatioTemporal, sys::SystemModel{N,L,T,P,E}
) where {N,L,T,P,E}

    nregions = length(sys.regions)

    periodsdropped_total = meanvariance()
    periodsdropped_region = [meanvariance() for _ in 1:nregions]
    periodsdropped_period = [meanvariance() for _ in 1:N]
    periodsdropped_region_period = Matrix{MeanVariance}(undef, nregions, N)

    periodsdropped_total_currentsim = 0
    periodsdropped_region_currentsim = zeros(Int, nregions)

    unservedload_total = meanvariance()
    unservedload_region = [meanvariance() for _ in 1:nregions]
    unservedload_period = [meanvariance() for _ in 1:N]
    unservedload_region_period = Matrix{MeanVariance}(undef, nregions, N)

    unservedload_total_currentsim = 0
    unservedload_region_currentsim = zeros(Int, nregions)

    for r in 1:nregions, t in 1:N
        periodsdropped_region_period[r,t] = meanvariance()
        unservedload_region_period[r,t] = meanvariance()
    end

    return SequentialMonteCarloSpatioTemporalAccumulator{N,L,T,P,E}(
        periodsdropped_total, periodsdropped_region,
        periodsdropped_period, periodsdropped_region_period,
        periodsdropped_total_currentsim, periodsdropped_region_currentsim,
        unservedload_total, unservedload_region,
        unservedload_period, unservedload_region_period,
        unservedload_total_currentsim, unservedload_region_currentsim)

end

function record!(
    acc::SequentialMonteCarloSpatioTemporalAccumulator{N,L,T,P,E},
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    totalshortfall = 0
    isshortfall = false

    edges = problem.fp.edges

    for r in problem.region_unserved_edges

        regionshortfall = edges[r].flow
        isregionshortfall = regionshortfall > 0

        fit!(acc.periodsdropped_region_period[r,t], isregionshortfall)
        fit!(acc.unservedload_region_period[r,t], regionshortfall)

        if isregionshortfall

            isshortfall = true
            totalshortfall += regionshortfall

            acc.periodsdropped_region_currentsim[r] += 1
            acc.unservedload_region_currentsim[r] += regionshortfall

        end

    end

    if isshortfall
        acc.periodsdropped_total_currentsim += 1
        acc.unservedload_total_currentsim += totalshortfall
    end

    fit!(acc.periodsdropped_period[t], isshortfall)
    fit!(acc.unservedload_period[t], totalshortfall)

    return

end

function reset!(acc::SequentialMonteCarloSpatioTemporalAccumulator{N,L,T,P,E}, sampleid::Int
) where {N,L,T,P,E}

    # Store regional / total sums for current simulation
    fit!(acc.periodsdropped_total, acc.periodsdropped_total_currentsim)
    fit!(acc.unservedload_total, acc.unservedload_total_currentsim)

    nregions = length(acc.periodsdropped_region)
    for r in 1:nregions
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
    results::Channel{SequentialMonteCarloSpatioTemporalAccumulator{N,L,T,P,E}},
    simspec::SequentialMonteCarlo,
    system::SystemModel{N,L,T,P,E},
    accsremaining::Int
) where {N,L,T,P,E}

    nregions = length(system.regions)

    periodsdropped_total = meanvariance()
    periodsdropped_period = [meanvariance() for _ in 1:N]
    periodsdropped_region = [meanvariance() for _ in 1:nregions]
    periodsdropped_region_period = Matrix{MeanVariance}(undef, nregions, N)

    unservedload_total = meanvariance()
    unservedload_period = [meanvariance() for _ in 1:N]
    unservedload_region = [meanvariance() for _ in 1:nregions]
    unservedload_region_period = Matrix{MeanVariance}(undef, nregions, N)

    for r in 1:nregions, t in 1:N
        periodsdropped_region_period[r,t] = meanvariance()
        unservedload_region_period[r,t] = meanvariance()
    end

    while accsremaining > 0

        acc = take!(results)

        merge!(periodsdropped_total, acc.periodsdropped_total)
        merge!(unservedload_total, acc.unservedload_total)

        for r in 1:nregions
            merge!(periodsdropped_region[r], acc.periodsdropped_region[r])
            merge!(unservedload_region[r], acc.unservedload_region[r])
        end

        for t in 1:N

            merge!(periodsdropped_period[t], acc.periodsdropped_period[t])
            merge!(unservedload_period[t], acc.unservedload_period[t])

            for r in 1:nregions
                merge!(periodsdropped_region_period[r,t], acc.periodsdropped_region_period[r, t])
                merge!(unservedload_region_period[r,t], acc.unservedload_region_period[r, t])
            end

        end

        accsremaining -= 1

    end

    close(results)

    lole = makemetric(LOLE{N,L,T}, periodsdropped_total)
    region_loles = makemetric.(LOLE{N,L,T}, periodsdropped_region)
    lolps = makemetric.(LOLP{L,T}, periodsdropped_period)
    region_lolps = makemetric.(LOLP{L,T}, periodsdropped_region_period)

    p2e = conversionfactor(L,T,P,E)
    eue = makemetric_scale(EUE{N,L,T,E}, p2e, unservedload_total)
    region_eues = makemetric_scale.(EUE{N,L,T,E}, p2e, unservedload_region)
    period_eues = makemetric_scale.(EUE{1,L,T,E}, p2e, unservedload_period)
    regionperiod_eues = makemetric_scale.(EUE{1,L,T,E}, p2e, unservedload_region_period)

    return SpatioTemporalResult(
        system.regions.names, system.timestamps,
        lole, region_loles, lolps, region_lolps,
        eue, region_eues, period_eues, regionperiod_eues,
        simspec)

end
