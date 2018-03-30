abstract type ReliabilityAssessmentResult{N,P<:Period,E<:EnergyUnit,V<:Real} end

# Single-period reliability results

struct SinglePeriodReliabilityAssessmentResult{
    N,P<:Period,E<:EnergyUnit,V<:AbstractFloat} <: ReliabilityAssessmentResult{N,P,E,V}
    lolp::LOLP{N,P,V}
    eue::EUE{E,N,P,V}
end

LOLP(x::SinglePeriodReliabilityAssessmentResult) = x.lolp
EUE(x::SinglePeriodReliabilityAssessmentResult) = x.eue


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

LOLE(x::MultiPeriodReliabilityAssessmentResult) = LOLE([LOLP(r) for r in x.results])
EUE(x::MultiPeriodReliabilityAssessmentResult) = EUE([EUE(r) for r in x.results])


include("reliability/extraction.jl")
include("reliability/assessment.jl")

function assess(extractionmethod::SinglePeriodExtractionMethod,
                assessmentmethod::ReliabilityAssessmentMethod,
                systemset::SystemDistributionSet)

    # More efficient for copperplate assessment.
    # What to do with this? Preprocess step?
    # systemset_collapsed = collapse(systemset)

    dts = unique(systemset.timestamps)
    batchsize = ceil(Int, length(dts)/nworkers())
    results = pmap(dt -> assess(assessmentmethod,
                                extract(extractionmethod, dt, systemset)),
                   dts, batch_size=batchsize)

    return MultiPeriodReliabilityAssessmentResult(dts, results)

end
