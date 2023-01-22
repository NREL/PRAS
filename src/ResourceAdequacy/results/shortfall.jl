# TODO: Need to fix power-energy unit conversions since timestep no
#       longer described by N,L,T,P,E relationships

struct Shortfall{F1,F2} <: ResultSpec
    regionmap::F1
    periodmap::F2
end

Shortfall(;regionmap::Function=identity, periodmap::Function=identity) =
    Shortfall(regionmap, periodmap)

abstract type AbstractShortfallResult{N,L,T} <: Result{N,L,T} end

# Colon indexing

getindex(x::AbstractShortfallResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, x.regions, t)

getindex(x::AbstractShortfallResult, r::AbstractString, ::Colon) =
    getindex.(x, r, x.timestamps)

getindex(x::AbstractShortfallResult, ::Colon, ::Colon) =
    getindex.(x, x.regions, permutedims(x.timestamps))


LOLE(x::AbstractShortfallResult, ::Colon, t::ZonedDateTime) =
    LOLE.(x, x.regions, t)

LOLE(x::AbstractShortfallResult, r::AbstractString, ::Colon) =
    LOLE.(x, r, x.timestamps)

LOLE(x::AbstractShortfallResult, ::Colon, ::Colon) =
    LOLE.(x, x.regions, permutedims(x.timestamps))


EUE(x::AbstractShortfallResult, ::Colon, t::ZonedDateTime) =
    EUE.(x, x.regions, t)

EUE(x::AbstractShortfallResult, r::AbstractString, ::Colon) =
    EUE.(x, r, x.timestamps)

EUE(x::AbstractShortfallResult, ::Colon, ::Colon) =
    EUE.(x, x.regions, permutedims(x.timestamps))

# Sample-averaged shortfall data

struct ShortfallResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractShortfallResult{N,L,T}

    nsamples::Union{Int,Nothing}
    regions::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    eventperiod_mean::Float64
    eventperiod_std::Float64

    eventperiod_region_mean::Vector{Float64}
    eventperiod_region_std::Vector{Float64}

    eventperiod_period_mean::Vector{Float64}
    eventperiod_period_std::Vector{Float64}

    eventperiod_regionperiod_mean::Matrix{Float64}
    eventperiod_regionperiod_std::Matrix{Float64}


    shortfall_mean::Matrix{Float64} # r x t

    shortfall_std::Float64
    shortfall_region_std::Vector{Float64}
    shortfall_period_std::Vector{Float64}
    shortfall_regionperiod_std::Matrix{Float64}

    function ShortfallResult{N,L,T,E}(
        nsamples::Union{Int,Nothing},
        regions::Vector{String},
        timestamps::StepRange{ZonedDateTime,T},
        eventperiod_mean::Float64,
        eventperiod_std::Float64,
        eventperiod_region_mean::Vector{Float64},
        eventperiod_region_std::Vector{Float64},
        eventperiod_period_mean::Vector{Float64},
        eventperiod_period_std::Vector{Float64},
        eventperiod_regionperiod_mean::Matrix{Float64},
        eventperiod_regionperiod_std::Matrix{Float64},
        shortfall_mean::Matrix{Float64},
        shortfall_std::Float64,
        shortfall_region_std::Vector{Float64},
        shortfall_period_std::Vector{Float64},
        shortfall_regionperiod_std::Matrix{Float64}
    ) where {N,L,T<:Period,E<:EnergyUnit}

        isnothing(nsamples) || nsamples > 0 ||
            throw(DomainError("Sample count must be positive or `nothing`."))


        length(timestamps) == N ||
            error("The provided timestamp range does not match the simulation length")

        nregions = length(regions)

        length(eventperiod_region_mean) == nregions &&
        length(eventperiod_region_std) == nregions &&
        length(eventperiod_period_mean) == N &&
        length(eventperiod_period_std) == N &&
        size(eventperiod_regionperiod_mean) == (nregions, N) &&
        size(eventperiod_regionperiod_std) == (nregions, N) &&
        length(shortfall_region_std) == nregions &&
        length(shortfall_period_std) == N &&
        size(shortfall_regionperiod_std) == (nregions, N) ||
            error("Inconsistent input data sizes")

        new{N,L,T,E}(nsamples, regions, timestamps,
            eventperiod_mean, eventperiod_std,
            eventperiod_region_mean, eventperiod_region_std,
            eventperiod_period_mean, eventperiod_period_std,
            eventperiod_regionperiod_mean, eventperiod_regionperiod_std,
            shortfall_mean, shortfall_std,
            shortfall_region_std, shortfall_period_std,
            shortfall_regionperiod_std)

    end

end

function getindex(x::ShortfallResult)
    return sum(x.shortfall_mean), x.shortfall_std
end

function getindex(x::ShortfallResult, r::AbstractString)
    i_r = findfirstunique(x.regions, r)
    return sum(view(x.shortfall_mean, i_r, :)), x.shortfall_region_std[i_r]
end

function getindex(x::ShortfallResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return sum(view(x.shortfall_mean, :, i_t)), x.shortfall_period_std[i_t]
end

function getindex(x::ShortfallResult, r::AbstractString, t::ZonedDateTime)
    i_r = findfirstunique(x.regions, r)
    i_t = findfirstunique(x.timestamps, t)
    return x.shortfall_mean[i_r, i_t], x.shortfall_regionperiod_std[i_r, i_t]
end


LOLE(x::ShortfallResult{N,L,T}) where {N,L,T} =
    LOLE{N,L,T}(MeanEstimate(x.eventperiod_mean,
                             x.eventperiod_std,
                             x.nsamples))

function LOLE(x::ShortfallResult{N,L,T}, r::AbstractString) where {N,L,T}
    i_r = findfirstunique(x.regions, r)
    return LOLE{N,L,T}(MeanEstimate(x.eventperiod_region_mean[i_r],
                                    x.eventperiod_region_std[i_r],
                                    x.nsamples))
end

function LOLE(x::ShortfallResult{N,L,T}, t::ZonedDateTime) where {N,L,T}
    i_t = findfirstunique(x.timestamps, t)
    return LOLE{1,L,T}(MeanEstimate(x.eventperiod_period_mean[i_t],
                                    x.eventperiod_period_std[i_t],
                                    x.nsamples))
end

function LOLE(x::ShortfallResult{N,L,T}, r::AbstractString, t::ZonedDateTime) where {N,L,T}
    i_r = findfirstunique(x.regions, r)
    i_t = findfirstunique(x.timestamps, t)
    return LOLE{1,L,T}(MeanEstimate(x.eventperiod_regionperiod_mean[i_r, i_t],
                                    x.eventperiod_regionperiod_std[i_r, i_t],
                                    x.nsamples))
end


EUE(x::ShortfallResult{N,L,T,E}) where {N,L,T,E} =
    EUE{N,L,T,E}(MeanEstimate(x[]..., x.nsamples))

EUE(x::ShortfallResult{N,L,T,E}, r::AbstractString) where {N,L,T,E} =
    EUE{N,L,T,E}(MeanEstimate(x[r]..., x.nsamples))

EUE(x::ShortfallResult{N,L,T,E}, t::ZonedDateTime) where {N,L,T,E} =
    EUE{1,L,T,E}(MeanEstimate(x[t]..., x.nsamples))

EUE(x::ShortfallResult{N,L,T,E}, r::AbstractString, t::ZonedDateTime) where {N,L,T,E} =
    EUE{1,L,T,E}(MeanEstimate(x[r, t]..., x.nsamples))

# Full shortfall data 

struct ShortfallSamples <: ResultSpec end

struct ShortfallSamplesResult{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractShortfallResult{N,L,T}

    regions::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    shortfall::Array{Int,3} # r x t x s

end

function getindex(
    x::ShortfallSamplesResult{N,L,T,P,E}
) where {N,L,T,P,E}
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * sum(x.shortfall, dims=1:2))
end

function getindex(
    x::ShortfallSamplesResult{N,L,T,P,E}, r::AbstractString
) where {N,L,T,P,E}
    i_r = findfirstunique(x.regions, r)
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * sum(view(x.shortfall, i_r, :, :), dims=1))
end

function getindex(
    x::ShortfallSamplesResult{N,L,T,P,E}, t::ZonedDateTime
) where {N,L,T,P,E}
    i_t = findfirstunique(x.timestamps, t)
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * sum(view(x.shortfall, :, i_t, :), dims=1))
end

function getindex(
    x::ShortfallSamplesResult{N,L,T,P,E}, r::AbstractString, t::ZonedDateTime
) where {N,L,T,P,E}
    i_r = findfirstunique(x.regions, r)
    i_t = findfirstunique(x.timestamps, t)
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * x.shortfall[i_r, i_t, :])
end


function LOLE(x::ShortfallSamplesResult{N,L,T}) where {N,L,T}
    eventperiods = sum(sum(x.shortfall, dims=1) .> 0, dims=2)
    return LOLE{N,L,T}(MeanEstimate(eventperiods))
end

function LOLE(x::ShortfallSamplesResult{N,L,T}, r::AbstractString) where {N,L,T}
    i_r = findfirstunique(x.regions, r)
    eventperiods = sum(view(x.shortfall, i_r, :, :) .> 0, dims=1)
    return LOLE{N,L,T}(MeanEstimate(eventperiods))
end

function LOLE(x::ShortfallSamplesResult{N,L,T}, t::ZonedDateTime) where {N,L,T}
    i_t = findfirstunique(x.timestamps, t)
    eventperiods = sum(view(x.shortfall, :, i_t, :), dims=1) .> 0
    return LOLE{1,L,T}(MeanEstimate(eventperiods))
end

function LOLE(x::ShortfallSamplesResult{N,L,T}, r::AbstractString, t::ZonedDateTime) where {N,L,T}
    i_r = findfirstunique(x.regions, r)
    i_t = findfirstunique(x.timestamps, t)
    eventperiods = view(x.shortfall, i_r, i_t, :) .> 0
    return LOLE{1,L,T}(MeanEstimate(eventperiods))
end


EUE(x::ShortfallSamplesResult{N,L,T,P,E}) where {N,L,T,P,E} =
    EUE{N,L,T,E}(MeanEstimate(x[]))

EUE(x::ShortfallSamplesResult{N,L,T,P,E}, r::AbstractString) where {N,L,T,P,E} =
    EUE{N,L,T,E}(MeanEstimate(x[r]))

EUE(x::ShortfallSamplesResult{N,L,T,P,E}, t::ZonedDateTime) where {N,L,T,P,E} =
    EUE{1,L,T,E}(MeanEstimate(x[t]))

EUE(x::ShortfallSamplesResult{N,L,T,P,E}, r::AbstractString, t::ZonedDateTime) where {N,L,T,P,E} =
    EUE{1,L,T,E}(MeanEstimate(x[r, t]))
