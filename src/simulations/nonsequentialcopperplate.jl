struct NonSequentialCopperplate <: SimulationSpec{NonSequential} end

ismontecarlo(::NonSequentialCopperplate) = false
iscopperplate(::NonSequentialCopperplate) = true

function assess!(acc::ResultAccumulator,
                 simulationspec::NonSequentialCopperplate,
                 sys::SystemInputStateDistribution{L,T,P,E,V},
                 t::Int) where {L,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}

    # Collapse net load
    netloadsamples = vec(sum(sys.loadsamples, 1) .- sum(sys.vgsamples, 1))
    netload = to_distr(netloadsamples)

    # Collapse regions
    # (hopefully already done during extraction, this approach is very slow)
    supply = sys.region_maxdispatchabledistrs[1]
    for i in 2:length(sys.region_maxdispatchabledistrs)
        supply = add_dists(supply, sys.region_maxdispatchabledistrs[i])
    end

    lolp, eul = assess(supply, netload)
    eue = powertoenergy(eul, L, T, P, E)
    update!(acc, SystemOutputStateSummary{L,T,E}(lolp, [lolp], [eue]), t)

end

function to_distr(vs::Vector)
    p = 1/length(vs)
    cmap = countmap(vs)
    return Generic(collect(keys(cmap)),
                   [p * w for w in values(cmap)])
end
