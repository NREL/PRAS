struct NetworkResult <: ResultSpec
    failuresonly::Bool
end

struct NodeResult{N,T<:Period,P<:PowerUnit,V<:Real}

    generation_available::V
    generation::V
    demand::V
    demand_served::V

    function NodeResult{N,T,P}(
        gen_av::V, gen::V, dem::V, dem_served::V
    ) where {N,T<:Period,P<:PowerUnit,V<:Real}
        @assert gen_av >= gen
        @assert dem >= dem_served
        new{N,T,P,V}(gen_av, gen, dem, dem_served)
    end

end

struct EdgeResult{N,T<:Period,P<:PowerUnit,V<:Real}

    max_transfer_magnitude::V
    transfer::V

    function EdgeResult{N,T,P}(
        max::V, actual::V) where {N,T,P,V}
        @assert max >= abs(actual)
        new{N,T,P,V}(max, actual)
    end

end

struct NetworkState{N,T,P,V}
    nodes::Vector{NodeResult{N,T,P,V}}
    edges::Vector{EdgeResult{N,T,P,V}}
    edgelabels::Vector{Tuple{Int,Int}}

    function NetworkState(
        nodes::Vector{NodeResult{N,T,P,V}},
        edges::Vector{EdgeResult{N,T,P,V}},
        edgelabels::Vector{Tuple{Int,Int}}
    ) where {N,T,P,V}
        @assert length(edges) == length(edgelabels)
        new{N,T,P,V}(nodes, edges, edgelabels)
    end
end

function NetworkState{N,T,P}(state_matrix::Matrix{V}, flow_matrix::Matrix{V},
                      edge_labels::Vector{Tuple{Int,Int}}, n::Int) where {V<:Real}

    source = n+1
    sink = n+2
    nodes = [NodeResult{N,T,P}(state_matrix[source,i],
                        flow_matrix[source,i],
                        state_matrix[i,sink],
                        flow_matrix[i,sink]) for i in 1:n]

    edges = [EdgeResult{N,T,P}(state_matrix[i,j],
                        flow_matrix[i,j]) for (i,j) in edge_labels]

    return NetworkState(nodes, edges, edge_labels)

end

function droppedload(ns::NetworkState{N,T,P,V}) where {N,T,P,V}
    result = zero(V)
    for node in ns.nodes
        if !(node.demand ≈ node.demand_served)
            result += node.demand - node.demand_served
        end
    end
    return result
end

struct NetworkStateSet{N,T,P,V}
    nodesset::Vector{Vector{NodeResult{N,T,P,V}}}
    edgesset::Vector{Vector{EdgeResult{N,T,P,V}}}
    edgelabels::Vector{Tuple{Int,Int}}

    function NetworkStateSet(nodesset::Vector{Vector{NodeResult{N,T,P,V}}},
                             edgesset::Vector{Vector{EdgeResult{N,T,P,V}}},
                             edgelabels::Vector{Tuple{Int,Int}})
        @assert length(nodesset) == length(edgesset)
        new{N,T,P,V}(nodesset, edgesset, edgelabels)
    end
end

droppedload(nss::NetworkStateSet) =
    [droppedload(NetworkState(edges, nodes, nss.edgelabels))
    for edges, nodes in zip(nss.nodesset, nss.edgesset)]

function LOLP(nss::NetworkStateSet{N,T,P,V}) where {N,T,P,V}
    μ = mean(droppedload(nss) .> 0)
    σ² = μ * (1-μ)
    return LOLP{N,T,V}(μ, sqrt(σ²/length(nss)))
end

function LOLP(nss::NetworkStateSet{N,T,P,V}, ntrials::Int) where {N,T,P,V}
    μ = length(nss) / ntrials
    σ² = μ * (1-μ)
    return LOLP{N,T,V}(μ, sqrt(σ²/ntrials))
end

function EUE(nss::NetworkStateSet)
    results = droppedload.(nss)
    μ = mean(results)
    σ² = var(results)
    return EUE(μ, sqrt(σ²/length(nss)))
end

function EUE(nss::NetworkStateSet, ntrials::Int)
    nfails = length(nss)
    nsuccess = ntrials - nfails
    dropresults = droppedload.(nss)
    μ = sum(dropresults) / ntrials
    σ² = (sum((dropresults .- μ).^2) +
          nsuccess*μ^2) / ntrials
    return EUE(μ, sqrt(σ²/ntrials))
end

struct SinglePeriodNetworkResult{
    N,P<:Period,E<:EnergyUnit,V<:Real,
    SS<:SimulationSpec} <: SinglePeriodReliabilityResult{N,P,E,V,SS}

    failuresonly::Bool
    node_labels::Vector{String}
    edge_labels::Vector{Tuple{Int,Int}}
    states::NetworkStateSet{V}
    simulationspec::SS

    function SinglePeriodNetworkResult{N,P,E}(
        failuresonly::Bool,
        node_labels::Vector{String},
        edge_labels::Vector{Tuple{Int,Int}},
        states::NetworkStateSet{V},
        simulationspec::SS;
    ) where {
        N, P<:Period, E<:EnergyUnit, V,
        SS<:SimulationSpec
    }

        @assert length(node_labels) == length(edge_labels)

        new{N,P,E,V,SS}(failuresonly,
                        node_labels, edge_labels,
                        states, simulationspec)

    end
end

LOLP(x::SinglePeriodNetworkResult) =
    x.failuresonly ?
    LOLP(x.states, x.simulationspec.ntrials) :
    LOLP(x.states)


EUE(x::SinglePeriodNetworkResult) =
    x.failuresonly ?
    EUE(x.states, x.simulationspec.ntrials) :
    EUE(x.states)


struct MultiPeriodNetworkResult{
    N1,P1<:Period,N2,P2<:Period,
    E<:EnergyUnit,V<:Real,
    SS<:SimulationSpec,
    ES<:ExtractionSpec} <: MultiPeriodReliabilityResult{N1,P1,N2,P2,E,V,ES,SS}

    failuresonly::Bool
    timestamps::Vector{DateTime}
    nodelabels::Vector{String}
    edgelabels::Vector{Tuple{Int,Int}}
    statesets::Vector{NetworkStateSet{V}}
    extractionspec::ES
    simulationspec::SS

    function MultiPeriodNetworkResult{N1,P1,N2,P2,E}(
        timestamps::Vector{DateTime},
        nodelabels::Vector{String},
        edgellabels::Vector{Tuple{Int,Int}},
        statesets::Vector{NetworkStateSet{V}},
        extractionspec::ES,
        simulationspec::SS
    ) where {N1,P1<:Period,N2,P2<:Period,
             E<:EnergyUnit,V,
             ES<:ExtractionSpec,
             SS<:SimulationSpec}

        n = length(timestamps)
        @assert n == length(statesets)
        @assert uniquesorted(timestamps)

        new{N1,P1,N2,P2,E,V,ES,SS}(
            timestamps, nodelabels, edgelabels,
            statesets, extractonspec, simulationspec)

    end

end


LOLE(x::MultiPeriodNetworkResult) = LOLE(
    x.failuresonly ?
    LOLP.(x.statesets, x.simulationspec.ntrials) :
    LOLP.(x.statesets)
)

EUE(x::MultiPeriodNetworkResult) = EUE(
    x.failuresonly ?
    EUE.(x.statesets, x.simulationspec.ntrials) :
    EUE.(x.statesets)
)

timestamps(x::MultiPeriodNetworkResult) = x.timestamps

function Base.getindex(x::MultiPeriodNetworkResult,
                       dt::DateTime)
    idxs = searchsorted(x.timestamps, dt)
    if length(idxs) > 0
        return SinglePeriodNetworkResult(
            x.failuresonly,
            x.nodelabels, x.edgelabels,
            x.statesets[first(idxs)],
            x.simulationspec
        )
    else
        throw(BoundsError(x, dt))
    end
end
