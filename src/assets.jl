abstract type AbstractAssets{N,L,T<:Period,P<:PowerUnit} end
Base.length(a::AbstractAssets) = length(a.names)

struct Generators{N,L,T<:Period,P<:PowerUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    capacity::Matrix{Int} # power

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Generators{N,L,T,P}(
        names::Vector{String}, categories::Vector{String},
        capacity::Matrix{Int}, λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {N,L,T,P}

        n_gens = length(names)
        @assert length(categories) == n_gens
        @assert allunique(names)

        @assert size(capacity) == (n_gens, N)
        @assert all(capacity .>= 0) # Why not just use unsigned integers?

        @assert size(λ) == (n_gens, N)
        @assert size(μ) == (n_gens, N)
        @assert all(0 .<= λ .<= 1)
        @assert all(0 .<= μ .<= 1)

        new{N,L,T,P}(names, categories, capacity, λ, μ)

    end

end

struct Storages{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    chargecapacity::Matrix{Int} # power
    dischargecapacity::Matrix{Int} # power
    energycapacity::Matrix{Int} # energy
    chargeefficiency::Matrix{Float64}
    dischargeefficiency::Matrix{Float64}
    carryoverefficiency::Matrix{Float64}

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Storages{N,L,T,P,E}(
        names::Vector{String}, categories::Vector{String},
        chargecapacity::Matrix{Int}, dischargecapacity::Matrix{Int},
        energycapacity::Matrix{Int}, chargeefficiency::Matrix{Float64},
        dischargeefficiency::Matrix{Float64}, carryoverefficiency::Matrix{Float64},
        λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {N,L,T,P,E}

        n_stors = length(names)
        @assert length(categories) == n_stors
        @assert allunique(names)

        @assert size(chargecapacity) == (n_stors, N)
        @assert size(dischargecapacity) == (n_stors, N)
        @assert size(energycapacity) == (n_stors, N)
        @assert all(chargecapacity .>= 0)
        @assert all(dischargecapacity .>= 0)
        @assert all(energycapacity .>= 0)

        @assert size(chargeefficiency) == (n_stors, N)
        @assert size(dischargeefficiency) == (n_stors, N)
        @assert size(carryoverefficiency) == (n_stors, N)
        @assert all(0 .<= chargeefficiency .<= 1)
        @assert all(0 .<= dischargeefficiency .<= 1)
        @assert all(0 .<= carryoverefficiency .<= 1)

        @assert size(λ) == (n_stors, N)
        @assert size(μ) == (n_stors, N)
        @assert all(0 .<= λ .<= 1)
        @assert all(0 .<= μ .<= 1)

        new{N,L,T,P,E}(names, categories,
                       chargecapacity, dischargecapacity, energycapacity,
                       chargeefficiency, dischargeefficiency, carryoverefficiency,
                       λ, μ)

    end

end

struct GeneratorStorages{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

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

    function GeneratorStorages{N,L,T,P,E}(
        names::Vector{String}, categories::Vector{String}, inflowcapacity::Matrix{Int},
        chargecapacity::Matrix{Int}, dischargecapacity::Matrix{Int},
        storage_chargecapacity::Matrix{Int}, storage_dischargecapacity::Matrix{Int},
        storage_energycapacity::Matrix{Int}, storage_chargeefficiency::Matrix{Float64},
        storage_dischargeefficiency::Matrix{Float64}, storage_carryoverefficiency::Matrix{Float64},
        λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {N,L,T,P,E}

        n_stors = length(names)
        @assert length(categories) == n_stors
        @assert allunique(names)

        @assert size(inflowcapacity) == (n_stors, N)
        @assert size(chargecapacity) == (n_stors, N)
        @assert size(dischargecapacity) == (n_stors, N)
        @assert all(inflowcapacity .>= 0)
        @assert all(chargecapacity .>= 0)
        @assert all(dischargecapacity .>= 0)

        @assert size(storage_chargecapacity) == (n_stors, N)
        @assert size(storage_dischargecapacity) == (n_stors, N)
        @assert size(storage_energycapacity) == (n_stors, N)
        @assert all(storage_chargecapacity .>= 0)
        @assert all(storage_dischargecapacity .>= 0)
        @assert all(storage_energycapacity .>= 0)

        @assert size(storage_chargeefficiency) == (n_stors, N)
        @assert size(storage_dischargeefficiency) == (n_stors, N)
        @assert size(storage_carryoverefficiency) == (n_stors, N)
        @assert all(0 .<= storage_chargeefficiency .<= 1)
        @assert all(0 .<= storage_dischargeefficiency .<= 1)
        @assert all(0 .<= storage_carryoverefficiency .<= 1)

        @assert size(λ) == (n_stors, N)
        @assert size(μ) == (n_stors, N)
        @assert all(0 .<= λ .<= 1)
        @assert all(0 .<= μ .<= 1)

        new{N,L,T,P,E}(names, categories,
                       inflowcapacity, chargecapacity, dischargecapacity,
                       storage_chargecapacity, storage_dischargecapacity,
                       storage_energycapacity,
                       storage_chargeefficiency, storage_dischargeefficiency,
                       storage_carryoverefficiency,
                       λ, μ)

    end

end

struct Lines{N,L,T<:Period,P<:PowerUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    forwardcapacity::Matrix{Int} # power
    backwardcapacity::Matrix{Int} # power

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Lines{N,L,T,P}(
        names::Vector{String}, categories::Vector{String},
        forwardcapacity::Matrix{Int}, backwardcapacity::Matrix{Int},
        λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {N,L,T,P}

        n_lines = length(names)
        @assert length(categories) == n_lines
        @assert allunique(names)

        @assert size(forwardcapacity) == (n_lines, N)
        @assert size(backwardcapacity) == (n_lines, N)
        @assert all(forwardcapacity .>= 0)
        @assert all(backwardcapacity .>= 0)

        @assert size(λ) == (n_lines, N)
        @assert size(μ) == (n_lines, N)
        @assert all(0 .<= λ .<= 1)
        @assert all(0 .<= μ .<= 1)

        new{N,L,T,P}(names, categories, forwardcapacity, backwardcapacity, λ, μ)

    end

end
