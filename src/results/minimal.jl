struct MinimalResult <: ResultSpec end

# Single-period reliability results

struct SinglePeriodMinimalResult{
    N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:AbstractFloat,
    SS<:SimulationSpec} <: SinglePeriodReliabilityResult{N,T,P,E,V,SS}

    lolp::LOLP{N,T,V}
    eue::EUE{E,N,T,V}
    simulationspec::SS

    function SinglePeriodMinimalResult{P}(
        lolp::LOLP{N,T,V},
        eue::EUE{E,N,T,V},
        simulationspec::SS) where {
            N,T,P<:PowerUnit,E,V,SS<:SimulationSpec}
        new{N,T,P,E,V,SS}(lolp, eue, simulationspec)
    end

end

LOLP(x::SinglePeriodMinimalResult) = x.lolp
EUE(x::SinglePeriodMinimalResult) = x.eue

# Multi-period reliability results

struct MultiPeriodMinimalResult{
    N1,
    T1<:Period,
    N2,
    T2<:Period,
    P<:PowerUnit,
    E<:EnergyUnit,
    V<:AbstractFloat,
    ES<:ExtractionSpec,
    SS<:SimulationSpec
} <: MultiPeriodReliabilityResult{N1,T1,N2,T2,P,E,V,ES,SS}

    timestamps::Vector{DateTime}
    results::Vector{SinglePeriodMinimalResult{N1,T1,P,E,V,SS}}
    extractionspec::ES
    simulationspec::SS

    function MultiPeriodMinimalResult(
        timestamps::Vector{DateTime},
        results::Vector{SinglePeriodMinimalResult{N1,T1,P,E,V,SS}},
        extractionspec::ES,
        simulationspec::SS
    ) where {N1,T1,P,E,V,ES<:ExtractionSpec,SS<:SimulationSpec}
        n = length(timestamps)
        @assert n == length(results)
        @assert uniquesorted(timestamps)
        new{N1,T1,N1*n,T1,P,E,V,ES,SS}(
            timestamps, results, extractionspec, simulationspec)
    end
end

timestamps(x::MultiPeriodMinimalResult) = x.timestamps

function Base.getindex(x::MultiPeriodReliabilityResult,
                       dt::DateTime)
    idxs = searchsorted(x.timestamps, dt)
    if length(idxs) > 0
        return x.results[first(idxs)]
    else
        throw(BoundsError(x, dt))
    end
end


LOLE(x::MultiPeriodMinimalResult) = LOLE([LOLP(r) for r in x.results])
EUE(x::MultiPeriodMinimalResult) = EUE([EUE(r) for r in x.results])
