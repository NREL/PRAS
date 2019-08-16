abstract type AbstractAssets{L,T<:Period,P<:PowerUnit} end

struct Generators{L,T<:Period,P<:PowerUnit} <: AbstractAssets{L,T,P}

    name::Vector{String}
    category::Vector{String}

    capacity::Matrix{Int} # power

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Generators{L,T,P}(
        name::Vector{String}, category::Vector{String},
        capacity::Matrix{Int}, λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {L,T,P}

        n_gens = length(name)
        n_periods = size(capacity, 2)

        @assert length(category) == n_gens
        @assert size(capacity) == (n_gens, n_periods)
        @assert all(capacity .>= 0) # Why not just use unsigned integers?

        @assert size(λ) == (n_gens, n_periods)
        @assert size(μ) == (n_gens, n_periods)
        @assert all(0 .<= λ .<= 1)
        @assert all(0 .<= μ .<= 1)

        new{L,T,P}(name, category, capacity, λ, μ)

    end

end

struct Storages{L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractAssets{L,T,P}

    name::Vector{String}
    category::Vector{String}

    chargecapacity::Matrix{Int} # power
    dischargecapacity::Matrix{Int} # power
    energycapacity::Matrix{Int} # energy
    chargeefficiency::Matrix{Float64}
    dischargeefficiency::Matrix{Float64}
    carryoverefficiency::Matrix{Float64}

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Storages{L,T,P,E}(
        name::Vector{String}, category::Vector{String},
        chargecapacity::Matrix{Int}, dischargecapacity::Matrix{Int},
        energycapacity::Matrix{Int}, chargeefficiency::Matrix{Int},
        dischargeefficiency::Matrix{Float64}, carryoverefficiency::Matrix{Float64},
        λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {L,T,P,E}

        n_stors = length(name)
        n_periods = size(capacity, 2)

        @assert length(category) == n_gens

        @assert size(chargecapacity) == (n_gens, n_periods)
        @assert size(dischargecapacity) == (n_gens, n_periods)
        @assert size(energycapacity) == (n_gens, n_periods)
        @assert all(chargecapacity .>= 0)
        @assert all(dischargecapacity .>= 0)
        @assert all(energycapacity .>= 0)

        @assert size(chargeefficiency) == (n_gens, n_periods)
        @assert size(dischargeefficiency) == (n_gens, n_periods)
        @assert size(carryoverefficiency) == (n_gens, n_periods)
        @assert all(0 .<= chargeefficiency .<= 1)
        @assert all(0 .<= dischargeefficiency .<= 1)
        @assert all(0 .<= carryoverefficiency .<= 1)

        @assert size(λ) == (n_gens, n_periods)
        @assert size(μ) == (n_gens, n_periods)
        @assert all(0 .<= λ .<= 1)
        @assert all(0 .<= μ .<= 1)

        new{L,T,P,E}(name, category,
                     chargecapacity, dischargecapacity, energycapacity,
                     chargeefficiency, dischargeefficiency, carryoverefficiency,
                     λ, μ)

    end

end

struct GeneratorStorages{L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractAssets{L,T,P}

    name::Vector{String}
    category::Vector{String}

    inflowcapacity::Matrix{Int} # power
    chargecapacity::Matrix{Int} # power
    dischargecapacity::Matrix{Int} # power
    storage_chargecapacity::Matrix{Int} # power
    storage_dischargecapacity::Matrix{Int} # power
    storage_energycapacity::Matrix{Int} # energy
    storage_chargeefficiency::Matrix{Float64}
    storage_dischargeefficiency::Matrix{Float64}
    storage_carryoverefficiency::Matrix{Float64}

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function GeneratorStorages{L,T,P,E}(
        name::Vector{String}, category::Vector{String}, inflowcapacity::Matrix{Int},
        chargecapacity::Matrix{Int}, dischargecapacity::Matrix{Int},
        storage_chargecapacity::Matrix{Int}, storage_dischargecapacity::Matrix{Int},
        storage_energycapacity::Matrix{Int}, storage_chargeefficiency::Matrix{Int},
        storage_dischargeefficiency::Matrix{Float64}, storage_carryoverefficiency::Matrix{Float64},
        λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {L,T,P,E}

        n_stors = length(name)
        n_periods = size(capacity, 2)

        @assert length(category) == n_gens

        @assert size(inflowcapacity) == (n_gens, n_periods)
        @assert size(chargecapacity) == (n_gens, n_periods)
        @assert size(dischargecapacity) == (n_gens, n_periods)
        @assert all(inflowcapacity .>= 0)
        @assert all(chargecapacity .>= 0)
        @assert all(dischargecapacity .>= 0)

        @assert size(storage_chargecapacity) == (n_gens, n_periods)
        @assert size(storage_dischargecapacity) == (n_gens, n_periods)
        @assert size(storage_energycapacity) == (n_gens, n_periods)
        @assert all(storage_chargecapacity .>= 0)
        @assert all(storage_dischargecapacity .>= 0)
        @assert all(storage_energycapacity .>= 0)

        @assert size(storage_chargeefficiency) == (n_gens, n_periods)
        @assert size(storage_dischargeefficiency) == (n_gens, n_periods)
        @assert size(storage_carryoverefficiency) == (n_gens, n_periods)
        @assert all(0 .<= storage_chargeefficiency .<= 1)
        @assert all(0 .<= storage_dischargeefficiency .<= 1)
        @assert all(0 .<= storage_carryoverefficiency .<= 1)

        @assert size(λ) == (n_gens, n_periods)
        @assert size(μ) == (n_gens, n_periods)
        @assert all(0 .<= λ .<= 1)
        @assert all(0 .<= μ .<= 1)

        new{L,T,P,E}(name, category,
                     inflowcapacity, chargecapacity, dischargecapacity,
                     storage_chargecapacity, storage_dischargecapacity,
                     storage_energycapacity,
                     storage_chargeefficiency, storage_dischargeefficiency,
                     storage_carryoverefficiency,
                     λ, μ)

    end

end

struct Lines{L,T<:Period,P<:PowerUnit} <: AbstractAssets{L,T,P}

    name::Vector{String}
    category::Vector{String}

    forwardcapacity::Matrix{Int} # power
    backwardcapacity::Matrix{Int} # power

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Lines{L,T,P}(
        name::Vector{String}, category::Vector{String},
        forwardcapacity::Matrix{Int}, backwardcapacity::Matrix{Int},
        λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {L,T,P}

        n_gens = length(name)
        n_periods = size(capacity, 2)

        @assert length(category) == n_gens
        @assert size(forwardcapacity) == (n_gens, n_periods)
        @assert size(backwardcapacity) == (n_gens, n_periods)
        @assert all(forwardcapacity .>= 0)
        @assert all(backwardcapacity .>= 0)

        @assert size(λ) == (n_gens, n_periods)
        @assert size(μ) == (n_gens, n_periods)
        @assert all(0 .<= λ .<= 1)
        @assert all(0 .<= μ .<= 1)

        new{L,T,P}(name, category, forwardcapacity, backwardcapacity, λ, μ)

    end

end
