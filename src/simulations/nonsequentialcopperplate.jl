# Simulation specification

struct NonSequentialCopperplate <: SimulationSpec{NonSequential} end

ismontecarlo(::NonSequentialCopperplate) = false
iscopperplate(::NonSequentialCopperplate) = true

# Simulation cache

struct NonSequentialCopperplateCache{N,L,T,P,E} <:
    SimulationCache{N,L,T,P,E,NonSequentialCopperplate}
    simulationspec::NonSequentialCopperplate
    system::SystemModel{N,L,T,P,E}
end

function cache(simulationspec::NonSequentialCopperplate,
               system::SystemModel, seed::UInt)
    return NonSequentialCopperplateCache(simulationspec, system)
end

# Simulation assessment

function assess!(
    cache::NonSequentialCopperplateCache{N,L,T,P,E},
    acc::ResultAccumulator, t::Int
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    statedistr = SystemInputStateDistribution(cache.system, t, copperplate=true)
    lolp, eul = assess(statedistr.regions[1])
    eue = powertoenergy(E, eul, P, L, T)
    update!(acc, SystemOutputStateSummary{L,T,E}(lolp, [lolp], [eue]), t)

end
