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

# Full Storage state-of-charge data

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

# Full GeneratorStorage state-of-charge data

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
