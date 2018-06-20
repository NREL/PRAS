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

struct MultiPeriodBasicResult{
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
    results::Vector{SinglePeriodReliabilityAssessmentResult{N1,P1,E,V}}
    simulationspec::SS
    extractionspec::ES

    function MultiPeriodReliabilityAssessmentResult(
        timestamps::Vector{DateTime},
        results::Vector{SinglePeriodReliabilityAssessmentResult{N1,P1,E,V}}) where {N1,P1,E,V}
        n = length(timestamps)
        @assert n == length(results)
        @assert uniquesorted(timestamps)
        new{N1,P1,N1*n,P1,E,V}(timestamps, results)
    end
end

timestamps(x::MultiPeriodBasicResult) = x.timestamps

function getindex(x::MultiPeriodBasicResult, dt::DateTime)
    idxs = searchsorted(x.timestamps, dt)
    if length(idxs) > 0
        return x.results[first(idxs)]
    else
        throw(BoundsError(x, dt))
    end
end

LOLE(x::MultiPeriodBasicResult) = LOLE([LOLP(r) for r in x.results])
EUE(x::MultiPeriodBasicResult) = EUE([EUE(r) for r in x.results])
