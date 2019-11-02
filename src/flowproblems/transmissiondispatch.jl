struct TransmissionDispatchProblem <: OptimizationProblem
    fp::FlowProblem
end

flowproblem(tdp::TransmissionDispatchProblem) = tdp.fp

"""

    TransmissionDispatchProblem(sys::SystemModel)

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

Flows to the charging node have an attenuated negative cost, incentivizing
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
function TransmissionDispatchProblem(sys::SystemModel)

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

    nedges = 2*ninterfaces + 2*nregions + 4*nstorages + 7*ngenstors
    nnodes = nregions + 2*nallstors + ngenstors + 1

    regionnodes = 1:nregions

    storagedischargenodes = last(regionnodes) .+ 1:nstorages
    genstordischargenodes = last(storagedischargenodes) .+ 1:ngenstors
    allstoragedischargenodes = last(regionnodes) .+ 1:nallstors

    storagechargenodes = last(allstoragedischargenodes) .+ 1:nstorages
    genstorchargenodes = last(storagechargenodes) .+ 1:ngenstors
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

    return TransmissionDispatchProblem(
        FlowProblem(nodesfrom, nodesto, limits, costs, injections))

end

function update_flownodes!(
    tdprob::TransmissionDispatchProblem,
    t::Int,
    loads::Matrix{Int},
    genranges::Vector{Tuple{Int,Int}},
    gens::Generators,
    gens_available::Vector{Bool},
    storranges::Vector{Tuple{Int,Int}},
    stors::Storages,
    stors_available::Vector{Bool},
    stors_energy::Vector{Int},
)

    nregions = length(genranges)
    fp = flowproblem(tdprob)
    slacknode = flowproblem.nodes[end]

    for r in 1:nregions

        region_node = fp.nodes[r]
        region_dischargenode = fp.nodes[nregions + r]
        region_chargenode = fp.nodes[2*nregions + r]

        # Update generators
        gen_range = genranges[r]
        region_gensurplus =
            available_capacity(gens_available, gens, gen_range, t) - loads[r, t]
        updateinjection!(region_node, slacknode, region_gensurplus)

        # Update storages
        stor_range = storranges[r]
        charge_capacity, discharge_capacity = available_storage_capacity(
            stors_available, stors_energy, stors, stor_range, t)
        updateinjection!(region_chargenode, slacknode, -charge_capacity)
        updateinjection!(region_dischargenode, slacknode, discharge_capacity)

    end

end

function update_flowedges!(
    tdprob::TransmissionDispatchProblem,
    t::Int,
    lineranges::Vector{Tuple{Int,Int}},
    lines::Lines,
    lines_available::Vector{Bool}
) where {V <: Real}

    ninterfaces = length(lineranges)
    fp = flowproblem(tdprob)

    for i in 1:ninterfaces

        interface_forwardedge = fp.edges[i]
        interface_backwardedge = fp.edges[ninterfaces + i]
        line_range = lineranges[i]

        interface_capacity_forward, interface_capacity_backward =
            available_capacity(lines_available, lines, line_range, t)

        updateflowlimit!(interface_forwardedge, interface_capacity_forward)
        updateflowlimit!(interface_backwardedge, interface_capacity_backward)

    end

end

function update_energy!(
    stors_energy::Vector{Int},
    t::Int,
    storranges::Vector{Tuple{Int,Int}},
    stors::Storages,
    stors_available::Vector{Bool},
    tdprob::TransmissionDispatchProblem,
    ninterfaces::Int
)

    nregions = length(storranges)
    nstors = length(stors)
    fp = flowproblem(tdprob)

    for r in 1:nregions

        region_discharge = fp.edges[2*ninterfaces + nregions + r].flow
        region_charge = fp.edges[2*ninterfaces + 3*nregions + r].flow

        storrange = storranges[r]

        if region_charge > 0

            charge_storage!(
                stors_available, stors_energy,
                region_charge, stors, storrange, t)

        elseif region_discharge > 0

            discharge_storage!(
                stors_available, stors_energy,
                region_discharge, stors, storrange, t)

        end

    end

end

# TODO: Use a macro to abstract out the significant commonalities with
#       update! methods for DispatchProblem and TranmssionProblem
function update!(
    sample::SystemOutputStateSample{L,T,P},
    tdprob::TransmissionDispatchProblem
) where {L,T<:Period,P<:PowerUnit}

    nregions = length(outputsample.regions)
    ninterfaces = length(outputsample.interfaces)
    fp = flowproblem(tdprob)

    # Save gen available, gen dispatched, demand, demand served for each region
    for i in 1:nregions
        node = fp.nodes[i]
        surplus_edge = fp.edges[2*ninterfaces + i]
        shortfall_edge = fp.edges[2*ninterfaces + 5*nregions + i]
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
