struct MinimalResult <: AbstractResultSpec end

# Single-period reliability results

struct SinglePeriodMinimalResult{
    N,P<:Period,E<:EnergyUnit,V<:AbstractFloat,
    SS<:SimulationSpec} <: SinglePeriodReliabilityResult{N,P,E,V,SS}

    lolp::LOLP{N,P,V}
    eue::EUE{E,N,P,V}
    simulationspec::SS

end

LOLP(x::SinglePeriodMinimalResult) = x.lolp
EUE(x::SinglePeriodMinimalResult) = x.eue

# Multi-period reliability results

struct MultiPeriodMinimalResult{
    N1,
    P1<:Period,
    N2,
    P2<:Period,
    E<:EnergyUnit,
    V<:AbstractFloat,
    SS<:SimulationSpec,
    ES<:ExtractionSpec
} <: MultiPeriodReliabilityResult{N1,P1,N2,P2,E,V,SS,ES}

    timestamps::Vector{DateTime}
    results::Vector{SinglePeriodMinimalResult{N1,P1,E,V}}
    simulationspec::SS
    extractionspec::ES

    function MultiPeriodMinimalResult(
        timestamps::Vector{DateTime},
        results::Vector{SinglePeriodMinimalResult{N1,P1,E,V}}) where {N1,P1,E,V}
        n = length(timestamps)
        @assert n == length(results)
        @assert uniquesorted(timestamps)
        new{N1,P1,N1*n,P1,E,V}(timestamps, results)
    end
end

timestamps(x::MultiPeriodMinimalResult) = x.timestamps

function getindex(x::MultiPeriodMinimalResult, dt::DateTime)
    idxs = searchsorted(x.timestamps, dt)
    if length(idxs) > 0
        return x.results[first(idxs)]
    else
        throw(BoundsError(x, dt))
    end
end

LOLE(x::MultiPeriodMinimalResult) = LOLE([LOLP(r) for r in x.results])
EUE(x::MultiPeriodMinimalResult) = EUE([EUE(r) for r in x.results])
