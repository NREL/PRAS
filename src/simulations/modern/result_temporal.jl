mutable struct ModernTemporalAccumulator{N,L,T,P,E} <: ResultAccumulator{Temporal}

    periodsdropped_period::Vector{MeanVariance} # Cross-simulation period LOL mean and variance
    periodsdropped_total::MeanVariance # Cross-simulation total LOL mean and variance
    periodsdropped_total_currentsim::Int # LOL count for current simulation

    unservedenergy_period::Vector{MeanVariance} # Cross-simulation period UE mean and variance
    unservedenergy_total::MeanVariance # Cross-simulation total UE mean and variance
    unservedenergy_total_currentsim::Int # UE sum for current simulation

end

accumulatortype(::Modern, ::Temporal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    ModernTemporalAccumulator{N,L,T,P,E}

accumulator(::Modern, ::Temporal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    ModernTemporalAccumulator{N,L,T,P,E}(
        [Series(Mean(), Variance()) for _ in 1:N], Series(Mean(), Variance()), 0,
        [Series(Mean(), Variance()) for _ in 1:N], Series(Mean(), Variance()), 0)

function record!(
    acc::ModernTemporalAccumulator{N,L,T,P,E},
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    isunservedload, unservedload = droppedload(problem)
    unservedenergy = powertoenergy(unservedload, P, L, T, E)

    fit!(acc.periodsdropped_period[t], isunservedload)
    fit!(acc.unservedenergy_period[t], unservedenergy)

    if isunservedload
        acc.periodsdropped_total_currentsim += 1
        acc.unservedenergy_total_currentsim += unservedenergy
    end

    return

end

function reset!(acc::ModernTemporalAccumulator, sampleid::Int)

        # Store totals for current simulation
        fit!(acc.periodsdropped_total, acc.periodsdropped_total_currentsim)
        fit!(acc.unservedenergy_total, acc.unservedenergy_total_currentsim)

        # Reset for new simulation
        acc.periodsdropped_total_currentsim = 0
        acc.unservedenergy_total_currentsim = 0

        return

end

function finalize(
    results::Channel{ModernTemporalAccumulator{N,L,T,P,E}},
    simspec::Modern,
    system::SystemModel{N,L,T,P,E},
    accsremaining::Int
) where {N,L,T,P,E}

    periodsdropped_total = Series(Mean(), Variance())
    periodsdropped_period = [Series(Mean(), Variance()) for _ in 1:N]

    unservedenergy_total = Series(Mean(), Variance())
    unservedenergy_period = [Series(Mean(), Variance()) for _ in 1:N]

    while accsremaining > 0

        acc = take!(results)

        merge!(periodsdropped_total, acc.periodsdropped_total)
        merge!(unservedenergy_total, acc.unservedenergy_total)

        for t in 1:N
            merge!(periodsdropped_period[t], acc.periodsdropped_period[t])
            merge!(unservedenergy_period[t], acc.unservedenergy_period[t])
        end

        accsremaining -= 1

    end

    close(results)

    lole = makemetric(LOLE{N,L,T}, periodsdropped_total)
    lolps = makemetric.(LOLP{L,T}, periodsdropped_period)

    eue = makemetric(EUE{N,L,T,E}, unservedenergy_total)
    eues = makemetric.(EUE{1,L,T,E}, unservedenergy_period)

    return TemporalResult(system.timestamps, lole, lolps, eue, eues, simspec)

end
