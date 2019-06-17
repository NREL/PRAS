function update_availability!(rng::MersenneTwister, availability::Vector{Bool},
                              devices::AbstractVector{<:AssetSpec})

    @inbounds for i in 1:length(availability)

        d = devices[i]

        if availability[i] # Unit is online
            rand(rng) < d.λ && (availability[i] = false) # Unit fails
        else # Unit is offline
            rand(rng) < d.μ && (availability[i] = true) # Unit is repaired
        end

    end

end

function decay_energy!(
    stors_energy::Vector{V},
    stors::AbstractVector{StorageDeviceSpec{V}}
) where {V<:Real}

    for (i, stor) in enumerate(stors)
        stors_energy[i] *= stor.decayrate
    end

end

function available_capacity(
    availability::AbstractVector{Bool},
    assets::AbstractVector{<:AssetSpec{T}}
) where {T <: Real}

    capacity = zero(T)

    for i in 1:length(availability)
        availability[i] && (capacity += assets[i].capacity)
    end

    return capacity

end

function available_storage_capacity(
    L::Int,
    T::Type{<:Period},
    P::Type{<:PowerUnit},
    E::Type{<:EnergyUnit},
    stors_available::AbstractVector{Bool},
    stors_energy::AbstractVector{V},
    stors::AbstractVector{StorageDeviceSpec{V}}
) where {V <: Real}

    charge_capacity = zero(V)
    discharge_capacity = zero(V)

    for i in 1:length(stors)
        if stors_available[i]
            stor = stors[i]
            stor_energy = stors_energy[i]
            max_power = powertoenergy(stor.capacity, L, T, P, E)
            charge_capacity += min(stor.capacity, energytopower(stor.energy - stor_energy, L, T, P, E))
            discharge_capacity += min(stor.capacity, energytopower(stor_energy, L, T, P, E))
        end
    end

    return charge_capacity, discharge_capacity

end

function charge_storage!(
    L::Int,
    T::Type{<:Period},
    P::Type{<:PowerUnit},
    E::Type{<:EnergyUnit},
    stors_available::AbstractVector{Bool},
    stors_energy::AbstractVector{V},
    surplus::V,
    stors::AbstractVector{StorageDeviceSpec{V}}
) where {V<:Real}

    # TODO: Replace with copperplate charging from Evans et al

    surplus = powertoenergy(surplus, L, T, P, E)

    for (i, stor) in enumerate(stors)

        if stors_available[i]

            power_limit = powertoenergy(stor.capacity, L, T, P, E)
            energy_limit = stor.energy - stors_energy[i]

            if energy_limit <= min(power_limit, surplus) # Charge to full energy

                stors_energy[i] = stor.energy
                surplus -= energy_limit

            elseif power_limit <= min(energy_limit, surplus) # Charge at full power

                stors_energy[i] += power_limit
                surplus -= power_limit

            else # Surplus is exhausted, allocate the last of it and return

                stors_energy[i] += surplus
                return zero(V)

            end

        end

    end

    return energytopower(surplus, L, T, P, E)

end

function discharge_storage!(
    L::Int,
    T::Type{<:Period},
    P::Type{<:PowerUnit},
    E::Type{<:EnergyUnit},
    stors_available::AbstractVector{Bool},
    stors_energy::AbstractVector{V},
    shortfall::V,
    stors::AbstractVector{StorageDeviceSpec{V}}
) where {V<:Real}

    # TODO: Replace with optimal copperplate charging from Evans et al

    shortfall = powertoenergy(shortfall, L, T, P, E)

    for (i, stor) in enumerate(stors)

        if stors_available[i]

            power_limit = powertoenergy(stor.capacity, L, T, P, E)
            energy_limit = stors_energy[i]

            if energy_limit <= min(power_limit, shortfall) # Discharge to zero energy

                stors_energy[i] = 0
                shortfall -= energy_limit

            elseif power_limit <= min(energy_limit, shortfall) # Discharge at full power

                stors_energy[i] -= power_limit
                shortfall -= power_limit

            else # Shortfall is exhausted, allocate the last of it and return

                stors_energy[i] -= shortfall
                return zero(V)

            end

        end

    end

    return energytopower(shortfall, L, T, P, E)

end
