"""
    GeneratorStorageAvailability

Generator storage availability represents the availability of generatorstorage resources at timestamps
in a GeneratorStorageAvailabilityResult with a (generatorstorages, timestamps, samples) matrix API.

No averaging occurs
"""
struct GeneratorStorageAvailability <: ResultSpec end

struct GenStorAvailabilityAccumulator <: ResultAccumulator{GeneratorStorageAvailability}

    available::Array{Bool,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::GeneratorStorageAvailability
) where {N}

    ngenstors = length(sys.generatorstorages)
    available = zeros(Bool, ngenstors, N, nsamples)

    return GenStorAvailabilityAccumulator(available)

end

function merge!(
    x::GenStorAvailabilityAccumulator, y::GenStorAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::GeneratorStorageAvailability) = GenStorAvailabilityAccumulator

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

function finalize(
    acc::GenStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorStorageAvailabilityResult{N,L,T}(
        system.generatorstorages.names, system.timestamps, acc.available)

end
