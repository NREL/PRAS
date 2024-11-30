"""
    SurplusSamples

Surplus samples represent extra generation at regions and timestamps
in a SurplusSamplesResult with a (regions, timestamps, samples) matrix API.

See [`Surplus`](@ref) for sample-averaged surplus data.
"""
struct SurplusSamples <: ResultSpec end

struct SurplusSamplesAccumulator <: ResultAccumulator{SurplusSamples}

    surplus::Array{Int,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::SurplusSamples
) where {N}

    nregions = length(sys.regions)
    surplus = zeros(Int, nregions, N, nsamples)

    return SurplusSamplesAccumulator(surplus)

end

function merge!(
    x::SurplusSamplesAccumulator, y::SurplusSamplesAccumulator
)

    x.surplus .+= y.surplus
    return

end

accumulatortype(::SurplusSamples) = SurplusSamplesAccumulator

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

function finalize(
    acc::SurplusSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return SurplusSamplesResult{N,L,T,P}(
        system.regions.names, system.timestamps, acc.surplus)

end
