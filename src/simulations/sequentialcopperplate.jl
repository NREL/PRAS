struct SequentialCopperplate <: SimulationSpec{Sequential}
    nsamples::Int

    function SequentialCopperplate(nsamples::Int)
        @assert nsamples > 0
        new(nsamples)
    end
end

iscopperplate(::SequentialCopperplate) = true

struct SequentialCopperplateCache{N,L,T,P,E} <:
    SimulationCache{N,L,T,P,E,SequentialCopperplate}

    simulationspec::SequentialCopperplate
    system::SystemModel{N,L,T,P,E}
    rngs::Vector{MersenneTwister}

    gens_available::Vector{Vector{Bool}}
    gens_nexttransition::Vector{Vector{Int}}

    stors_available::Vector{Vector{Bool}}
    stors_nexttransition::Vector{Vector{Int}}
    stors_energy::Vector{Vector{Int}} 

end

function cache(
    simulationspec::SequentialCopperplate,
    system::SystemModel, seed::UInt)

    nthreads = Threads.nthreads()

    ngens = length(system.generators)
    nstors = length(system.storages)

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)

    gens_available = Vector{Vector{Bool}}(undef, nthreads)
    gens_nexttransition = Vector{Vector{Int}}(undef, nthreads)

    stors_available = Vector{Vector{Bool}}(undef, nthreads)
    stors_nexttransition = Vector{Vector{Int}}(undef, nthreads)
    stors_energy = Vector{Vector{Int}}(undef, nthreads)

    Threads.@threads for i in 1:nthreads

        rngs[i] = copy(rngs_temp[i])

        gens_available[i] = Vector{Bool}(undef, ngens)
        gens_nexttransition[i] = Vector{Int}(undef, ngens)

        stors_available[i] = Vector{Bool}(undef, nstors)
        stors_nexttransition[i] = Vector{Int}(undef, nstors)
        stors_energy[i] = Vector{Int}(undef, nstors)

    end

    return SequentialCopperplateCache(
        simulationspec, system, rngs,
        gens_available, gens_nexttransition,
        stors_available, stors_nexttransition, stors_energy)

end

function assess!(
    cache::SequentialCopperplateCache{N,L,T,P,E},
    acc::ResultAccumulator, i::Int
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    threadid = Threads.threadid()

    rng = cache.rngs[threadid]

    gens = cache.system.generators
    gens_available = cache.gens_available[threadid]
    gens_nexttransition = cache.gens_nexttransition[threadid]
    all_gens = (1, length(gens))

    stors = cache.system.storages
    stors_available = cache.stors_available[threadid]
    stors_nexttransition = cache.stors_nexttransition[threadid]
    stors_energy = cache.stors_energy[threadid]
    all_stors = (1, length(stors))

    sample = SystemOutputStateSample{L,T,P}(Int[], Int[], 1) # Preallocate?

    # Initialize generator and storage state vector
    # based on long-run probabilities from period 1
    initialize_availability!(rng, gens_available, gens_nexttransition, gens, N)
    initialize_availability!(rng, stors_available, stors_nexttransition, stors, N)

    # Initialize storage devices as empty
    fill!(stors_energy, 0)

    # Main simulation loop
    for t in 1:N

        update_availability!(
            rng, gens_available, gens_nexttransition, gens, t, N)

        update_availability!(
            rng, stors_available, stors_nexttransition, stors, t, N)

        decay_energy!(stors_energy, stors, t)

        residual_generation = available_capacity(
            gens_available, gens, all_gens, t)
        residual_generation -= colsum(cache.system.regions.load, t)

        if residual_generation >= 0

            # Charge to consume residual_generation
            surplus = charge_storage!(
                stors_available, stors_energy, residual_generation,
                stors, all_stors, t)
            sample.regions[1] = RegionResult{L,T,P}(
                residual_generation, surplus, 0.)

        else

            # Discharge to meet residual_generation shortfall
            shortfall = discharge_storage!(
                stors_available, stors_energy, -residual_generation,
                stors, all_stors, t)
            sample.regions[1] = RegionResult{L,T,P}(
                residual_generation, 0., shortfall)

        end

        update!(acc, sample, t, i)

    end

end
