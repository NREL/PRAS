# Loss-of-Load Probability

struct LOLP{N,T<:Period,V<:Real} <: ReliabilityMetric{V}
    val::V
    stderr::V

    function LOLP{N,T}(val::V, stderr::V) where {N,T<:Period,V<:Real}
        (0 <= val <= 1) || error("$val is not a valid probability")
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N,T,V}(val, stderr)
    end

end

function Base.show(io::IO, x::LOLP{N,T}) where {N,T}

    v, s = roundresults(x)

    print(io, "LOLP = ", v,
          stderr(x) > 0 ? "±"*s : "",
          "/", N == 1 ? "" : N, unitsymbol(T))

end
