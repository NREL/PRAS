# struct REPRA <: ReliabilityAssessmentMethod end

# function assess(::Type{REPRA}, sys::SystemDistribution{N,T,P,V}) where {N,T,P,V}

#     n_samples = size(sys.loadsamples, 2)
#     netloadsamples = vec(sum(sys.loadsamples, 1) .- sum(sys.vgsamples, 1))
#     netload = to_distr(netloadsamples)

#     supply = sys.gen_distributions[1]
#     for i in 2:length(sys.gen_distributions)
#         supply = add_dists(supply, sys.gen_distributions[i])
#     end

#     lolp_val, eul_val = assess(supply, netload)
#     eue_val, E = to_energy(eul_val, P, N, T)

#     return SinglePeriodReliabilityAssessmentResult(
#         LOLP{N,T}(lolp_val, 0.),
#         EUE{E,N,T}(eue_val, 0.)
#     )


# end

function assess(::Type{REPRA}, systemset::SystemDistributionSet)

    collapsed = collapse(systemset)
    dts = unique(collapsed.timestamps)
    batchsize = ceil(Int, length(dts)/nworkers())
    results = pmap(dt -> assess(REPRA, extract(dt, collapsed)),
                   dts, batch_size=batchsize)

    return MultiPeriodReliabilityAssessmentResult(dts, results)

end
