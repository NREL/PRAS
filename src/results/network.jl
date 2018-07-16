struct NetworkResult <: ResultSpec
    failuresonly::Bool

    NetworkResult(;failuresonly::Bool=true) = new(failuresonly)
end

struct NodeResult{N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}

    generation_available::V
    generation::V
    demand::V
    demand_served::V

    function NodeResult{N,T,P,E}(
        gen_av::V, gen::V, dem::V, dem_served::V
    ) where {N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}
        @assert gen_av > gen || isapprox(gen_av, gen)
        @assert dem > dem_served || isapprox(dem, dem_served)
        new{N,T,P,E,V}(gen_av, gen, dem, dem_served)
    end

end

struct EdgeResult{N,T<:Period, P<:PowerUnit,E<:EnergyUnit, V<:Real}

    max_transfer_magnitude::V
    transfer::V

    function EdgeResult{N,T,P,E}(
        max::V, actual::V) where {N,T,P,E,V<:Real}
        @assert max > abs(actual) || isapprox(max, abs(actual))
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
    edge_labels::Vector{Tuple{Int,Int}}, n::Int
) where {N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}

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
    nodesset::Matrix{NodeResult{N,T,P,E,V}}
    edgesset::Matrix{EdgeResult{N,T,P,E,V}}
    edgelabels::Vector{Tuple{Int,Int}}

    function NetworkStateSet{}(
        nodesset::Matrix{NodeResult{N,T,P,E,V}},
        edgesset::Matrix{EdgeResult{N,T,P,E,V}},
        edgelabels::Vector{Tuple{Int,Int}}) where {N,T,P,E,V}
        @assert size(nodesset, 2) == size(edgesset, 2)
        new{N,T,P,E,V}(nodesset, edgesset, edgelabels)
    end
end

function NetworkStateSet(nss::Vector{T}) where {T<:NetworkState}
    nodesset, edgesset, edgelabels =
        zip([(ns.nodes, ns.edges, ns.edgelabels) for ns in nss]...)
    @assert all(edgelabels[1] == edgelabels[i] for i in 2:length(edgelabels))
    return NetworkStateSet(hcat(nodesset...), hcat(edgesset...), edgelabels[1])
end

Base.length(nss::NetworkStateSet) = size(nss.nodesset, 2)

droppedload(nss::NetworkStateSet) =
    [droppedload(NetworkState(nss.nodesset[:,i], nss.edgesset[:, i], nss.edgelabels))
    for i in 1:length(nss)]

function LOLP(nss::NetworkStateSet{N,T}) where {N,T}
    μ = mean(droppedload(nss) .> 0)
    σ² = μ * (1-μ)
    return LOLP{N,T}(μ, sqrt(σ²/length(nss)))
end

function LOLP(nss::NetworkStateSet{N,T}, nsamples::Int) where {N,T}
    μ = length(nss) / nsamples
    σ² = μ * (1-μ)
    return LOLP{N,T}(μ, sqrt(σ²/nsamples))
end

function EUE(nss::NetworkStateSet{N,T,P,E,V}) where {N,T,P,E,V}
    results = powertoenergy.(droppedload(nss), N, T, P, E)
    μ = mean(results)
    σ² = var(results, corrected=false, mean=μ)
    return EUE{E,N,T}(μ, sqrt(σ²/length(results)))
end

function EUE(nss::NetworkStateSet{N,T,P,E,V},
             nsamples::Int) where {N,T,P,E,V}
    dropresults = powertoenergy.(droppedload(nss), N, T, P, E)
    nfails = length(dropresults)
    nsuccess = nsamples - nfails
    μ = sum(dropresults) / nsamples
    σ² = (sum((dropresults .- μ).^2) +
          nsuccess*μ^2) / nsamples
    return EUE{E,N,T}(μ, sqrt(σ²/nsamples))
end

struct SinglePeriodNetworkResult{
    N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real,
    SS<:SimulationSpec} <: SinglePeriodReliabilityResult{N,T,P,E,V,SS}

    nodelabels::Vector{String}
    edgelabels::Vector{Tuple{Int,Int}}
    nodesset::Matrix{NodeResult{N,T,P,E,V}}
    edgesset::Matrix{EdgeResult{N,T,P,E,V}}
    simulationspec::SS
    resultspec::NetworkResult

    function SinglePeriodNetworkResult{}(
        nodelabels::Vector{String},
        edgelabels::Vector{Tuple{Int,Int}},
        nodesset::Matrix{NodeResult{N,T,P,E,V}},
        edgesset::Matrix{EdgeResult{N,T,P,E,V}},
        simulationspec::SS,
        resultspec::NetworkResult
    ) where {
        N, T<:Period, P<:PowerUnit, E<:EnergyUnit,
        V, SS<:SimulationSpec
    }

        @assert size(nodesset,2) == size(edgesset,2)

        new{N,T,P,E,V,SS}(nodelabels, edgelabels, nodesset, edgesset,
                          simulationspec, resultspec)

    end
end

function LOLP(x::SinglePeriodNetworkResult)
    nss = NetworkStateSet(x.nodesset, x.edgesset, x.edgelabels)
    return x.resultspec.failuresonly ?
        LOLP(nss, x.simulationspec.nsamples) : LOLP(nss)
end


function EUE(x::SinglePeriodNetworkResult)
    nss = NetworkStateSet(x.nodesset, x.edgesset, x.edgelabels)
    return x.resultspec.failuresonly ?
        EUE(nss, x.simulationspec.nsamples) : EUE(nss)
end

struct MultiPeriodNetworkResult{
    N1,T1<:Period,N2,T2<:Period,
    P<:PowerUnit,E<:EnergyUnit,V<:Real,
    ES<:ExtractionSpec, SS<:SimulationSpec
} <: MultiPeriodReliabilityResult{N1,T1,N2,T2,P,E,V,ES,SS}

    timestamps::Vector{DateTime}
    nodelabels::Vector{String}
    edgelabels::Vector{Tuple{Int,Int}}
    nodessets::Vector{Matrix{NodeResult{N1,T1,P,E,V}}}
    edgessets::Vector{Matrix{EdgeResult{N1,T1,P,E,V}}}
    extractionspec::ES
    simulationspec::SS
    resultspec::NetworkResult

    function MultiPeriodNetworkResult{}(
        timestamps::Vector{DateTime},
        nodelabels::Vector{String},
        edgelabels::Vector{Tuple{Int,Int}},
        nodessets::Vector{Matrix{NodeResult{N,T,P,E,V}}},
        edgessets::Vector{Matrix{EdgeResult{N,T,P,E,V}}},
        extractionspec::ES,
        simulationspec::SS,
        resultspec::NetworkResult
    ) where {N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V,
             ES<:ExtractionSpec, SS<:SimulationSpec}

        n = length(timestamps)
        @assert n == length(nodessets)
        @assert n == length(edgessets)
        @assert uniquesorted(timestamps)

        new{N,T,n*N,T,P,E,V,ES,SS}(
            timestamps, nodelabels, edgelabels,
            nodessets, edgessets,
            extractionspec, simulationspec, resultspec)

    end

end

function MultiPeriodNetworkResult(
    dts::Vector{DateTime},
    results::Vector{SinglePeriodNetworkResult{N,T,P,E,V,SS}},
    extrspec::ExtractionSpec
) where {N,T,P,E,V,SS}
    n_results = length(results)
    println("Before 228.")
    nodessets = Vector{Matrix{NodeResult{N,T,P,E,V}}}(n_results)
    edgessets = Vector{Matrix{EdgeResult{N,T,P,E,V}}}(n_results)	
   
    for (i,r) in enumerate(results)
        nodessets[i] = r.nodesset
        edgessets[i] = r.edgesset
    end
    #nodessets, edgessets = zip([(r.nodesset, r.edgesset) for r in results]...)
    result = results[1]
    println("after.")
    return MultiPeriodNetworkResult(
        dts, result.nodelabels, result.edgelabels,
        nodessets, edgessets,
        extrspec, result.simulationspec, result.resultspec)

end

aggregator(rs::NetworkResult) = MultiPeriodNetworkResult

function LOLE(x::MultiPeriodNetworkResult)
    nsss = map((nodesset, edgesset) ->
               NetworkStateSet(nodesset, edgesset, x.edgelabels),
            x.nodessets, x.edgessets)
    return LOLE(x.resultspec.failuresonly ?
                LOLP.(nsss, x.simulationspec.nsamples) :
                LOLP.(nsss))
end

function EUE(x::MultiPeriodNetworkResult)
    nsss = map((nodesset, edgesset) ->
               NetworkStateSet(nodesset, edgesset, x.edgelabels),
            x.nodessets, x.edgessets)
    return EUE(x.resultspec.failuresonly ?
               EUE.(nsss, x.simulationspec.nsamples) :
               EUE.(nsss))
end

timestamps(x::MultiPeriodNetworkResult) = x.timestamps

function Base.getindex(x::MultiPeriodNetworkResult, dt::DateTime)
    idxs = searchsorted(x.timestamps, dt)
    if length(idxs) > 0
        return SinglePeriodNetworkResult(
            x.nodelabels, x.edgelabels,
            x.nodessets[first(idxs)],
            x.edgessets[first(idxs)],
            x.simulationspec,
            x.resultspec
        )
    else
        throw(BoundsError(x, dt))
    end
end
