function searchsortedunique(a::AbstractVector{T}, i::T) where {T}
    idxs = searchsorted(a, i)
    length(idxs) == 0 && error("Element $i does not exist in $a")
    length(idxs) > 1 && error("Element $i occurs more than once in $a")
    return first(idxs)
end

function findfirstunique(a::AbstractVector{T}, i::T) where T
    i_idx = findfirst(a, i)
    i_idx > 0 || error("Element $i does not exist in $a")
    return i_idx
end
