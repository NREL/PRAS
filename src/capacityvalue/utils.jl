normdist = Normal()
function pequal(x::T, y::T) where {T<:ReliabilityMetric}
    z = abs((val(x) - val(y)) /
            sqrt(stderr(x)^2 + stderr(y)^2))
    return 2 * ccdf(normdist, z)
end

function addfirmcapacity(x::SystemDistributionSet{N1,T1,N2,T2,P,V},
                         nodes::Generic{Int,Float64,Vector{Int}},
                         capacity::Float64) where {N1,T1,N2,T2,P,V}

    gen_distrs = copy(x.region_maxdispatchabledistrs)

    for (node, weight) in zip(support(nodes), Distributions.probs(nodes))

        old_distr = gen_distrs[node]
        new_distr = Generic(support(old_distr) .+ weight*capacity,
                            Distributions.probs(old_distr))

        gen_distrs[node] = new_distr

    end

    return SystemDistributionSet{N1,T1,N2,T2,P,V}(
        x.timestamps,
        x.region_labels,
        gen_distrs,
        x.vgsamples,
        x.interface_labels,
        x.interface_maxflowdistrs,
        x.loadsamples)

end
