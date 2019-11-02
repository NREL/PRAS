# Simulation specification

struct NonSequentialNetworkFlow <: SimulationSpec{NonSequential}
    nsamples::Int

    function NonSequentialNetworkFlow(;samples::Int=10_000)

        @assert samples > 0
        new(samples)

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
    acc::ResultAccumulator, t::Int
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    thread = Threads.threadid()

    statesampler = sampler(
        SystemInputStateDistribution(cache.system, t, copperplate=false))
    flowproblem = TransmissionProblem(cache.system)
    outputsample = SystemOutputStateSample{L,T,P}(
        cache.system.interfaces.regions_from,
        cache.system.interfaces.regions_to,
        length(cache.system.regions))

    for i in 1:cache.simulationspec.nsamples
        rand!(cache.rngs[thread], flowproblem, statesampler)
        solveflows!(flowproblem)
        update!(outputsample, flowproblem)
        update!(acc, outputsample, t, i)
    end

end
