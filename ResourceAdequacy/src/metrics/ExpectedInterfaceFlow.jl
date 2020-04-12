# Expected Unserved Energy

struct ExpectedInterfaceFlow{N,L,T<:Period,P<:PowerUnit} <: ReliabilityMetric
    val::Float64
    stderr::Float64

    function ExpectedInterfaceFlow{N,L,T,P}(val::Float64, stderr::Float64
    ) where {N,L,T<:Period,P<:PowerUnit}
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N,L,T,P}(val, stderr)
    end

end

function Base.show(io::IO, x::ExpectedInterfaceFlow{N,L,T,P}) where {N,L,T,P}

    v, s = roundresults(x)

    print(io, "Expected Interface Flow = ", v,
          stderror(x) > 0 ? "±"*s : "", " ",
          unitsymbol(P), " (",
          N*L == 1 ? "" : N*L, unitsymbol(T), ")")

end

-(x::ExpectedInterfaceFlow{N,L,T,P}) where {N,L,T,P} =
    ExpectedInterfaceFlow{N,L,T,P}(-val(x), stderror(x))
