type REPRA_T <: ReliabilityAssessmentMethod end

function all_load_served(A::Matrix{T}, B::Matrix{T}, sink::Int, n::Int) where T
    served = true
    i = 1
    while served && (i <= n)
        served = A[i, sink] == B[i, sink]
        i += 1
    end
    return served
end

function assess(::Type{REPRA_T}, system::SystemDistribution{Float64}, iters::Int=10_000)

    systemsampler = SystemSampler(system)
    sink_idx = nv(systemsampler.graph)
    source_idx = sink_idx-1
    n = sink_idx-2

    state_matrix = zeros(sink_idx, sink_idx)
    lol_count = 0

    flow_matrix = Array{Float64}(sink_idx, sink_idx)
    height = Array{Int}(sink_idx)
    count = Array{Int}(2*sink_idx+1)
    excess = Array{Float64}(sink_idx)
    active = Array{Bool}(sink_idx)

    for i in 1:iters
        rand!(state_matrix, systemsampler)
        systemload, flow_matrix =
            LightGraphs.push_relabel!(flow_matrix, height, count, excess, active,
                          systemsampler.graph, source_idx, sink_idx, state_matrix)
        # TODO: Check whether generator or transmission constraints are to blame
        !all_load_served(state_matrix, flow_matrix, sink_idx, n) && (lol_count += 1)
    end

    μ = lol_count/iters
    σ² = μ * (1-μ)

    lolp_result = LOLP{N,P}(μ, sqrt(σ²/iters))
    eue_result = EUE{E,N,P}(NaN, 0.)
    return SinglePeriodReliabilityAssessmentResult(lolp_result, eue_result)

end

function assess(::Type{REPRA_T}, systemset::SystemDistributionSet, iters::Int=10_000)

    dts = unique(systemset.timestamps)
    batchsize = ceil(Int, length(dts)/nworkers())
    results = pmap(dt -> simulate(extract(dt, systemset), iters),
                   dts, batch_size=batchsize)

    return MultiPeriodReliabilityAssessmentResult(dts, results)

end
