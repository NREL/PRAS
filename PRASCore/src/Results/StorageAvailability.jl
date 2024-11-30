"""
    StorageAvailability

Storage availability represents the availability of storage resources at timestamps
in a StorageAvailabilityResult with a (storages, timestamps, samples) matrix API.

No averaging occurs.
"""
struct StorageAvailability <: ResultSpec end

struct StorAvailabilityAccumulator <: ResultAccumulator{StorageAvailability}

    available::Array{Bool,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::StorageAvailability
) where {N}

    nstors = length(sys.storages)
    available = zeros(Bool, nstors, N, nsamples)

    return StorAvailabilityAccumulator(available)

end

function merge!(
    x::StorAvailabilityAccumulator, y::StorAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::StorageAvailability) = StorAvailabilityAccumulator

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

function finalize(
    acc::StorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return StorageAvailabilityResult{N,L,T}(
        system.storages.names, system.timestamps, acc.available)

end
