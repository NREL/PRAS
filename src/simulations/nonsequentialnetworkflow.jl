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
    sink_idx = nv(system.graph)
    source_idx = sink_idx-1
    n = sink_idx-2

    statematrix = zeros(sink_idx, sink_idx)
    flowmatrix = Array{Float64}(sink_idx, sink_idx)
    height = Array{Int}(sink_idx)
    count = Array{Int}(2*sink_idx+1)
    excess = Array{Float64}(sink_idx)
    active = Array{Bool}(sink_idx)
    outputsample = SystemOutputStateSample{L,T,P,Float64}(system.interface_labels, n)

    for i in 1:simulationspec.nsamples

        rand!(acc.rngs[thread], statematrix, system)

        solveflows!(fp)
        # LightGraphs.push_relabel!( # Performance bottleneck
        #    flowmatrix, height, count, excess, active,
        #    system.graph, source_idx, sink_idx, statematrix)

        update!(outputsample, statematrix, flowmatrix)
        update!(acc, outputsample, t, i)

    end

end
