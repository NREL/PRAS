abstract type AbstractEnergyResult{N,L,T} <: Result{N,L,T} end

# Colon indexing

getindex(x::AbstractEnergyResult, ::Colon) =
    getindex.(x, x.timestamps)

getindex(x::AbstractEnergyResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, names(x), t)

getindex(x::AbstractEnergyResult, name::String, ::Colon) =
    getindex.(x, name, x.timestamps)

getindex(x::AbstractEnergyResult, ::Colon, ::Colon) =
    getindex.(x, names(x), permutedims(x.timestamps))

# Sample-averaged Storage state-of-charge data

"""
    StorageEnergy

Storage energy represents the state-of-charge of storage
resources at timestamps in a StorageEnergyResult with a (storages, timestamps)
matrix API.

Separate samples are averaged together into mean and std values.

See [`StorageEnergySamples`](@ref) for all storage energy samples.

See [`GeneratorStorageEnergy`](@ref) for generator storage energy.
"""
struct StorageEnergy <: ResultSpec end

struct StorageEnergyResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    nsamples::Union{Int,Nothing}
    storages::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    energy_mean::Matrix{Float64}

    energy_period_std::Vector{Float64}
    energy_regionperiod_std::Matrix{Float64}

end

names(x::StorageEnergyResult) = x.storages

function getindex(x::StorageEnergyResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return sum(view(x.energy_mean, :, i_t)), x.energy_period_std[i_t]
end

function getindex(x::StorageEnergyResult, s::AbstractString, t::ZonedDateTime)
    i_s = findfirstunique(x.storages, s)
    i_t = findfirstunique(x.timestamps, t)
    return x.energy_mean[i_s, i_t], x.energy_regionperiod_std[i_s, i_t]
end

# Sample-averaged GeneratorStorage state-of-charge data
"""
    GeneratorStorageEnergy

Generator storage energy represents state-of-charge of generatorstorage
resources at timestamps in a StorageEnergyResult with a (generatorstorages, timestamps)
matrix API.

Separate samples are averaged together into mean and std values.

See [`GeneratorStorageEnergySamples`](@ref) for all generator storage energy samples.

See [`StorageEnergy`](@ref) for storage energy.
"""
struct GeneratorStorageEnergy <: ResultSpec end

struct GeneratorStorageEnergyResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    nsamples::Union{Int,Nothing}
    generatorstorages::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    energy_mean::Matrix{Float64}

    energy_period_std::Vector{Float64}
    energy_regionperiod_std::Matrix{Float64}

end

names(x::GeneratorStorageEnergyResult) = x.generatorstorages

function getindex(x::GeneratorStorageEnergyResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return sum(view(x.energy_mean, :, i_t)), x.energy_period_std[i_t]
end

function getindex(x::GeneratorStorageEnergyResult, gs::AbstractString, t::ZonedDateTime)
    i_gs = findfirstunique(x.generatorstorages, gs)
    i_t = findfirstunique(x.timestamps, t)
    return x.energy_mean[i_gs, i_t], x.energy_regionperiod_std[i_gs, i_t]
end

"""
    StorageEnergySamples

Storage energy samples represent the state-of-charge of storage
resources at timestamps, which has not been averaged across different samples.
This presents a 3D matrix API (storages, timestamps, samples).

See [`StorageEnergy`](@ref) for sample-averaged storage energy.
"""
struct StorageEnergySamples <: ResultSpec end

struct StorageEnergySamplesResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    storages::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    energy::Array{Int,3}

end

names(x::StorageEnergySamplesResult) = x.storages

function getindex(x::StorageEnergySamplesResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return vec(sum(view(x.energy, :, i_t, :), dims=1))
end

function getindex(x::StorageEnergySamplesResult, s::AbstractString, t::ZonedDateTime)
    i_s = findfirstunique(x.storages, s)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.energy[i_s, i_t, :])
end

"""
    GeneratorStorageEnergySamples

Generator storage energy samples represent the state-of-charge of generatorstorage
resources at timestamps, which has not been averaged across different samples.
This presents a 3D matrix API (generatorstorages, timestamps, samples).

See [`GeneratorStorageEnergy`](@ref) for sample-averaged generator storage energy.
"""
struct GeneratorStorageEnergySamples <: ResultSpec end

struct GeneratorStorageEnergySamplesResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    generatorstorages::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    energy::Array{Int,3}

end

names(x::GeneratorStorageEnergySamplesResult) = x.generatorstorages

function getindex(x::GeneratorStorageEnergySamplesResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return vec(sum(view(x.energy, :, i_t, :), dims=1))
end

function getindex(x::GeneratorStorageEnergySamplesResult, gs::AbstractString, t::ZonedDateTime)
    i_gs = findfirstunique(x.generatorstorages, gs)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.energy[i_gs, i_t, :])
end
