"""
    ShortfallSamples

ShortfallSamples metric represents lost load at regions and timesteps
in ShortfallSamplesResult with a (regions, timestamps, samples) matrix API.

See [`Shortfall`](@ref) for averaged shortfall samples.
"""
struct ShortfallSamples <: ResultSpec end

struct ShortfallSamplesAccumulator <: ResultAccumulator{ShortfallSamples}

    shortfall::Array{Int,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::ShortfallSamples
) where {N}

    nregions = length(sys.regions)
    shortfall = zeros(Int, nregions, N, nsamples)

    return ShortfallSamplesAccumulator(shortfall)

end

function merge!(
    x::ShortfallSamplesAccumulator, y::ShortfallSamplesAccumulator
)

    x.shortfall .+= y.shortfall
    return

end

accumulatortype(::ShortfallSamples) = ShortfallSamplesAccumulator

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

function finalize(
    acc::ShortfallSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return ShortfallSamplesResult{N,L,T,P,E}(
        system.regions.names, system.timestamps, acc.shortfall)

end
