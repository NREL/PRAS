struct NonSequentialCopperplate <: SimulationSpec{NonSequential} end

ismontecarlo(::NonSequentialCopperplate) = false
iscopperplate(::NonSequentialCopperplate) = true

function assess!(acc::ResultAccumulator,
                 simulationspec::NonSequentialCopperplate,
                 sys::SystemInputStateDistribution{L,T,P,E},
                 t::Int) where {L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    # Collapse net load
    netloadsamples = vec(sum(sys.loadsamples, dims=1) .- sum(sys.vgsamples, dims=1))
    netload = to_distr(netloadsamples)

    # Collapse regions
    # (hopefully already done during extraction, this approach is very slow)
    supply = sys.region_maxdispatchabledistrs[1]
    for i in 2:length(sys.region_maxdispatchabledistrs)
        supply = add_dists(supply, sys.region_maxdispatchabledistrs[i])
    end

    lolp, eul = assess(supply, netload)
    eue = powertoenergy(E, eul, P, L, T)
    update!(acc, SystemOutputStateSummary{L,T,E}(lolp, [lolp], [eue]), t)

end

function to_distr(vs::Vector)
    p = 1/length(vs)
    cmap = countmap(vs)
    return DiscreteNonParametric(collect(keys(cmap)),
                   [p * w for w in values(cmap)])
end
