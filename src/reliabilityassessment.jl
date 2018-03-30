abstract type ReliabilityAssessmentMethod end
abstract type ReliabilityAssessmentResult{N,P<:Period,E<:EnergyUnit,V<:Real} end

# Single-period reliability results

struct SinglePeriodReliabilityAssessmentResult{
    N,P<:Period,E<:EnergyUnit,V<:AbstractFloat} <: ReliabilityAssessmentResult{N,P,E,V}
    lolp::LOLP{N,P,V}
    eue::EUE{E,N,P,V}
end

lolp(x::SinglePeriodReliabilityAssessmentResult) = x.lolp
eue(x::SinglePeriodReliabilityAssessmentResult) = x.eue


# Multi-period reliability results

struct MultiPeriodReliabilityAssessmentResult{
    N1,P1<:Period,N2,P2<:Period,
    E<:EnergyUnit,V<:AbstractFloat} <: ReliabilityAssessmentResult{N2,P2,E,V}
    timestamps::Vector{DateTime}
    results::Vector{SinglePeriodReliabilityAssessmentResult{N1,P1,E,V}}

    function MultiPeriodReliabilityAssessmentResult(
        timestamps::Vector{DateTime},
        results::Vector{SinglePeriodReliabilityAssessmentResult{N1,P1,E,V}}) where {N1,P1,E,V}
        n = length(timestamps)
        @assert n == length(results)
        new{N1,P1,N1*n,P1,E,V}(timestamps, results)
    end
end

lole(x::MultiPeriodReliabilityAssessmentResult) = LOLE([lolp(r) for r in x.results])
eue(x::MultiPeriodReliabilityAssessmentResult) = EUE([eue(r) for r in x.results])


# Assessment methods

include("reliabilityassessment/backcast.jl")
include("reliabilityassessment/repra.jl")
include("reliabilityassessment/repra_t.jl")
