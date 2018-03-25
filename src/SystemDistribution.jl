LimitDistributions{T} = Vector{Generic{T,Float64,Vector{T}}}
LimitSamplers{T} = Vector{Distributions.GenericSampler{T, Vector{T}}}

struct SystemDistribution{N,P<:Period,E<:EnergyUnit,V<:Real}
    gen_distributions::LimitDistributions{V}
    vgsamples::Matrix{V}
    interface_labels::Vector{Tuple{Int,Int}}
    interface_distributions::LimitDistributions{V}
    loadsamples::Matrix{V}

    function SystemDistribution{N,P,E}(gen_dists::LimitDistributions{V},
                                vgsamples::Matrix{V},
                                interface_labels::Vector{Tuple{Int,Int}},
                                interface_dists::LimitDistributions{V},
                                loadsamples::Matrix{V}
                                ) where {N,P,E,V}

        @assert length(gen_dists) == size(vgsamples, 1)
        @assert size(vgsamples) == size(loadsamples)
        @assert length(interface_dists) == length(interface_labels)

        new{N,P,E,V}(gen_dists, vgsamples,
               interface_labels, interface_dists, loadsamples)

    end

    function SystemDistribution{N,P,E}(gd::Generic{V,Float64,Vector{V}},
                                vg::Vector{V}, ld::Vector{V}) where {N,P,E,V}
        new{N,P,E,V}([gd], reshape(vg, 1, length(vg)),
               Vector{Tuple{Int,Int}}[], Generic{V,Float64,Vector{V}}[],
               reshape(ld, 1, length(ld)))
    end
end

struct SystemSampler{T <: Real}
    gen_samplers::LimitSamplers{T}
    vgsamples::Matrix{T}
    interface_labels::Vector{Tuple{Int,Int}}
    interface_samplers::LimitSamplers{T}
    loadsamples::Matrix{T}
    node_idxs::UnitRange{Int}
    interface_idxs::UnitRange{Int}
    timesample_idxs::UnitRange{Int}
    graph::DiGraph{Int}

    function SystemSampler(sys::SystemDistribution{N,P,E,V}) where {N,P,E,V}

        n_nodes = length(sys.gen_distributions)
        n_interfaces = length(sys.interface_distributions)
        n_netloadsamples = size(sys.loadsamples, 2)

        node_idxs = Base.OneTo(n_nodes)
        interface_idxs = Base.OneTo(n_interfaces)
        timesample_idxs = Base.OneTo(n_netloadsamples)

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

        new{V}(sampler.(sys.gen_distributions), sys.vgsamples,
               sys.interface_labels,
               sampler.(sys.interface_distributions),
               sys.loadsamples,
               node_idxs, interface_idxs, timesample_idxs,
               graph)

    end
end

function Base.rand!(A::Matrix{T}, system::SystemSampler{T}) where T

    node_idxs = system.node_idxs
    source_idx = last(node_idxs) + 1
    sink_idx = last(node_idxs) + 2
    timesample_idx = rand(system.timesample_idxs)

    # Assign random generation capacities and loads
    for i in node_idxs
        A[source_idx, i] =
            rand(system.gen_samplers[i]) +
            system.vgsamples[i, timesample_idx]
        A[i, sink_idx] = system.loadsamples[i, timesample_idx]
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

function Base.rand(system::SystemSampler{T}) where T
    n = nv(system.graph)
    A = zeros(T, n, n)
    return rand!(A, system)
end
