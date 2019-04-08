# Expected Unserved Energy

struct ExpectedInterfaceFlow{N,L,T<:Period,P<:PowerUnit,V<:Real} <: ReliabilityMetric{V}
    val::V
    stderr::V

    function ExpectedInterfaceFlow{N,L,T,P}(val::V, stderr::V) where {N,L,T<:Period,P<:PowerUnit,V<:Real}
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N,L,T,P,V}(val, stderr)
    end

end

function Base.show(io::IO, x::ExpectedInterfaceFlow{N,L,T,P}) where {N,L,T,P}

    v, s = roundresults(x)

    print(io, "Expected Interface Flow = ", v,
          stderror(x) > 0 ? "±"*s : "", " ",
          unitsymbol(P), " (",
          N*L == 1 ? "" : N*L, unitsymbol(T), ")")

end
