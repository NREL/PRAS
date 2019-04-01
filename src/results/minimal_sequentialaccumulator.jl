# TODO: Need to enforce consistency between V and SystemModel{.., V}
struct SequentialMinimalResultAccumulator{V,S,ES,SS} <: ResultAccumulator{V,S,ES,SS}
    droppedcount::Vector{MeanVariance{V}} # LOL mean and variance
    droppedsum::Vector{MeanVariance{V}} #UE mean and variance
    simidx::Vector{Int} # Current thread-local simulation idx
    droppedcount_sim::Vector{V} # LOL count for thread-local simulations
    droppedsum_sim::Vector{V} # UE sum for thread-local simulations
    system::S
    extractionspec::ES
    simulationspec::SS
    rngs::Vector{MersenneTwister}
end

function accumulator(extractionspec::ExtractionSpec,
                     simulationspec::SimulationSpec{Sequential},
                     resultspec::Minimal, sys::SystemModel{N,L,T,P,E,V},
                     seed::UInt) where {N,L,T,P,E,V}

    nthreads = Threads.nthreads()

    droppedcount = Vector{MeanVariance{V}}(undef, nthreads)
    droppedsum = Vector{MeanVariance{V}}(undef, nthreads)

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)

    simidx = zeros(Int, nthreads)
    simcount = Vector{V}(undef, nthreads)
    simsum = Vector{V}(undef, nthreads)

    Threads.@threads for i in 1:nthreads
        droppedcount[i] = Series(Mean(), Variance())
        droppedsum[i] = Series(Mean(), Variance())
        rngs[i] = copy(rngs_temp[i])
    end

    return SequentialMinimalResultAccumulator(
        droppedcount, droppedsum, simidx, simcount, simsum,
        sys, extractionspec, simulationspec, rngs)

end

function update!(acc::SequentialMinimalResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    error("Sequential analytical solutions are not currently supported.")

end

function update!(acc::SequentialMinimalResultAccumulator{V,SystemModel{N,L,T,P,E,V}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E,V}

    thread = Threads.threadid()
    isshortfall, unservedload = droppedload(sample)
    unservedenergy = powertoenergy(unservedload, L, T, P, E)

    prev_i = acc.simidx[thread]
    if i != prev_i # Previous thread-local simulation has finished

        if prev_i != 0 # Previous simulation had results, so store them
            fit!(acc.droppedcount[thread], acc.droppedcount_sim[thread])
            fit!(acc.droppedsum[thread], acc.droppedsum_sim[thread])
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

function finalize(acc::SequentialMinimalResultAccumulator{V,<:SystemModel{N,L,T,P,E,V}}
                  ) where {N,L,T,P,E,V}

   nthreads = Threads.nthreads()

   # Store final simulation results
    for thread in 1:nthreads
        if acc.simidx[thread] != 0 # Previous simulation had results, so store them
            fit!(acc.droppedcount[thread], acc.droppedcount_sim[thread])
            fit!(acc.droppedsum[thread], acc.droppedsum_sim[thread])
        end
    end

    # Merge thread-local cross-simulation stats into final stats
    for i in 2:nthreads
        merge!(acc.droppedcount[1], acc.droppedcount[i])
        merge!(acc.droppedsum[1], acc.droppedsum[i])
    end

    # Convert cross-simulation stats to final metrics
    nsamples = acc.simulationspec.nsamples
    lole, lole_stderr = mean_stderr(acc.droppedcount[1], nsamples)
    eue, eue_stderr = mean_stderr(acc.droppedsum[1], nsamples)

    return MinimalResult(
        LOLE{N,L,T}(lole, lole_stderr),
        EUE{N,L,T,E}(eue, eue_stderr),
        acc.extractionspec, acc.simulationspec)

end
