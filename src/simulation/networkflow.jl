struct NonSequentialNetworkFlow <: SimulationSpec{NonSequential}
    nsamples::Int

    function NonSequentialNetworkFlow(nsamples::Int)
        @assert nsamples > 0
        new(nsamples)
    end
end

mutable struct SinglePeriodNetworkMinimalResultAccumulator{
    N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}

    lol_count::Int
    eue::OnlineStats.Variance{OnlineStatsBase.EqualWeight}
    edgelabels::Vector{Tuple{Int,Int}}
    simulationspec::NonSequentialNetworkFlow

    function SinglePeriodNetworkMinimalResultAccumulator{}(
        simulationspec::NonSequentialNetworkFlow,
        sys::SystemDistribution{N,T,P,E,V}
    ) where {N,T,P,E,V}
        new{N,T,P,E,V}(0, Variance(), sys.interface_labels, simulationspec)
    end
end

accumulator(ss::NonSequentialNetworkFlow, rs::MinimalResult,
            sys::SystemDistribution) =
                SinglePeriodNetworkMinimalResultAccumulator(ss, sys)

function update!(acc::SinglePeriodNetworkMinimalResultAccumulator{N,T,P,E,Float64},
                 statematrix::Matrix{Float64},
                 flowmatrix::Matrix{Float64},
                 sink_idx::Int, n_regions::Int) where {N,T,P,E}

    if !all_load_served(statematrix, flowmatrix, sink_idx, n_regions)
        acc.lol_count += 1
        ns = NetworkState{N,T,P,E}(statematrix, flowmatrix, acc.edgelabels, n_regions)
        fit!(acc.eue, powertoenergy(droppedload(ns), N, T, P, E))
    else
        fit!(acc.eue, 0.)
    end

    return acc

end

function finalize(acc::SinglePeriodNetworkMinimalResultAccumulator{N,T,P,E,V}
                  ) where {N,T,P,E,V}

    nsamples = acc.simulationspec.nsamples

    lolp_μ = acc.lol_count/nsamples
    lolp_σ² = lolp_μ * (1-lolp_μ)

    eue_μ = acc.eue.μ
    eue_σ² = acc.eue.σ2

    return SinglePeriodMinimalResult{P}(
        LOLP{N,T}(lolp_μ, sqrt(lolp_σ²/nsamples)),
        EUE{E,N,T}(eue_μ, sqrt(eue_σ²/nsamples)),
        acc.simulationspec)

end


struct SinglePeriodNetworkResultAccumulator{
    N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}

    nodelabels::Vector{String}
    edgelabels::Vector{Tuple{Int,Int}}
    nodestates::Vector{Vector{NodeResult{N,T,P,E,V}}}
    edgestates::Vector{Vector{EdgeResult{N,T,P,E,V}}}
    simulationspec::NonSequentialNetworkFlow
    resultspec::NetworkResult

    function SinglePeriodNetworkResultAccumulator{}(
        simspec::NonSequentialNetworkFlow,
        resultspec::NetworkResult,
        system::SystemDistribution{N,T,P,E,V}
    ) where {N,T,P,E,V}

        new{N,T,P,E,V}(
            system.region_labels, system.interface_labels,
            Vector{NodeResult{N,T,P,E,V}}[],
            Vector{EdgeResult{N,T,P,E,V}}[],
            simspec, resultspec)
    end

end

accumulator(ss::NonSequentialNetworkFlow, rs::NetworkResult,
            sys::SystemDistribution) =
                SinglePeriodNetworkResultAccumulator(ss, rs, sys)

function all_load_served(A::Matrix{T}, B::Matrix{T}, sink::Int, n::Int) where T
    served = true
    i = 1
    while served && (i <= n)
        served = A[i, sink] == B[i, sink]
        i += 1
    end
    return served
end

function update!(acc::SinglePeriodNetworkResultAccumulator{N,T,P,E,Float64},
                 statematrix::Matrix{Float64},
                 flowmatrix::Matrix{Float64},
                 sink_idx::Int, n_regions::Int) where {N,T,P,E}

    if !(acc.resultspec.failuresonly &&
         all_load_served(statematrix, flowmatrix, sink_idx, n_regions))

        ns = NetworkState{N,T,P,E}(statematrix, flowmatrix, acc.edgelabels, n_regions)
        push!(acc.nodestates, ns.nodes)
        push!(acc.edgestates, ns.edges)

    end

    return acc

end

finalize(acc::SinglePeriodNetworkResultAccumulator) =
    SinglePeriodNetworkResult(
        acc.nodelabels, acc.edgelabels,
        hcat(acc.nodestates...), hcat(acc.edgestates...),
        acc.simulationspec, acc.resultspec)


function assess(simulationspec::NonSequentialNetworkFlow,
                resultspec::ResultSpec,
                system::SystemDistribution{N,T,P,E,Float64}) where {N,T,P,E}

    systemsampler = SystemSampler(system)
    sink_idx = nv(systemsampler.graph)
    source_idx = sink_idx-1
    n = sink_idx-2

    resultaccumulator = accumulator(simulationspec, resultspec, system)

    state_matrix = zeros(sink_idx, sink_idx)
    flow_matrix = Array{Float64}(sink_idx, sink_idx)
    height = Array{Int}(sink_idx)
    count = Array{Int}(2*sink_idx+1)
    excess = Array{Float64}(sink_idx)
    active = Array{Bool}(sink_idx)

    for i in 1:simulationspec.nsamples

        rand!(state_matrix, systemsampler)
        systemload, flow_matrix =
            LightGraphs.push_relabel!(
                flow_matrix, height, count, excess, active,
                systemsampler.graph, source_idx, sink_idx, state_matrix)

        update!(resultaccumulator, state_matrix, flow_matrix, sink_idx, n)

    end

    return finalize(resultaccumulator)

end
