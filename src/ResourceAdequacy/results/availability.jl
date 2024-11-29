abstract type AbstractAvailabilityResult{N,L,T} <: Result{N,L,T} end

# Colon indexing

getindex(x::AbstractAvailabilityResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, names(x), t)

getindex(x::AbstractAvailabilityResult, name::String, ::Colon) =
    getindex.(x, name, x.timestamps)

getindex(x::AbstractAvailabilityResult, ::Colon, ::Colon) =
    getindex.(x, names(x), permutedims(x.timestamps))

"""
    GeneratorAvailability

Generator availability represents the availability of generators at timestamps
in a GeneratorAvailabilityResult with a (generators, timestamps, samples) matrix API.

No averaging occurs.
"""
struct GeneratorAvailability <: ResultSpec end

struct GeneratorAvailabilityResult{N,L,T<:Period} <: AbstractAvailabilityResult{N,L,T}

    generators::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    available::Array{Bool,3}

end

names(x::GeneratorAvailabilityResult) = x.generators

function getindex(x::GeneratorAvailabilityResult, g::AbstractString, t::ZonedDateTime)
    i_g = findfirstunique(x.generators, g)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.available[i_g, i_t, :])
end

"""
    StorageAvailability

Storage availability represents the availability of storage resources at timestamps
in a StorageAvailabilityResult with a (storages, timestamps, samples) matrix API.

No averaging occurs.
"""
struct StorageAvailability <: ResultSpec end

struct StorageAvailabilityResult{N,L,T<:Period} <: AbstractAvailabilityResult{N,L,T}

    storages::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    available::Array{Bool,3}

end

names(x::StorageAvailabilityResult) = x.storages

function getindex(x::StorageAvailabilityResult, s::AbstractString, t::ZonedDateTime)
    i_s = findfirstunique(x.storages, s)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.available[i_s, i_t, :])
end

"""
    GeneratorStorageAvailability

Generator storage availability represents the availability of generatorstorage resources at timestamps
in a GeneratorStorageAvailabilityResult with a (generatorstorages, timestamps, samples) matrix API.

No averaging occurs
"""
struct GeneratorStorageAvailability <: ResultSpec end

struct GeneratorStorageAvailabilityResult{N,L,T<:Period} <: AbstractAvailabilityResult{N,L,T}

    generatorstorages::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    available::Array{Bool,3}

end

names(x::GeneratorStorageAvailabilityResult) = x.generatorstorages

function getindex(x::GeneratorStorageAvailabilityResult, gs::AbstractString, t::ZonedDateTime)
    i_gs = findfirstunique(x.generatorstorages, gs)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.available[i_gs, i_t, :])
end

"""
    LineAvailability

Line availability represents the availability of lines at timestamps
in a LineAvailabilityResult with a (lines, timestamps, samples) matrix API.

No averaging occurs.
"""
struct LineAvailability <: ResultSpec end

struct LineAvailabilityResult{N,L,T<:Period} <: AbstractAvailabilityResult{N,L,T}

    lines::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    available::Array{Bool,3}

end

names(x::LineAvailabilityResult) = x.lines

function getindex(x::LineAvailabilityResult, l::AbstractString, t::ZonedDateTime)
    i_l = findfirstunique(x.lines, l)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.available[i_l, i_t, :])
end
