struct SequentialNetworkFlow <: SimulationSpec{Sequential}
    nsamples::Int
    collapsestorage::Bool

    function SequentialNetworkFlow(;
        samples::Int=10_000,
        collapsestorage::Bool=false)

        @assert samples > 0
        new(samples, collapsestorage)

    end

end

ismontecarlo(::SequentialNetworkFlow) = true
iscopperplate(::SequentialNetworkFlow) = false

struct SequentialNetworkFlowCache{N,L,T,P,E} <:
    SimulationCache{N,L,T,P,E,SequentialNetworkFlow}

    simulationspec::SequentialNetworkFlow
    system::SystemModel{N,L,T,P,E}
    rngs::Vector{MersenneTwister}

    gens_available::Vector{Vector{Bool}}
    gens_nexttransition::Vector{Vector{Int}}

    lines_available::Vector{Vector{Bool}}
    lines_nexttransition::Vector{Vector{Int}}

    stors_available::Vector{Vector{Bool}}
    stors_nexttransition::Vector{Vector{Int}}
    stors_energy::Vector{Vector{Int}}

end

function cache(
    simulationspec::SequentialNetworkFlow,
    system::SystemModel, seed::UInt)

    nthreads = Threads.nthreads()

    ngens = length(system.generators)
    nlines = length(system.lines)
    nstors = length(system.storages)

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)

    gens_available = Vector{Vector{Bool}}(undef, nthreads)
    gens_nexttransition = Vector{Vector{Int}}(undef, nthreads)

    lines_available = Vector{Vector{Bool}}(undef, nthreads)
    lines_nexttransition = Vector{Vector{Int}}(undef, nthreads)

    stors_available = Vector{Vector{Bool}}(undef, nthreads)
    stors_nexttransition = Vector{Vector{Int}}(undef, nthreads)
    stors_energy = Vector{Vector{Int}}(undef, nthreads)

    Threads.@threads for i in 1:nthreads

        rngs[i] = copy(rngs_temp[i])

        gens_available[i] = Vector{Bool}(undef, ngens)
        gens_nexttransition[i] = Vector{Int}(undef, ngens)

        lines_available[i] = Vector{Bool}(undef, nlines)
        lines_nexttransition[i] = Vector{Int}(undef, nlines)

        stors_available[i] = Vector{Bool}(undef, nstors)
        stors_nexttransition[i] = Vector{Int}(undef, nstors)
        stors_energy[i] = Vector{Int}(undef, nstors)

    end

    return SequentialNetworkFlowCache(
        simulationspec, system, rngs,
        gens_available, gens_nexttransition,
        lines_available, lines_nexttransition,
        stors_available, stors_nexttransition, stors_energy)

end

function assess!(
    cache::SequentialNetworkFlowCache{N,L,T,P,E},
    acc::ResultAccumulator, i::Int
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    threadid = Threads.threadid()

    rng = cache.rngs[threadid]

    gens = cache.system.generators
    gens_available = cache.gens_available[threadid]
    gens_nexttransition = cache.gens_nexttransition[threadid]
    genranges = assetgrouprange(cache.system.generators_regionstart, length(gens))

    stors = cache.system.storages
    stors_available = cache.stors_available[threadid]
    stors_nexttransition = cache.stors_nexttransition[threadid]
    stors_energy = cache.stors_energy[threadid]
    storranges = assetgrouprange(cache.system.storages_regionstart, length(stors))

    lines = cache.system.lines
    lines_available = cache.lines_available[threadid]
    lines_nexttransition = cache.lines_nexttransition[threadid]
    lineranges = assetgrouprange(cache.system.lines_interfacestart, length(lines))

    nregions = length(cache.system.regions)
    ninterfaces = length(cache.system.interfaces)

    outputsample = SystemOutputStateSample{L,T,P}(  # Preallocate?
        cache.system.interfaces.regions_from,
        cache.system.interfaces.regions_to, nregions)

    # Initialize generator and storage state vector
    # based on long-run probabilities from period 1
    initialize_availability!(rng, gens_available, gens_nexttransition, gens, N)
    initialize_availability!(rng, stors_available, stors_nexttransition, stors, N)
    initialize_availability!(rng, lines_available, lines_nexttransition, lines, N)

    # Initialize storage devices as empty
    fill!(stors_energy, 0)

    flowproblem = FlowProblem(cache.simulationspec, cache.system)

    # Main simulation loop
    for t in 1:N

        # Update assets for timestep
        update_availability!(
            rng, gens_available, gens_nexttransition, gens, t, N)
        update_availability!(
            rng, lines_available, lines_nexttransition, lines, t, N)
        update_availability!(
            rng, stors_available, stors_nexttransition, stors, t, N)
        decay_energy!(stors_energy, stors, t)

        update_flownodes!(
            flowproblem, t, cache.system.regions.load,
            genranges, gens, gens_available,
            storranges, stors, stors_available, stors_energy)

        update_flowedges!(
            flowproblem, t,
            lineranges, lines, lines_available)

        solveflows!(flowproblem)

        update_energy!(
            stors_energy, t,
            storranges, stors, stors_available,
            flowproblem, ninterfaces)

        update!(cache.simulationspec, outputsample, flowproblem)
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
        outputsample.interfaces[i] =
            InterfaceResult{L,T,P}(forwardedge.limit, flow)
    end

end
