struct NodeResult{L,T<:Period,P<:PowerUnit,V<:Real}

    generation_available::V
    generation::V
    demand::V
    demand_served::V

    function NodeResult{L,T,P}(
        gen_av::V, gen::V, dem::V, dem_served::V
    ) where {L,T<:Period,P<:PowerUnit,V<:Real}
        @assert gen_av > gen || isapprox(gen_av, gen)
        @assert dem > dem_served || isapprox(dem, dem_served)
        new{L,T,P,V}(gen_av, gen, dem, dem_served)
    end

end

struct EdgeResult{L,T<:Period,P<:PowerUnit,V<:Real}

    max_transfer_magnitude::V
    transfer::V

    function EdgeResult{L,T,P}(
        max::V, actual::V) where {L,T<:Period,P<:PowerUnit,V<:Real}
        @assert max > abs(actual) || isapprox(max, abs(actual))
        new{L,T,P,V}(max, actual)
    end

end

struct SystemOutputStateSample{L,T,P,V}
    nodes::Vector{NodeResult{L,T,P,V}}
    edges::Vector{EdgeResult{L,T,P,V}}
    edgelabels::Vector{Tuple{Int,Int}}

    function SystemOutputStateSample(
        nodes::Vector{NodeResult{L,T,P,V}},
        edges::Vector{EdgeResult{L,T,P,V}},
        edgelabels::Vector{Tuple{Int,Int}}
    ) where {L,T,P,V}
        @assert length(edges) == length(edgelabels)
        new{L,T,P,V}(nodes, edges, edgelabels)
    end
end

function SystemOutputStateSample{L,T,P}(
    state_matrix::Matrix{V}, flow_matrix::Matrix{V},
    edge_labels::Vector{Tuple{Int,Int}}, n::Int
) where {L,T<:Period,P<:PowerUnit,V<:Real}

    source = n+1
    sink = n+2
    nodes = [NodeResult{L,T,P}(state_matrix[source,i],
                        flow_matrix[source,i],
                        state_matrix[i,sink],
                        flow_matrix[i,sink]) for i in 1:n]

    edges = [EdgeResult{L,T,P}(state_matrix[i,j],
                        flow_matrix[i,j]) for (i,j) in edge_labels]

    return SystemOutputStateSample(nodes, edges, edge_labels)

end

function droppedload(sample::SystemOutputStateSample{L,T,P,V}) where {L,T,P,V}

    result = zero(V)

    for node in sample.nodes
        (node.demand ≈ node.demand_served) ||
            (result += node.demand - node.demand_served)
    end

    return result

end

function droppedloads(sample::SystemOutputStateSample{L,T,P,V}) where {L,T,P,V}

    nnodes = length(sample.nodes)
    results = zeros(V, nnodes)

    for i in 1:nnodes
        node = sample.nodes[i]
        (node.demand ≈ node.demand_served) ||
            (results[i] = node.demand - node.demand_served)
    end

    return results

end

function all_load_served(A::Matrix{T}, B::Matrix{T}, sink::Int, n::Int) where T
    served = true
    i = 1
    while served && (i <= n)
        served = A[i, sink] ≈ B[i, sink]
        i += 1
    end
    return served
end
