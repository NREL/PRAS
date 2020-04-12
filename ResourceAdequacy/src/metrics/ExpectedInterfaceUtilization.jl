# Expected Unserved Energy

struct ExpectedInterfaceUtilization{N,L,T<:Period} <: ReliabilityMetric
    val::Float64
    stderr::Float64

    function ExpectedInterfaceUtilization{N,L,T}(val::Float64, stderr::Float64
    ) where {N,L,T<:Period}
        (0 <= val <= 1) || error("$val is not a valid interface utilization expectation")
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N,L,T}(val, stderr)
    end

end

function Base.show(io::IO, x::ExpectedInterfaceUtilization{N,L,T}) where {N,L,T}

    v, s = roundresults(x)

    print(io, "Expected Interface Utilization = ", v,
          stderror(x) > 0 ? "±"*s : "",
          " (", N*L == 1 ? "" : N*L, unitsymbol(T), ")")

end
