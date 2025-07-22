abstract type AbstractAssets{N,L,T<:Period,P<:PowerUnit} end
Base.length(a::AbstractAssets) = length(a.names)

function Base.show(io::IO, asset_collection::T) where {T<:AbstractAssets}

    # Count occurrences of each category
    category_counts = Dict{String, Int}()
    for category in asset_collection.categories
        category_counts[category] = get(category_counts, category, 0) + 1
    end
    
    # Format category counts as strings in a table
    category_strings = [@sprintf("%-10s | %-10s",category,count) for (category, count) in category_counts]
    column_names = @sprintf("  %-10s | %-5s", "Category", "Count")
    header_separator = @sprintf("  %-10s%3s%-5s","-"^10,"-"^5,"-"^5)
    
    type_outputstring_map = Dict(
        Generators => "generators",
        Storages => "storage devices",
        GeneratorStorages => "generator-storage devices",
    )

    asset_type = typeof(asset_collection)
    
    # Get the appropriate output string based on asset type
    output_string = get(type_outputstring_map, asset_type.name.wrapper, "assets")
    
    # Printing logic
    println(io, "$(length(asset_collection.names)) $(output_string):")
    println(io, column_names)
    println(io, header_separator)
    println(io, "  $(join(category_strings, "\n  "))")
    
end

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
        @assert all(isnonnegative, capacity) # Why not just use unsigned integers?

        @assert size(λ) == (n_gens, N)
        @assert size(μ) == (n_gens, N)
        @assert all(isfractional, λ)
        @assert all(isfractional, μ)

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

function Base.vcat(gs::Generators{N,L,T,P}...) where {N, L, T, P}

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
        @assert all(isnonnegative, chargecapacity)
        @assert all(isnonnegative, dischargecapacity)
        @assert all(isnonnegative, energycapacity)

        @assert size(chargeefficiency) == (n_stors, N)
        @assert size(dischargeefficiency) == (n_stors, N)
        @assert size(carryoverefficiency) == (n_stors, N)
        @assert all(isfractional, chargeefficiency)
        @assert all(isfractional, dischargeefficiency)
        @assert all(isfractional, carryoverefficiency)

        @assert size(λ) == (n_stors, N)
        @assert size(μ) == (n_stors, N)
        @assert all(isfractional, λ)
        @assert all(isfractional, μ)

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

Base.getindex(s::S, idxs::AbstractVector{Int}) where {S <: Storages} =
    S(s.names[idxs], s.categories[idxs],s.charge_capacity[idxs,:],
      s.discharge_capacity[idxs, :],s.energy_capacity[idxs, :],
      s.charge_efficiency[idxs, :], s.discharge_efficiency[idxs, :], 
      s.carryover_efficiency[idxs, :],s.λ[idxs, :], s.μ[idxs, :])

function Base.vcat(stors::Storages{N,L,T,P,E}...) where {N, L, T, P, E}

    n_stors = sum(length(s) for s in stors)

    names = Vector{String}(undef, n_stors)
    categories = Vector{String}(undef, n_stors)

    charge_capacity = Matrix{Int}(undef, n_stors, N)
    discharge_capacity = Matrix{Int}(undef, n_stors, N)
    energy_capacity = Matrix{Int}(undef, n_stors, N) 

    charge_efficiency = Matrix{Float64}(undef, n_stors, N)
    discharge_efficiency = Matrix{Float64}(undef, n_stors, N)
    carryover_efficiency = Matrix{Float64}(undef, n_stors, N)

    λ = Matrix{Float64}(undef, n_stors, N)
    μ = Matrix{Float64}(undef, n_stors, N)

    last_idx = 0

    for s in stors

        n = length(s)
        rows = last_idx .+ (1:n)

        names[rows] = s.names
        categories[rows] = s.categories

        charge_capacity[rows, :] = s.charge_capacity
        discharge_capacity[rows, :] = s.discharge_capacity
        energy_capacity[rows, :] = s.energy_capacity

        charge_efficiency[rows, :] = s.charge_efficiency
        discharge_efficiency[rows, :] = s.discharge_efficiency
        carryover_efficiency[rows, :] = s.carryover_efficiency

        λ[rows, :] = s.λ
        μ[rows, :] = s.μ

        last_idx += n

    end

    return Storages{N,L,T,P,E}(names, categories, charge_capacity, discharge_capacity, energy_capacity, charge_efficiency, discharge_efficiency, 
                               carryover_efficiency, λ, μ)

end

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

        @assert all(isnonnegative, charge_capacity)
        @assert all(isnonnegative, discharge_capacity)
        @assert all(isnonnegative, energy_capacity)

        @assert size(charge_efficiency) == (n_stors, N)
        @assert size(discharge_efficiency) == (n_stors, N)
        @assert size(carryover_efficiency) == (n_stors, N)

        @assert all(isfractional, charge_efficiency)
        @assert all(isfractional, discharge_efficiency)
        @assert all(isfractional, carryover_efficiency)

        @assert size(inflow) == (n_stors, N)
        @assert size(gridwithdrawal_capacity) == (n_stors, N)
        @assert size(gridinjection_capacity) == (n_stors, N)

        @assert all(isnonnegative, inflow)
        @assert all(isnonnegative, gridwithdrawal_capacity)
        @assert all(isnonnegative, gridinjection_capacity)

        @assert size(λ) == (n_stors, N)
        @assert size(μ) == (n_stors, N)
        @assert all(isfractional, λ)
        @assert all(isfractional, μ)

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

Base.getindex(g_s::G, idxs::AbstractVector{Int}) where {G <: GeneratorStorages} =
    G(g_s.names[idxs], g_s.categories[idxs], g_s.charge_capacity[idxs,:],
      g_s.discharge_capacity[idxs, :], g_s.energy_capacity[idxs, :],
      g_s.charge_efficiency[idxs, :], g_s.discharge_efficiency[idxs, :], 
      g_s.carryover_efficiency[idxs, :],g_s.inflow[idxs, :],
      g_s.gridwithdrawal_capacity[idxs, :],g_s.gridinjection_capacity[idxs, :],
      g_s.λ[idxs, :], g_s.μ[idxs, :])

function Base.vcat(gen_stors::GeneratorStorages{N,L,T,P,E}...) where {N, L, T, P, E}

    n_gen_stors = sum(length(g_s) for g_s in gen_stors)

    names = Vector{String}(undef, n_gen_stors)
    categories = Vector{String}(undef, n_gen_stors)

    charge_capacity = Matrix{Int}(undef, n_gen_stors, N)
    discharge_capacity = Matrix{Int}(undef, n_gen_stors, N)
    energy_capacity = Matrix{Int}(undef, n_gen_stors, N) 

    charge_efficiency = Matrix{Float64}(undef, n_gen_stors, N)
    discharge_efficiency = Matrix{Float64}(undef, n_gen_stors, N)
    carryover_efficiency = Matrix{Float64}(undef, n_gen_stors, N)

    inflow = Matrix{Int}(undef, n_gen_stors, N)
    gridwithdrawal_capacity = Matrix{Int}(undef, n_gen_stors, N)
    gridinjection_capacity = Matrix{Int}(undef, n_gen_stors, N)

    λ = Matrix{Float64}(undef, n_gen_stors, N)
    μ = Matrix{Float64}(undef, n_gen_stors, N)

    last_idx = 0

    for g_s in gen_stors

        n = length(g_s)
        rows = last_idx .+ (1:n)

        names[rows] = g_s.names
        categories[rows] = g_s.categories

        charge_capacity[rows, :] = g_s.charge_capacity
        discharge_capacity[rows, :] = g_s.discharge_capacity
        energy_capacity[rows, :] = g_s.energy_capacity

        charge_efficiency[rows, :] = g_s.charge_efficiency
        discharge_efficiency[rows, :] = g_s.discharge_efficiency
        carryover_efficiency[rows, :] = g_s.carryover_efficiency

        inflow[rows, :] = g_s.inflow
        gridwithdrawal_capacity[rows, :] = g_s.gridwithdrawal_capacity
        gridinjection_capacity[rows, :] = g_s.gridinjection_capacity

        λ[rows, :] = g_s.λ
        μ[rows, :] = g_s.μ

        last_idx += n

    end

    return GeneratorStorages{N,L,T,P,E}(names, categories, charge_capacity, discharge_capacity, energy_capacity, charge_efficiency, discharge_efficiency, 
                               carryover_efficiency,inflow, gridwithdrawal_capacity, gridinjection_capacity, λ, μ)

end

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
        @assert all(isnonnegative, forward_capacity)
        @assert all(isnonnegative, backward_capacity)

        @assert size(λ) == (n_lines, N)
        @assert size(μ) == (n_lines, N)
        @assert all(isfractional, λ)
        @assert all(isfractional, μ)

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

Base.getindex(lines::L, idxs::AbstractVector{Int}) where {L <: Lines} =
    L(lines.names[idxs], lines.categories[idxs],lines.forward_capacity[idxs,:],
      lines.backward_capacity[idxs, :],lines.λ[idxs, :], lines.μ[idxs, :])

function Base.vcat(lines::Lines{N,L,T,P}...) where {N, L, T, P}

    n_lines = sum(length(line) for line in lines)

    names = Vector{String}(undef, n_lines)
    categories = Vector{String}(undef, n_lines)

    forward_capacity = Matrix{Int}(undef, n_lines, N)
    backward_capacity = Matrix{Int}(undef, n_lines, N)
    
    λ = Matrix{Float64}(undef,n_lines, N)
    μ = Matrix{Float64}(undef,n_lines, N)

    last_idx = 0

    for line in lines

        n = length(line)
        rows = last_idx .+ (1:n)

        names[rows] = line.names
        categories[rows] = line.categories

        forward_capacity[rows, :] = line.forward_capacity
        backward_capacity[rows, :] = line.backward_capacity

        λ[rows, :] = line.λ
        μ[rows, :] = line.μ

        last_idx += n

    end

    return Lines{N,L,T,P}(names, categories, forward_capacity, backward_capacity, λ, μ)

end

