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

    threadid = Threads.threadid()

    rng = acc.rngs[threadid]

    gens_available = acc.gens_available[threadid]
    lines_available = acc.lines_available[threadid]
    stors_available = acc.stors_available[threadid]
    stors_energy = acc.stors_energy[threadid]

    nregions = length(sys.regions)
    ngens = size(sys.generators, 1)
    nstors = size(sys.storages, 1)

    ninterfaces = length(sys.interfaces)
    nlines = size(sys.lines, 1)

    outputsample = SystemOutputStateSample{L,T,P,V}(
        sys.interfaces, nregions)

    # Initialize generator and storage state vector
    # based on long-run probabilities from period 1

    t1_gens = sys.timestamps_generatorset[1]
    for i in 1:ngens
        gen = sys.generators[i, t1_gens]
        gens_available[i] = rand(rng) < gen.μ / (gen.λ + gen.μ)
    end

    t1_lines = sys.timestamps_lineset[1]
    for i in 1:nlines
        line = sys.lines[i, t1_lines]
        lines_available[i] = rand(rng) < line.μ / (line.λ + line.μ)
    end

    t1_stors = sys.timestamps_storageset[1]
    for i in 1:nstors
        stor = sys.storages[i, t1_stors]
        stors_available[i] = rand(rng) < stor.μ / (stor.λ + stor.μ)
    end

    fill!(stors_energy, zero(V))

    flowproblem = FlowProblem(simulationspec, sys)

    genranges = assetgrouprange(sys.generators_regionstart, ngens)
    storranges = assetgrouprange(sys.storages_regionstart, nstors)
    lineranges = assetgrouprange(sys.lines_interfacestart, nlines)

    # Main simulation loop
    for (t, (gen_set, line_set, stor_set)) in enumerate(zip(
        sys.timestamps_generatorset,
        sys.timestamps_lineset,
        sys.timestamps_storageset))

        # TODO: Support non-backcast sampling methods
        loads = view(sys.load, :, t)
        vgs = view(sys.vg, :, t)

        # Update assets for timestep
        update_availability!(rng, gens_available, sys.generators, gen_set)
        update_availability!(rng, lines_available, sys.lines, line_set)
        update_availability!(rng, stors_available, sys.storages, stor_set)
        decay_energy!(stors_energy, sys.storages, stor_set)

        update_flownodes!(
            L, T, P, E,
            flowproblem, loads, vgs,
            genranges, sys.generators, gens_available, gen_set,
            storranges, sys.storages, stors_available, stors_energy, stor_set)

        update_flowedges!(
            flowproblem,
            lineranges, sys.lines, lines_available, line_set)

        solveflows!(flowproblem)

        update_energy!(
            L, T, P, E,
            stors_energy,
            storranges, sys.storages, stors_available, stor_set,
            flowproblem, ninterfaces)

        update!(simulationspec, outputsample, flowproblem)
        update!(acc, outputsample, t, i)

    end

end

function update_flownodes!(
    L::Int, # TODO: Eliminate this with units for storage devices in next breaking release
    T::Type{<:Period},
    P::Type{<:PowerUnit},
    E::Type{<:EnergyUnit},
    flowproblem::FlowProblem,
    loads::AbstractVector{V}, vgs::AbstractVector{V}, 
    genranges::Vector{Tuple{Int,Int}},
    gens::Matrix{DispatchableGeneratorSpec{V}},
    gens_available::Vector{Bool},
    gen_set::Int,
    storranges::Vector{Tuple{Int,Int}},
    stors::Matrix{StorageDeviceSpec{V}},
    stors_available::Vector{Bool},
    stors_energy::Vector{V},
    stor_set::Int
) where {V <: Real}

    nregions = length(genranges)
    slacknode = flowproblem.nodes[end]

    for r in 1:nregions

        region_node = flowproblem.nodes[r]
        region_dischargenode = flowproblem.nodes[nregions + r]
        region_chargenode = flowproblem.nodes[2*nregions + r]

        # Update generators
        gen_range = genranges[r]
        region_gensurplus = vgs[r] - loads[r] +
            available_capacity(gens_available, gens, gen_range, gen_set)
        updateinjection!(region_node, slacknode, round(Int, region_gensurplus))

        # Update storages
        stor_range = storranges[r]
        charge_capacity, discharge_capacity = available_storage_capacity(
            L, T, P, E,
            stors_available, stors_energy, stors, stor_range, stor_set)
        updateinjection!(region_chargenode, slacknode, -round(Int, charge_capacity))
        updateinjection!(region_dischargenode, slacknode, round(Int, discharge_capacity))

    end

end

function update_flowedges!(
    flowproblem::FlowProblem,
    lineranges::Vector{Tuple{Int,Int}},
    lines::Matrix{LineSpec{V}},
    lines_available::Vector{Bool},
    line_set::Int
) where {V <: Real}

    ninterfaces = length(lineranges)

    for i in 1:ninterfaces

        interface_forwardedge = flowproblem.edges[i]
        interface_backwardedge = flowproblem.edges[ninterfaces + i]
        line_range = lineranges[i]

        interface_capacity = round(Int,
            available_capacity(lines_available, lines, line_range, line_set)
        )

        updateflowlimit!(interface_forwardedge, interface_capacity)
        updateflowlimit!(interface_backwardedge, interface_capacity)

    end

end

function update_energy!(
    L::Int, # TODO: Eliminate this with units for storage devices in next breaking release
    T::Type{<:Period},
    P::Type{<:PowerUnit},
    E::Type{<:EnergyUnit},
    stors_energy::Vector{V},
    storranges::Vector{Tuple{Int,Int}},
    stors::Matrix{StorageDeviceSpec{V}},
    stors_available::Vector{Bool},
    stor_set::Int,
    flowproblem::FlowProblem,
    ninterfaces::Int
) where {V <: Real}

    nregions = length(storranges)
    nstors = length(stors)

    for r in 1:nregions

        region_discharge = V(flowproblem.edges[2*ninterfaces + nregions + r].flow)
        region_charge = V(flowproblem.edges[2*ninterfaces + 3*nregions + r].flow)

        storrange = storranges[r]

        if region_charge > 0

            charge_storage!(
                L, T, P, E, stors_available, stors_energy,
                region_charge, stors, storrange, stor_set)

        elseif region_discharge > 0

            discharge_storage!(
                L, T, P, E, stors_available, stors_energy,
                region_discharge, stors, storrange, stor_set)

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
