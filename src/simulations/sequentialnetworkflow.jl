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

    nregions = length(sys.regions)
    ngens = size(sys.generators, 1)
    nstors = size(sys.storages, 1)

    ninterfaces = length(sys.interfaces)
    nlines = size(sys.lines, 1)

    outputsample = SystemOutputStateSample{L,T,P,V}(
        sys.interfaces, nregions)

    # Initialize generator and storage state vector
    # based on long-run probabilities from period 1
    gens_available = Bool[rand(rng) < gen.μ /(gen.λ + gen.μ)
                          for gen in view(sys.generators, :, 1)]
    lines_available = Bool[rand(rng) < line.μ / (line.λ + line.μ)
                           for line in view(sys.lines, :, 1)]
    stors_available = Bool[rand(rng) < stor.μ / (stor.λ + stor.μ)
                           for stor in view(sys.storages, :, 1)]
    stors_energy = zeros(V, size(sys.storages, 1))

    flowproblem = FlowProblem(simulationspec, sys)

    genranges = assetgrouprange(sys.generators_regionstart, ngens)
    storranges = assetgrouprange(sys.storages_regionstart, nstors)
    lineranges = assetgrouprange(sys.lines_interfacestart, nlines)

    # Main simulation loop
    for (t, (gen_set, line_set, stor_set)) in enumerate(zip(
        sys.timestamps_generatorset,
        sys.timestamps_lineset,
        sys.timestamps_storageset))

        # Load data for timestep
        gens = view(sys.generators, :, gen_set)
        lines = view(sys.lines, :, line_set)
        stors = view(sys.storages, :, stor_set)

        # TODO: Support non-backcast sampling methods
        loads = view(sys.load, :, t)
        vgs = view(sys.vg, :, t)

        # Update assets for timestep
        update_availability!(rng, gens_available, gens)
        update_availability!(rng, lines_available, lines)
        update_availability!(rng, stors_available, stors)
        decay_energy!(stors_energy, stors)

        update_flownodes!(
            flowproblem, loads, vgs,
            genranges, gens, gens_available,
            storranges, stors, stors_available, stors_energy)

        update_flowedges!(
            flowproblem,
            lineranges, lines, lines_available)

        solveflows!(flowproblem)

        update_energy!(
            stors_energy,
            storranges, stors, stors_available,
            flowproblem, ninterfaces)

        update!(simulationspec, outputsample, flowproblem)
        update!(acc, outputsample, t, i)

    end

end

function update_flownodes!(
    flowproblem::FlowProblem,
    loads::AbstractVector{V}, vgs::AbstractVector{V}, 
    genranges::Vector{UnitRange{Int}},
    gens::AbstractVector{DispatchableGeneratorSpec{V}},
    gens_available::AbstractVector{Bool},
    storranges::Vector{UnitRange{Int}},
    stors::AbstractVector{StorageDeviceSpec{V}},
    stors_available::AbstractVector{Bool},
    stors_energy::AbstractVector{V}
) where {V <: Real}

    nregions = length(genranges)
    slacknode = flowproblem.nodes[end]

    for r in 1:nregions

        region_node = flowproblem.nodes[r]
        region_dischargenode = flowproblem.nodes[nregions + r]
        region_chargenode = flowproblem.nodes[2*nregions + r]

        # Update generators
        region_genrange = genranges[r]
        region_gensurplus = vgs[r] - loads[r] +
            available_capacity(
                view(gens_available, region_genrange),
                view(gens, region_genrange))
        updateinjection!(region_node, slacknode, round(Int, region_gensurplus))

        # Update storages
        region_storrange = storranges[r]
        charge_capacity, discharge_capacity = available_storage_capacity(
            view(stors_available, region_storrange),
            view(stors_energy, region_storrange),
            view(stors, region_storrange))
        updateinjection!(region_chargenode, slacknode, round(Int, charge_capacity))
        updateinjection!(region_dischargenode, slacknode, round(Int, discharge_capacity))

    end

end

function update_flowedges!(
    flowproblem::FlowProblem,
    lineranges::Vector{UnitRange{Int}},
    lines::AbstractVector{LineSpec{V}},
    lines_available::AbstractVector{Bool}
) where {V <: Real}

    ninterfaces = length(lineranges)

    for i in 1:ninterfaces

        interface_forwardedge = flowproblem.edges[i]
        interface_backwardedge = flowproblem.edges[ninterfaces + i]
        interface_linerange = lineranges[i]

        interface_capacity = round(Int,
            available_capacity(
                view(lines_available, interface_linerange),
                view(lines, interface_linerange)))

        updateflowlimit!(interface_forwardedge, interface_capacity)
        updateflowlimit!(interface_backwardedge, interface_capacity)

    end

end

function update_energy!(
    stors_energy::Vector{V},
    storranges::Vector{UnitRange{Int}},
    stors::AbstractVector{StorageDeviceSpec{V}},
    stors_available::Vector{Bool},
    flowproblem::FlowProblem,
    ninterfaces::Int
) where {V <: Real}

    nregions = length(storranges)
    nstors = length(stors)

    for r in 1:nregions

        region_discharge = flowproblem.edges[2*ninterfaces + nregions + r].flow
        region_charge = flowproblem.edges[2*ninterfaces + 3*nregions + r].flow

        storrange = storranges[r]
        region_stors_available = view(stors_available, storrange)
        region_stors_energy = view(stors_energy, storrange)
        region_stors = view(stors, storrange)

        if region_charge > 0

            charge_storage!(
                L, T, P, E, region_stors_available, region_stors_energy,
                region_charge, region_stors)

        elseif region_discharge > 0

            discharge_storage!(
                L, T, P, E, region_stors_available, region_stors_energy,
                region_discharge, region_stors)

        end

    end

end

#TODO: This function is very similar to the NonSequentialNetworkFlow
#      equivalent - refactor to share code?
function update!(
    simulationspec::SequentialNetworkFlow,
    outputsample::SystemOutputStateSample{L,T,P,V},
    flowproblem::FlowProblem
) where {L,T<:Period,P<:PowerUnit,V<:Real}

    nregions = length(outputsample.regions)
    ninterfaces = length(outputsample.interfaces)

    # Save gen available, gen dispatched, demand, demand served for each region
    for i in 1:nregions
        node = flowproblem.nodes[i]
        surplus_edge = flowproblem.edges[2*ninterfaces + i]
        shortfall_edge = flowproblem.edges[2*ninterfaces + 5*nregions + i]
        outputsample.regions[i] = RegionResult{L,T,P}(
            V(node.injection), V(surplus_edge.flow), V(shortfall_edge.flow))
    end

    # Save flow available, flow for each interface
    for i in 1:ninterfaces
        forwardedge = flowproblem.edges[i]
        forwardflow = forwardedge.flow
        reverseflow = flowproblem.edges[ninterfaces+i].flow
        flow = forwardflow > reverseflow ? forwardflow : -reverseflow
        outputsample.interfaces[i] = InterfaceResult{L,T,P}(V(forwardedge.limit), V(flow))
    end

end
