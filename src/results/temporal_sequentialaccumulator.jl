struct SequentialTemporalResultAccumulator{V,S,ES,SS} <: ResultAccumulator{V,S,ES,SS}
    droppedcount_overall::Vector{MeanVariance{V}}
    droppedsum_overall::Vector{MeanVariance{V}}
    droppedcount_period::Matrix{MeanVariance{V}}
    droppedsum_period::Matrix{MeanVariance{V}}
    simidx::Vector{Int}
    droppedcount_sim::Vector{V}
    droppedsum_sim::Vector{V}
    system::S
    extractionspec::ES
    simulationspec::SS
    rngs::Vector{MersenneTwister}
end

function accumulator(extractionspec::ExtractionSpec,
                     simulationspec::SimulationSpec{Sequential},
                     resultspec::Temporal, sys::SystemModel{N,L,T,P,E,V},
                     seed::UInt) where {N,L,T,P,E,V}

    nthreads = Threads.nthreads()
    nperiods = length(sys.timestamps)

    droppedcount_overall = Vector{MeanVariance{V}}(undef, nthreads)
    droppedsum_overall = Vector{MeanVariance{V}}(undef, nthreads)
    droppedcount_period = Matrix{MeanVariance{V}}(undef, nperiods, nthreads)
    droppedsum_period = Matrix{MeanVariance{V}}(undef, nperiods, nthreads)

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)

    simidx = zeros(Int, nthreads)
    simcount = Vector{V}(undef, nthreads)
    simsum = Vector{V}(undef, nthreads)

    Threads.@threads for i in 1:nthreads
        droppedcount_overall[i] = Series(Mean(), Variance())
        droppedsum_overall[i] = Series(Mean(), Variance())
        for t in 1:nperiods
            droppedsum_period[t, i] = Series(Mean(), Variance())
            droppedcount_period[t, i] = Series(Mean(), Variance())
        end
        rngs[i] = copy(rngs_temp[i])
    end

    return SequentialTemporalResultAccumulator(
        droppedcount_overall, droppedsum_overall,
        droppedcount_period, droppedsum_period,
        simidx, simcount, simsum,
        sys, extractionspec, simulationspec, rngs)

end

function update!(acc::SequentialTemporalResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    error("Sequential analytical solutions are not currently supported.")

end

function update!(acc::SequentialTemporalResultAccumulator{V,SystemModel{N,L,T,P,E,V}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E,V}

    thread = Threads.threadid()
    isshortfall, unservedload = droppedload(sample)
    unservedenergy = powertoenergy(unservedload, L, T, P, E)

    # Update temporal results
    fit!(acc.droppedcount_period[t, thread], V(isshortfall))
    fit!(acc.droppedsum_period[t, thread], unservedenergy)

    # Update overall results
    prev_i = acc.simidx[thread]
    if i != prev_i # Previous thread-local simulation has finished

        if prev_i != 0 # Previous simulation had results, so store them
            fit!(acc.droppedcount_overall[thread], acc.droppedcount_sim[thread])
            fit!(acc.droppedsum_overall[thread], acc.droppedsum_sim[thread])
        end

        # Reset thread-local tracking for new simulation
        acc.simidx[thread] = i
        acc.droppedcount_sim[thread] = V(isshortfall)
        acc.droppedsum_sim[thread] = unservedenergy

    elseif isshortfall

        # Previous thread-local simulation is still ongoing
        # Load was dropped, update thread-local tracking

        acc.droppedcount_sim[thread] += one(V)
        acc.droppedsum_sim[thread] += unservedenergy

    end

    return

end

function finalize(acc::SequentialTemporalResultAccumulator{V,<:SystemModel{N,L,T,P,E,V}}
                  ) where {N,L,T,P,E,V}

    timestamps = acc.system.timestamps
    nperiods = length(timestamps)
    nthreads = Threads.nthreads()

    # Store final simulation time-aggregated results
    for thread in 1:nthreads
        if acc.simidx[thread] != 0 # Previous simulation had results, so store them
            fit!(acc.droppedcount_overall[thread], acc.droppedcount_sim[thread])
            fit!(acc.droppedsum_overall[thread], acc.droppedsum_sim[thread])
        end
    end

    # Merge thread-local stats into final stats
    for i in 2:nthreads

        merge!(acc.droppedcount_overall[1], acc.droppedcount_overall[i])
        merge!(acc.droppedsum_overall[1], acc.droppedsum_overall[i])

        for t in 1:nperiods
            merge!(acc.droppedcount_period[t, 1], acc.droppedcount_period[t, i])
            merge!(acc.droppedsum_period[t, 1], acc.droppedsum_period[t, i])
        end

    end

    nsamples = acc.simulationspec.nsamples

    lole = LOLE{N,L,T}(mean_stderr(acc.droppedcount_overall[1], nsamples)...)
    eue = EUE{N,L,T,E}(mean_stderr(acc.droppedsum_overall[1], nsamples)...)

    lolps = map(r -> LOLP{L,T}(r...),
                mean_stderr.(acc.droppedcount_period[:, 1], nsamples))
    eues = map(r -> EUE{1,L,T,E}(r...),
               mean_stderr.(acc.droppedsum_period[:, 1], nsamples))

    return TemporalResult(timestamps, lole, lolps, eue, eues,
                          acc.extractionspec, acc.simulationspec)

end
