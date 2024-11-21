meanvariance() = Series(Mean(), Variance())

function mean_std(x::MeanVariance)
    m, v = value(x)
    return m, sqrt(v)
end

function mean_std(x::AbstractArray{<:MeanVariance})
    means = similar(x, Float64)
    vars = similar(means)

    for i in eachindex(x)
        m, v = mean_std(x[i])
        means[i] = m
        vars[i] = v
    end

    return means, vars
end

function findfirstunique_directional(a::AbstractVector{<:Pair}, i::Pair)
    i_idx = findfirst(isequal(i), a)
    if isnothing(i_idx)
        i_idx = findfirstunique(a, last(i) => first(i))
        reverse = true
    else
        reverse = false
    end
    return i_idx, reverse
end

function findfirstunique(a::AbstractVector{T}, i::T) where {T}
    i_idx = findfirst(isequal(i), a)
    i_idx === nothing && throw(BoundsError(a))
    return i_idx
end

function assetgrouplist(idxss::Vector{UnitRange{Int}})
    results = Vector{Int}(undef, last(idxss[end]))
    for (g, idxs) in enumerate(idxss)
        results[idxs] .= g
    end
    return results
end

function colsum(x::Matrix{T}, col::Int) where {T}
    result = zero(T)
    for i in 1:size(x, 1)
        result += x[i, col]
    end
    return result
end
