struct Surplus <: ResultSpec end
abstract type AbstractSurplusResult{N,L,T} <: Result{N,L,T} end

# Colon indexing

getindex(x::AbstractSurplusResult, ::Colon) =
    getindex.(x, x.timestamps)

getindex(x::AbstractSurplusResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, x.regions, t)

getindex(x::AbstractSurplusResult, r::AbstractString, ::Colon) =
    getindex.(x, r, x.timestamps)

getindex(x::AbstractSurplusResult, ::Colon, ::Colon) =
    getindex.(x, x.regions, permutedims(x.timestamps))

# Sample-averaged surplus data

struct SurplusResult{N,L,T<:Period,P<:PowerUnit} <: AbstractSurplusResult{N,L,T}

    nsamples::Union{Int,Nothing}
    regions::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    surplus_mean::Matrix{Float64}

    surplus_period_std::Vector{Float64}
    surplus_regionperiod_std::Matrix{Float64}

end

function getindex(x::SurplusResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return sum(view(x.surplus_mean, :, i_t)), x.surplus_period_std[i_t]
end

function getindex(x::SurplusResult, r::AbstractString, t::ZonedDateTime)
    i_r = findfirstunique(x.regions, r)
    i_t = findfirstunique(x.timestamps, t)
    return x.surplus_mean[i_r, i_t], x.surplus_regionperiod_std[i_r, i_t]
end

# Full surplus data 

struct SurplusSamples <: ResultSpec end

struct SurplusSamplesResult{N,L,T<:Period,P<:PowerUnit} <: AbstractSurplusResult{N,L,T}

    regions::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    surplus::Array{Int,3}

end

function getindex(x::SurplusSamplesResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return vec(sum(view(x.surplus, :, i_t, :), dims=1))
end

function getindex(x::SurplusSamplesResult, r::AbstractString, t::ZonedDateTime)
    i_r = findfirstunique(x.regions, r)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.surplus[i_r, i_t, :])
end
