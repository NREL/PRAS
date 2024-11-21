"""
    Utilization

Utilization metric represents how much an interface between regions is used
across timestamps in a UtilizationResult with a (interfaces, timestamps) matrix API.

Separate samples are averaged together into mean and std values.

See [`UtilizationSamples`](@ref) for all utilization samples.
"""
struct Utilization <: ResultSpec end
abstract type AbstractUtilizationResult{N,L,T} <: Result{N,L,T} end

# Colon indexing

getindex(x::AbstractUtilizationResult, ::Colon) =
    getindex.(x, x.interfaces)

getindex(x::AbstractUtilizationResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, x.interfaces, t)

getindex(x::AbstractUtilizationResult, i::Pair{<:AbstractString,<:AbstractString}, ::Colon) =
    getindex.(x, i, x.timestamps)

getindex(x::AbstractUtilizationResult, ::Colon, ::Colon) =
    getindex.(x, x.interfaces, permutedims(x.timestamps))

# Sample-averaged utilization data

struct UtilizationResult{N,L,T<:Period} <: AbstractUtilizationResult{N,L,T}

    nsamples::Union{Int,Nothing}
    interfaces::Vector{Pair{String,String}}
    timestamps::StepRange{ZonedDateTime,T}

    utilization_mean::Matrix{Float64}

    utilization_interface_std::Vector{Float64}
    utilization_interfaceperiod_std::Matrix{Float64}

end

function getindex(x::UtilizationResult, i::Pair{<:AbstractString,<:AbstractString})
    i_i, _ = findfirstunique_directional(x.interfaces, i)
    return mean(view(x.utilization_mean, i_i, :)), x.utilization_interface_std[i_i]
end

function getindex(x::UtilizationResult, i::Pair{<:AbstractString,<:AbstractString}, t::ZonedDateTime)
    i_i, _ = findfirstunique_directional(x.interfaces, i)
    i_t = findfirstunique(x.timestamps, t)
    return x.utilization_mean[i_i, i_t], x.utilization_interfaceperiod_std[i_i, i_t]
end

"""
    UtilizationSamples

Utilization samples represent the utilization between interfaces at timestamps, which has
not been averaged across different samples. This presents a
3D matrix API (interfaces, timestamps, samples).

See [`Utilization`](@ref) for averaged utilization samples.
"""
struct UtilizationSamples <: ResultSpec end

struct UtilizationSamplesResult{N,L,T<:Period} <: AbstractUtilizationResult{N,L,T}

    interfaces::Vector{Pair{String,String}}
    timestamps::StepRange{ZonedDateTime,T}

    utilization::Array{Float64,3}

end

function getindex(x::UtilizationSamplesResult,
                  i::Pair{<:AbstractString,<:AbstractString})
    i_i, _ = findfirstunique_directional(x.interfaces, i)
    return vec(mean(view(x.utilization, i_i, :, :), dims=1))
end


function getindex(x::UtilizationSamplesResult,
                  i::Pair{<:AbstractString,<:AbstractString}, t::ZonedDateTime)
    i_i, _ = findfirstunique_directional(x.interfaces, i)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.utilization[i_i, i_t, :])
end
