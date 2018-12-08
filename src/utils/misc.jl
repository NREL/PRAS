CapacityDistribution{T} = Distributions.Generic{T,Float64,Vector{T}}
CapacitySampler{T} = Distributions.GenericSampler{T, Vector{T}}

SumVariance{T} = OnlineStats.Series{
    Number,
    Tuple{OnlineStats.Sum{T},
          OnlineStats.Variance{OnlineStatsBase.EqualWeight}
}}

MeanVariance = OnlineStats.Series{
    Number,
    Tuple{OnlineStats.Mean{OnlineStatsBase.EqualWeight},
          OnlineStats.Variance{OnlineStatsBase.EqualWeight}}
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
    length(idxs) == 0 && BoundsError(a, i)
    length(idxs) > 1 && error("Element $i occurs more than once in $a")
    return first(idxs)
end

function findfirstunique(a::AbstractVector{T}, i::T) where T
    i_idx = findfirst(a, i)
    i_idx > 0 || BoundsError(a, i)
    return i_idx
end

"""
Allocate each RNG on its own thread.
Note that the seed alone is not enough to enforce determinism: the number of
threads used will also affect results. For full reproducibility the thread
count should be constant between runs.
"""
function init_rngs(seed::UInt=rand(UInt))
    nthreads = Threads.nthreads()
    rngs = Vector{MersenneTwister}(nthreads)
    rngs_temp = randjump(MersenneTwister(seed),nthreads)
    Threads.@threads for i in 1:nthreads
        rngs[i] = copy(rngs_temp[i])
    end
    return rngs
end

function unzip(xys::Vector{Tuple{X,Y}}) where {X,Y}

    n = length(xys)

    xs = Vector{X}(n)
    ys = Vector{Y}(n)

    for i in 1:n
       x, y = xys[i]
       xs[i] = x
       ys[i] = y
    end

    return xs, ys

end

function transferperiodresults!(
    dest_sum::Array{V,N}, dest_var::Array{V,N},
    src::Array{MeanVariance,N}, idxs::Vararg{Int,N}) where {V,N}

    series = src[idxs...]

    # Do nothing if Series has no data
    if first(series.stats).n > 0
        s, v = value(series)
        dest_sum[idxs...] += s
        dest_var[idxs...] += v
        src[idxs...] = Series(Mean(), Variance())
    end

end

approxnonzero(x::V) where V = V(!isapprox(x, zero(V)))
