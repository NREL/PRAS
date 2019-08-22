struct NonSequentialTemporalResultAccumulator{S,SS} <: ResultAccumulator{S,SS}
    droppedcount::Vector{MeanVariance}
    droppedsum::Vector{MeanVariance}
    system::S
    simulationspec::SS
    rngs::Vector{MersenneTwister}

    NonSequentialTemporalResultAccumulator(
        droppedcount::Vector{MeanVariance}, droppedsum::Vector{MeanVariance},
        system::S, simulationspec::SS,
        rngs::Vector{MersenneTwister}) where {S,SS} =
        new{S,SS}(droppedcount, droppedsum, system, simulationspec, rngs)

end

function accumulator(simulationspec::SimulationSpec{NonSequential},
                     resultspec::Temporal, sys::SystemModel{N,L,T,P,E},
                     seed::UInt) where {N,L,T,P,E}

    nthreads = Threads.nthreads()
    nperiods = length(sys.timestamps)

    droppedcount = Vector{MeanVariance}(undef, nperiods)
    droppedsum = Vector{MeanVariance}(undef, nperiods)

    for t in 1:nperiods
        droppedcount[t] = Series(Mean(), Variance())
        droppedsum[t] = Series(Mean(), Variance())
    end

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)

    Threads.@threads for i in 1:nthreads
        rngs[i] = copy(rngs_temp[i])
    end

    return NonSequentialTemporalResultAccumulator(
        droppedcount, droppedsum, sys, simulationspec, rngs)

end

function update!(acc::NonSequentialTemporalResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    fit!(acc.droppedcount[t], result.lolp_system)
    fit!(acc.droppedsum[t], sum(result.eue_regions))
    return

end

function update!(acc::NonSequentialTemporalResultAccumulator{SystemModel{N,L,T,P,E}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E}

    isshortfall, droppedpower = droppedload(sample)
    droppedenergy = powertoenergy(E, droppedpower, P, L, T)

    fit!(acc.droppedcount[t], isshortfall)
    fit!(acc.droppedsum[t], droppedenergy)

    return

end

function finalize(acc::NonSequentialTemporalResultAccumulator{SystemModel{N,L,T,P,E}}
                  ) where {N,L,T,P,E}

    lolps = makemetric.(LOLP{L,T}, acc.droppedcount)
    eues = makemetric.(EUE{1,L,T,E}, acc.droppedsum)

    return TemporalResult(
        acc.system.timestamps, LOLE(lolps), lolps, EUE(eues), eues,
        acc.simulationspec)

end
