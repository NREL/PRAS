struct NonSequentialSpatioTemporalResultAccumulator{S,SS} <: ResultAccumulator{S,SS}

    # LOLP / LOLE
    droppedcount::Vector{MeanVariance}
    droppedcount_regions::Matrix{MeanVariance}

    # EUE
    droppedsum::Vector{MeanVariance}
    droppedsum_regions::Matrix{MeanVariance}

    localshortfalls::Vector{Vector{Int}}

    system::S
    simulationspec::SS
    rngs::Vector{MersenneTwister}

    NonSequentialSpatioTemporalResultAccumulator(
        droppedcount::Vector{MeanVariance},
        droppedcount_regions::Matrix{MeanVariance},
        droppedsum::Vector{MeanVariance},
        droppedsum_regions::Matrix{MeanVariance},
        localshortfalls::Vector{Vector{Int}},
        system::S, simulationspec::SS,
        rngs::Vector{MersenneTwister}) where {
        V,S<:SystemModel,SS<:SimulationSpec} =
        new{V,S,SS}(
            droppedcount, droppedcount_regions, droppedsum, droppedsum_regions,
            localshortfalls, system, simulationspec, rngs)

end

function accumulator(simulationspec::SimulationSpec{NonSequential},
                     resultspec::SpatioTemporal, sys::SystemModel{N,L,T,P,E},
                     seed::UInt) where {N,L,T,P,E}

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

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)
    localshortfalls = Vector{Vector{Int}}(undef, nthreads)

    Threads.@threads for i in 1:nthreads
        rngs[i] = copy(rngs_temp[i])
        localshortfalls[i] = zeros(V, nregions)
    end

    return NonSequentialSpatioTemporalResultAccumulator(
        droppedcount, droppedcount_regions, droppedsum, droppedsum_regions,
        localshortfalls,
        sys, simulationspec, rngs)

end

"""
Updates a NonSequentialSpatioTemporalResultAccumulator `acc` with the
exact results for the timestep `t`.
"""
function update!(acc::NonSequentialSpatioTemporalResultAccumulator,
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
Updates a NonSequentialSpatioTemporalResultAccumulator `acc` with the results of a
single Monte Carlo sample `i` for the timestep `t`.
"""
function update!(acc::NonSequentialSpatioTemporalResultAccumulator{V,SystemModel{N,L,T,P,E}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E,V}

    i = Threads.threadid()

    isshortfall, totalshortfall, localshortfalls =
        droppedloads!(acc.localshortfalls[i], sample)

    fit!(acc.droppedcount[t], isshortfall)
    fit!(acc.droppedsum[t], powertoenergy(E, totalshortfall, P, L, T))

    for r in 1:length(acc.system.regions)
        shortfall = localshortfalls[r]
        fit!(acc.droppedcount_regions[r, t], approxnonzero(shortfall))
        fit!(acc.droppedsum_regions[r, t], powertoenergy(E, shortfall, P, L, T))
    end

    return

end

function finalize(acc::NonSequentialSpatioTemporalResultAccumulator{SystemModel{N,L,T,P,E}}
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

    return SpatioTemporalResult(
        acc.system.regions, acc.system.timestamps,
        lole, regionloles, periodlolps, regionalperiodlolps,
        eue, regioneues, periodeues, regionalperiodeues,
        acc.simulationspec)

end
