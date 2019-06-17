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
    sys::SystemModel{N,L,T,P,E,V},
    i::Int
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit,V}

    rng = acc.rngs[Threads.threadid()]
    sample = SystemOutputStateSample{L,T,P,V}(Tuple{Int,Int}[], 1) # Preallocate?

    # Initialize generator and storage state vector
    # based on long-run probabilities from period 1
    # Note: Could pre-allocate these once per thread?
    gens_available = Bool[rand(rng) < gen.μ /(gen.λ + gen.μ)
                         for gen in view(sys.generators, :, 1)]
    stors_available = Bool[rand(rng) < stor.μ / (stor.λ + stor.μ)
                          for stor in view(sys.storages, :, 1)]
    stors_energy = zeros(V, size(sys.storages, 1))

    # Main simulation loop
    for (t, (gen_set, stor_set)) in enumerate(zip(
        sys.timestamps_generatorset, sys.timestamps_storageset))

        gens = view(sys.generators, :, gen_set)
        stors = view(sys.storages, :, stor_set)

        update_availability!(rng, gens_available, gens)
        update_availability!(rng, stors_available, stors)
        decay_energy!(stors_energy, stors)

        dispatchable_gen_available = available_capacity(gens_available, gens)
        netload = colsum(sys.load, t) - colsum(sys.vg, t)
        residual_generation = dispatchable_gen_available - netload

        if residual_generation >= 0

            # Charge to consume residual_generation
            surplus = charge_storage!(
                L, T, P, E,
                stors_available, stors_energy, residual_generation, stors)
            sample.regions[1] = RegionResult{L,T,P}(
                residual_generation, surplus, 0.)

        else

            # Discharge to meet residual_generation shortfall
            shortfall = discharge_storage!(
                L, T, P, E,
                stors_available, stors_energy, -residual_generation, stors)
            sample.regions[1] = RegionResult{L,T,P}(residual_generation, 0., shortfall)

        end

        update!(acc, sample, t, i)

    end

end
