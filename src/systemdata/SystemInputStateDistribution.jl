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

        new{N,T,P,E,V}(
            region_idxs, region_labels,
            region_maxdispatchabledistrs,
            region_maxdispatchablesamplers,
            vgsample_idxs, vgsamples,
	    interface_idxs, interface_labels,
            interface_maxflowdistrs,
            interface_maxflowsamplers,
            loadsample_idxs, loadsamples)

    end

    # Single-region constructor
    function SystemInputStateDistribution{N,T,P,E}(
        maxdispatchable_distr::CapacityDistribution{V},
        maxdispatchable_sampler::CapacitySampler{V},
        vgsamples::Vector{V}, loadsamples::Vector{V}
    ) where {N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V}

        new{N,T,P,E,V}(
            Base.OneTo(1), ["Region"],
            [maxdispatchable_distr], [maxdispatchable_sampler],
            Base.OneTo(length(vgsamples)), reshape(vgsamples, 1, :),
            Base.OneTo(0), Tuple{Int,Int}[],
            CapacityDistribution{V}[], CapacitySampler{V}[],
            Base.OneTo(length(loadsamples)), reshape(loadsamples, 1, :))

    end

end

"""
Create a min-cost flow problem for the max power delivery problem. This involves
a supplementary "slack" node in the network that can absorb undispatched power
or pass unserved energy through to satisfy power balance constraints.
Flows to the slack node are free, but flows from the slack node incur the lost
load penalty of 9999. Flows on transmission interfaces assume a hurdle rate of 1
to keep unserved energy close to the source of the shortage and eliminate
loop flows.

Nodes in the problem are indexed in the system's region order, with the slack node
included last. Edges are ordered as: forward transmission (interface order),
backwards transmission (interface order), excess capacity (region order),
unserved energy (region order).
"""
function MinCostFlows.FlowProblem(sys::SystemInputStateDistribution)

    nregions = length(sys.region_labels)
    ninterfaceedges = 2 * length(sys.interface_labels)
    nedges = 2*ninterfaces + 2*nregions

    regions = 1:nregions
    slacknode = nregions + 1

    nodesfrom = Vector{Int}(undef, nedges)
    nodesto = Vector{Int}(undef, nedges)
    costs = Vector{Int}(undef, nedges)
    limits = Vector{Int}(undef, nedges)
    injections = zeros(Int, slacknode)

    # Forward transmission edges
    forwardtransmission = 1:ninterfaceedges
    nodesfrom[forwardtransmission] = first.(sys.edge_labels)
    nodesto[forwardtransmission] = last.(sys.edge_labels)
    limits[forwardtransmission] = 0
    costs[forwardtransmission] = 1

    # Reverse transmission edges
    reversetranmsission = forwardtransmission .+ ninterfaceedges
    nodesfrom[reversetranmsission] = last.(sys.edge_labels)
    nodesto[reversetransmission] = first.(sys.edge_labels)
    limits[reversetransmission] = 0
    costs[reversetransmission] = 1

    # Surplus capacity edges
    surpluscapacityedges = (1:nregions) .+ 2*ninterfacedges
    nodesfrom[surpluscapacityedges] = regions
    nodesto[surpluscapacityedges] = slacknode
    limits[surpluscapacityedges] = 999999
    costs[surpluscapacityedges] = 0

    # Unserved energy edges
    unservedenergyedges = surpluscapacityedges .+ nregions
    nodesfrom[unservedenergyedges] = slacknode
    nodesto[unservedenergyedges] = regions
    limits[unservedenergyedges] = 999999
    costs[unservedenergyedges] = 9999

    return FlowProblem(nodesfrom, nodesto, limits, costs, injections)

end

function Base.rand!(rng::MersenneTwister, fp::FlowProblem,
                    system::SystemInputStateDistribution{N,T,P,E,V}
    ) where {N,T,P,E,V}

    slacknode = fp.nodes[end]
    ninterfaces = length(system.interface_labels)

    vgsample_idx = rand(rng, system.vgsample_idxs)
    loadsample_idx = rand(rng, system.loadsample_idxs)

    # Draw random capacity surplus / deficits
    for i in system.region_idxs
        updateinjection!(
            fp.nodes[i], slacknode,
            rand(rng, system.region_maxdispatchablesamplers[i]) + # Dispatchable generation
            system.vgsamples[i, vgsample_idx] - # Variable generation
            system.loadsamples[i, loadsample_idx] # Load
        )
    end

    # Assign random line limits
    for ij in system.interface_idxs
        i, j = system.interface_labels[ij]
        flowlimit = rand(rng, system.interface_maxflowsamplers[ij])
        updateflowlimit!(fp.edges[ij], flowlimit) # Forward transmission
        updateflowlimit!(fp.edges[ninterfaces + ij], flowlimit) # Reverse transmission
    end

    return A

end

function Base.rand(rng::MersenneTwister, fp::FlowProblem,
                   system::SystemInputStateDistribution{N,T,P,E,V}
    ) where {N,T,P,E,V}
    return rand!(rng, FlowProblem(system), system)
end
