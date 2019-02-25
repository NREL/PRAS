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
                 system::SystemInputStateDistribution{L,T,P,E,Float64},
                 t::Int) where {L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    thread = Threads.threadid()

    flowproblem = FlowProblem(simulationspec, system)
    outputsample = SystemOutputStateSample{L,T,P,Float64}(
        system.interface_labels, length(system.region_labels))

    for i in 1:simulationspec.nsamples
        rand!(acc.rngs[thread], flowproblem, system)
        solveflows!(flowproblem)
        update!(simulationspec, outputsample, flowproblem)
        update!(acc, outputsample, t, i)
    end

end

function update!(
    simulationspec::NonSequentialNetworkFlow,
    sample::SystemOutputStateSample{L,T,P,V},
    fp::FlowProblem
) where {L,T<:Period,P<:PowerUnit,V<:Real}

    nregions = length(sample.regions)
    ninterfaces = length(sample.interfaces)

    # Save gen available, gen dispatched, demand, demand served for each region
    for i in 1:nregions
        node = fp.nodes[i]
        surplus_edge = fp.edges[2*ninterfaces + i]
        shortfall_edge = fp.edges[2*ninterfaces + nregions + i]
        sample.regions[i] = RegionResult{L,T,P}(
            V(node.injection), V(surplus_edge.flow), V(shortfall_edge.flow))
    end

    # Save flow available, flow for each interface
    for i in 1:ninterfaces
        forwardedge = fp.edges[i]
        forwardflow = forwardedge.flow
        reverseflow = fp.edges[ninterfaces+i].flow
        flow = forwardflow > reverseflow ? forwardflow : -reverseflow
        sample.interfaces[i] = InterfaceResult{L,T,P}(V(forwardedge.limit), V(flow))
    end

end
