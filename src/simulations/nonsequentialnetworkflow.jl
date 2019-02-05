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

    flowproblem = FlowProblem(system)
    outputsample = SystemOutputStateSample{L,T,P,Float64}(
        system.interface_labels, length(system.region_labels))

    for i in 1:simulationspec.nsamples
        rand!(acc.rngs[thread], flowproblem, system)
        solveflows!(flowproblem)
        update!(outputsample, flowproblem)
        update!(acc, outputsample, t, i)
    end

end
