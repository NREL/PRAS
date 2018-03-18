normdist = Normal()
function pequal(x::T, y::T) where {T<:ReliabilityMetric}
    z = abs((val(x) - val(y)) /
            sqrt(stderr(x)^2 + stderr(y)^2))
    return 2 * ccdf(normdist, z)
end
