function to_distr(vs::Vector)
    p = 1/length(vs)
    cmap = countmap(vs)
    return Generic(collect(keys(cmap)),
                   [p * w for w in values(cmap)])
end

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

function solve_copperplate(systemset::SystemDistributionSet{T}) where T

    collapsed = collapse(systemset)
    dts = unique(collapsed.timestamps)
    batchsize = ceil(Int, length(dts)/nworkers())
    results = pmap(dt -> solve_copperplate(extract(dt, collapsed)),
                   dts, batch_size=batchsize)

    return SimulationResultSet(dts, results)

end
