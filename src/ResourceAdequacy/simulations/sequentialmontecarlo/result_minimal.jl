mutable struct SequentialMonteCarloMinimalAccumulator{N,L,T,P,E} <: ResultAccumulator{Minimal}

    periodsdropped_total::MeanVariance # Cross-simulation total LOL mean and variance
    periodsdropped_total_currentsim::Int # LOL count for current simulation

    # Note: Unserved load (not energy) does not consider time units
    unservedload_total::MeanVariance # Cross-simulation total UL mean and variance
    unservedload_total_currentsim::Int # UL sum for current simulation

end

accumulatortype(::SequentialMonteCarlo, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    SequentialMonteCarloMinimalAccumulator{N,L,T,P,E}

accumulator(::SequentialMonteCarlo, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    SequentialMonteCarloMinimalAccumulator{N,L,T,P,E}(
        Series(Mean(), Variance()), 0,
        Series(Mean(), Variance()), 0)

function record!(
    acc::SequentialMonteCarloMinimalAccumulator{N,L,T,P,E},
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    isunservedload, unservedload = droppedload(problem)

    if isunservedload
        acc.periodsdropped_total_currentsim += 1
        acc.unservedload_total_currentsim += unservedload
    end

    return

end

function reset!(acc::SequentialMonteCarloMinimalAccumulator, sampleid::Int)

        # Store totals for current simulation
        fit!(acc.periodsdropped_total, acc.periodsdropped_total_currentsim)
        fit!(acc.unservedload_total, acc.unservedload_total_currentsim)

        # Reset for new simulation
        acc.periodsdropped_total_currentsim = 0
        acc.unservedload_total_currentsim = 0

        return

end

function finalize(
    results::Channel{SequentialMonteCarloMinimalAccumulator{N,L,T,P,E}},
    simspec::SequentialMonteCarlo,
    system::SystemModel{N,L,T,P,E},
    accsremaining::Int
) where {N,L,T,P,E}

    periodsdropped = Series(Mean(), Variance())
    unservedload = Series(Mean(), Variance())

    while accsremaining > 0

        acc = take!(results)

        merge!(periodsdropped, acc.periodsdropped_total)
        merge!(unservedload, acc.unservedload_total)

        accsremaining -= 1

    end

    close(results)

    p2e = conversionfactor(L,T,P,E)
    lole = makemetric(LOLE{N,L,T}, periodsdropped)
    eue = makemetric_scale(EUE{N,L,T,E}, p2e, unservedload)

    return MinimalResult(lole, eue, simspec)

end
