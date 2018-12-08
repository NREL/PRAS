struct SystemInputStateDistribution{N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}
    region_labels::Vector{String}
    region_maxdispatchabledistrs::Vector{CapacityDistribution{V}}
    vgsamples::Matrix{V}
    interface_labels::Vector{Tuple{Int,Int}}
    interface_maxflowdistrs::Vector{CapacityDistribution{V}}
    loadsamples::Matrix{V}

    # Multi-region constructor
    function SystemInputStateDistribution{N,T,P,E}(
        region_labels::Vector{String},
        region_maxdispatchabledistrs::Vector{CapacityDistribution{V}},
        vgsamples::Matrix{V},
        interface_labels::Vector{Tuple{Int,Int}},
        interface_maxflowdistrs::Vector{CapacityDistribution{V}},
        loadsamples::Matrix{V}) where {N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V}

        n_regions = length(region_labels)
        @assert length(region_maxdispatchabledistrs) == n_regions
        @assert size(vgsamples, 1) == n_regions
        @assert size(loadsamples, 1) == n_regions
        @assert length(interface_labels) == length(interface_maxflowdistrs)

        new{N,T,P,E,V}(region_labels, region_maxdispatchabledistrs, vgsamples,
                     interface_labels, interface_maxflowdistrs, loadsamples)

    end

    # Single-region constructor
    function SystemInputStateDistribution{N,T,P,E}(
        maxdispatchable::CapacityDistribution{V},
        vgsamples::Vector{V}, loadsamples::Vector{V}
    ) where {N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V}

        new{N,T,P,E,V}(["Region"], [maxdispatchable], reshape(vgsamples, 1, :),
                     Tuple{Int,Int}[], CapacityDistribution[],
                     reshape(loadsamples, 1, :))

    end

end

struct SystemInputStateSampler{T <: Real}
    maxdispatchable_samplers::Vector{CapacitySampler{T}}
    vgsamples::Matrix{T}
    interface_labels::Vector{Tuple{Int,Int}}
    interface_samplers::Vector{CapacitySampler{T}}
    loadsamples::Matrix{T}
    node_idxs::UnitRange{Int}
    interface_idxs::UnitRange{Int}
    loadsample_idxs::UnitRange{Int}
    vgsample_idxs::UnitRange{Int}
    graph::DiGraph{Int}

    function SystemInputStateSampler(sys::SystemInputStateDistribution{N,T,P,E,V}) where {N,T,P,E,V}

        n_nodes = length(sys.region_labels)
        n_interfaces = length(sys.interface_labels)
        n_vgsamples = size(sys.vgsamples, 2)
        n_loadsamples = size(sys.loadsamples, 2)

        node_idxs = Base.OneTo(n_nodes)
        interface_idxs = Base.OneTo(n_interfaces)
        loadsample_idxs = Base.OneTo(n_loadsamples)
        vgsample_idxs = Base.OneTo(n_vgsamples)

        source_node = n_nodes + 1
        sink_node   = n_nodes + 2
        graph = DiGraph(sink_node)

        # Populate graph with interface edges
        for (from, to) in sys.interface_labels
            add_edge!(graph, from, to)
            add_edge!(graph, to, from)
        end

        # Populate graph with source and sink edges
        for i in node_idxs

            add_edge!(graph, source_node, i)
            add_edge!(graph, i, sink_node)

            # Graph requires reverse edges as well,
            # even if max flow is zero
            # (why does LightGraphs use a DiGraph for this then?)
            add_edge!(graph, i, source_node)
            add_edge!(graph, sink_node, i)

        end

        new{V}(sampler.(sys.region_maxdispatchabledistrs), sys.vgsamples,
               sys.interface_labels,
               sampler.(sys.interface_maxflowdistrs),
               sys.loadsamples,
               node_idxs, interface_idxs,
               loadsample_idxs, vgsample_idxs,
               graph)

    end
end

function Base.rand!(A::Matrix{T}, system::SystemInputStateSampler{T}) where T

    node_idxs = system.node_idxs
    source_idx = last(node_idxs) + 1
    sink_idx = last(node_idxs) + 2

    vgsample_idx = rand(system.vgsample_idxs)
    loadsample_idx = rand(system.loadsample_idxs)

    # Assign random generation capacities and loads
    for i in node_idxs
        A[source_idx, i] =
            rand(system.maxdispatchable_samplers[i]) +
            system.vgsamples[i, vgsample_idx]
        A[i, sink_idx] = system.loadsamples[i, loadsample_idx]
    end

    # Assign random line limits
    for ij in system.interface_idxs
        i, j = system.interface_labels[ij]
        flowlimit = rand(system.interface_samplers[ij])
        A[i,j] = flowlimit
        A[j,i] = flowlimit
    end

    return A

end

function Base.rand(system::SystemInputStateSampler{T}) where T
    n = nv(system.graph)
    A = zeros(T, n, n)
    return rand!(A, system)
end
