struct NonSequentialTemporalResultAccumulator{V,S,ES,SS} <: ResultAccumulator{V,S,ES,SS}
    droppedcount::Vector{MeanVariance{V}}
    droppedsum::Vector{MeanVariance{V}}
    system::S
    extractionspec::ES
    simulationspec::SS
    rngs::Vector{MersenneTwister}

    NonSequentialTemporalResultAccumulator{V}(
        droppedcount::Vector{MeanVariance{V}}, droppedsum::Vector{MeanVariance{V}},
        system::S, extractionspec::ES, simulationspec::SS,
        rngs::Vector{MersenneTwister}) where {V,S,ES,SS} =
        new{V,S,ES,SS}(droppedcount, droppedsum, system,
                       extractionspec, simulationspec, rngs)

end

function accumulator(extractionspec::ExtractionSpec,
                     simulationspec::SimulationSpec{NonSequential},
                     resultspec::Temporal, sys::SystemModel{N,L,T,P,E},
                     seed::UInt) where {N,L,T,P,E,V}

    nthreads = Threads.nthreads()
    nperiods = length(sys.timestamps)

    droppedcount = Vector{MeanVariance{V}}(undef, nperiods)
    droppedsum = Vector{MeanVariance{V}}(undef, nperiods)

    for t in 1:nperiods
        droppedcount[t] = Series(Mean(), Variance())
        droppedsum[t] = Series(Mean(), Variance())
    end

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)

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

function update!(acc::NonSequentialTemporalResultAccumulator{V,SystemModel{N,L,T,P,E}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E,V}

    isshortfall, droppedpower = droppedload(sample)
    droppedenergy = powertoenergy(droppedpower, L, T, P, E)

    fit!(acc.droppedcount[t], V(isshortfall))
    fit!(acc.droppedsum[t], droppedenergy)

    return

end

function finalize(acc::NonSequentialTemporalResultAccumulator{V,<:SystemModel{N,L,T,P,E}}
                  ) where {N,L,T,P,E,V}

    lolps = makemetric.(LOLP{L,T}, acc.droppedcount)
    eues = makemetric.(EUE{1,L,T,E}, acc.droppedsum)

    return TemporalResult(
        acc.system.timestamps, LOLE(lolps), lolps, EUE(eues), eues,
        acc.extractionspec, acc.simulationspec)

end
