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
