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

# Decision: Should this carry the period-level results as well?
struct MultiPeriodReliabilityAssessmentResult{
    N1,P1<:Period,N2,P2<:Period,
    E<:EnergyUnit,V<:AbstractFloat} <: ReliabilityAssessmentResult{N2,P2,E,V}
    timestamps::Vector{DateTime}
    results::Vector{SinglePeriodReliabilityAssessmentResult{N1,P1,E,V}}
    # TODO: Constructor to enforce equal vector lengths and determine N2,P2
end

lole(x::MultiPeriodReliabilityAssessmentResult) = LOLE(x.results)
eue(x::MultiPeriodReliabilityAssessmentResult) = EUE(x.results)


# Assessment methods

include("reliabilityassessment/backcast.jl")
include("reliabilityassessment/repra.jl")
include("reliabilityassessment/repra_t.jl")
