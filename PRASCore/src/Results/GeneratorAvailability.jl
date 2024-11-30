"""
    GeneratorAvailability

Generator availability represents the availability of generators at timestamps
in a GeneratorAvailabilityResult with a (generators, timestamps, samples) matrix API.

No averaging occurs.
"""
struct GeneratorAvailability <: ResultSpec end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::GeneratorAvailability
) where {N}

    ngens = length(sys.generators)
    available = zeros(Bool, ngens, N, nsamples)

    return GenAvailabilityAccumulator(available)

end

struct GenAvailabilityAccumulator <:
    ResultAccumulator{GeneratorAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::GenAvailabilityAccumulator, y::GenAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::GeneratorAvailability) = GenAvailabilityAccumulator

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

function finalize(
    acc::GenAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorAvailabilityResult{N,L,T}(
        system.generators.names, system.timestamps, acc.available)

end
