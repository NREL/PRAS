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

# Full utilization data

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
