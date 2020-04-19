mutable struct SequentialMonteCarloTemporalAccumulator{N,L,T,P,E} <: ResultAccumulator{Temporal}

    periodsdropped_period::Vector{MeanVariance} # Cross-simulation period LOL mean and variance
    periodsdropped_total::MeanVariance # Cross-simulation total LOL mean and variance
    periodsdropped_total_currentsim::Int # LOL count for current simulation

    unservedload_period::Vector{MeanVariance} # Cross-simulation period UE mean and variance
    unservedload_total::MeanVariance # Cross-simulation total UE mean and variance
    unservedload_total_currentsim::Int # UE sum for current simulation

end

accumulatortype(::SequentialMonteCarlo, ::Temporal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    SequentialMonteCarloTemporalAccumulator{N,L,T,P,E}

accumulator(::SequentialMonteCarlo, ::Temporal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    SequentialMonteCarloTemporalAccumulator{N,L,T,P,E}(
        [Series(Mean(), Variance()) for _ in 1:N], Series(Mean(), Variance()), 0,
        [Series(Mean(), Variance()) for _ in 1:N], Series(Mean(), Variance()), 0)

function record!(
    acc::SequentialMonteCarloTemporalAccumulator{N,L,T,P,E},
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    isunservedload, unservedload = droppedload(problem)

    fit!(acc.periodsdropped_period[t], isunservedload)
    fit!(acc.unservedload_period[t], unservedload)

    if isunservedload
        acc.periodsdropped_total_currentsim += 1
        acc.unservedload_total_currentsim += unservedload
    end

    return

end

function reset!(acc::SequentialMonteCarloTemporalAccumulator, sampleid::Int)

        # Store totals for current simulation
        fit!(acc.periodsdropped_total, acc.periodsdropped_total_currentsim)
        fit!(acc.unservedload_total, acc.unservedload_total_currentsim)

        # Reset for new simulation
        acc.periodsdropped_total_currentsim = 0
        acc.unservedload_total_currentsim = 0

        return

end

function finalize(
    results::Channel{SequentialMonteCarloTemporalAccumulator{N,L,T,P,E}},
    simspec::SequentialMonteCarlo,
    system::SystemModel{N,L,T,P,E},
    accsremaining::Int
) where {N,L,T,P,E}

    periodsdropped_total = Series(Mean(), Variance())
    periodsdropped_period = [Series(Mean(), Variance()) for _ in 1:N]

    unservedload_total = Series(Mean(), Variance())
    unservedload_period = [Series(Mean(), Variance()) for _ in 1:N]

    while accsremaining > 0

        acc = take!(results)

        merge!(periodsdropped_total, acc.periodsdropped_total)
        merge!(unservedload_total, acc.unservedload_total)

        for t in 1:N
            merge!(periodsdropped_period[t], acc.periodsdropped_period[t])
            merge!(unservedload_period[t], acc.unservedload_period[t])
        end

        accsremaining -= 1

    end

    close(results)

    lole = makemetric(LOLE{N,L,T}, periodsdropped_total)
    lolps = makemetric.(LOLP{L,T}, periodsdropped_period)

    p2e = conversionfactor(L,T,P,E)
    eue = makemetric_scale(EUE{N,L,T,E}, p2e, unservedload_total)
    eues = makemetric_scale.(EUE{1,L,T,E}, p2e, unservedload_period)

    return TemporalResult(system.timestamps, lole, lolps, eue, eues, simspec)

end
