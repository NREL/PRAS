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
    stors_available::AbstractVector{Bool},
    stors_energy::AbstractVector{Bool},
    stors::AbstractVector{StorageDeviceSpec{T}}
) where {T <: Real}

    charge_capacity = zero(T)
    discharge_capacity = zero(T)

    for i in length(stors)
        if availability[i]
            stor_energy = stors_energy[i]
            max_power = powertoenergy(stor.capacity, L, T, P, E)
            charge_capacity += min(max_power, stor.energy - stor_energy)
            discharge_capacity += min(max_power, stor_energy)
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

            max_charge_power = powertoenergy(stor.capacity, L, T, P, E)
            max_charge_energy = stor.energy - stors_energy[i]
            max_charge = min(max_charge_power, max_charge_energy)

            if surplus > max_charge # Fully charge

                stors_energy[i] = stor.energy
                surplus -= max_charge

            else # Partially charge

                stors_energy[i] += surplus
                return zero(V)

            end

        end

    end

    return surplus

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

            max_discharge_power = powertoenergy(stor.capacity, L, T, P, E)
            max_discharge_energy = stors_energy[i]
            max_discharge = min(max_discharge_power, max_discharge_energy)

            if shortfall > max_discharge # Fully discharge

                stors_energy[i] = 0
                shortfall -= max_discharge

            else # Partially discharge

                stors_energy[i] -= shortfall
                return zero(V)

            end

        end

    end

    return shortfall

end
