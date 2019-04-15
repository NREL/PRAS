# Expected Unserved Energy

struct ExpectedInterfaceUtilization{N,L,T<:Period,V<:Real} <: ReliabilityMetric{V}
    val::V
    stderr::V

    function ExpectedInterfaceUtilization{N,L,T}(val::V, stderr::V) where {N,L,T<:Period,V<:Real}
        (0 <= val <= 1) || error("$val is not a valid interface utilization expectation")
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N,L,T,V}(val, stderr)
    end

end

function Base.show(io::IO, x::ExpectedInterfaceUtilization{N,L,T}) where {N,L,T}

    v, s = roundresults(x)

    print(io, "Expected Interface Utilization = ", v,
          stderror(x) > 0 ? "±"*s : "",
          " (", N*L == 1 ? "" : N*L, unitsymbol(T), ")")

end
