# Multi-period results

struct SimulationResultSet
    periods::Vector{DateTime}
    results::Vector{SimulationResult}
end

lole(x::SimulationResultSet) = sum(lolp, x)
# eue(x::SimulationResultSet) = sum(eue, x)

function Base.sum(f::Function, x::SimulationResultSet)
    μ = 0
    σ² = 0
    for v in x.results
        val = f(v)
        μ += mean(val)
        σ² += std(val)^2
    end
    return NormalResultEstimate(μ, sqrt(σ²))
end

function solve_copperplate(systemset::SystemDistributionSet{T}) where T

    collapsed = collapse(systemset)
    dts = unique(collapsed.timestamps)
    batchsize = ceil(Int, length(dts)/nworkers())
    results = pmap(dt -> solve_copperplate(extract(dt, collapsed)),
                   dts, batch_size=batchsize)

    return SimulationResultSet(dts, results)

end

function simulate(systemset::SystemDistributionSet, iters::Int=10_000)

    dts = unique(systemset.timestamps)
    batchsize = ceil(Int, length(dts)/nworkers())
    results = pmap(dt -> simulate(extract(dt, systemset), iters),
                   dts, batch_size=batchsize)

    return SimulationResultSet(dts, results)

end
