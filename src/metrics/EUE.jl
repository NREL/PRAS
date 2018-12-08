# Expected Unserved Energy

struct EUE{N,L,T<:Period,E<:EnergyUnit,V<:Real} <: ReliabilityMetric{V}
    val::V
    stderr::V

    function EUE{N,L,T,E}(val::V, stderr::V) where {N,L,T<:Period,E<:EnergyUnit,V<:Real}
        (val >= 0) || error("$val is not a valid unserved energy expectation")
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N,L,T,E,V}(val, stderr)
    end

end

function EUE(eues::Vector{EUE{1,L,T,E,V}}) where {
    L,T<:Period,E<:EnergyUnit,V<:AbstractFloat}

    N = length(eues)
    total = zero(V)
    s = zero(V)

    for eue in eues
        total += val(eue)
        s += stderr(eue)^2
    end

    return EUE{N,L,T,E}(total, sqrt(s))

end

function Base.show(io::IO, x::EUE{N,L,T,E}) where {N,L,T,E}

    v, s = roundresults(x)

    print(io, "EUE = ", v,
          stderr(x) > 0 ? "±"*s : "", " ",
          unitsymbol(E), "/",
          N*L == 1 ? "" : N*L, unitsymbol(T))

end
