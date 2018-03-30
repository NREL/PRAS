struct NetworkFlow <: ReliabilityAssessmentMethod
    iters::Int

    function NetworkFlow(iters::Int)
        @assert iters > 0
        new(iters)
    end
end

function all_load_served(A::Matrix{T}, B::Matrix{T}, sink::Int, n::Int) where T
    served = true
    i = 1
    while served && (i <= n)
        served = A[i, sink] == B[i, sink]
        i += 1
    end
    return served
end

function assess(params::NetworkFlow, system::SystemDistribution{N,T,P,Float64}) where {N,T,P}

    systemsampler = SystemSampler(system)
    sink_idx = nv(systemsampler.graph)
    source_idx = sink_idx-1
    n = sink_idx-2

    state_matrix = zeros(sink_idx, sink_idx)
    lol_count = 0
    lol_sum = 0.

    flow_matrix = Array{Float64}(sink_idx, sink_idx)
    height = Array{Int}(sink_idx)
    count = Array{Int}(2*sink_idx+1)
    excess = Array{Float64}(sink_idx)
    active = Array{Bool}(sink_idx)

    for i in 1:params.iters
        rand!(state_matrix, systemsampler)
        systemload, flow_matrix =
            LightGraphs.push_relabel!(flow_matrix, height, count, excess, active,
                          systemsampler.graph, source_idx, sink_idx, state_matrix)
        # TODO: Check whether generator or transmission constraints are to blame
        !all_load_served(state_matrix, flow_matrix, sink_idx, n) && (lol_count += 1)
    end

    μ = lol_count/params.iters
    σ² = μ * (1-μ)
    # eue_val, E = to_energy(lol_sum/params.iters, P, N, T)
    eue_val, E = to_energy(Inf, P, N, T)

    return SinglePeriodReliabilityAssessmentResult(
        LOLP{N,T}(μ, sqrt(σ²/params.iters)),
        EUE{E,N,T}(eue_val, 0.)
    )

end
