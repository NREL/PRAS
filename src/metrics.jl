abstract type ReliabilityMetric{V<:Real} end

# Loss-of-Load Probability
type LOLP{N,P<:Period,V<:AbstractFloat} <: ReliabilityMetric{V}
    val::V
    stderr::V

    function LOLP{N,P}(val::V, stderr::V) where {N,P<:Period,V<:AbstractFloat}
        (0 <= val <= 1) || error("$val is not a valid probability")
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N,P,V}(val, stderr)
    end

end
Base.show(io::IO, x::LOLP{N,P}) where {N,P<:Period} =
    print(io, "LOLP = ", val(x),
          stderr(x) > 0 ? "±"*string(stderr(x)) : "",
          "/", N == 1 ? "" : N, unitsymbol(P))


# Loss-of-Load Expectation

type LOLE{N1,P1<:Period,N2,P2<:Period,V<:AbstractFloat} <: ReliabilityMetric{V}
    val::V
    stderr::V

    function LOLE{N1,P1,N2,P2}(val::V, stderr::V) where {N1,P1<:Period,N2,P2<:Period,V<:AbstractFloat}
        (val >= 0) || error("$val is not a valid occurence expectation")
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N1,P1,N2,P2,V}(val, stderr)
    end

end

function LOLE(lolps::Vector{LOLP{N,T,V}}) where {N,T<:Period,V<:AbstractFloat}

    n = length(lolps)
    lole = zero(V)
    s = zero(V)

    for lolp in lolps
        lole += val(lolp)
        s += stderr(lolp)^2
    end

    return LOLE{N,T,n*N,T}(lole, sqrt(s))

end


Base.show(io::IO, x::LOLE{N1,P1,N2,P2}) where {N1,P1,N2,P2} =
    print(io, "LOLE = ", val(x),
          stderr(x) > 0 ? "±"*string(stderr(x)) : "", " ",
          N1 == 1 ? "" : N1, unitsymbol(P1), "/",
          N2 == 1 ? "" : N2, unitsymbol(P2))


# Expected Unserved Energy

type EUE{E<:EnergyUnit,N,P<:Period,V<:AbstractFloat} <: ReliabilityMetric{V}
    val::V
    stderr::V

    function EUE{E,N,P}(val::V, stderr::V) where {E<:EnergyUnit,N,P<:Period,V<:AbstractFloat}
        (val >= 0) || error("$val is not a valid unserved energy expectation")
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{E,N,P,V}(val, stderr)
    end

end

function EUE(eues::Vector{EUE{E,N,P,V}}) where {E<:EnergyUnit,N,P<:Period,V<:AbstractFloat}

    n = length(eues)
    total = zero(V)
    s = zero(V)

    for eue in eues
        total += val(eue)
        s += stderr(eue)^2
    end

    return EUE{E,n*N,P}(total, sqrt(s))

end

Base.show(io::IO, x::EUE{E,N,P}) where {E<:EnergyUnit,N,P<:Period} =
    print(io, "EUE = ", val(x),
          stderr(x) > 0 ? "±"*string(stderr(x)) : "", " ",
          unitsymbol(E), "/",
          N == 1 ? "" : N, unitsymbol(P))


# Common getter methods
for T in [LOLP, LOLE, EUE]
    @eval val(x::($T)) = x.val
    @eval stderr(x::($T)) = x.stderr
end
