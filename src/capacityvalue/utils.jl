normdist = Normal()
function pequal(x::T, y::T) where {T<:ReliabilityMetric}
    z = abs((val(x) - val(y)) /
            sqrt(stderr(x)^2 + stderr(y)^2))
    return 2 * ccdf(normdist, z)
end

function addfirmcapacity(x::SystemDistributionSet{N1,T1,N2,T2,P,V},
                         node::Int, capacity::Float64) where {N1,T1,N2,T2,P,V}

    old_distr = x.gen_distrs[node]
    new_distr = Generic(support(old_distr) .+ capacity,
                        Distributions.probs(old_distr))

    newdispatchabledistrs = copy(x.gen_distrs)
    newdispatchabledistrs[node] = new_distr

    return SystemDistributionSet{N1,T1,N2,T2,P,V}(
        x.timestamps,
        newdispatchabledistrs,
        x.vgsamples,
        x.interface_labels,
        x.interface_distrs,
        x.loadsamples,
        x.hourwindow, x.daywindow)

end
