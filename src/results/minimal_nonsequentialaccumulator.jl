struct NonSequentialMinimalResultAccumulator{V,S,ES,SS} <: ResultAccumulator{V,S,ES,SS}
    droppedcount_valsum::Vector{V}
    droppedcount_varsum::Vector{V}
    droppedsum_valsum::Vector{V}
    droppedsum_varsum::Vector{V}
    periodidx::Vector{Int}
    droppedcount_period::Vector{MeanVariance}
    droppedsum_period::Vector{MeanVariance}
    system::S
    extractionspec::ES
    simulationspec::SS
    rngs::Vector{MersenneTwister}
end

function accumulator(extractionspec::ExtractionSpec,
                     simulationspec::SimulationSpec{NonSequential},
                     resultspec::Minimal, sys::SystemModel{N,L,T,P,E,V},
                     seed::UInt) where {N,L,T,P,E,V}

    nthreads = Threads.nthreads()

    droppedcount_valsum = zeros(V, nthreads)
    droppedcount_varsum = zeros(V, nthreads)
    droppedsum_valsum = zeros(V, nthreads)
    droppedsum_varsum = zeros(V, nthreads)

    rngs = Vector{MersenneTwister}(nthreads)
    rngs_temp = randjump(MersenneTwister(seed), nthreads)

    periodidx = zeros(Int, nthreads)
    periodcount = Vector{MeanVariance}(nthreads)
    periodsum = Vector{MeanVariance}(nthreads)

    Threads.@threads for i in 1:nthreads
        periodcount[i] = Series(Mean(), Variance())
        periodsum[i] = Series(Mean(), Variance())
        rngs[i] = copy(rngs_temp[i])
    end

    return NonSequentialMinimalResultAccumulator(
        droppedcount_valsum, droppedcount_varsum,
        droppedsum_valsum, droppedsum_varsum,
        periodidx, periodcount, periodsum,
        sys, extractionspec, simulationspec, rngs)

end

function update!(acc::NonSequentialMinimalResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    thread = Threads.threadid()
    acc.droppedcount_valsum[thread] += result.lolp_system
    acc.droppedsum_valsum[thread] += sum(result.eue_regions)

    return

end

function update!(acc::NonSequentialMinimalResultAccumulator{V,SystemModel{N,L,T,P,E,V}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E,V}

    thread = Threads.threadid()

    if t != acc.periodidx[thread]

        # Previous thread-local simulation has finished,
        # so store previous local result and reset

        transferperiodresults!(
            acc.droppedcount_valsum, acc.droppedcount_varsum,
            acc.droppedcount_period, thread)

        transferperiodresults!(
            acc.droppedsum_valsum, acc.droppedsum_varsum,
            acc.droppedsum_period, thread)

        acc.periodidx[thread] = t

    end

    shortfall = droppedload(sample)
    isshortfall = !isapprox(shortfall, 0.)
    droppedenergy = powertoenergy(shortfall, L, T, P, E)

    fit!(acc.droppedcount_period[thread], V(isshortfall))
    fit!(acc.droppedsum_period[thread], droppedenergy)

    return

end

function finalize(acc::NonSequentialMinimalResultAccumulator{V,<:SystemModel{N,L,T,P,E,V}}
                  ) where {N,L,T,P,E,V}

    # Add the final local results
    for thread in 1:Threads.threadid()

        transferperiodresults!(
            acc.droppedcount_valsum, acc.droppedcount_varsum,
            acc.droppedcount_period, thread)

        transferperiodresults!(
            acc.droppedsum_valsum, acc.droppedsum_varsum,
            acc.droppedsum_period, thread)

    end

    # Combine per-thread totals

    lole = sum(acc.droppedcount_valsum)
    eue = sum(acc.droppedsum_valsum)

    if ismontecarlo(acc.simulationspec)
        nsamples = acc.simulationspec.nsamples
        lole_stderr = sqrt(sum(acc.droppedcount_varsum) ./ nsamples)
        eue_stderr = sqrt(sum(acc.droppedsum_varsum) ./ nsamples)
    else
        lole_stderr = eue_stderr = zero(V)
    end

    return MinimalResult(
        LOLE{N,L,T}(lole, lole_stderr),
        EUE{N,L,T,E}(eue, eue_stderr),
        acc.extractionspec, acc.simulationspec)

end
