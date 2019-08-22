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
    simulationspec::SequentialNetworkFlow,
    sys::SystemModel{N,L,T,P,E},
    i::Int
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    threadid = Threads.threadid()

    rng = acc.rngs[threadid]

    gens_available = acc.gens_available[threadid]
    lines_available = acc.lines_available[threadid]
    stors_available = acc.stors_available[threadid]
    stors_energy = acc.stors_energy[threadid]

    nregions = length(sys.regions)
    ngens = length(sys.generators)
    nstors = length(sys.storages)

    ninterfaces = length(sys.interfaces)
    nlines = length(sys.lines)

    outputsample = SystemOutputStateSample{L,T,P}(
        sys.interfaces.regions_from, sys.interfaces.regions_to, nregions)

    # Initialize generator and storage state vector
    # based on long-run probabilities from period 1

    for i in 1:ngens
        μ = sys.generators.μ[i, 1]
        λ = sys.generators.λ[i, 1]
        gens_available[i] = rand(rng) < μ / (λ + μ)
    end

    for i in 1:nlines
        μ = sys.lines.μ[i, 1]
        λ = sys.lines.λ[i, 1]
        lines_available[i] = rand(rng) < μ / (λ + μ)
    end

    for i in 1:nstors
        μ = sys.storages.μ[i, 1]
        λ = sys.storages.λ[i, 1]
        stors_available[i] = rand(rng) < μ / (λ + μ)
    end

    fill!(stors_energy, 0)

    flowproblem = FlowProblem(simulationspec, sys)

    genranges = assetgrouprange(sys.generators_regionstart, ngens)
    storranges = assetgrouprange(sys.storages_regionstart, nstors)
    lineranges = assetgrouprange(sys.lines_interfacestart, nlines)

    # Main simulation loop
    for t in 1:N

        # Update assets for timestep
        update_availability!(rng, gens_available, sys.generators, t)
        update_availability!(rng, lines_available, sys.lines, t)
        update_availability!(rng, stors_available, sys.storages, t)
        decay_energy!(stors_energy, sys.storages, t)

        update_flownodes!(
            flowproblem, t, sys.regions.load,
            genranges, sys.generators, gens_available,
            storranges, sys.storages, stors_available, stors_energy)

        update_flowedges!(
            flowproblem, t,
            lineranges, sys.lines, lines_available)

        solveflows!(flowproblem)

        update_energy!(
            stors_energy, t,
            storranges, sys.storages, stors_available,
            flowproblem, ninterfaces)

        update!(simulationspec, outputsample, flowproblem)
        update!(acc, outputsample, t, i)

    end

end

function update_flownodes!(
    flowproblem::FlowProblem,
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
    slacknode = flowproblem.nodes[end]

    for r in 1:nregions

        region_node = flowproblem.nodes[r]
        region_dischargenode = flowproblem.nodes[nregions + r]
        region_chargenode = flowproblem.nodes[2*nregions + r]

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
    flowproblem::FlowProblem,
    t::Int,
    lineranges::Vector{Tuple{Int,Int}},
    lines::Lines,
    lines_available::Vector{Bool}
) where {V <: Real}

    ninterfaces = length(lineranges)

    for i in 1:ninterfaces

        interface_forwardedge = flowproblem.edges[i]
        interface_backwardedge = flowproblem.edges[ninterfaces + i]
        line_range = lineranges[i]

        interface_capacity =
            available_capacity(lines_available, lines, line_range, t)

        updateflowlimit!(interface_forwardedge, interface_capacity)
        updateflowlimit!(interface_backwardedge, interface_capacity)

    end

end

function update_energy!(
    stors_energy::Vector{Int},
    t::Int,
    storranges::Vector{Tuple{Int,Int}},
    stors::Storages,
    stors_available::Vector{Bool},
    flowproblem::FlowProblem,
    ninterfaces::Int
)

    nregions = length(storranges)
    nstors = length(stors)

    for r in 1:nregions

        region_discharge = flowproblem.edges[2*ninterfaces + nregions + r].flow
        region_charge = flowproblem.edges[2*ninterfaces + 3*nregions + r].flow

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

#TODO: This function is very similar to the NonSequentialNetworkFlow
#      equivalent - refactor to share code?
function update!(
    simulationspec::SequentialNetworkFlow,
    outputsample::SystemOutputStateSample{L,T,P},
    flowproblem::FlowProblem
) where {L,T<:Period,P<:PowerUnit}

    nregions = length(outputsample.regions)
    ninterfaces = length(outputsample.interfaces)

    # Save gen available, gen dispatched, demand, demand served for each region
    for i in 1:nregions
        node = flowproblem.nodes[i]
        surplus_edge = flowproblem.edges[2*ninterfaces + i]
        shortfall_edge = flowproblem.edges[2*ninterfaces + 5*nregions + i]
        outputsample.regions[i] = RegionResult{L,T,P}(
            node.injection, surplus_edge.flow, shortfall_edge.flow)
    end

    # Save flow available, flow for each interface
    for i in 1:ninterfaces
        forwardedge = flowproblem.edges[i]
        forwardflow = forwardedge.flow
        reverseflow = flowproblem.edges[ninterfaces+i].flow
        flow = forwardflow > reverseflow ? forwardflow : -reverseflow
        outputsample.interfaces[i] = InterfaceResult{L,T,P}(forwardedge.limit, flow)
    end

end
