struct RegionResult{L,T<:Period,P<:PowerUnit,V<:Real}

    net_injection::V
    surplus::V
    shortfall::V

    RegionResult{L,T,P}(
        net_injection::V, surplus::V, shortfall::V
    ) where {L,T<:Period,P<:PowerUnit,V<:Real} =
    new{L,T,P,V}(net_injection, surplus, shortfall)

end

struct InterfaceResult{L,T<:Period,P<:PowerUnit,V<:Real}

    max_transfer_magnitude::V
    transfer::V

    function InterfaceResult{L,T,P}(
        max::V, actual::V) where {L,T<:Period,P<:PowerUnit,V<:Real}
        new{L,T,P,V}(max, actual)
    end

end

struct SystemOutputStateSample{L,T,P,V}
    nodes::Vector{RegionResult{L,T,P,V}}
    edges::Vector{InterfaceResult{L,T,P,V}}
    edgelabels::Vector{Tuple{Int,Int}}

    function SystemOutputStateSample(
        nodes::Vector{RegionResult{L,T,P,V}},
        edges::Vector{InterfaceResult{L,T,P,V}},
        edgelabels::Vector{Tuple{Int,Int}}
    ) where {L,T,P,V}
        @assert length(edges) == length(edgelabels)
        new{L,T,P,V}(nodes, edges, edgelabels)
    end
end

function SystemOutputStateSample{L,T,P,V}(
    edge_labels::Vector{Tuple{Int,Int}}, n::Int) where {L,T,P,V}

    nodes = Vector{RegionResult{L,T,P,V}}(n)
    edges = Vector{InterfaceResult{L,T,P,V}}(length(edge_labels))
    return SystemOutputStateSample(nodes, edges, edge_labels)

end

function update!(
    sample::SystemOutputStateSample{L,T,P,V},
    fp::FlowProblem
) where {L,T<:Period,P<:PowerUnit,V<:Real}

    nnodes = length(sample.nodes)
    nedges = length(sample.edges)

    # Save gen available, gen dispatched, demand, demand served for each region
    for i in 1:nnodes
        node = fp.nodes[i]
        surplus_edge = fp.nodes[2*nedges + i]
        shortfall_edge = fp.nodes[2*nedges + nnodes + i]
        sample.nodes[i] = RegionResult{L,T,P}(
            node.injection, surplus_edge.flow, shortfall_edge.flow)
    end

    # Save flow available, flow for each interface
    for e in 1:nedges
        i, j = sample.edgelabels[e]
        forwardflow = fp.edges[e].flow
        reverseflow = fp.edges[e+nedges].flow
        flow = forwardflow > reverseflow : forwardflow : -reverseflow
        sample.edges[e] = InterfaceResult{L,T,P}(edgeforward.limit, flow)
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
