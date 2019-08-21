struct SequentialMinimalResultAccumulator{S,ES,SS} <: ResultAccumulator{S,ES,SS}
    droppedcount::Vector{MeanVariance} # LOL mean and variance
    droppedsum::Vector{MeanVariance} #UE mean and variance
    simidx::Vector{Int} # Current thread-local simulation idx
    droppedcount_sim::Vector{Int} # LOL count for thread-local simulations
    droppedsum_sim::Vector{Int} # UE sum for thread-local simulations
    system::S
    extractionspec::ES
    simulationspec::SS
    rngs::Vector{MersenneTwister}
    gens_available::Vector{Vector{Bool}}
    lines_available::Vector{Vector{Bool}}
    stors_available::Vector{Vector{Bool}}
    stors_energy::Vector{Vector{Int}}
end

function accumulator(extractionspec::ExtractionSpec,
                     simulationspec::SimulationSpec{Sequential},
                     resultspec::Minimal, sys::SystemModel{N,L,T,P,E},
                     seed::UInt) where {N,L,T,P,E}

    nthreads = Threads.nthreads()

    ngens = length(sys.generators)
    nstors = length(sys.storages)
    nlines = length(sys.lines)

    droppedcount = Vector{MeanVariance}(undef, nthreads)
    droppedsum = Vector{MeanVariance}(undef, nthreads)

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)

    simidx = zeros(Int, nthreads)
    simcount = Vector{Int}(undef, nthreads)
    simsum = Vector{Int}(undef, nthreads)

    gens_available = Vector{Vector{Bool}}(undef, nthreads)
    lines_available = Vector{Vector{Bool}}(undef, nthreads)
    stors_available = Vector{Vector{Bool}}(undef, nthreads)
    stors_energy = Vector{Vector{Int}}(undef, nthreads)

    Threads.@threads for i in 1:nthreads
        droppedcount[i] = Series(Mean(), Variance())
        droppedsum[i] = Series(Mean(), Variance())
        rngs[i] = copy(rngs_temp[i])
        gens_available[i] = Vector{Bool}(undef, ngens)
        lines_available[i] = Vector{Bool}(undef, nlines)
        stors_available[i] = Vector{Bool}(undef, nstors)
        stors_energy[i] = Vector{Int}(undef, nstors)
    end

    return SequentialMinimalResultAccumulator(
        droppedcount, droppedsum, simidx, simcount, simsum,
        sys, extractionspec, simulationspec, rngs,
        gens_available, lines_available, stors_available,
        stors_energy)

end

function update!(acc::SequentialMinimalResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    error("Sequential analytical solutions are not currently supported.")

end

function update!(acc::SequentialMinimalResultAccumulator{SystemModel{N,L,T,P,E}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E}

    thread = Threads.threadid()
    isshortfall, unservedload = droppedload(sample)
    unservedenergy = powertoenergy(E, unservedload, P, L, T)

    prev_i = acc.simidx[thread]
    if i != prev_i # Previous thread-local simulation has finished

        if prev_i != 0 # Previous simulation had results, so store them
            fit!(acc.droppedcount[thread], acc.droppedcount_sim[thread])
            fit!(acc.droppedsum[thread], acc.droppedsum_sim[thread])
        end

        # Reset thread-local tracking for new simulation
        acc.simidx[thread] = i
        acc.droppedcount_sim[thread] = isshortfall
        acc.droppedsum_sim[thread] = unservedenergy

    elseif isshortfall

        # Previous thread-local simulation is still ongoing
        # Load was dropped, update thread-local tracking

        acc.droppedcount_sim[thread] += 1
        acc.droppedsum_sim[thread] += unservedenergy

    end

    return

end

function finalize(acc::SequentialMinimalResultAccumulator{SystemModel{N,L,T,P,E}}
                  ) where {N,L,T,P,E}

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
