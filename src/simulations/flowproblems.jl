"""

    FlowProblem(::NonSequentialNetworkFlow, sys::SystemModel)

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
function MinCostFlows.FlowProblem(::NonSequentialNetworkFlow, sys::SystemModel)

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

    return FlowProblem(nodesfrom, nodesto, limits, costs, injections)

end

MinCostFlows.FlowProblem(simspec::SequentialNetworkFlow, sys::SystemModel) =
    simspec.collapsestorage ?
        flowproblem_collapsedstorage(sys) : 
        flowproblem_explicitstorage(sys)

"""

    flowproblem_collapsedstorage(sys::SystemModel)

Create a min-cost flow problem for the max power delivery problem with
generation and storage discharging in decreasing order of priority, and
storage charging with excess capacity. Storage devices within a region
are pooled into a single node on the network.

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
 4. Storage discharge dispatch (region order)
 5. Storage discharge unused capacity (region order)
 6. Storage charge dispatch (region order)
 7. Storage charge unused capacity (region order)
 8. Unserved energy (region order)

"""
function flowproblem_collapsedstorage(sys::SystemModel)

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
    nodesfrom[forwardtransmission] = sys.interfaces.regions_from
    nodesto[forwardtransmission] = sys.interfaces.regions_to
    limits[forwardtransmission] .= 0 # Will be updated during simulation
    costs[forwardtransmission] .= 1

    # Reverse transmission edges
    reversetransmission = forwardtransmission .+ ninterfaces
    nodesfrom[reversetransmission] = sys.interfaces.regions_to
    nodesto[reversetransmission] = sys.interfaces.regions_from
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


"""

    flowproblem_explicitstorage(sys::SystemModel)

Create a min-cost flow problem for the max power delivery problem with
generation and storage discharging in decreasing order of priority, and
storage charging with excess capacity. Storage and GeneratorStorage devices
within a region are represented individually on the network.

This involves injections/withdrawals at one node (regional capacity
surplus/shortfall) for each modelled region, as well as two/three nodes
associated with each Storage/GeneratorStorage device, and a supplementary
"slack" node in the network that can absorb undispatched power or pass
unserved energy or unused charging capability through to satisfy
power balance constraints.

Flows from the generation nodes are free, while flows from the charging and
discharging nodes are costed according to the time-to-charge/discharge of the
storage device, ensuring efficient coordination across units, while enforcing
that storage is only discharged once generation capacity is exhausted,
implying a storage operation strategy that prioritizes resource adequacy over
economic arbitrage).

Flows to the charging node have an attenduated negative cost, incentivizing
immediate storage charging if generation and transmission allows it, while
avoiding charging by discharging other similar-priority storage (since that
would incur an overall positive cost).

Flows to the slack node (representing unused generation or storage discharge
capacity) are free, but flows from the slack node to serve load incur the lost
load penalty of 9999. Flows from the slack node in lieu of storage charging
or discharging are free.

Flows on transmission interfaces assume a hurdle rate of 1
to keep unserved energy close to the source of the shortage and eliminate
loop flows. This has the side-effect of disincentivising wheeling power across
multiple regions for charging purposes, however.

Nodes in the problem are ordered as:

 1. Regional generation surplus/shortfall (region order)
 2. Device storage discharge capacity (device order, all storages)
 3. Device storage charge capacity (device order, all storages)
 3. Device inflow capacity (device order, GeneratorStorages only)
 4. Slack node

Edges are ordered as:

 1. Forward transmission (interface order)
 2. Reverse transmission (interface order)
 3. Generation unused capacity (region order)
 4. Device storage discharge dispatch (device order)
 5. Device storage discharge unused capacity (device order)
 6. Device storage charge dispatch (device order)
 7. Device storage charge unused capacity (device order)
 8. Inflow discharged (device order)
 9. Inflow charged (device order)
 10. Inflow spilled (device order)
 11. Unserved energy (region order)

"""
function flowproblem_explicitstorage(sys::SystemModel)

    nregions = length(sys.regions)
    ninterfaces = length(sys.interfaces)
    nstorages = length(sys.storages)
    ngenstors = length(sys.generatorstorages)
    nallstors = nstorages + ngenstors

    storageregions =
        assetgrouplist(sys.storages_regionstart, nstorages)
    genstorageregions =
        assetgrouplist(sys.generatorstorages_regionstart, ngenstors)
    allstorageregions = [storageregions; genstorageregions]

    nedges = ninterfaceedges + 2*nregions + 4*nstorages + 7*ngenstors
    nnodes = nregions + 2*nallstorages + ngenstors + 1

    regionnodes = 1:nregions

    storagedischargenodes = last(regionnodes) .+ 1:nstorages
    genstordischargenodes = last(storagedischargenodes) .+ 1:genstors
    allstoragedischargenodes = last(regionnodes) .+ 1:nallstors

    storagechargenodes = last(allstoragedischargenodes) .+ 1:nstorages
    genstorchargenodes = last(storagechargenodes) .+ 1:genstors
    allstoragechargenodes = last(allstoragedischargenodes) .+ 1:nallstors

    inflownodes = last(allstoragechargenodes) .+ 1:ngenstors
    slacknode = last(inflownodes) + 1

    nodesfrom = Vector{Int}(undef, nedges)
    nodesto = Vector{Int}(undef, nedges)
    costs = Vector{Int}(undef, nedges)
    limits = Vector{Int}(undef, nedges)
    injections = zeros(Int, nnodes)

    # Forward transmission edges
    forwardtransmission = 1:ninterfaces
    nodesfrom[forwardtransmission] = sys.interfaces.regions_from
    nodesto[forwardtransmission] = sys.interfaces.regions_to
    limits[forwardtransmission] .= 0 # Will be updated during simulation
    costs[forwardtransmission] .= 1

    # Reverse transmission edges
    reversetransmission = last(forwardtransmission) .+ 1:ninterfaces
    nodesfrom[reversetransmission] = sys.interfaces.regions_to
    nodesto[reversetransmission] = sys.interfaces.regions_from
    limits[reversetransmission] .= 0 # Will be updated during simulation
    costs[reversetransmission] .= 1

    # Unused generation edges
    unusedcapacityedges = last(reversetransmission) .+ 1:nregions
    nodesfrom[unusedcapacityedges] = regionnodes
    nodesto[unusedcapacityedges] .= slacknode
    limits[unusedcapacityedges] .= 999999
    costs[unusedcapacityedges] .= 0

    # Dispatched storage discharge edges
    storagedischargeedges = last(unusedcapacityedges) .+ 1:nallstors
    nodesfrom[storagedischargeedges] = allstoragedischargenodes
    nodesto[storagedischargeedges] = allstorageregions
    limits[storagedischargeedges] .= 999999
    costs[storagedischargeedges] .= 10 # Will be updated during simulation

    # Unused storage discharge edges
    unusedstoragedischargeedges = last(storagedischargeedges) .+ 1:nallstors
    nodesfrom[unusedstoragedischargeedges] = allstoragedischargenodes
    nodesto[unusedstoragedischargeedges] .= slacknode
    limits[unusedstoragedischargeedges] .= 999999
    costs[unusedstoragedischargeedges] .= 0

    # Dispatched storage charge edges
    storagechargeedges = last(unusedstoragedischargeedges) .+ 1:nallstors
    nodesfrom[storagechargeedges] = allstorageregions
    nodesto[storagechargeedges] = allstoragechargenodes
    limits[storagechargeedges] .= 999999
    costs[storagechargeedges] .= -9 # Will be updated during simulation

    # Unused storage charge edges
    unusedstoragechargeedges = last(storagechargeedges) .+ 1:nallstors
    nodesfrom[unusedstoragechargeedges] .= slacknode
    nodesto[unusedstoragechargeedges] = allstoragechargenodes
    limits[unusedstoragechargeedges] .= 999999
    costs[unusedstoragechargeedges] .= 0

    # Inflow discharging
    inflowdischargeedges = last(unusedstoragechargeedges) .+ 1:ngenstors
    nodesfrom[inflowdischargeedges] = inflownodes
    nodesto[inflowdischargeedges] = genstordischargenodes
    limits[inflowdischargeedges] .= 0 # Will be updated during simulation
    costs[inflowdischargeedges] .= 0

    # Inflow charging
    inflowchargeedges = last(inflowdischargeedges) .+ 1:ngenstors
    nodesfrom[inflowchargeedges] = inflownodes
    nodesto[inflowchargeedges] = genstorchargenodes
    limits[inflowchargeedges] .= 0 # Will be updated during simulation
    costs[inflowchargeedges] .= 1

    # Inflow spill
    inflowspilledges = last(inflowchargeedges) .+ 1:ngenstors
    nodesfrom[inflowchargeedges] = inflownodes
    nodesto[inflowchargeedges] .= slacknode
    limits[inflowchargeedges] .= 999999
    costs[inflowchargeedges] .= 0

    # Unserved energy edges
    unservedenergyedges = last(inflowspilledges) .+ 1:nregions
    nodesfrom[unservedenergyedges] .= slacknode
    nodesto[unservedenergyedges] = regionnodes
    limits[unservedenergyedges] .= 999999
    costs[unservedenergyedges] .= 9999

    return FlowProblem(nodesfrom, nodesto, limits, costs, injections)

end
