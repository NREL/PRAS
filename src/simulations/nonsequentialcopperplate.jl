struct NonSequentialCopperplate <: SimulationSpec{NonSequential} end

ismontecarlo(::NonSequentialCopperplate) = false
iscopperplate(::NonSequentialCopperplate) = true

function assess!(acc::ResultAccumulator,
                 simulationspec::NonSequentialCopperplate,
                 sys::SystemModel{N,L,T,P,E},
                 t::Int) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    # TODO: Generate surplus/shortfall distribution
    distr = DiscreteNonParametric(sys, t)
    lolp, eul = assess(distr)
    eue = powertoenergy(E, eul, P, L, T)
    update!(acc, SystemOutputStateSummary{L,T,E}(lolp, [lolp], [eue]), t)

end
