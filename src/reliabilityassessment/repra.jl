type REPRA <: ReliabilityAssessmentMethod end

function to_distr(vs::Vector)
    p = 1/length(vs)
    cmap = countmap(vs)
    return Generic(collect(keys(cmap)),
                   [p * w for w in values(cmap)])
end

function assess(::Type{REPRA}, sys::SystemDistribution{N,P,E,V}) where {N,P,E,V}

    n_samples = size(sys.loadsamples, 2)
    netloadsamples = vec(sum(sys.loadsamples, 1) .- sum(sys.vgsamples, 1))
    netload = to_distr(netloadsamples)

    supply = sys.gen_distributions[1]
    for i in 2:length(sys.gen_distributions)
        supply = add_dists(supply, sys.gen_distributions[i])
    end

    lolp_result = LOLP{N,P}(lolp(supply, netload), 0.)
    eue_result = EUE{E,N,P}(Inf, 0.)
    return SinglePeriodReliabilityAssessmentResult(lolp_result, eue_result)

end

function assess(::Type{REPRA}, systemset::SystemDistributionSet{T}) where T

    collapsed = collapse(systemset)
    dts = unique(collapsed.timestamps)
    batchsize = ceil(Int, length(dts)/nworkers())
    results = pmap(dt -> assess(REPRA, extract(dt, collapsed)),
                   dts, batch_size=batchsize)

    return MutliPeriodReliabilityAssessmentResult(dts, results)

end
