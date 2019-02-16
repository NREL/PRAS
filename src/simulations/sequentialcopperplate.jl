struct SequentialCopperplate <: SimulationSpec{Sequential}
    nsamples::Int

    function SequentialCopperplate(nsamples::Int)
        @assert nsamples > 0
        new(nsamples)
    end
end

iscopperplate(::SequentialCopperplate) = true

function assess_singlesequence!(
    acc::ResultAccumulator,
    extractionspec::Backcast, #TODO: Generalize
    simulationspec::SequentialCopperplate,
    sys::SystemModel{N1,T1,N2,T2,P,E,V},
    i::Int
) where {N1,T1,N2,T2,P,E,V}

    rng = acc.rng[Threads.threadid()]
    sample = SystemOutputStateSample(Vector{Tuple{Int,Int}}[], 1)

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

        dispatchable_gen_available = available_gen_capacity(gens_available, gens)
        netload = sum(view(sys.load, :, t)) - sum(view(sys.vg, :, t))

        residual_generation = dispatchable_gen_available - netload

        if residual_generation >= 0

            # Charge to consume residual_generation
            residual_generation = charge_storage!(stors_available, stors_energy,
                                                  residual_generation, stors)
            sample.regions[1] = RegionResult{L,T,P}(residual_generation, residual_generation, 0.)

        else

            # Discharge to meet residual_generation shortfall
            shortfall = discharge_storage!(stors_available, stors_energy,
                                           -residual_generation, stors)
            sample.regions[1] = RegionResult{L,T,P}(shortfall, 0., shortfall)

        end

        update!(acc, sample, t, i)

    end


end

function update_availability!(rng::MersenneTwister, availability::Vector{Bool},
                              devices::AbstractVector{<:AssetSpec})

    @inbounds for i in 1:length(availability)

        a = assets[i]

        if availability[i] # Unit is online
            rand(rng) < a.λ && (availability[i] = false) # Unit fails
        else # Unit is offline
            rand(rng) < a.μ && (availability[i] = true) # Unit is repaired
        end

    end

end

function available_gen_capacity(
    rng::MersenneTwister,
    gen_availability::Vector{Bool},
    generators::AbstractVector{DispatchableGeneratorSpec{T}}
) where {T <: Real}

    capacity = zero(T)

    @inbounds for i in 1:length(gen_availability)
        gen_availability[i] && (capacity += generators[i].capacity)
    end

    return capacity

end

function decay_energy!(stors_energy::Vector{V},
                       stors::AbstractVector{StorageDeviceSpec{V}}
) where {V<:Real}

    for (i, stor) in enumerate(stors)
        stors_energy[i] *= stor.decayrate
    end

end

function charge_storage!(stors_available::Vector{Bool},
                         stors_energy::Vector{T},
                         surplus::T,
                         stors::AbstractVector{StorageDeviceSpec{T}}
                         ) where {T <: Real}

    # TODO: Replace with strategic charging
    # TODO: Stop assuming hourly periods

    for (i, stor) in enumerate(stors)

        if stors_available[i]

            max_charge = stor.energy - stors_energy[i]

            # TODO: This is wrong, need to consider max charge rate
            if surplus > max_charge # Fully charge

                stors_energy[i] = stor.energy
                surplus -= max_charge

            else # Partially charge

                stors_energy[i] += surplus
                return zero(T)

            end

        end

    end

    return surplus

end

function discharge_storage!(rng::MersenneTwister,
                            stors_available::Vector{Bool},
                            stors_energy::Vector{T},
                            shortfall::T,
                            stors::AbstractVector{StorageDeviceSpec{T}}
                           ) where {T <: Real}

    # TODO: Replace with strategic discharging
    # TODO: Stop assuming hourly periods

    for (i, stor) in enumerate(stors)

        if stors_available[i]

            # TODO: This is wrong, need to consider max charge rate
            max_discharge = stors_energy[i]

            if shortfall > max_discharge # Fully discharge

                stors_energy[i] = 0
                shortfall -= max_discharge

            else # Partially discharge

                stors_energy[i] -= shortfall
                return zero(T)

            end

        end

    end

    return shortfall

end
