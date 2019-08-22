struct NonSequentialNetworkFlow <: SimulationSpec{NonSequential}
    nsamples::Int

    function NonSequentialNetworkFlow(nsamples::Int)
        @assert nsamples > 0
        new(nsamples)
    end
end

ismontecarlo(::NonSequentialNetworkFlow) = true
iscopperplate(::NonSequentialNetworkFlow) = false

function assess!(acc::ResultAccumulator,
                 simulationspec::NonSequentialNetworkFlow,
                 sys::SystemModel{N,L,T,P,E},
                 t::Int) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    thread = Threads.threadid()

    statesampler = sampler(SystemInputStateDistribution(sys, t, copperplate=false))
    flowproblem = FlowProblem(simulationspec, sys)
    outputsample = SystemOutputStateSample{L,T,P}(
        sys.interfaces.regions_from, sys.interfaces.regions_to, length(sys.regions))

    for i in 1:simulationspec.nsamples
        rand!(acc.rngs[thread], flowproblem, statesampler)
        solveflows!(flowproblem)
        update!(simulationspec, outputsample, flowproblem)
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
