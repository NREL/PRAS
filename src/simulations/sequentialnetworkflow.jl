struct SequentialNetworkFlow <: SimulationSpec{Sequential}
    nsamples::Int

    function SequentialNetworkFlow(nsamples::Int)
        @assert nsamples > 0
        new(nsamples)
    end
end

ismontecarlo(::SequentialNetworkFlow) = true
iscopperplate(::SequentialNetworkFlow) = false

function assess!(
    acc::ResultAccumulator,
    extractionspec::Backcast, #TODO: Generalize
    simulationspec::SequentialNetworkFlow,
    sys::SystemModel{N,L,T,P,E,V},
    i::Int
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit,V}

    rng = acc.rngs[Threads.threadid()]
    outputsample = SystemOutputStateSample{L,T,P,V}(
        sys.interfaces, length(sys.regions))

    # Initialize generator and storage state vector
    # based on long-run probabilities from period 1
    # Note: Could pre-allocate these once per thread?
    gens_available = Bool[rand(rng) < gen.μ /(gen.λ + gen.μ)
                         for gen in view(sys.generators, :, 1)]
    lines_available = Bool[rand(rng) < line.μ / (line.λ + line.μ)
                          for line in view(sys.lines, :, 1)]
    stors_available = Bool[rand(rng) < stor.μ / (stor.λ + stor.μ)
                          for stor in view(sys.storages, :, 1)]
    stors_energy = zeros(V, size(sys.storages, 1))

    flowproblem = FlowProblem(simulationspec, system)

    # Main simulation loop
    for (t, (gen_set, line_set, stor_set)) in enumerate(zip(
        sys.timestamps_generatorset,
        sys.timestamps_lineset,
        sys.timestamps_storageset))

        # Load data for timestep
        gens = view(sys.generators, :, gen_set)
        lines = view(sys.lines, :, line_set)
        stors = view(sys.storages, :, stor_set)
        loads = view(sys.load, :, t)
        vgs = view(sys.vg, :, t)

        # Update assets for timestep
        update_availability!(rng, gens_available, gens)
        update_availability!(rng, lines_available, lines)
        update_availability!(rng, stors_available, stors)
        decay_energy!(stors_energy, stors)

        # Update flowproblem with asset data for timestep
        update_gen_surplusshortfall!(flowproblem, loads, vgs, gens_available, gens)
        update_line_capacity!(flowproblem, lines_available, lines)
        update_stor_capacity!(flowproblem, stors_available, stors)

        # Solve flowproblem
        solveflows!(flowproblem)

        # Update asset data with flowproblem solution
        update_energy!(stors_energy, stors, flowproblem)

        # Update results with flowproblem solution
        update!(outputsample, flowproblem)
        update!(acc, outputsample, t, i)

    end

end

"""

    FlowProblem(::NonSequentialNetworkFlow, sys::SystemInputStateDistribution)

Create a min-cost flow problem for the max power delivery problem with
generation and storage discharging in decreasing order of priority, and
storage charging with excess capacity.

This involves injections/withdrawals at four nodes (generation, charging,
discharging, and load) for each modelled region, as well as a supplementary
"slack" node in the network that can absorb undispatched power or pass
unserved energy or unused charging capability through to satisfy power balance
constraints.

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

    nregions = length(sys.region_labels)
    ninterfaces = length(sys.interface_labels)

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
    nodesfrom[forwardtransmission] = first.(sys.interface_labels)
    nodesto[forwardtransmission] = last.(sys.interface_labels)
    limits[forwardtransmission] .= 0 # Will be updated during simulation
    costs[forwardtransmission] .= 1

    # Reverse transmission edges
    reversetransmission = forwardtransmission .+ ninterfaces
    nodesfrom[reversetransmission] = last.(sys.interface_labels)
    nodesto[reversetransmission] = first.(sys.interface_labels)
    limits[reversetransmission] .= 0 # Will be updated during simulation
    costs[reversetransmission] .= 1

    # Unused generation edges
    unusedcapacityedges = (1:nregions) .+ ninterfaceedges
    nodesfrom[surpluscapacityedges] = regions
    nodesto[surpluscapacityedges] .= slacknode
    limits[surpluscapacityedges] .= 999999
    costs[surpluscapacityedges] .= 0

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

function update_gen_surplusshortfall!(
    flowproblem::FlowProblem,
    loads::AbstractVector{V},
    vgs::AbstractVector{V},
    gens_available::Vector{Bool},
    gens::AbstractVector{DispatchableGeneratorSpec{V},
    gens_regionstart::Vector{Int}
) where {V <: Real}

    slacknode = flowproblem.nodes[end]
    nregions = length(gens_regionstart)
    ngens = length(gens)
    g_idx = 1

    for r in 1:nregions

        regionnode = flowproblem.nodes[r]
        region_gensurplus = vgs[r] - loads[r]
        region_lastgen = r < nregions ? gens_regionstart[r+1]-1 : ngens

        while g_idx <= region_lastgen
            if gens_available[g_idx]
                region_gensurplus += gens[g_idx].capacity
            end
            g_idx += 1
        end

        updateinjection!(regionnode, slacknode, round(Int, region_gensurplus))

    end

end

function update_line_capacity!(
    flowproblem::FlowProblem,
    lines_available::Vector{Bool},
    lines::Vector{LineSpec{V},
    lines_interfacestart::Vector{Int}
) where {V <: Real}

    ninterfaces = length(lines_interfacestart)
    nlines = length(lines)

    for i in 1:ninterfaces

        forwardinterface = flowproblem.edges[i]
        backwardinterface = flowproblem.edges[ninterfaces + i]
        interface_capacity = zero(V)

        while l_idx <= interface_lastline
            if lines_available[l_idx]
                interface_capacity += lines[l_idx].capacity
            end
            l_idx += 1
        end

        interface_capacity_rounded = round(Int, interface_capacity)
        updateflowlimit!(forwardinterface, interface_capacity_rounded)
        updateflowlimit!(backwardinterface, interface_capacity_rounded)

    end

end

function update_stor_capacity!(
    flowproblem::FlowProblem,
    stors_available::Vector{Bool},
    stors::Vector{StorageDeviceSpec{V},
    stors_regionstart::Vector{Int}
) where {V <: Real}

    # TODO
    # Update both chargeable and dischargeable capacity
    # Re-use logic from copperplate case?

end

function update_energy!(
    stors_energy::Vector{V},
    stors::Vector{StorageDeviceSpec{V},
    stors_regionstart::Vector{Int},
    flowproblem::FlowProblem
) where {V <: Real}

    # TODO
    # Re-use logic from copperplate case?

end

function update!(
    outputsample::SystemOutputStateSample{L,T,P,V},
    flowproblem::FlowProblem
) where {L,T<:Period,P<:PowerUnit,V<:Real}

    # TODO

end
