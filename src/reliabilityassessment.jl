abstract type ReliabilityAssessment{N,P<:Period,E<:EnergyUnit,V<:Real} end


# Single-period reliability results

struct SinglePeriodReliabilityAssessment{
    N,P<:Period,E<:EnergyUnit,V<:AbstractFloat} <: ReliabilityAssessment{N,P,E,V}
    lolp::LOLP{N,P,V}
    eue::EUE{E,N,P,V}
end

lolp(x::SinglePeriodReliabilityAssessment) = x.lolp
eue(x::SinglePeriodReliabilityAssessment) = x.eue


# Multi-period reliability results

# Decision: Should this carry the period-level results as well?
struct MultiPeriodReliabilityAssessment{
    N1,P1<:Period,N2,P2<:Period,
    E<:EnergyUnit,V<:AbstractFloat} <: ReliabilityAssessment{N2,P2,E,V}
    lole::LOLE{N1,P1,N2,P2,V}
    eue::EUE{E,N2,P2,V}
end

lole(x::MultiPeriodReliabilityAssessment) = x.lole
eue(x::MultiPeriodReliabilityAssessment) = x.eue


# Assessment methods

include("reliabilityassessment/backcast.jl")
include("reliabilityassessment/repra.jl")
include("reliabilityassessment/repra_t.jl")
