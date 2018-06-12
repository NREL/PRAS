abstract type ReliabilityAssessmentMethod end
abstract type ReliabilityAssessmentResult{N,P<:Period,E<:EnergyUnit,V<:Real} end

struct NodeResult{V<:Real}
    generation_available::V
    generation::V
    demand::V
    demand_served::V
end

struct EdgeResult{V<:Real}
    max_transfer_magnitude::V
    transfer::V
end

struct FailureResult{V}
    nodes::Vector{NodeResult{V}}
    edges::Vector{EdgeResult{V}}
end

function FailureResult(state_matrix::Matrix{V}, flow_matrix::Matrix{V},
                       edge_labels::Vector{Tuple{Int,Int}}, n::Int) where {V<:Real}
    source = n+1
    sink = n+2
    nodes = [NodeResult(state_matrix[source,i],
                        flow_matrix[source,i],
                        state_matrix[i,sink],
                        flow_matrix[i,sink]) for i in 1:n]

    edges = [EdgeResult(state_matrix[i,j],
                        flow_matrix[i,j]) for (i,j) in edge_labels]

    return FailureResult{V}(nodes, edges)

end

struct FailureResultSet{V<:Real}
    failures::Vector{FailureResult{V}}
    edge_labels::Vector{Tuple{Int,Int}}
end

# Single-period reliability results

struct SinglePeriodReliabilityAssessmentResult{
    N,P<:Period,E<:EnergyUnit,V<:AbstractFloat} <: ReliabilityAssessmentResult{N,P,E,V}
    lolp::LOLP{N,P,V}
    eue::EUE{E,N,P,V}
    failures::Union{Void,FailureResultSet{V}}
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

include("simulation/copperplate.jl")
include("simulation/networkflow.jl")

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
