abstract type AbstractAssets{N,L,T<:Period,P<:PowerUnit} end
Base.length(a::AbstractAssets) = length(a.names)

struct Generators{N,L,T<:Period,P<:PowerUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    capacity::Matrix{Int} # power

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Generators{N,L,T,P}(
        names::Vector{<:AbstractString}, categories::Vector{<:AbstractString},
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

        new{N,L,T,P}(string.(names), string.(categories), capacity, λ, μ)

    end

end

Base.:(==)(x::T, y::T) where {T <: Generators} =
    x.names == y.names &&
    x.categories == y.categories &&
    x.capacity == y.capacity &&
    x.λ == y.λ &&
    x.μ == y.μ

Base.getindex(g::G, idxs::AbstractVector{Int}) where {G <: Generators} =
    G(g.names[idxs], g.categories[idxs],
      g.capacity[idxs, :], g.λ[idxs, :], g.μ[idxs, :])

function Base.vcat(gs::G...) where {N, L, T, P, G <: Generators{N,L,T,P}}

    n_gens = sum(length(g) for g in gs)

    names = Vector{String}(undef, n_gens)
    categories = Vector{String}(undef, n_gens)

    capacity = Matrix{Int}(undef, n_gens, N)

    λ = Matrix{Float64}(undef, n_gens, N)
    μ = Matrix{Float64}(undef, n_gens, N)

    last_idx = 0

    for g in gs

        n = length(g)
        rows = last_idx .+ (1:n)

        names[rows] = g.names
        categories[rows] = g.categories
        capacity[rows, :] = g.capacity
        λ[rows, :] = g.λ
        μ[rows, :] = g.μ

        last_idx += n

    end

    return Generators{N,L,T,P}(names, categories, capacity, λ, μ)

end

struct Storages{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    charge_capacity::Matrix{Int} # power
    discharge_capacity::Matrix{Int} # power
    energy_capacity::Matrix{Int} # energy

    charge_efficiency::Matrix{Float64}
    discharge_efficiency::Matrix{Float64}
    carryover_efficiency::Matrix{Float64}

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Storages{N,L,T,P,E}(
        names::Vector{<:AbstractString}, categories::Vector{<:AbstractString},
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
        @assert all(0 .< chargeefficiency .<= 1)
        @assert all(0 .< dischargeefficiency .<= 1)
        @assert all(0 .< carryoverefficiency .<= 1)

        @assert size(λ) == (n_stors, N)
        @assert size(μ) == (n_stors, N)
        @assert all(0 .<= λ .<= 1)
        @assert all(0 .<= μ .<= 1)

        new{N,L,T,P,E}(string.(names), string.(categories),
                       chargecapacity, dischargecapacity, energycapacity,
                       chargeefficiency, dischargeefficiency, carryoverefficiency,
                       λ, μ)

    end

end

Base.:(==)(x::T, y::T) where {T <: Storages} =
    x.names == y.names &&
    x.categories == y.categories &&
    x.charge_capacity == y.charge_capacity &&
    x.discharge_capacity == y.discharge_capacity &&
    x.energy_capacity == y.energy_capacity &&
    x.charge_efficiency == y.charge_efficiency &&
    x.discharge_efficiency == y.discharge_efficiency &&
    x.carryover_efficiency == y.carryover_efficiency &&
    x.λ == y.λ &&
    x.μ == y.μ

struct GeneratorStorages{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    charge_capacity::Matrix{Int} # power
    discharge_capacity::Matrix{Int} # power
    energy_capacity::Matrix{Int} # energy

    charge_efficiency::Matrix{Float64}
    discharge_efficiency::Matrix{Float64}
    carryover_efficiency::Matrix{Float64}

    inflow::Matrix{Int} # power
    gridwithdrawal_capacity::Matrix{Int} # power
    gridinjection_capacity::Matrix{Int} # power

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function GeneratorStorages{N,L,T,P,E}(
        names::Vector{<:AbstractString}, categories::Vector{<:AbstractString},
        charge_capacity::Matrix{Int}, discharge_capacity::Matrix{Int},
        energy_capacity::Matrix{Int},
        charge_efficiency::Matrix{Float64}, discharge_efficiency::Matrix{Float64},
        carryover_efficiency::Matrix{Float64},
        inflow::Matrix{Int},
        gridwithdrawal_capacity::Matrix{Int}, gridinjection_capacity::Matrix{Int},
        λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {N,L,T,P,E}

        n_stors = length(names)
        @assert length(categories) == n_stors
        @assert allunique(names)

        @assert size(charge_capacity) == (n_stors, N)
        @assert size(discharge_capacity) == (n_stors, N)
        @assert size(energy_capacity) == (n_stors, N)

        @assert all(charge_capacity .>= 0)
        @assert all(discharge_capacity .>= 0)
        @assert all(energy_capacity .>= 0)

        @assert size(charge_efficiency) == (n_stors, N)
        @assert size(discharge_efficiency) == (n_stors, N)
        @assert size(carryover_efficiency) == (n_stors, N)

        @assert all(0 .< charge_efficiency .<= 1)
        @assert all(0 .< discharge_efficiency .<= 1)
        @assert all(0 .< carryover_efficiency .<= 1)

        @assert size(inflow) == (n_stors, N)
        @assert size(gridwithdrawal_capacity) == (n_stors, N)
        @assert size(gridinjection_capacity) == (n_stors, N)

        @assert all(inflow .>= 0)
        @assert all(gridwithdrawal_capacity .>= 0)
        @assert all(gridinjection_capacity .>= 0)

        @assert size(λ) == (n_stors, N)
        @assert size(μ) == (n_stors, N)
        @assert all(0 .<= λ .<= 1)
        @assert all(0 .<= μ .<= 1)

        new{N,L,T,P,E}(
            string.(names), string.(categories),
            charge_capacity, discharge_capacity, energy_capacity,
            charge_efficiency, discharge_efficiency, carryover_efficiency,
            inflow, gridwithdrawal_capacity, gridinjection_capacity,
            λ, μ)

    end

end

Base.:(==)(x::T, y::T) where {T <: GeneratorStorages} =
    x.names == y.names &&
    x.categories == y.categories &&
    x.charge_capacity == y.charge_capacity &&
    x.discharge_capacity == y.discharge_capacity &&
    x.energy_capacity == y.energy_capacity &&
    x.charge_efficiency == y.charge_efficiency &&
    x.discharge_efficiency == y.discharge_efficiency &&
    x.carryover_efficiency == y.carryover_efficiency &&
    x.inflow == y.inflow &&
    x.gridwithdrawal_capacity == y.gridwithdrawal_capacity &&
    x.gridinjection_capacity == y.gridinjection_capacity &&
    x.λ == y.λ &&
    x.μ == y.μ

struct Lines{N,L,T<:Period,P<:PowerUnit} <: AbstractAssets{N,L,T,P}

    names::Vector{String}
    categories::Vector{String}

    forward_capacity::Matrix{Int} # power
    backward_capacity::Matrix{Int} # power

    λ::Matrix{Float64}
    μ::Matrix{Float64}

    function Lines{N,L,T,P}(
        names::Vector{<:AbstractString}, categories::Vector{<:AbstractString},
        forward_capacity::Matrix{Int}, backward_capacity::Matrix{Int},
        λ::Matrix{Float64}, μ::Matrix{Float64}
    ) where {N,L,T,P}

        n_lines = length(names)
        @assert length(categories) == n_lines
        @assert allunique(names)

        @assert size(forward_capacity) == (n_lines, N)
        @assert size(backward_capacity) == (n_lines, N)
        @assert all(forward_capacity .>= 0)
        @assert all(backward_capacity .>= 0)

        @assert size(λ) == (n_lines, N)
        @assert size(μ) == (n_lines, N)
        @assert all(0 .<= λ .<= 1)
        @assert all(0 .<= μ .<= 1)

        new{N,L,T,P}(string.(names), string.(categories), forward_capacity, backward_capacity, λ, μ)

    end

end

Base.:(==)(x::T, y::T) where {T <: Lines} =
    x.names == y.names &&
    x.categories == y.categories &&
    x.forward_capacity == y.forward_capacity &&
    x.backward_capacity == y.backward_capacity &&
    x.λ == y.λ &&
    x.μ == y.μ
