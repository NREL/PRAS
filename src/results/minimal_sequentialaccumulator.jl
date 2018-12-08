# TODO: Need to enforce consistency between V and SystemModel{.., V}
struct SequentialMinimalResultAccumulator{V,S,ES,SS} <: ResultAccumulator{V,S,ES,SS}
    droppedcount::Vector{SumVariance{V}}
    droppedsum::Vector{SumVariance{V}}
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
                     resultspec::Minimal, sys::SystemModel{N,L,T,P,E,V},
                     seed::UInt) where {N,L,T,P,E,V}

    nthreads = Threads.nthreads()

    droppedcount = Vector{SumVariance{V}}(nthreads)
    droppedsum = Vector{SumVariance{V}}(nthreads)
    rngs = Vector{MersenneTwister}(nthreads)
    rngs_temp = randjump(MersenneTwister(seed), nthreads)

    simidx = zeros(Int, nthreads)
    simcount = Vector{V}(nthreads)
    simsum = Vector{V}(nthreads)

    Threads.@threads for i in 1:nthreads
        droppedcount[i] = Series(Sum(), Variance())
        droppedsum[i] = Series(Sum(), Variance())
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
    shortfall = droppedload(sample)
    isshortfall = !isapprox(shortfall, 0.)
    droppedenergy = powertoenergy(shortfall, L, T, P, E)

    if i != acc.localidx[thread]

        # Previous local simulation/timestep has finished,
        # so store previous local result and reset

        fit!(acc.droppedcount[thread], acc.droppedcount_local[thread])
        fit!(acc.droppedsum[thread], acc.droppedsum_local[thread])

        acc.localidx[thread] = i
        acc.droppedcount_local[thread] = V(isshortfall)
        acc.droppedsum_local[thread] = droppedenergy

    elseif isshortfall

        # Local simulation/timestep is still ongoing
        # Load was dropped, update local tracking

        acc.droppedcount_local[thread] += one(V)
        acc.droppedsum_local[thread] += droppedenergy

    end

    return

end

function finalize(acc::SequentialMinimalResultAccumulator{V,<:SystemModel{N,L,T,P,E,V}}
                  ) where {N,L,T,P,E,V}

    # Merge thread-local stats into final stats
    for i in 2:Threads.nthreads()
        merge!(acc.droppedcount[1], acc.droppedcount[i])
        merge!(acc.droppedsum[1], acc.droppedsum[i])
    end

    # Accumulator summed results nsamples V, to scale back down
    nsamples = acc.simulationspec.nsamples
    lole, lole_stderr = mean_stderr(acc.droppedcount[1], nsamples)
    eue, eue_stderr = mean_stderr(acc.droppedsum[1], nsamples)

    return MinimalResult(
        LOLE{N,L,T}(lole, lole_stderr),
        EUE{N,L,T,E}(eue, eue_stderr),
        acc.extractionspec, acc.simulationspec)

end


