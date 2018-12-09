struct NodeResult{L,T<:Period,P<:PowerUnit,V<:Real}

    generation_available::V
    generation::V
    demand::V
    demand_served::V

    NodeResult{L,T,P}(
        gen_av::V, gen::V, dem::V, dem_served::V, ::NoCheck
    ) where {L,T<:Period,P<:PowerUnit,V<:Real} =
    new{L,T,P,V}(gen_av, gen, dem, dem_served)

end

function NodeResult{L,T,P}(gen_av::V, gen::V, dem::V, dem_served::V
    ) where {L,T<:Period,P<:PowerUnit,V<:Real}

    @assert gen_av > gen || isapprox_stable(gen_av, gen)
    @assert dem > dem_served || isapprox_stable(dem, dem_served)
    return NodeResult{L,T,P}(gen_av, gen, dem, dem_served, NoCheck())

end

struct EdgeResult{L,T<:Period,P<:PowerUnit,V<:Real}

    max_transfer_magnitude::V
    transfer::V

    function EdgeResult{L,T,P}(
        max::V, actual::V, ::NoCheck) where {L,T<:Period,P<:PowerUnit,V<:Real}
        new{L,T,P,V}(max, actual)
    end

end

function EdgeResult{L,T,P}(
    max::V, actual::V) where {L,T<:Period,P<:PowerUnit,V<:Real}
    @assert max > abs(actual) || isapprox_stable(max, abs(actual))
    return EdgeResult{L,T,P}(max, actual, NoCheck())
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

function SystemOutputStateSample{L,T,P,V}(
    edge_labels::Vector{Tuple{Int,Int}}, n::Int) where {L,T,P,V}

    nodes = Vector{NodeResult{L,T,P,V}}(n)
    edges = Vector{EdgeResult{L,T,P,V}}(length(edge_labels))
    return SystemOutputStateSample(nodes, edges, edge_labels)

end


function update!(
    sample::SystemOutputStateSample{L,T,P,V},
    state_matrix::Matrix{V}, flow_matrix::Matrix{V},
) where {L,T<:Period,P<:PowerUnit,V<:Real}

    n = length(sample.nodes)
    source = n+1
    sink = n+2

    for i in 1:n
        sample.nodes[i] = NodeResult{L,T,P}(
            state_matrix[source,i], flow_matrix[source,i],
            state_matrix[i,sink], flow_matrix[i,sink], NoCheck())
    end

    for e in 1:length(sample.edgelabels)
        i, j = sample.edgelabels[e]
        sample.edges[e] = EdgeResult{L,T,P}(
            state_matrix[i,j], flow_matrix[i,j], NoCheck())
    end

end

function droppedload(sample::SystemOutputStateSample{L,T,P,V}) where {L,T,P,V}

    isshortfall = false
    totalshortfall = zero(V)

    for node in sample.nodes
        different, difference = checkdifference(node.demand, node.demand_served)
        if different 
            isshortfall = true
            totalshortfall += difference
        end
    end

    return isshortfall, totalshortfall

end

function droppedloads(sample::SystemOutputStateSample{L,T,P,V}) where {L,T,P,V}

    nnodes = length(sample.nodes)
    isshortfall = false
    totalshortfall = zero(V)
    localshortfalls = zeros(V, nnodes)

    for i in 1:nnodes
        node = sample.nodes[i]
        different, difference = checkdifference(node.demand, node.demand_served)
        if different
            isshortfall = true
            totalshortfall += difference
            localshortfalls[i] = difference
        end
    end

    return isshortfall, totalshortfall, localshortfalls

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
