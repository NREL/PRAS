struct Copperplate <: ReliabilityAssessmentMethod end

function to_distr(vs::Vector)
    p = 1/length(vs)
    cmap = countmap(vs)
    return Generic(collect(keys(cmap)),
                   [p * w for w in values(cmap)])
end

function assess(::Copperplate, sys::SystemDistribution{N,T,P}) where {N,T,P}

    # Collapse net load
    netloadsamples = vec(sum(sys.loadsamples, 1) .- sum(sys.vgsamples, 1))
    netload = to_distr(netloadsamples)

    # Collapse transmission nodes
    supply = sys.region_maxdispatchabledistrs[1]
    for i in 2:length(sys.region_maxdispatchabledistrs)
        supply = add_dists(supply, sys.region_maxdispatchabledistrs[i])
    end

    lolp_val, eul_val = assess(supply, netload)
    eue_val, E = to_energy(eul_val, P, N, T)

    return SinglePeriodReliabilityAssessmentResult(
        LOLP{N,T}(lolp_val, 0.),
        EUE{E,N,T}(eue_val, 0.),
        nothing
    )

end
