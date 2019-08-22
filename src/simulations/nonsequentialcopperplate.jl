struct NonSequentialCopperplate <: SimulationSpec{NonSequential} end

ismontecarlo(::NonSequentialCopperplate) = false
iscopperplate(::NonSequentialCopperplate) = true

function assess!(acc::ResultAccumulator,
                 simulationspec::NonSequentialCopperplate,
                 sys::SystemModel{N,L,T,P,E},
                 t::Int) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    statedistr = SystemInputStateDistribution(sys, t, copperplate=true)
    lolp, eul = assess(statedistr.regions[1])
    eue = powertoenergy(E, eul, P, L, T)
    update!(acc, SystemOutputStateSummary{L,T,E}(lolp, [lolp], [eue]), t)

end
