struct TransmissionProblem <: OptimizationProblem
    fp::FlowProblem
end

flowproblem(tp::TransmissionProblem) = tp.fp

"""

    TransmissionProblem(sys::SystemModel)

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
function TransmissionProblem(sys::SystemModel)

    nregions = length(sys.regions)
    ninterfaces = length(sys.interfaces)

    ninterfaceedges = 2*ninterfaces
    nedges = ninterfaceedges + 2*nregions

    regions = 1:nregions
    slacknode = nregions + 1

    nodesfrom = Vector{Int}(undef, nedges)
    nodesto = Vector{Int}(undef, nedges)
    costs = Vector{Int}(undef, nedges)
    limits = Vector{Int}(undef, nedges)
    injections = zeros(Int, slacknode)

    # Forward transmission edges
    forwardtransmission = 1:ninterfaces
    nodesfrom[forwardtransmission] = sys.interfaces.regions_from
    nodesto[forwardtransmission] = sys.interfaces.regions_to
    limits[forwardtransmission] .= 0
    costs[forwardtransmission] .= 1

    # Reverse transmission edges
    reversetransmission = forwardtransmission .+ ninterfaces
    nodesfrom[reversetransmission] = sys.interfaces.regions_to
    nodesto[reversetransmission] = sys.interfaces.regions_from
    limits[reversetransmission] .= 0
    costs[reversetransmission] .= 1

    # Surplus capacity edges
    surpluscapacityedges = (1:nregions) .+ ninterfaceedges
    nodesfrom[surpluscapacityedges] = regions
    nodesto[surpluscapacityedges] .= slacknode
    limits[surpluscapacityedges] .= 999999
    costs[surpluscapacityedges] .= 0

    # Unserved energy edges
    unservedenergyedges = surpluscapacityedges .+ nregions
    nodesfrom[unservedenergyedges] .= slacknode
    nodesto[unservedenergyedges] = regions
    limits[unservedenergyedges] .= 999999
    costs[unservedenergyedges] .= 9999

    return TransmissionProblem(
        FlowProblem(nodesfrom, nodesto, limits, costs, injections))

end

function rand!(rng::MersenneTwister, tp::TransmissionProblem,
               sampler::SystemInputStateSampler)

    fp = flowproblem(tp)
    slacknode = fp.nodes[end]
    nregions = length(sampler.regions)
    ninterfaces = length(sampler.interfaces)

    # Draw random capacity surplus / deficits
    for i in 1:nregions
        injection = rand(rng, sampler.regions[i])
        updateinjection!(fp.nodes[i], slacknode, injection)
    end

    # Assign random interface limits
    # TODO: Model seperate forward and reverse flow limits
    #       (based on common line outages)
    for i in 1:ninterfaces
        flowlimit = rand(rng, sampler.interfaces[i])
        updateflowlimit!(fp.edges[i], flowlimit) # Forward transmission
        updateflowlimit!(fp.edges[ninterfaces + i], flowlimit) # Reverse transmission
    end

    return fp

end

function update!(
    sample::SystemOutputStateSample{L,T,P},
    transmissionproblem::TransmissionProblem
) where {L,T<:Period,P<:PowerUnit}

    nregions = length(sample.regions)
    ninterfaces = length(sample.interfaces)
    fp = flowproblem(transmissionproblem)

    # Save gen available, gen dispatched, demand, demand served for each region
    for i in 1:nregions
        node = fp.nodes[i]
        surplus_edge = fp.edges[2*ninterfaces + i]
        shortfall_edge = fp.edges[2*ninterfaces + nregions + i]
        sample.regions[i] = RegionResult{L,T,P}(
            node.injection, surplus_edge.flow, shortfall_edge.flow)
    end

    # Save flow available, flow for each interface
    for i in 1:ninterfaces
        forwardedge = fp.edges[i]
        forwardflow = forwardedge.flow
        reverseflow = fp.edges[ninterfaces+i].flow
        flow = forwardflow > reverseflow ? forwardflow : -reverseflow
        sample.interfaces[i] = InterfaceResult{L,T,P}(forwardedge.limit, flow)
    end

end
