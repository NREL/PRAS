struct NonSequentialNetworkResultAccumulator{N,L,T,P,E} <:
    ResultAccumulator{Network,NonSequential}

    # LOLP / LOLE
    droppedcount::Vector{MeanVariance}
    droppedcount_regions::Matrix{MeanVariance}

    # EUE
    droppedsum::Vector{MeanVariance}
    droppedsum_regions::Matrix{MeanVariance}

    localshortfalls::Vector{Vector{Int}}

    flows::Matrix{MeanVariance}
    utilizations::Matrix{MeanVariance}

end

function accumulator(
    ::Type{NonSequential}, resultspec::Network, sys::SystemModel{N,L,T,P,E}
) where {N,L,T,P,E}

    nthreads = Threads.nthreads()
    nperiods = length(sys.timestamps)
    nregions = length(sys.regions)
    ninterfaces = length(sys.interfaces)

    droppedcount = Vector{MeanVariance}(undef, nperiods)
    droppedcount_regions = Matrix{MeanVariance}(undef, nregions, nperiods)

    droppedsum = Vector{MeanVariance}(undef, nperiods)
    droppedsum_regions = Matrix{MeanVariance}(undef, nregions, nperiods)

    flows = Matrix{MeanVariance}(undef, ninterfaces, nperiods)
    utilizations = Matrix{MeanVariance}(undef, ninterfaces, nperiods)

    for t in 1:nperiods
        droppedcount[t] = Series(Mean(), Variance())
        droppedsum[t] = Series(Mean(), Variance())
        for r in 1:nregions
            droppedcount_regions[r,t] = Series(Mean(), Variance())
            droppedsum_regions[r,t] = Series(Mean(), Variance())
        end
        for i in 1:ninterfaces
            flows[i,t] = Series(Mean(), Variance())
            utilizations[i,t] = Series(Mean(), Variance())
        end
    end

    localshortfalls = Vector{Vector{Int}}(undef, nthreads)

    Threads.@threads for i in 1:nthreads
        localshortfalls[i] = zeros(Float64, nregions)
    end

    return NonSequentialNetworkResultAccumulator{N,L,T,P,E}(
        droppedcount, droppedcount_regions, droppedsum, droppedsum_regions,
        localshortfalls, flows, utilizations)

end

# TODO: Should this be here? Spatial models don't support exact results anyways?
"""
Updates a NonSequentialNetworkResultAccumulator `acc` with the
exact results for the timestep `t`.
"""
function update!(acc::NonSequentialNetworkResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    fit!(acc.droppedcount[t], result.lolp_system)
    fit!(acc.droppedsum[t], sum(result.eue_regions))

    for r in 1:length(acc.system.regions)
        fit!(acc.droppedcount_regions[r, t], result.lolp_regions[r])
        fit!(acc.droppedsum_regions[r, t], result.eue_regions[r])
    end

    return

end

"""
Updates a NonSequentialNetworkResultAccumulator `acc` with the results of a
single Monte Carlo sample `i` for the timestep `t`.
"""
function update!(
    acc::NonSequentialNetworkResultAccumulator{N,L,T,P,E},
    sample::SystemOutputStateSample, t::Int, i::Int
) where {N,L,T,P,E}

    thread = Threads.threadid()
    nregions = length(acc.localshortfalls[thread])
    ninterfaces = size(acc.flows, 1)

    isshortfall, totalshortfall, localshortfalls =
        droppedloads!(acc.localshortfalls[thread], sample)

    fit!(acc.droppedcount[t], isshortfall)
    fit!(acc.droppedsum[t], powertoenergy(E, totalshortfall, P, L, T))

    for r in 1:nregions
        shortfall = localshortfalls[r]
        fit!(acc.droppedcount_regions[r, t], shortfall > 0)
        fit!(acc.droppedsum_regions[r, t], powertoenergy(E, shortfall, P, L, T))
    end

    for i in 1:ninterfaces
        fit!(acc.flows[i,t], sample.interfaces[i].transfer)
        fit!(acc.utilizations[i,t],
             abs(sample.interfaces[i].transfer) /
             sample.interfaces[i].max_transfer_magnitude)
    end

    return

end

function finalize(
    cache::SimulationCache{N,L,T,P,E},
    acc::NonSequentialNetworkResultAccumulator{N,L,T,P,E}
) where {N,L,T,P,E}

    nregions = length(cache.system.regions)
    interfaces = tuple.(cache.system.interfaces.regions_from,
                        cache.system.interfaces.regions_to)

    periodlolps = makemetric.(LOLP{L,T}, acc.droppedcount)
    lole = LOLE(periodlolps)
    regionalperiodlolps = makemetric.(LOLP{L,T}, acc.droppedcount_regions)
    regionloles = [LOLE(regionalperiodlolps[r, :]) for r in 1:nregions]

    periodeues = makemetric.(EUE{1,L,T,E}, acc.droppedsum)
    eue = EUE(periodeues)
    regionalperiodeues = makemetric.(EUE{1,L,T,E}, acc.droppedsum_regions)
    regioneues = [EUE(regionalperiodeues[r, :]) for r in 1:nregions]

    flows = makemetric.(ExpectedInterfaceFlow{1,L,T,P}, acc.flows)
    utilizations = makemetric.(ExpectedInterfaceUtilization{1,L,T}, acc.utilizations)

    return NetworkResult(
        cache.system.regions.names, interfaces, cache.system.timestamps,
        lole, regionloles, periodlolps, regionalperiodlolps,
        eue, regioneues, periodeues, regionalperiodeues,
        flows, utilizations, cache.simulationspec)

end
