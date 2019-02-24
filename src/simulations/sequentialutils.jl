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
