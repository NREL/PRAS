struct SequentialTemporalResultAccumulator{S,SS} <: ResultAccumulator{S,SS}
    droppedcount_overall::Vector{MeanVariance}
    droppedsum_overall::Vector{MeanVariance}
    droppedcount_period::Matrix{MeanVariance}
    droppedsum_period::Matrix{MeanVariance}
    simidx::Vector{Int}
    droppedcount_sim::Vector{Int}
    droppedsum_sim::Vector{Int}
    system::S
    simulationspec::SS
    rngs::Vector{MersenneTwister}
    gens_available::Vector{Vector{Bool}}
    lines_available::Vector{Vector{Bool}}
    stors_available::Vector{Vector{Bool}}
    stors_energy::Vector{Vector{Int}}
end

function accumulator(simulationspec::SimulationSpec{Sequential},
                     resultspec::Temporal, sys::SystemModel{N,L,T,P,E},
                     seed::UInt) where {N,L,T,P,E}

    nthreads = Threads.nthreads()
    nperiods = length(sys.timestamps)

    ngens = length(sys.generators)
    nstors = length(sys.storages)
    nlines = length(sys.lines)

    droppedcount_overall = Vector{MeanVariance}(undef, nthreads)
    droppedsum_overall = Vector{MeanVariance}(undef, nthreads)
    droppedcount_period = Matrix{MeanVariance}(undef, nperiods, nthreads)
    droppedsum_period = Matrix{MeanVariance}(undef, nperiods, nthreads)

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
        droppedcount_overall[i] = Series(Mean(), Variance())
        droppedsum_overall[i] = Series(Mean(), Variance())
        for t in 1:nperiods
            droppedsum_period[t, i] = Series(Mean(), Variance())
            droppedcount_period[t, i] = Series(Mean(), Variance())
        end
        rngs[i] = copy(rngs_temp[i])
        gens_available[i] = Vector{Bool}(undef, ngens)
        lines_available[i] = Vector{Bool}(undef, nlines)
        stors_available[i] = Vector{Bool}(undef, nstors)
        stors_energy[i] = Vector{Int}(undef, nstors)
    end

    return SequentialTemporalResultAccumulator(
        droppedcount_overall, droppedsum_overall,
        droppedcount_period, droppedsum_period,
        simidx, simcount, simsum,
        sys, simulationspec, rngs,
        gens_available, lines_available, stors_available,
        stors_energy)

end

function update!(acc::SequentialTemporalResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    error("Sequential analytical solutions are not currently supported.")

end

function update!(acc::SequentialTemporalResultAccumulator{SystemModel{N,L,T,P,E}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E}

    thread = Threads.threadid()
    isshortfall, unservedload = droppedload(sample)
    unservedenergy = powertoenergy(E, unservedload, P, L, T)

    # Update temporal results
    fit!(acc.droppedcount_period[t, thread], isshortfall)
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

function finalize(acc::SequentialTemporalResultAccumulator{SystemModel{N,L,T,P,E}}
                  ) where {N,L,T,P,E}

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

    return TemporalResult(timestamps, lole, lolps, eue, eues, acc.simulationspec)

end
