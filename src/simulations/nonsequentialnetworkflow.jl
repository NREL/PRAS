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

    systemsampler = SystemInputStateSampler(system)
    sink_idx = nv(systemsampler.graph)
    source_idx = sink_idx-1
    n = sink_idx-2

    statematrix = zeros(sink_idx, sink_idx)
    flowmatrix = Array{Float64}(sink_idx, sink_idx)
    height = Array{Int}(sink_idx)
    count = Array{Int}(2*sink_idx+1)
    excess = Array{Float64}(sink_idx)
    active = Array{Bool}(sink_idx)

    for i in 1:simulationspec.nsamples

        rand!(statematrix, systemsampler)
        LightGraphs.push_relabel!(
            flowmatrix, height, count, excess, active,
            systemsampler.graph, source_idx, sink_idx, statematrix)

        outputsample = SystemOutputStateSample{L,T,P}(
            statematrix, flowmatrix, system.interface_labels, n)
        update!(acc, outputsample, t, i)

    end

end
