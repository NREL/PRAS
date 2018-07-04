struct NetworkResult <: ResultSpec
    failuresonly::Bool
end

struct NodeResult{N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}

    generation_available::V
    generation::V
    demand::V
    demand_served::V

    function NodeResult{N,T,P,E}(
        gen_av::V, gen::V, dem::V, dem_served::V
    ) where {N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}
        @assert gen_av >= gen
        @assert dem >= dem_served
        new{N,T,P,E,V}(gen_av, gen, dem, dem_served)
    end

end

struct EdgeResult{N,T<:Period, P<:PowerUnit,E<:EnergyUnit, V<:Real}

    max_transfer_magnitude::V
    transfer::V

    function EdgeResult{N,T,P,E}(
        max::V, actual::V) where {N,T,P,E,V<:Real}
        @assert max >= abs(actual)
        new{N,T,P,E,V}(max, actual)
    end

end

struct NetworkState{N,T,P,E,V}
    nodes::Vector{NodeResult{N,T,P,E,V}}
    edges::Vector{EdgeResult{N,T,P,E,V}}
    edgelabels::Vector{Tuple{Int,Int}}

    function NetworkState(
        nodes::Vector{NodeResult{N,T,P,E,V}},
        edges::Vector{EdgeResult{N,T,P,E,V}},
        edgelabels::Vector{Tuple{Int,Int}}
    ) where {N,T,P,E,V}
        @assert length(edges) == length(edgelabels)
        new{N,T,P,E,V}(nodes, edges, edgelabels)
    end
end

function NetworkState{N,T,P,E}(
    state_matrix::Matrix{V}, flow_matrix::Matrix{V},
    edge_labels::Vector{Tuple{Int,Int}},
    n::Int) where {N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}

    source = n+1
    sink = n+2
    nodes = [NodeResult{N,T,P,E}(state_matrix[source,i],
                        flow_matrix[source,i],
                        state_matrix[i,sink],
                        flow_matrix[i,sink]) for i in 1:n]

    edges = [EdgeResult{N,T,P,E}(state_matrix[i,j],
                        flow_matrix[i,j]) for (i,j) in edge_labels]

    return NetworkState(nodes, edges, edge_labels)

end

function droppedload(ns::NetworkState{N,T,P,E,V}) where {N,T,P,E,V}
    result = zero(V)
    for node in ns.nodes
        if !(node.demand ≈ node.demand_served)
            result += node.demand - node.demand_served
        end
    end
    return result
end

struct NetworkStateSet{N,T,P,E,V}
    nodesset::Vector{Vector{NodeResult{N,T,P,E,V}}}
    edgesset::Vector{Vector{EdgeResult{N,T,P,E,V}}}
    edgelabels::Vector{Tuple{Int,Int}}

    function NetworkStateSet{}(
        nodesset::Vector{Vector{NodeResult{N,T,P,E,V}}},
        edgesset::Vector{Vector{EdgeResult{N,T,P,E,V}}},
        edgelabels::Vector{Tuple{Int,Int}}) where {N,T,P,E,V}
        @assert length(nodesset) == length(edgesset)
        new{N,T,P,E,V}(nodesset, edgesset, edgelabels)
    end
end

function NetworkStateSet(nss::Vector{T}) where {T<:NetworkState}
    nodesset, edgesset, edgelabels =
        zip([(ns.nodes, ns.edges, ns.edgelabels) for ns in nss]...)
    @assert all(edgelabels[1] == edgelabels[i] for i in 2:length(edgelabels))
    return NetworkStateSet(collect(nodesset), collect(edgesset), edgelabels[1])
end

Base.length(nss::NetworkStateSet) = length(nss.nodesset)

droppedload(nss::NetworkStateSet) =
    [droppedload(NetworkState(edges, nodes, nss.edgelabels))
    for (edges, nodes) in zip(nss.nodesset, nss.edgesset)]

function LOLP(nss::NetworkStateSet{N,T}) where {N,T}
    μ = mean(droppedload(nss) .> 0)
    σ² = μ * (1-μ)
    return LOLP{N,T}(μ, sqrt(σ²/length(nss)))
end

function LOLP(nss::NetworkStateSet{N,T}, ntrials::Int) where {N,T}
    μ = length(nss) / ntrials
    σ² = μ * (1-μ)
    return LOLP{N,T}(μ, sqrt(σ²/ntrials))
end

function EUE(nss::NetworkStateSet{N,T,P,E,V}) where {N,T,P,E,V}
    results = powertoenergy.(droppedload(nss), N, T, P, E)
    μ = mean(results)
    σ² = var(results, corrected=false, mean=μ)
    return EUE{E,N,T}(μ, sqrt(σ²/length(results)))
end

function EUE(nss::NetworkStateSet{N,T,P,E,V},
             ntrials::Int) where {N,T,P,E,V}
    dropresults = powertoenergy.(droppedload(nss), N, T, P, E)
    nfails = length(dropresults)
    nsuccess = ntrials - nfails
    μ = sum(dropresults) / ntrials
    σ² = (sum((dropresults .- μ).^2) +
          nsuccess*μ^2) / ntrials
    return EUE{E,N,T}(μ, sqrt(σ²/ntrials))
end

struct SinglePeriodNetworkResult{
    N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real,
    SS<:SimulationSpec} <: SinglePeriodReliabilityResult{N,T,P,E,V,SS}

    failuresonly::Bool
    node_labels::Vector{String}
    edge_labels::Vector{Tuple{Int,Int}}
    states::NetworkStateSet{N,T,P,E,V}
    simulationspec::SS

    function SinglePeriodNetworkResult(
        failuresonly::Bool,
        node_labels::Vector{String},
        edge_labels::Vector{Tuple{Int,Int}},
        states::NetworkStateSet{N,T,P,E,V},
        simulationspec::SS;
    ) where {
        N, T<:Period, P<:PowerUnit, E<:EnergyUnit,
        V, SS<:SimulationSpec
    }

        @assert length(node_labels) == length(edge_labels)

        new{N,T,P,E,V,SS}(failuresonly,
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
    N1,T1<:Period,N2,T2<:Period,
    P<:PowerUnit,E<:EnergyUnit,V<:Real,
    SS<:SimulationSpec,
    ES<:ExtractionSpec} <: MultiPeriodReliabilityResult{
        N1,T1,N2,T2,P,E,V,ES,SS}

    failuresonly::Bool
    timestamps::Vector{DateTime}
    nodelabels::Vector{String}
    edgelabels::Vector{Tuple{Int,Int}}
    statesets::Vector{NetworkStateSet{N1,T1,P,E,V}}
    extractionspec::ES
    simulationspec::SS

    function MultiPeriodNetworkResult{N1,T1,N2,T2,P,E}(
        timestamps::Vector{DateTime},
        nodelabels::Vector{String},
        edgellabels::Vector{Tuple{Int,Int}},
        statesets::Vector{NetworkStateSet{N1,T1,P,E,V}},
        extractionspec::ES,
        simulationspec::SS
    ) where {N1,T1<:Period,N2,T2<:Period,
             P<:PowerUnit,E<:EnergyUnit,V,
             ES<:ExtractionSpec,
             SS<:SimulationSpec}

        n = length(timestamps)
        @assert n == length(statesets)
        @assert uniquesorted(timestamps)

        new{N1,T1,N2,T2,P,E,V,ES,SS}(
            timestamps, nodelabels, edgelabels,
            statesets, extractionspec, simulationspec)

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
