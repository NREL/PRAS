struct DispatchProblem <: OptimizationProblem
    fp::FlowProblem
end

flowproblem(dp::DispatchProblem) = dp.fp

"""

    DispatchProblem(sys::SystemModel)

Create a min-cost flow problem to solve the max power delivery problem with
heterogeneous storage device dispatch and no transmission constraints.
Energy-unlimited generators are dispatched first in aggregate, while Storage
and GeneratorStorage devices are represented individually.

This involves injections/withdrawals at one node (capacity
surplus/shortfall), as well as two/three nodes associated with each
Storage/GeneratorStorage device, and a supplementary "slack" node in the
network that can absorb undispatched power or pass unserved energy or unused
charging capability through to satisfy power balance constraints.

Flows from the generation nodes are free, while flows from the charging and
discharging nodes are costed according to the time-to-charge/discharge of the
storage device, ensuring efficient coordination across units, while enforcing
that storage is only discharged once generation capacity is exhausted,
implying a storage operation strategy that prioritizes resource adequacy over
economic arbitrage).

Flows to the charging node have an attenuated negative cost, incentivizing
immediate storage charging if generation and transmission allows it, while
avoiding charging by discharging other similar-priority storage (since that
would incur an overall positive cost).

Flows to the slack node (representing unused generation or storage discharge
capacity) are free, but flows from the slack node to serve load incur the lost
load penalty of 9999. Flows from the slack node in lieu of storage charging
or discharging are free.

Nodes in the problem are ordered as:

 1. Generation surplus/shortfall node
 2. Device storage discharge capacity (device order, all storages)
 3. Device storage charge capacity (device order, all storages)
 4. Device inflow capacity (device order, GeneratorStorages only)
 5. Slack node

Edges are ordered as:

 1. Generation unused capacity
 2. Device storage discharge dispatch (device order)
 3. Device storage discharge unused capacity (device order)
 4. Device storage charge dispatch (device order)
 5. Device storage charge unused capacity (device order)
 6. Inflow discharged (device order)
 7. Inflow charged (device order)
 8. Inflow spilled (device order)
 9. Unserved energy

"""
function DispatchProblem(sys::SystemModel)

    nstorages = length(sys.storages)
    ngenstors = length(sys.generatorstorages)
    nallstors = nstorages + ngenstors

    nedges = 4*nstorages + 7*ngenstors
    nnodes = 2*nallstorages + ngenstors + 2

    generationnode = 1
    storagedischargenodes = generationnode .+ 1:nstorages
    genstordischargenodes = last(storagedischargenodes) .+ 1:genstors
    allstoragedischargenodes = generationnode .+ 1:nallstors

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

    # Unused generation edge
    unusedcapacityedge = 1
    nodesfrom[unusedcapacityedge] = generationnode
    nodesto[unusedcapacityedge] .= slacknode
    limits[unusedcapacityedge] .= 999999
    costs[unusedcapacityedge] .= 0

    # Dispatched storage discharge edges
    storagedischargeedges = unusedcapacityedge .+ 1:nallstors
    nodesfrom[storagedischargeedges] = allstoragedischargenodes
    nodesto[storagedischargeedges] = generationnode
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
    nodesfrom[storagechargeedges] = generationnode
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
    unservedenergyedge = last(inflowspilledges) + 1
    nodesfrom[unservedenergyedge] = slacknode
    nodesto[unservedenergyedge] = generationnode
    limits[unservedenergyedge] = 999999
    costs[unservedenergyedge] = 9999

    return DispatchProblem(
        FlowProblem(nodesfrom, nodesto, limits, costs, injections))

end
