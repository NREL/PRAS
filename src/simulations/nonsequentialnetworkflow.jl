struct NonSequentialNetworkFlow <: SimulationSpec{NonSequential}
    nsamples::Int

    function NonSequentialNetworkFlow(nsamples::Int)
        @assert nsamples > 0
        new(nsamples)
    end
end

ismontecarlo(::NonSequentialNetworkFlow) = true
iscopperplate(::NonSequentialNetworkFlow) = false

function assess!(acc::ResultAccumulator,
                 simulationspec::NonSequentialNetworkFlow,
                 system::SystemInputStateDistribution{L,T,P,E,Float64},
                 t::Int) where {L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    thread = Threads.threadid()

    flowproblem = FlowProblem(simulationspec, system)
    outputsample = SystemOutputStateSample{L,T,P,Float64}(
        system.interface_labels, length(system.region_labels))

    for i in 1:simulationspec.nsamples
        rand!(acc.rngs[thread], flowproblem, system)
        solveflows!(flowproblem)
        update!(outputsample, flowproblem)
        update!(acc, outputsample, t, i)
    end

end

"""

    FlowProblem(::NonSequentialNetworkFlow, sys::SystemInputStateDistribution)

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
function MinCostFlows.FlowProblem(::NonSequentialNetworkFlow, sys::SystemInputStateDistribution)

    nregions = length(sys.region_labels)
    ninterfaces = length(sys.interface_labels)

    ninterfaceedges = 2 * ninterfaces
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
    nodesfrom[forwardtransmission] = first.(sys.interface_labels)
    nodesto[forwardtransmission] = last.(sys.interface_labels)
    limits[forwardtransmission] .= 0
    costs[forwardtransmission] .= 1

    # Reverse transmission edges
    reversetransmission = forwardtransmission .+ ninterfaces
    nodesfrom[reversetransmission] = last.(sys.interface_labels)
    nodesto[reversetransmission] = first.(sys.interface_labels)
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

    return FlowProblem(nodesfrom, nodesto, limits, costs, injections)

end
