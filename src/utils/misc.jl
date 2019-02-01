CapacityDistribution{T} =
    Distributions.DiscreteNonParametric{T,Float64,Vector{T},Vector{Float64}}

CapacitySampler{T} =
    Distributions.DiscreteNonParametricSampler{
        T, Vector{T},
        Distributions.AliasTable{Random.SamplerRangeFast{UInt64,Int64}}}

struct NoCheck end # For bypassing constructor checks

SumVariance{T} = OnlineStats.Series{
    Number,
    Tuple{OnlineStats.Sum{T},
          OnlineStats.Variance{T, EqualWeight}
}}

MeanVariance{T} = OnlineStats.Series{
    Number,
    Tuple{OnlineStats.Mean{T, EqualWeight},
          OnlineStats.Variance{T, EqualWeight}}
}

function makemetric(f, mv::MeanVariance)
    nsamples = first(mv.stats).n
    samplemean, samplevar = value(mv)
    return f(samplemean, nsamples > 1 ? sqrt(samplevar / nsamples) : 0.)
end

function mean_stderr(mv::MeanVariance, nsamples::Int)
    samplemean, samplevar = value(mv)
    return (samplemean, sqrt(samplevar / nsamples))
end

function searchsortedunique(a::AbstractVector{T}, i::T) where {T}
    idxs = searchsorted(a, i)
    length(idxs) == 0 && throw(BoundsError(a))
    length(idxs) > 1 && throw(ArgumentError("Element $i occurs more than once in $a"))
    return first(idxs)
end

function findfirstunique(a::AbstractVector{T}, i::T) where T
    i_idx = findfirst(isequal(i), a)
    i_idx === nothing && throw(BoundsError(a))
    return i_idx
end

"""
Generate a vector of `n` MersenneTwister random number generators, derived from
a MersenneTwister seeded with `seed`, with `step` steps between each generated
RNG.
"""
function initrngs(n::Int; seed::UInt=rand(UInt), step::Integer=big(10)^20)
    result = Vector{MersenneTwister}(undef, n)
    prev = MersenneTwister(seed)
    for i in 1:n
        prev = Future.randjump(prev, step)
        result[i] = prev
    end
    return result
end

function unzip(xys::Vector{Tuple{X,Y}}) where {X,Y}

    n = length(xys)

    xs = Vector{X}(undef, n)
    ys = Vector{Y}(undef, n)

    for i in 1:n
       x, y = xys[i]
       xs[i] = x
       ys[i] = y
    end

    return xs, ys

end

function transferperiodresults!(
    dest_sum::Array{V,N}, dest_var::Array{V,N},
    src::Array{MeanVariance{V},N}, idxs::Vararg{Int,N}) where {V,N}

    series = src[idxs...]

    # Do nothing if Series has no data
    if first(series.stats).n > 0
        s, v = value(series)
        dest_sum[idxs...] += s
        dest_var[idxs...] += v
        src[idxs...] = Series(Mean(), Variance())
    end

end

function checkdifference(x::V, y::V) where {V<:AbstractFloat}
    diff = x - y
    return abs(diff) > sqrt(eps(V))*max(abs(x), abs(y)), diff
end

function approxnonzero(x::V, T::Type=V) where {V<:AbstractFloat}
    absx = abs(x)
    return T(absx > sqrt(eps(V))*absx)
end
