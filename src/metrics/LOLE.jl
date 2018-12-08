# Loss-of-Load Expectation

struct LOLE{N,L,T<:Period,V<:Real} <: ReliabilityMetric{V}
    val::V
    stderr::V

    function LOLE{N,L,T}(val::V, stderr::V) where {N,L,T<:Period,V<:Real}
        (val >= 0) || error("$val is not a valid occurence expectation")
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N,L,T,V}(val, stderr)
    end

end

function LOLE(lolps::Vector{LOLP{L,T,V}}) where {L,T<:Period,V<:AbstractFloat}

    N = length(lolps)
    lole = zero(V)
    s = zero(V)

    for lolp in lolps
        lole += val(lolp)
        s += stderr(lolp)^2
    end

    return LOLE{N,L,T}(lole, sqrt(s))

end

function Base.show(io::IO, x::LOLE{N,L,T}) where {N,L,T}

    v, s = roundresults(x)

    print(io, "LOLE = ", v,
          stderr(x) > 0 ? "±"*s : "", " ",
          L == 1 ? "" : L, unitsymbol(T), "/",
          N*L == 1 ? "" : N*L, unitsymbol(T))

end
