function pvalue(lower::T, upper::T) where {T<:ReliabilityMetric}

    vl = val(lower)
    sl = stderror(lower)

    vu = val(upper)
    su = stderror(upper)

    if iszero(sl) && iszero(su)
        result = Float64(vl ≈ vu)
    else
        # single-sided z-test with null hypothesis that (vu - vl) not > 0
        z = (vu - vl) / sqrt(su^2 + sl^2)
        result = ccdf(Normal(), z)
    end

    return result

end

function prob_greater(x1::T, x2::T) where T <: ReliabilityMetric

    m1 = val(x1)
    s1 = stderror(x1)

    m2 = val(x2)
    s2 = stderror(x2)

    z = (m1 - m2) / sqrt(s1^2 + s2^2)

    return cdf(Normal(), z)

end

function prob_same(x1::T, x2::T) where T <: ReliabilityMetric

    m1 = val(x1)
    s1 = stderror(x1)

    m2 = val(x2)
    s2 = stderror(x2)

    z = (m2 - m1) / sqrt(s1^2 + s2^2)

    return 2 * cdf(Normal(), -abs(z))

end

function allocate_regions(
    region_names::Vector{String},
    regionname_shares::Vector{Tuple{String,Float64}}
)

    region_allocations = similar(regionname_shares, Tuple{Int,Float64})

    for (i, (name, share)) in enumerate(regionname_shares)

        r = findfirst(isequal(name), region_names)

        isnothing(r) &&
            error("$name is not a region name in the provided systems")

        region_allocations[i] = (r, share)

    end

    return sort!(region_allocations)

end

incr_range(rnge::UnitRange{Int}, inc::Int) = rnge .+ inc
incr_range(rnge::UnitRange{Int}, inc1::Int, inc2::Int) =
    (first(rnge) + inc1):(last(rnge) + inc2)
