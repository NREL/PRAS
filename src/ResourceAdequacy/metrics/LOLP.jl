# Loss-of-Load Probability

struct LOLP{N,T<:Period} <: ReliabilityMetric
    val::Float64
    stderr::Float64

    function LOLP{N,T}(val::Float64, stderr::Float64) where {N,T<:Period}
        (0 <= val <= 1) || error("$val is not a valid probability")
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N,T}(val, stderr)
    end

end

function Base.show(io::IO, x::LOLP{N,T}) where {N,T}

    v, s = roundresults(x)

    print(io, "LOLP = ", v,
          stderror(x) > 0 ? "±"*s : "",
          "/", N == 1 ? "" : N, unitsymbol(T))

end
