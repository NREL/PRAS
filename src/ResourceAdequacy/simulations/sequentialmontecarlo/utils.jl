function initialize_availability!(
    rng::AbstractRNG,
    availability::Vector{Bool}, nexttransition::Vector{Int},
    devices::AbstractAssets, t_last::Int)

    for i in 1:length(devices)

        λ = devices.λ[i, 1]
        μ = devices.μ[i, 1]
        online = rand(rng) < μ / (λ + μ)

        availability[i] = online

        transitionprobs = online ? devices.λ : devices.μ
        nexttransition[i] = randtransitiontime(
            rng, transitionprobs, i, 1, t_last)

    end

    return availability

end

function update_availability!(
    rng::AbstractRNG,
    availability::Vector{Bool}, nexttransition::Vector{Int},
    devices::AbstractAssets, t_now::Int, t_last::Int)

    for i in 1:length(devices)

        if nexttransition[i] == t_now # Unit switches states
            transitionprobs = (availability[i] ⊻= true) ? devices.λ : devices.μ
            nexttransition[i] = randtransitiontime(
                rng, transitionprobs, i, t_now, t_last)
        end

    end

end

function randtransitiontime(
    rng::AbstractRNG, p::Matrix{Float64},
    i::Int, t_now::Int, t_last::Int
)

    cdf = 0.
    p_noprevtransition = 1.

    x = rand(rng)
    t = t_now + 1

    while t <= t_last
        p_it = p[i,t]
        cdf += p_noprevtransition * p_it
        x < cdf && return t
        p_noprevtransition *= (1. - p_it)
        t += 1
    end

    return t_last + 1

end

function available_capacity(
    availability::Vector{Bool},
    lines::Lines,
    idxs::UnitRange{Int}, t::Int
)

    avcap_forward = 0
    avcap_backward = 0

    for i in idxs
        if availability[i]
            avcap_forward += lines.forward_capacity[i, t]
            avcap_backward += lines.backward_capacity[i, t]
        end
    end

    return avcap_forward, avcap_backward

end

function available_capacity(
    availability::Vector{Bool},
    gens::Generators,
    idxs::UnitRange{Int}, t::Int
)

    caps = gens.capacity
    avcap = 0

    for i in idxs
        availability[i] && (avcap += caps[i, t])
    end

    return avcap

end

function update_energy!(
    stors_energy::Vector{Int},
    stors::AbstractAssets,
    t::Int
)

    for i in 1:length(stors_energy)

        soc = stors_energy[i]
        efficiency = stors.carryover_efficiency[i,t]
        maxenergy = stors.energy_capacity[i,t]

        # Decay SoC
        soc = round(Int, soc * efficiency)

        # Shed SoC above current energy limit
        stors_energy[i] = min(soc, maxenergy)

    end

end

function maxtimetocharge_discharge(system::SystemModel)

    if length(system.storages) > 0

        if any(iszero, system.storages.charge_capacity)
            stor_charge_max = length(system.timestamps) + 1
        else
            stor_charge_durations =
                system.storages.energy_capacity ./ system.storages.charge_capacity
            stor_charge_max = ceil(Int, maximum(stor_charge_durations))
        end

        if any(iszero, system.storages.discharge_capacity)
            stor_discharge_max = length(system.timestamps) + 1
        else
            stor_discharge_durations =
                system.storages.energy_capacity ./ system.storages.discharge_capacity
            stor_discharge_max = ceil(Int, maximum(stor_discharge_durations))
        end

    else

        stor_charge_max = 0
        stor_discharge_max = 0

    end

    if length(system.generatorstorages) > 0

        if any(iszero, system.generatorstorages.charge_capacity)
            genstor_charge_max = length(system.timestamps) + 1
        else
            genstor_charge_durations =
                system.generatorstorages.energy_capacity ./ system.generatorstorages.charge_capacity
            genstor_charge_max = ceil(Int, maximum(genstor_charge_durations))
        end

        if any(iszero, system.generatorstorages.discharge_capacity)
            genstor_discharge_max = length(system.timestamps) + 1
        else
            genstor_discharge_durations =
                system.generatorstorages.energy_capacity ./ system.generatorstorages.discharge_capacity
            genstor_discharge_max = ceil(Int, maximum(genstor_discharge_durations))
        end

    else

        genstor_charge_max = 0
        genstor_discharge_max = 0

    end

    return (max(stor_charge_max, genstor_charge_max),
            max(stor_discharge_max, genstor_discharge_max))

end
