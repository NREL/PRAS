# Expected Unserved Energy

struct EUE{N,L,T<:Period,E<:EnergyUnit} <: ReliabilityMetric
    val::Float64
    stderr::Float64

    function EUE{N,L,T,E}(val::Float64, stderr::Float64) where {N,L,T<:Period,E<:EnergyUnit}
        (val >= 0) || error("$val is not a valid unserved energy expectation")
        (stderr >= 0) || error("$stderr is not a valid standard error")
        new{N,L,T,E}(val, stderr)
    end

end

function EUE(eues::Vector{EUE{1,L,T,E}}) where {L,T<:Period,E<:EnergyUnit}

    N = length(eues)
    total = 0.
    s = 0.

    for eue in eues
        total += val(eue)
        s += stderror(eue)^2
    end

    return EUE{N,L,T,E}(total, sqrt(s))

end

function Base.show(io::IO, x::EUE{N,L,T,E}) where {N,L,T,E}

    v, s = roundresults(x)

    print(io, "EUE = ", v,
          stderror(x) > 0 ? "±"*s : "", " ",
          unitsymbol(E), "/",
          N*L == 1 ? "" : N*L, unitsymbol(T))

end
