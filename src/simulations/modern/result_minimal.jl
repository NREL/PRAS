mutable struct ModernMinimalAccumulator{N,L,T,P,E} <: ResultAccumulator{Minimal}

    periodsdropped_total::MeanVariance # Cross-simulation total LOL mean and variance
    periodsdropped_total_currentsim::Int # LOL count for current simulation

    unservedenergy_total::MeanVariance # Cross-simulation total UE mean and variance
    unservedenergy_total_currentsim::Int # UE sum for current simulation

end

accumulatortype(::Modern, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    ModernMinimalAccumulator{N,L,T,P,E}

accumulator(::Modern, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    ModernMinimalAccumulator{N,L,T,P,E}(
        Series(Mean(), Variance()), 0,
        Series(Mean(), Variance()), 0)

function record!(
    acc::ModernMinimalAccumulator{N,L,T,P,E},
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    isunservedload, unservedload = droppedload(problem)

    if isunservedload
        acc.periodsdropped_total_currentsim += 1
        acc.unservedenergy_total_currentsim +=
            powertoenergy(unservedload, P, L, T, E)
    end

    return

end

function reset!(acc::ModernMinimalAccumulator, sampleid::Int)

        # Store totals for current simulation
        fit!(acc.periodsdropped_total, acc.periodsdropped_total_currentsim)
        fit!(acc.unservedenergy_total, acc.unservedenergy_total_currentsim)

        # Reset for new simulation
        acc.periodsdropped_total_currentsim = 0
        acc.unservedenergy_total_currentsim = 0

        return

end

function finalize(
    results::Channel{ModernMinimalAccumulator{N,L,T,P,E}},
    simspec::Modern,
    system::SystemModel{N,L,T,P,E},
    accsremaining::Int
) where {N,L,T,P,E}

    periodsdropped = Series(Mean(), Variance())
    unservedenergy = Series(Mean(), Variance())

    while accsremaining > 0

        acc = take!(results)

        merge!(periodsdropped, acc.periodsdropped_total)
        merge!(unservedenergy, acc.unservedenergy_total)

        accsremaining -= 1

    end

    close(results)

    lole = makemetric(LOLE{N,L,T}, periodsdropped)
    eue = makemetric(EUE{N,L,T,E}, unservedenergy)

    return MinimalResult(lole, eue, simspec)

end
