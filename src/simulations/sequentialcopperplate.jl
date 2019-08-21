struct SequentialCopperplate <: SimulationSpec{Sequential}
    nsamples::Int

    function SequentialCopperplate(nsamples::Int)
        @assert nsamples > 0
        new(nsamples)
    end
end

iscopperplate(::SequentialCopperplate) = true

function assess!(
    acc::ResultAccumulator,
    extractionspec::Backcast, #TODO: Generalize
    simulationspec::SequentialCopperplate,
    sys::SystemModel{N,L,T,P,E},
    i::Int
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    threadid = Threads.threadid()

    rng = acc.rngs[threadid]

    gens_available = acc.gens_available[threadid]
    stors_available = acc.stors_available[threadid]
    stors_energy = acc.stors_energy[threadid]

    ngens = length(sys.generators)
    nstors = length(sys.storages)

    sample = SystemOutputStateSample{L,T,P}(Int[], Int[], 1) # Preallocate?

    # Initialize generator and storage state vector
    # based on long-run probabilities from period 1

    for i in 1:ngens
        μ = sys.generators.μ[i, 1]
        λ = sys.generators.λ[i, 1]
        gens_available[i] = rand(rng) < μ / (λ + μ)
    end

    for i in 1:nstors
        μ = sys.storages.μ[i, 1]
        λ = sys.storages.λ[i, 1]
        stors_available[i] = rand(rng) < μ / (λ + μ)
    end

    fill!(stors_energy, 0)

    all_gens = (1, ngens)
    all_stors = (1, nstors)

    # Main simulation loop
    for t in 1:N

        update_availability!(rng, gens_available, sys.generators, t)
        update_availability!(rng, stors_available, sys.storages, t)
        decay_energy!(stors_energy, sys.storages, t)

        residual_generation = available_capacity(gens_available, sys.generators, all_gens, t)
        residual_generation -= colsum(sys.regions.load, t)

        if residual_generation >= 0

            # Charge to consume residual_generation
            surplus = charge_storage!(
                stors_available, stors_energy, residual_generation, sys.storages, all_stors, t)
            sample.regions[1] = RegionResult{L,T,P}(
                residual_generation, surplus, 0.)

        else

            # Discharge to meet residual_generation shortfall
            shortfall = discharge_storage!(
                stors_available, stors_energy, -residual_generation, sys.storages, all_stors, t)
            sample.regions[1] = RegionResult{L,T,P}(residual_generation, 0., shortfall)

        end

        update!(acc, sample, t, i)

    end

end
