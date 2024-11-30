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

struct LineAvailabilityAccumulator <: ResultAccumulator{LineAvailability}

    available::Array{Bool,3}

end

accumulatortype(::LineAvailability) = LineAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::LineAvailability
) where {N}

    nlines = length(sys.lines)
    available = zeros(Bool, nlines, N, nsamples)

    return LineAvailabilityAccumulator(available)

end

function merge!(
    x::LineAvailabilityAccumulator, y::LineAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

function finalize(
    acc::LineAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return LineAvailabilityResult{N,L,T}(
        system.lines.names, system.timestamps, acc.available)

end
