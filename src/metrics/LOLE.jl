# Loss-of-Load Expectation

struct LOLE{N,L,T<:Period} <: ReliabilityMetric
    val::Float64
    stderr::Float64

    function LOLE{N,L,T}(val::Float64, stderr::Float64) where {N,L,T<:Period}
        (val >= 0) || error("$val is not a valid occurence expectation")
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N,L,T}(val, stderr)
    end

end

function LOLE(lolps::Vector{LOLP{L,T}}) where {L,T<:Period}

    N = length(lolps)
    lole = 0.
    s = 0.

    for lolp in lolps
        lole += val(lolp)
        s += stderror(lolp)^2
    end

    return LOLE{N,L,T}(lole, sqrt(s))

end

function Base.show(io::IO, x::LOLE{N,L,T}) where {N,L,T}

    v, s = roundresults(x)

    print(io, "LOLE = ", v,
          stderror(x) > 0 ? "±"*s : "", " ",
          L == 1 ? "" : L, unitsymbol(T), "/",
          N*L == 1 ? "" : N*L, unitsymbol(T))

end
