"""

    DispatchProblem(sys::SystemModel)

Create a min-cost flow problem for the multi-region max power delivery problem
with generation and storage discharging in decreasing order of priority, and
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

 1. Regions generation surplus/shortfall (Regions order)
 2. Storage discharge capacity (Storage order)
 3. Storage charge capacity (Storage order)
 4. GenerationStorage discharge capacity (GenerationStorage order)
 5. GenerationStorage charge capacity (GenerationStorage order)
 6. GenerationStorage inflow capacity (GeneratorStorage order)
 7. Slack node

Edges are ordered as:

 1. Regions unserved energy (Regions order)
 2. Regions generation capacity (Regions order)
 3. Interfaces forward capacity (Interfaces order)
 4. Interfaces reverse capacity (Interfaces order)
 5. Storage discharge dispatch (Storage order)
 6. Storage discharge unused capacity (Storage order)
 7. Storage charge dispatch (Storage order)
 8. Storage charge unused capacity (Storage order)
 9. GenerationStorage discharge dispatch (GenerationStorage order)
 10. GenerationStorage discharge unused capacity (GenerationStorage order)
 11. GenerationStorage charge dispatch (GenerationStorage order)
 12. GenerationStorage charge unused capacity (GenerationStorage order)
 13. GenerationStorage inflow discharged (GenerationStorage order)
 14. GenerationStorage inflow charged (GenerationStorage order)
 15. GenerationStorage inflow unused (GenerationStorage order)

"""
struct DispatchProblem

    fp::FlowProblem

    # Node labels
    region_nodes::UnitRange{Int}
    storage_discharge_nodes::UnitRange{Int}
    storage_charge_nodes::UnitRange{Int}
    genstorage_discharge_nodes::UnitRange{Int}
    genstorage_charge_nodes::UnitRange{Int}
    genstorage_inflow_nodes::UnitRange{Int}
    slacknode::Int

    # Edge labels
    region_unserved_edges::UnitRange{Int}
    region_unused_edges::UnitRange{Int}
    interface_forward_edges::UnitRange{Int}
    interface_reverse_edges::UnitRange{Int}
    storage_dischargedispatch_edges::UnitRange{Int}
    storage_dischargeunused_edges::UnitRange{Int}
    storage_chargedispatch_edges::UnitRange{Int}
    storage_chargeunused_edges::UnitRange{Int}
    genstorage_dischargedispatch_edges::UnitRange{Int}
    genstorage_dischargeunused_edges::UnitRange{Int}
    genstorage_chargedispatch_edges::UnitRange{Int}
    genstorage_chargeunused_edges::UnitRange{Int}
    genstorage_inflowdischarge_edges::UnitRange{Int}
    genstorage_inflowcharge_edges::UnitRange{Int}
    genstorage_inflowunused_edges::UnitRange{Int}

    function DispatchProblem(
        sys::SystemModel; unlimited::Int=999999, shortagepenalty::Int=9999)

        nregions = length(sys.regions)
        nifaces = length(sys.interfaces)
        nstors = length(sys.storages)
        ngenstors = length(sys.generatorstorages)

        stor_regions =
            assetgrouplist(sys.storages_regionstart, nstors)
        genstor_regions =
            assetgrouplist(sys.generatorstorages_regionstart, ngenstors)

        region_nodes = 1:nregions
        stor_discharge_nodes = indices_after(regionnodes, nstors)
        stor_charge_nodes = indices_after(storagedischargenodes, nstors)
        genstor_discharge_nodes = indices_after(storagechargenodes, ngenstors)
        genstor_charge_nodes = indices_after(genstordischargenodes, ngenstors)
        genstor_inflow_nodes = indices_after(genstorchargenodes, ngenstors)
        slacknode = nnodes = last(genstorinflownodes) + 1

        region_unservedenergy = 1:nregions
        region_unusedcapacity = indices_after(region_unservedenergy, nregions)
        iface_forward = indices_after(region_unusedcapacity, nifaces)
        iface_reverse = indices_after(iface_forward, nifaces)
        stor_dischargeused = indices_after(iface_reverse, nstors)
        stor_dischargeunused = indices_after(stor_discharge, nstors)
        stor_chargeused = indices_after(stor_dischargeunused, nstors)
        stor_chargeunused = indices_after(stor_charge, nstors)
        genstor_dischargeused = indices_after(stor_chargeunused, ngenstors)
        genstor_dischargeunused = indices_after(genstor_discharge, ngenstors)
        genstor_chargeused = indices_after(genstor_dischargeunused, ngenstors)
        genstor_chargeunused = indices_after(genstor_charge, ngenstors)
        genstor_inflowdischarge = indices_after(genstor_chargeunused, ngenstors)
        genstor_inflowcharge = indices_after(genstor_inflowdischarge, ngenstors)
        genstor_inflowunused = indices_after(genstor_inflowcharge, ngenstors)
        nedges = last(genstor_inflowunused)

        nodesfrom = Vector{Int}(undef, nedges)
        nodesto = Vector{Int}(undef, nedges)
        costs = Vector{Int}(undef, nedges)
        limits = Vector{Int}(undef, nedges)
        injections = zeros(Int, nnodes)

        function initused(idxs::UnitRange{Int}, from::Vector{Int}, to::Int)
            nodesfrom[idxs] = from
            nodesto[idxs] .= to
            limits[idxs] .= unlimited
        end

        function initused(idxs::UnitRange{Int}, from::Int, to::Vector{Int})
            nodesfrom[idxs] .= from
            nodesto[idxs] = to
            limits[idxs] .= unlimited
        end

        function initunused(idxs::UnitRange{Int}, from, to)
            initused(idxs, from, to)
            costs[idxs] .= 0
        end

        # Unserved energy edges
        initused(region_unservedenergy, slacknode, region_nodes)
        costs[region_unservedenergy] .= shortagepenalty

        # Unused generation edges
        initunused(region_unusedcapacity, regionnodes, slacknode)

        # Forward transmission edges
        nodesfrom[iface_forward] = sys.interfaces.regions_from
        nodesto[iface_forward] = sys.interfaces.regions_to
        costs[iface_forward] .= 1

        # Reverse transmission edges
        nodesfrom[iface_reverse] = sys.interfaces.regions_to
        nodesto[iface_reverse] = sys.interfaces.regions_from
        costs[iface_reverse] .= 1

        # Storage charging / discharging
        initused(stor_dischargeused, stor_discharge_nodes, stor_regions)
        initunused(stor_dischargeunused, stor_discharge_nodes, slacknode)
        initused(stor_chargeused, stor_regions, stor_charge_nodes)
        initunused(stor_chargeunused, slacknode, stor_charge_nodes)

        # GeneratorStorage charging / discharging
        initused(genstor_dischargeused, genstor_discharge_nodes, genstor_regions)
        initunused(genstor_dischargeunused, genstor_discharge_nodes, slacknode)
        initused(genstor_chargeused, genstor_regions, genstor_charge_nodes)
        initunused(genstor_chargeunused, slacknode, genstor_charge)

        # GeneratorStorage inflow charging /  discharging
        nodesfrom[genstor_inflowdischarge] = genstor_inflow_nodes
        nodesto[genstor_inflowdischarge] = genstor_discharge_nodes
        costs[genstor_inflowdischarge] .= 0
        nodesfrom[genstor_inflowcharge] = genstor_inflow_nodes
        nodesto[genstor_inflowcharge] = genstor_charge_nodes
        costs[genstor_inflowcharge] .= 1 # Avoid spilling through unused charge
        initunused(genstor_inflowunused, genstor_inflow_nodes, slacknode)

        return TransmissionDispatchProblem(
            FlowProblem(nodesfrom, nodesto, limits, costs, injections),
            region_nodes, storage_discharge_nodes, storage_charge_nodes,
            genstorage_discharge_nodes, genstorage_charge_nodes,
            genstorage_inflow_nodes, slacknode,
            region_unservedenergy, region_unusedcapacity,
            iface_forward, iface_reverse,
            stor_dischargeused, stor_dischargeunused,
            stor_chargeused, stor_chargeunused,
            genstor_dischargeused, genstor_dischargeunused,
            genstor_chargeused, genstor_chargeunused,
            genstor_inflowdischarge, genstor_inflowcharge, genstor_inflowunused
        )

    end

end

indices_after(lastset::UnitRange{Int}, setsize::Int) =
    1:setsize .+ last(lastset) 

# TODO
function update_problem!(
    problem::DispatchProblem, state::SystemState,
    system::SystemModel, t::Int)


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

# TODO
function update_state!(
    state::SystemState, problem::DispatchProblem
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
