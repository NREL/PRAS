struct NonSequentialTemporalResultAccumulator{V,S,ES,SS} <: ResultAccumulator{V,S,ES,SS}
    droppedcount::Vector{MeanVariance}
    droppedsum::Vector{MeanVariance}
    system::S
    extractionspec::ES
    simulationspec::SS
    rngs::Vector{MersenneTwister}

    NonSequentialTemporalResultAccumulator{V}(
        droppedcount::Vector{MeanVariance}, droppedsum::Vector{MeanVariance},
        system::S, extractionspec::ES, simulationspec::SS,
        rngs::Vector{MersenneTwister}) where {V,S,ES,SS} =
        new{V,S,ES,SS}(droppedcount, droppedsum, system,
                       extractionspec, simulationspec)

end

function accumulator(extractionspec::ExtractionSpec,
                     simulationspec::SimulationSpec{NonSequential},
                     resultspec::Temporal, sys::SystemModel{N,L,T,P,E,V},
                     seed::UInt) where {N,L,T,P,E,V}

    nthreads = Threads.nthreads()
    nperiods = length(sys.timestamps)

    droppedcount = Vector{MeanVariance}(nperiods)
    droppedsum = Vector{MeanVariance}(nperiods)

    for t in 1:nperiods
        droppedcount[t] = Series(Mean(), Variance())
        droppedsum[t] = Series(Mean(), Variance())
    end

    rngs = Vector{MersenneTwister}(nthreads)
    rngs_temp = randjump(MersenneTwister(seed), nthreads)

    Threads.@threads for i in 1:nthreads
        rngs[i] = copy(rngs_temp[i])
    end

    return NonSequentialTemporalResultAccumulator{V}(
        droppedcount, droppedsum,
        sys, extractionspec, simulationspec, rngs)

end

function update!(acc::NonSequentialTemporalResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    fit!(acc.droppedcount[t], result.lolp_system)
    fit!(acc.droppedsum[t], sum(result.eue_regions))
    return

end

function update!(acc::NonSequentialTemporalResultAccumulator{V,SystemModel{N,L,T,P,E,V}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E,V}

    shortfall = droppedload(sample)
    isshortfall = !isapprox(shortfall, 0.)
    droppedenergy = powertoenergy(shortfall, L, T, P, E)

    fit!(acc.droppedcount[t], V(isshortfall))
    fit!(acc.droppedsum[t], droppedenergy)

    return

end

function finalize(acc::NonSequentialTemporalResultAccumulator{V,<:SystemModel{N,L,T,P,E,V}}
                  ) where {N,L,T,P,E,V}

    timestamps = acc.system.timestamps
    lolps = makemetric.(LOLP{L,T}, acc.droppedcount)
    eues = makemetric.(EUE{1,L,T,E}, acc.droppedsum)

    return TemporalResult(
        timestamps, LOLE(lolps), lolps, EUE(eues), eues,
        acc.extractionspec, acc.simulationspec)

end
