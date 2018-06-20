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

struct NetworkState{V}
    nodes::Vector{NodeResult{V}}
    edges::Vector{EdgeResult{V}}
end

function NetworkState(state_matrix::Matrix{V}, flow_matrix::Matrix{V},
                      edge_labels::Vector{Tuple{Int,Int}}, n::Int) where {V<:Real}

    source = n+1
    sink = n+2
    nodes = [NodeResult(state_matrix[source,i],
                        flow_matrix[source,i],
                        state_matrix[i,sink],
                        flow_matrix[i,sink]) for i in 1:n]

    edges = [EdgeResult(state_matrix[i,j],
                        flow_matrix[i,j]) for (i,j) in edge_labels]

    return NetworkState{V}(nodes, edges)

end

NetworkStateSet{V} = Vector{NetworkState{V}}


abstract type PersistenceMethod end
struct FailuresOnly <: PersistenceMethod end
struct AllResults <: PersistenceMethod end

struct SinglePeriodNetworkResult{
    PM<:PersistenceMethod,
    N,P<:Period,E<:EnergyUnit,V<:Real,
    SS<:SimulationSpec} <: ReliabilityAssessmentResult{N,P,E,V}

    node_labels::Vector{String}
    edge_labels::Vector{Tuple{Int,Int}}
    states::NetworkStateSet{V}
    simulationspec::SS

    function SinglePeriodNetworkResult{PM,N,P,E}(
        node_labels::Vector{String}
        edge_labels::Vector{Tuple{Int,Int}}
        states::NetworkStateSet{V}) where {
            PM<:PersistenceMethod, N,
            P<:Period, E<:EnergyUnit, V}

        @assert length(node_labels) == length(edge_labels)

        new{PM,N,P,E,V}(node_labels, edge_labels, states)

    end
end

struct MultiPeriodNetworkResult{
    PM<:PersistenceMethod,
    N1,P1<:Period,N2,P2<:Period,
    E<:EnergyUnit,V<:Real,
    SS<:SimulationSpec,
    ES<:ExtractionSpec} <: ReliabilityAssessmentResult{N2,P2,E,V}

    timestamps::Vector{DateTime}
    nodelabels::Vector{String}
    edgelabels::Vector{Tuple{Int,Int}}
    statesets::Vector{NetworkStateSet{V}}
    simulationspec::SS
    extractionspec::ES

    function MultiPeriodNetworkResult{PM,N1,P1,N2,P2,E}(
        timestamps::Vector{DateTime},
        nodelabels::Vector{String},
        edgellabels::Vector{Tuple{Int,Int}},
        statesets::Vector{NetworkStateSet{V}}
    ) where {PM<:PersistenceMethod,N1,P1<:Period,E<:EnergyUnit}

        n = length(timestamps)
        @assert n == length(statesets)
        @assert uniquesorted(timestamps)

        new{}(timestamps, nodelabels, edgelabels, statesets)

    end

end
