struct NonSequentialNetworkResultAccumulator{S,ES,SS} <: ResultAccumulator{S,ES,SS}

    # LOLP / LOLE
    droppedcount::Vector{MeanVariance}
    droppedcount_regions::Matrix{MeanVariance}

    # EUE
    droppedsum::Vector{MeanVariance}
    droppedsum_regions::Matrix{MeanVariance}

    localshortfalls::Vector{Vector{Int}}

    flows::Matrix{MeanVariance}
    utilizations::Matrix{MeanVariance}

    system::S
    extractionspec::ES
    simulationspec::SS
    rngs::Vector{MersenneTwister}

    NonSequentialNetworkResultAccumulator{}(
        droppedcount::Vector{MeanVariance},
        droppedcount_regions::Matrix{MeanVariance},
        droppedsum::Vector{MeanVariance},
        droppedsum_regions::Matrix{MeanVariance},
        localshortfalls::Vector{Vector{Int}},
        flows::Matrix{MeanVariance},
        utilizations::Matrix{MeanVariance},
        system::S, extractionspec::ES, simulationspec::SS,
        rngs::Vector{MersenneTwister}) where {
        S<:SystemModel,ES<:ExtractionSpec,SS<:SimulationSpec} =
        new{S,ES,SS}(
            droppedcount, droppedcount_regions, droppedsum, droppedsum_regions,
            localshortfalls, flows, utilizations, system,
            extractionspec, simulationspec, rngs)

end

function accumulator(extractionspec::ExtractionSpec,
                     simulationspec::SimulationSpec{NonSequential},
                     resultspec::Network, sys::SystemModel{N,L,T,P,E},
                     seed::UInt) where {N,L,T,P,E}

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

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)
    localshortfalls = Vector{Vector{Int}}(undef, nthreads)

    Threads.@threads for i in 1:nthreads
        rngs[i] = copy(rngs_temp[i])
        localshortfalls[i] = zeros(Float64, nregions)
    end

    return NonSequentialNetworkResultAccumulator(
        droppedcount, droppedcount_regions, droppedsum, droppedsum_regions,
        localshortfalls, flows, utilizations, sys,
        extractionspec, simulationspec, rngs)

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
function update!(acc::NonSequentialNetworkResultAccumulator{SystemModel{N,L,T,P,E}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E}

    i = Threads.threadid()

    isshortfall, totalshortfall, localshortfalls =
        droppedloads!(acc.localshortfalls[i], sample)

    fit!(acc.droppedcount[t], isshortfall)
    fit!(acc.droppedsum[t], powertoenergy(E, totalshortfall, P, L, T))

    for r in 1:length(acc.system.regions)
        shortfall = localshortfalls[r]
        fit!(acc.droppedcount_regions[r, t], approxnonzero(shortfall))
        fit!(acc.droppedsum_regions[r, t], powertoenergy(shortfall, L, T, P, E))
    end

    for i in 1:length(acc.system.interfaces)
        fit!(acc.flows[i,t], sample.interfaces[i].transfer)
        fit!(acc.utilizations[i,t],
             abs(sample.interfaces[i].transfer) /
             sample.interfaces[i].max_transfer_magnitude)
    end

    return

end

function finalize(acc::NonSequentialNetworkResultAccumulator{SystemModel{N,L,T,P,E}}
                  ) where {N,L,T,P,E}

    nregions = length(acc.system.regions)

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
        acc.system.regions, acc.system.interfaces, acc.system.timestamps,
        lole, regionloles, periodlolps, regionalperiodlolps,
        eue, regioneues, periodeues, regionalperiodeues,
        flows, utilizations, acc.extractionspec, acc.simulationspec)

end
