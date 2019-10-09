# Simulation specification

struct NonSequentialNetworkFlow <: SimulationSpec{NonSequential}
    nsamples::Int

    function NonSequentialNetworkFlow(nsamples::Int)
        @assert nsamples > 0
        new(nsamples)
    end
end

ismontecarlo(::NonSequentialNetworkFlow) = true
iscopperplate(::NonSequentialNetworkFlow) = false

# Simulation cache
struct NonSequentialNetworkFlowCache{N,L,T,P,E} <:
    SimulationCache{N,L,T,P,E,NonSequentialNetworkFlow}

    simulationspec::NonSequentialNetworkFlow
    system::SystemModel{N,L,T,P,E}
    rngs::Vector{MersenneTwister}

end

function cache(simulationspec::NonSequentialNetworkFlow,
               system::SystemModel, seed::UInt)

    nthreads = Threads.nthreads()
    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)

    Threads.@threads for i in 1:nthreads
        rngs[i] = copy(rngs_temp[i])
    end

    return NonSequentialNetworkFlowCache(simulationspec, system, rngs)

end

# Simulation assessment

function assess!(
    cache::NonSequentialNetworkFlowCache{N,L,T,P,E},
    acc::ResultAccumulator,
    sys::SystemModel{N,L,T,P,E}, t::Int
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    thread = Threads.threadid()

    statesampler = sampler(SystemInputStateDistribution(sys, t, copperplate=false))
    flowproblem = FlowProblem(cache.simulationspec, sys)
    outputsample = SystemOutputStateSample{L,T,P}(
        sys.interfaces.regions_from, sys.interfaces.regions_to, length(sys.regions))

    for i in 1:cache.simulationspec.nsamples
        rand!(cache.rngs[thread], flowproblem, statesampler)
        solveflows!(flowproblem)
        update!(cache.simulationspec, outputsample, flowproblem)
        update!(acc, outputsample, t, i)
    end

end

function update!(
    simulationspec::NonSequentialNetworkFlow,
    sample::SystemOutputStateSample{L,T,P},
    fp::FlowProblem
) where {L,T<:Period,P<:PowerUnit}

    nregions = length(sample.regions)
    ninterfaces = length(sample.interfaces)

    # Save gen available, gen dispatched, demand, demand served for each region
    for i in 1:nregions
        node = fp.nodes[i]
        surplus_edge = fp.edges[2*ninterfaces + i]
        shortfall_edge = fp.edges[2*ninterfaces + nregions + i]
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
