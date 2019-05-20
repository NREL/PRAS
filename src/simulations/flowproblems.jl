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

"""

    FlowProblem(::SequentialNetworkFlow, sys::SystemInputStateDistribution)

Create a min-cost flow problem for the max power delivery problem with
generation and storage discharging in decreasing order of priority, and
storage charging with excess capacity.

This involves injections/withdrawals at three nodes (regional capacity
surplus/shortfall, charging, and discharging) for each modelled region, as well
as a supplementary "slack" node in the network that can absorb undispatched
power or pass unserved energy or unused charging capability through to satisfy
power balance constraints.

Flows from the generation nodes are free, while flows from the discharging
nodes have a cost of 10 (this ensures storage is only discharged once generation
capacity is exhausted, implying a storage operation strategy that prioritizes
resource adequacy over economic arbitrage).

Flows to the charging node have a cost of -9, incentivizing immediate storage
charging if generation and transmission allows it, while avoiding charging by
discharging other storage (since that would incur an overall positive cost).

Flows to the slack node (representing unused generation or storage discharge
capacity) are free, but flows from the slack node to serve load incur the lost
load penalty of 9999. Flows from the slack node in lieu of storage charging
are free.

Flows on transmission interfaces assume a hurdle rate of 1
to keep unserved energy close to the source of the shortage and eliminate
loop flows. This has the side-effect of disincentivising wheeling power across
multiple regions for charging purposes, however.

Nodes in the problem are ordered as:

 1. Regional generation surplus/shortfall (region order)
 2. Regional storage discharge capacity (region order)
 3. Regional storage charge capacity (region order)
 4. Slack node

Edges are ordered as: 

 1. Forward transmission (interface order)
 2. Reverse transmission (interface order)
 3. Generation unused capacity (region order)
 3. Storage discharge dispatch (region order)
 4. Storage discharge unused capacity (region order)
 5. Storage charge dispatch (region order)
 6. Storage charge unused capacity (region order)
 7. Unserved energy (region order)

"""
function MinCostFlows.FlowProblem(::SequentialNetworkFlow, sys::SystemModel)

    nregions = length(sys.regions)
    ninterfaces = length(sys.interfaces)

    ninterfaceedges = 2*ninterfaces
    nedges = ninterfaceedges + 6*nregions

    regions = 1:nregions
    storagedischargenodes = nregions .+ regions
    storagechargenodes = 2*nregions .+ regions
    slacknode = 3*nregions + 1

    nodesfrom = Vector{Int}(undef, nedges)
    nodesto = Vector{Int}(undef, nedges)
    costs = Vector{Int}(undef, nedges)
    limits = Vector{Int}(undef, nedges)
    injections = zeros(Int, slacknode)

    # Forward transmission edges
    forwardtransmission = 1:ninterfaces
    nodesfrom[forwardtransmission] = first.(sys.interfaces)
    nodesto[forwardtransmission] = last.(sys.interfaces)
    limits[forwardtransmission] .= 0 # Will be updated during simulation
    costs[forwardtransmission] .= 1

    # Reverse transmission edges
    reversetransmission = forwardtransmission .+ ninterfaces
    nodesfrom[reversetransmission] = last.(sys.interfaces)
    nodesto[reversetransmission] = first.(sys.interfaces)
    limits[reversetransmission] .= 0 # Will be updated during simulation
    costs[reversetransmission] .= 1

    # Unused generation edges
    unusedcapacityedges = (1:nregions) .+ ninterfaceedges
    nodesfrom[unusedcapacityedges] = regions
    nodesto[unusedcapacityedges] .= slacknode
    limits[unusedcapacityedges] .= 999999
    costs[unusedcapacityedges] .= 0

    # Dispatched storage discharge edges
    storagedischargeedges = unusedcapacityedges .+ nregions
    nodesfrom[storagedischargeedges] = storagedischargenodes
    nodesto[storagedischargeedges] = regions
    limits[storagedischargeedges] .= 999999
    costs[storagedischargeedges] .= 10

    # Unused storage discharge edges
    unusedstoragedischargeedges = storagedischargeedges .+ nregions
    nodesfrom[unusedstoragedischargeedges] = storagedischargenodes
    nodesto[unusedstoragedischargeedges] .= slacknode
    limits[unusedstoragedischargeedges] .= 999999
    costs[unusedstoragedischargeedges] .= 0

    # Dispatched storage charge edges
    storagechargeedges = unusedstoragedischargeedges .+ nregions
    nodesfrom[storagechargeedges] = regions
    nodesto[storagechargeedges] = storagechargenodes
    limits[storagechargeedges] .= 999999
    costs[storagechargeedges] .= -9

    # Unused storage charge edges
    unusedstoragechargeedges = storagechargeedges .+ nregions
    nodesfrom[unusedstoragechargeedges] .= slacknode
    nodesto[unusedstoragechargeedges] = storagechargenodes
    limits[unusedstoragechargeedges] .= 999999
    costs[unusedstoragechargeedges] .= 0

    # Unserved energy edges
    unservedenergyedges = unusedstoragechargeedges .+ nregions
    nodesfrom[unservedenergyedges] .= slacknode
    nodesto[unservedenergyedges] = regions
    limits[unservedenergyedges] .= 999999
    costs[unservedenergyedges] .= 9999

    return FlowProblem(nodesfrom, nodesto, limits, costs, injections)

end
