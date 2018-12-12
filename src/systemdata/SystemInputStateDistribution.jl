struct SystemInputStateDistribution{N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}
    region_idxs::Base.OneTo{Int}
    region_labels::Vector{String}
    region_maxdispatchabledistrs::Vector{CapacityDistribution{V}}
    region_maxdispatchablesamplers::Vector{CapacitySampler{V}}
    vgsample_idxs::Base.OneTo{Int}
    vgsamples::Matrix{V}
    interface_idxs::Base.OneTo{Int}
    interface_labels::Vector{Tuple{Int,Int}}
    interface_maxflowdistrs::Vector{CapacityDistribution{V}}
    interface_maxflowsamplers::Vector{CapacitySampler{V}}
    loadsample_idxs::Base.OneTo{Int}
    loadsamples::Matrix{V}
    graph::DiGraph{Int}


    # Multi-region constructor
    function SystemInputStateDistribution{N,T,P,E}(
        region_labels::Vector{String},
        region_maxdispatchabledistrs::Vector{CapacityDistribution{V}},
        region_maxdispatchablesamplers::Vector{CapacitySampler{V}},
        vgsamples::Matrix{V},
        interface_labels::Vector{Tuple{Int,Int}},
        interface_maxflowdistrs::Vector{CapacityDistribution{V}},
        interface_maxflowsamplers::Vector{CapacitySampler{V}},
        loadsamples::Matrix{V}) where {N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V}

        n_regions = length(region_labels)
        region_idxs = Base.OneTo(n_regions)
        @assert length(region_maxdispatchabledistrs) == n_regions
        @assert size(vgsamples, 1) == n_regions
        @assert size(loadsamples, 1) == n_regions

        n_interfaces = length(interface_labels)
        interface_idxs = Base.OneTo(n_interfaces)
        @assert n_interfaces == length(interface_maxflowdistrs)

        n_vgsamples = size(vgsamples, 2)
        vgsample_idxs = Base.OneTo(n_vgsamples)

        n_loadsamples = size(loadsamples, 2)
        loadsample_idxs = Base.OneTo(n_loadsamples)

        source_node = n_regions + 1
        sink_node   = n_regions + 2
        graph = DiGraph(sink_node)

        # Populate graph with interface edges
        for (from, to) in interface_labels
            add_edge!(graph, from, to)
            add_edge!(graph, to, from)
        end

        # Populate graph with source and sink edges
        for i in region_idxs

            add_edge!(graph, source_node, i)
            add_edge!(graph, i, sink_node)

            # Graph requires reverse edges as well,
            # even if max flow is zero
            # (why does LightGraphs use a DiGraph for this then?)
            add_edge!(graph, i, source_node)
            add_edge!(graph, sink_node, i)

        end

        new{N,T,P,E,V}(
            region_idxs, region_labels,
            region_maxdispatchabledistrs,
            region_maxdispatchablesamplers,
            vgsample_idxs, vgsamples,
	    interface_idxs, interface_labels,
            interface_maxflowdistrs,
            interface_maxflowsamplers,
            loadsample_idxs, loadsamples, graph)

    end

    # Single-region constructor
    function SystemInputStateDistribution{N,T,P,E}(
        maxdispatchable_distr::CapacityDistribution{V},
        maxdispatchable_sampler::CapacitySampler{V},
        vgsamples::Vector{V}, loadsamples::Vector{V}
    ) where {N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V}

        graph = DiGraph(3)
        add_edge!(graph, 1, 2)
        add_edge!(graph, 2, 1)
        add_edge!(graph, 1, 3)
        add_edge!(graph, 3, 1)

        new{N,T,P,E,V}(
            Base.OneTo(1), ["Region"],
            [maxdispatchable_distr], [maxdispatchable_sampler],
            Base.OneTo(length(vgsamples)), reshape(vgsamples, 1, :),
            Base.OneTo(0), Tuple{Int,Int}[],
            CapacityDistribution{V}[], CapacitySampler{V}[],
            Base.OneTo(length(loadsamples)), reshape(loadsamples, 1, :), graph)

    end

end

function Base.rand!(rng::MersenneTwister, A::Matrix{V},
                    system::SystemInputStateDistribution{N,T,P,E,V}
    ) where {N,T,P,E,V}

    region_idxs = system.region_idxs
    source_idx = last(region_idxs) + 1
    sink_idx = last(region_idxs) + 2

    vgsample_idx = rand(rng, system.vgsample_idxs)
    loadsample_idx = rand(rng, system.loadsample_idxs)

    # Assign random generation capacities and loads
    for i in region_idxs
        A[source_idx, i] =
            rand(rng, system.region_maxdispatchablesamplers[i]) +
            system.vgsamples[i, vgsample_idx]
        A[i, sink_idx] = system.loadsamples[i, loadsample_idx]
    end

    # Assign random line limits
    for ij in system.interface_idxs
        i, j = system.interface_labels[ij]
        flowlimit = rand(rng, system.interface_maxflowsamplers[ij])
        A[i,j] = flowlimit
        A[j,i] = flowlimit
    end

    return A

end

function Base.rand(rng::MersenneTwister,
                   system::SystemInputStateDistribution{N,T,P,E,V}
    ) where {N,T,P,E,V}
    n = nv(system.graph)
    A = zeros(V, n, n)
    return rand!(rng, A, system)
end
