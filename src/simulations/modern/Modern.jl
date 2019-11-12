include("modern_dispatchproblem.jl")
include("modern_utils.jl")
include("SystemOutputStateSample.jl")

struct Modern <: SimulationSpec
    nsamples::Int

    function SequentialNetworkFlow(;nsamples::Int=10_000)
        @assert nsamples > 0
        new(nsamples)
    end

end

function assess(simulationspec::Modern,
                resultspec::ResultSpec,
                system::SystemModel,
                seed::UInt=rand(UInt))

    cch = cache(simulationspec, system, seed)
    acc = accumulator(Sequential, resultspec, system)

    Threads.@threads for i in 1:simulationspec.nsamples
        assess!(cch, acc, i)
    end

    return finalize(cch, acc)

end

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

# TODO: Switch cache over to collection of thread-specific caches (SystemState).
#       Or, use parallel Tasks/Channels with thread-local allocations instead
#       (potentially reworking result accumulation eventually)

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

    flowproblem = TransmissionDispatchProblem(cache.system)

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
