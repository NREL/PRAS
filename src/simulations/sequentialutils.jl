function update_availability!(rng::MersenneTwister, availability::Vector{Bool},
                              devices::Matrix{<:AssetSpec}, s::Int)

    @inbounds for i in 1:length(availability)

        d = devices[i, s]

        if availability[i] # Unit is online
            rand(rng) < d.λ && (availability[i] = false) # Unit fails
        else # Unit is offline
            rand(rng) < d.μ && (availability[i] = true) # Unit is repaired
        end

    end

end

function decay_energy!(
    stors_energy::Vector{V},
    stors::Matrix{StorageDeviceSpec{V}},
    s::Int
) where {V<:Real}

    for i in 1:length(stors_energy)
        stor = stors[i, s]
        stors_energy[i] *= stor.decayrate
    end

end

function available_capacity(
    availability::Vector{Bool},
    assets::Matrix{<:AssetSpec{T}},
    i_bounds::Tuple{Int,Int}, s::Int
) where {T <: Real}

    capacity = zero(T)

    for i in first(i_bounds):last(i_bounds)
        availability[i] && (capacity += assets[i, s].capacity)
    end

    return capacity

end

function available_storage_capacity(
    L::Int,
    T::Type{<:Period},
    P::Type{<:PowerUnit},
    E::Type{<:EnergyUnit},
    stors_available::Vector{Bool},
    stors_energy::Vector{V},
    stors::Matrix{StorageDeviceSpec{V}},
    i_bounds::Tuple{Int,Int}, s::Int
) where {V <: Real}

    charge_capacity = zero(V)
    discharge_capacity = zero(V)

    for i in first(i_bounds):last(i_bounds)
        if stors_available[i]
            stor = stors[i, s]
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
    stors_available::Vector{Bool},
    stors_energy::Vector{V},
    surplus::V,
    stors::Matrix{StorageDeviceSpec{V}},
    stors_range::Tuple{Int,Int}, stor_set::Int
) where {V<:Real}

    # TODO: Replace with copperplate charging from Evans et al

    surplus = powertoenergy(surplus, L, T, P, E)

    for i in first(stors_range):last(stors_range)

        stor = stors[i, stor_set]

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
    stors_available::Vector{Bool},
    stors_energy::Vector{V},
    shortfall::V,
    stors::Matrix{StorageDeviceSpec{V}},
    stor_range::Tuple{Int,Int}, stor_set::Int
) where {V<:Real}

    # TODO: Replace with optimal copperplate charging from Evans et al

    shortfall = powertoenergy(shortfall, L, T, P, E)

    for i in first(stor_range):last(stor_range)

        stor = stors[i, stor_set]

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
