# Simulation specification

struct Classic <: SimulationSpec end

function assess(simulationspec::Classic,
                resultspec::ResultSpec,
                system::SystemModel{N},
                seed::UInt=rand(UInt)) where {N}

    cch = cache(simulationspec, system, seed)
    acc = accumulator(NonSequential, resultspec, system)

    nstors = length(system.storages)
    ngenstors = length(system.generatorstorages)

    if nstors + ngenstors > 0
        resources = String[]
        nstors > 0 && push!(resources, "$nstors Storage")
        ngenstors > 0 && push!(resources, "$ngenstors GeneratorStorage")
        @warn "$simulationspec is a non-sequential simulation method. " *
              "The system's " * join(resources, " and ") * " resources " *
              "will be ignored in the assessment."
    end

    Threads.@threads for t in 1:N 
        assess!(cch, acc, t)
    end

    return finalize(cch, acc)

end

# Simulation cache

struct NonSequentialCopperplateCache{N,L,T,P,E} <:
    SimulationCache{N,L,T,P,E,NonSequentialCopperplate}
    simulationspec::NonSequentialCopperplate
    system::SystemModel{N,L,T,P,E}
end

function cache(simulationspec::Classic,
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
