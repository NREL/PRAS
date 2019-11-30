mutable struct ModernMinimalAccumulator{N,L,T,P,E} <: ResultAccumulator{Minimal}

    periodsdropped_currentsim::Int # LOL count for current simulation
    periodsdropped::MeanVariance # Cross-simulation total LOL mean and variance

    unservedenergy_currentsim::Int # UE sum for current simulation
    unservedenergy::MeanVariance # Cross-simulation total UE mean and variance

end

accumulatortype(::Modern, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    ModernMinimalAccumulator{N,L,T,P,E}

accumulator(::Modern, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    ModernMinimalAccumulator{N,L,T,P,E}(
        0, Series(Mean(), Variance()),
        0, Series(Mean(), Variance()))

function record!(
    acc::ModernMinimalAccumulator{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    unservedload = droppedload(problem)

    if unservedload > 0
        acc.periodsdropped_currentsim += 1
        acc.unservedenergy_currentsim +=
            powertoenergy(E, unservedload, P, L, T)
    end

    return

end

function reset!(acc::ModernMinimalAccumulator, sampleid::Int)

        # Store totals for current simulation
        fit!(acc.periodsdropped, acc.periodsdropped_currentsim)
        fit!(acc.unservedenergy, acc.unservedenergy_currentsim)

        # Reset for new simulation
        acc.periodsdropped_currentsim = 0
        acc.unservedenergy_currentsim = 0

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

        merge!(periodsdropped, acc.periodsdropped)
        merge!(unservedenergy, acc.unservedenergy)

        accsremaining -= 1

    end

    close(results)

    lole, lole_stderr = mean_stderr(periodsdropped, simspec.nsamples)
    eue, eue_stderr = mean_stderr(unservedenergy, simspec.nsamples)

    return MinimalResult(
        LOLE{N,L,T}(lole, lole_stderr),
        EUE{N,L,T,E}(eue, eue_stderr),
        simspec)

end
