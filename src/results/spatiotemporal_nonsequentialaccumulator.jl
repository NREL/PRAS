struct NonSequentialSpatioTemporalResultAccumulator{N,L,T,P,E} <:
    ResultAccumulator{SpatioTemporal,NonSequential}

    # LOLP / LOLE
    droppedcount::Vector{MeanVariance}
    droppedcount_regions::Matrix{MeanVariance}

    # EUE
    droppedsum::Vector{MeanVariance}
    droppedsum_regions::Matrix{MeanVariance}

    localshortfalls::Vector{Vector{Int}}

end

function accumulator(
    ::Type{NonSequential}, resultspec::SpatioTemporal, sys::SystemModel{N,L,T,P,E}
) where {N,L,T,P,E}

    nthreads = Threads.nthreads()
    nperiods = length(sys.timestamps)
    nregions = length(sys.regions)

    droppedcount = Vector{MeanVariance}(undef, nperiods)
    droppedcount_regions = Matrix{MeanVariance}(undef, nregions, nperiods)

    droppedsum = Vector{MeanVariance}(undef, nperiods)
    droppedsum_regions = Matrix{MeanVariance}(undef, nregions, nperiods)

    for t in 1:nperiods
        droppedcount[t] = Series(Mean(), Variance())
        droppedsum[t] = Series(Mean(), Variance())
        for r in 1:nregions
            droppedcount_regions[r,t] = Series(Mean(), Variance())
            droppedsum_regions[r,t] = Series(Mean(), Variance())
        end
    end

    localshortfalls = Vector{Vector{Int}}(undef, nthreads)

    Threads.@threads for i in 1:nthreads
        localshortfalls[i] = zeros(Int, nregions)
    end

    return NonSequentialSpatioTemporalResultAccumulator{N,L,T,P,E}(
        droppedcount, droppedcount_regions, droppedsum, droppedsum_regions,
        localshortfalls)

end

"""
Updates a NonSequentialSpatioTemporalResultAccumulator `acc` with the
exact results for the timestep `t`.
"""
function update!(acc::NonSequentialSpatioTemporalResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    thread = Threads.threadid()
    nregions = length(acc.localshortfalls[thread])

    fit!(acc.droppedcount[t], result.lolp_system)
    fit!(acc.droppedsum[t], sum(result.eue_regions))

    for r in 1:nregions
        fit!(acc.droppedcount_regions[r, t], result.lolp_regions[r])
        fit!(acc.droppedsum_regions[r, t], result.eue_regions[r])
    end

    return

end

"""
Updates a NonSequentialSpatioTemporalResultAccumulator `acc` with the results of a
single Monte Carlo sample `i` for the timestep `t`.
"""
function update!(
    acc::NonSequentialSpatioTemporalResultAccumulator{N,L,T,P,E},
    sample::SystemOutputStateSample, t::Int, i::Int
) where {N,L,T,P,E}

    thread = Threads.threadid()
    nregions = length(acc.localshortfalls[thread])

    isshortfall, totalshortfall, localshortfalls =
        droppedloads!(acc.localshortfalls[thread], sample)

    fit!(acc.droppedcount[t], isshortfall)
    fit!(acc.droppedsum[t], powertoenergy(E, totalshortfall, P, L, T))

    for r in 1:nregions
        shortfall = localshortfalls[r]
        fit!(acc.droppedcount_regions[r, t], shortfall > 0)
        fit!(acc.droppedsum_regions[r, t], powertoenergy(E, shortfall, P, L, T))
    end

    return

end

function finalize(
    cache::SimulationCache{N,L,T,P,E},
    acc::NonSequentialSpatioTemporalResultAccumulator{N,L,T,P,E}
) where {N,L,T,P,E}

    nregions = length(cache.system.regions)

    periodlolps = makemetric.(LOLP{L,T}, acc.droppedcount)
    lole = LOLE(periodlolps)
    regionalperiodlolps = makemetric.(LOLP{L,T}, acc.droppedcount_regions)
    regionloles = [LOLE(regionalperiodlolps[r, :]) for r in 1:nregions]

    periodeues = makemetric.(EUE{1,L,T,E}, acc.droppedsum)
    eue = EUE(periodeues)
    regionalperiodeues = makemetric.(EUE{1,L,T,E}, acc.droppedsum_regions)
    regioneues = [EUE(regionalperiodeues[r, :]) for r in 1:nregions]

    return SpatioTemporalResult(
        cache.system.regions.names, cache.system.timestamps,
        lole, regionloles, periodlolps, regionalperiodlolps,
        eue, regioneues, periodeues, regionalperiodeues,
        cache.simulationspec)

end
