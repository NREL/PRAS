struct NormalResultEstimate{T <: Real}
    μ::T
    σ::T
end

Base.mean(x::NormalResultEstimate) = x.μ
Base.std(x::NormalResultEstimate) = x.σ
Base.show(io::IO, x::NormalResultEstimate) =
    print(io, mean(x), " ± ", 2*std(x))

normdist = Normal()
function pequal(x::NormalResultEstimate,
                y::NormalResultEstimate)
    z = abs((mean(x) - mean(y)) /
            sqrt(std(x)^2 + std(y)^2))
    return 2 * ccdf(normdist, z)
end

struct SimulationResult
    # Eventually will include EUE and potentially other metrics
    lolp::NormalResultEstimate{Float64}
end

lolp(x::SimulationResult) = x.lolp

function solve_copperplate(sys::SystemDistribution{T}) where T

    n_samples = size(sys.loadsamples, 2)
    netloadsamples = vec(sum(sys.loadsamples, 1) .- sum(sys.vgsamples, 1))
    netload = to_distr(netloadsamples)

    supply = sys.gen_distributions[1]
    for i in 2:length(sys.gen_distributions)
        supply = add_dists(supply, sys.gen_distributions[i])
    end

    return SimulationResult(NormalResultEstimate(lolp(supply, netload),0.))

end

function to_distr(vs::Vector)
    p = 1/length(vs)
    cmap = countmap(vs)
    return Generic(collect(keys(cmap)),
                   [p * w for w in values(cmap)])
end

function simulate(system::SystemDistribution{Float64}, iters::Int=10_000)

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
    return SimulationResult(NormalResultEstimate(μ, sqrt(σ²/iters)))

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
