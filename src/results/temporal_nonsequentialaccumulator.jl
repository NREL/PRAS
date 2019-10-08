struct NonSequentialTemporalResultAccumulator{N,L,T,P,E} <:
    ResultAccumulator{Temporal,NonSequential}

    droppedcount::Vector{MeanVariance}
    droppedsum::Vector{MeanVariance}

end

function accumulator(
    ::Type{NonSequential}, resultspec::Temporal, sys::SystemModel{N,L,T,P,E}
) where {N,L,T,P,E}

    nthreads = Threads.nthreads()
    nperiods = length(sys.timestamps)

    droppedcount = Vector{MeanVariance}(undef, nperiods)
    droppedsum = Vector{MeanVariance}(undef, nperiods)

    for t in 1:nperiods
        droppedcount[t] = Series(Mean(), Variance())
        droppedsum[t] = Series(Mean(), Variance())
    end

    return NonSequentialTemporalResultAccumulator{N,L,T,P,E}(
        droppedcount, droppedsum)

end

function update!(acc::NonSequentialTemporalResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    fit!(acc.droppedcount[t], result.lolp_system)
    fit!(acc.droppedsum[t], sum(result.eue_regions))
    return

end

function update!(acc::NonSequentialTemporalResultAccumulator{N,L,T,P,E},
                 sample::SystemOutputStateSample{L,T,P}, t::Int, i::Int
) where {N,L,T,P,E}

    isshortfall, droppedpower = droppedload(sample)
    droppedenergy = powertoenergy(E, droppedpower, P, L, T)

    fit!(acc.droppedcount[t], isshortfall)
    fit!(acc.droppedsum[t], droppedenergy)

    return

end

function finalize(
    cache::SimulationCache{N,L,T,P,E},
    acc::NonSequentialTemporalResultAccumulator{N,L,T,P,E}
) where {N,L,T,P,E}

    lolps = makemetric.(LOLP{L,T}, acc.droppedcount)
    eues = makemetric.(EUE{1,L,T,E}, acc.droppedsum)

    return TemporalResult(
        cache.system.timestamps, LOLE(lolps), lolps, EUE(eues), eues,
        cache.simulationspec)

end
