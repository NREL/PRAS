struct SequentialCopperplate <: SimulationSpec{Sequential}
    nsamples::Int

    function SequentialCopperplate(nsamples::Int)
        @assert nsamples > 0
        new(nsamples)
    end
end

iscopperplate(::SequentialCopperplate) = true

function assess_singlesequence!(
    shortfalls::AbstractVector{V},
    rng::MersenneTwister,
    extractionspec::Backcast, #TODO: Generalize
    simulationspec::SequentialCopperplate,
    resultspec::MinimalResult, #TODO: Generalize
    sys::SystemModel{N1,T1,N2,T2,P,E,V}
) where {N1,T1,N2,T2,P,E,V}

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

        netload = sum(view(sys.load, :, t)) - sum(view(sys.vg, :, t))

        dispatchable_gen_available = available_capacity!(
            rng, gens_available, view(sys.generators, :, gen_set))

        # println("Net Load: ", netload, "\t",
        #         "Dispatchable Gen: ", dispatchable_gen_available)
        residual_generation = dispatchable_gen_available - netload

        if residual_generation >= 0

            # Charge to consume residual_generation
            charge_storage!(rng, stors_available, stors_energy,
                            residual_generation,
                            view(sys.storages, :, stor_set))

        else

            # Discharge to meet residual_generation shortfall
            shortfall = discharge_storage!(
                rng, stors_available, stors_energy,
                -residual_generation, view(sys.storages, :, stor_set))

            # Report remaining shortfall, if any
            shortfall > 0 && (shortfalls[t] = shortfall)

        end

    end

end

function available_capacity!(rng::MersenneTwister,
                             gen_availability::Vector{Bool},
                             generators::AbstractVector{DispatchableGeneratorSpec{T}}
                             ) where {T <: Real}

    capacity = zero(T)

    @inbounds for i in 1:length(gen_availability)
        gen = generators[i]
        if gen_availability[i]
            if rand(rng) > gen.λ # Unit doesn't fail, count capacity
                capacity += gen.capacity
            else # Unit fails, ignore its capacity
                gen_availability[i] = false
            end
        else
            if rand(rng) < gen.μ # Unit is repaired, count its capacity
                gen_availability[i] = true
                capacity += gen.capacity
            end
        end
    end

    return capacity

end

function charge_storage!(rng::MersenneTwister,
                         stors_available::Vector{Bool},
                         stors_energy::Vector{T},
                         surplus::T,
                         stors::AbstractVector{StorageDeviceSpec{T}}
                         ) where {T <: Real}

    # TODO: Replace with strategic charging
    # TODO: Stop assuming hourly periods

    for (i, stor) in enumerate(stors)

        stors_energy[i] *= stor.decayrate

        if stors_available[i]

            if rand(rng) > stor.λ # Unit doesn't fail

                max_charge = stor.energy - stors_energy[i]

                if surplus > max_charge # Fully charge

                    stors_energy[i] = stor.energy
                    surplus -= max_charge

                else # Partially charge

                    stors_energy[i] += surplus
                    return

                end

            else # Unit fails
                stors_available[i] = false
            end

        else

            if rand(rng) < stor.μ # Unit is repaired
                stors_available[i] = true

                max_charge = stor.energy - stors_energy[i]

                if surplus > max_charge # Fully charge

                    stors_energy[i] = stor.energy
                    surplus -= max_charge

                else # Partially charge

                    stors_energy[i] += surplus
                    return

                end

            end
        end
    end

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

        stors_energy[i] *= stor.decayrate

        if stors_available[i]

            if rand(rng) > stor.λ # Unit doesn't fail

                max_discharge = stors_energy[i]

                if shortfall > max_discharge # Fully discharge

                    stors_energy[i] = 0
                    shortfall -= max_discharge

                else # Partially discharge

                    stors_energy[i] -= shortfall
                    return zero(T)

                end

            else # Unit fails
                stors_available[i] = false
            end

        else

            if rand(rng) < stor.μ # Unit is repaired

                stors_available[i] = true

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
    end

    return shortfall

end
