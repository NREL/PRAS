struct NonSequentialSpatialResultAccumulator{S,SS} <: ResultAccumulator{S,SS}

    droppedcount_overall_valsum::Vector{Int}
    droppedcount_overall_varsum::Vector{Int}
    droppedsum_overall_valsum::Vector{Int}
    droppedsum_overall_varsum::Vector{Int}
    droppedcount_region_valsum::Matrix{Int}
    droppedcount_region_varsum::Matrix{Int}
    droppedsum_region_valsum::Matrix{Int}
    droppedsum_region_varsum::Matrix{Int}
    localshortfalls::Vector{Vector{Int}}

    periodidx::Vector{Int}
    droppedcount_overall_period::Vector{MeanVariance}
    droppedsum_overall_period::Vector{MeanVariance}
    droppedcount_region_period::Matrix{MeanVariance}
    droppedsum_region_period::Matrix{MeanVariance}

    system::S
    simulationspec::SS
    rngs::Vector{MersenneTwister}

end

function accumulator(simulationspec::SimulationSpec{NonSequential},
                     resultspec::Spatial, sys::SystemModel{N,L,T,P,E},
                     seed::UInt) where {N,L,T,P,E}

    nthreads = Threads.nthreads()
    nregions = length(sys.regions)

    droppedcount_overall_valsum = zeros(Int, nthreads)
    droppedcount_overall_varsum = zeros(Int, nthreads)
    droppedsum_overall_valsum = zeros(Int, nthreads)
    droppedsum_overall_varsum = zeros(Int, nthreads)

    droppedcount_region_valsum = zeros(Int, nregions, nthreads)
    droppedcount_region_varsum = zeros(Int, nregions, nthreads)
    droppedsum_region_valsum = zeros(Int, nregions, nthreads)
    droppedsum_region_varsum = zeros(Int, nregions, nthreads)

    periodidx = zeros(Int, nthreads)
    droppedcount_overall_period = Vector{MeanVariance}(undef, nthreads)
    droppedsum_overall_period = Vector{MeanVariance}(undef, nthreads)
    droppedcount_region_period = Matrix{MeanVariance}(undef, nregions, nthreads)
    droppedsum_region_period = Matrix{MeanVariance}(undef, nregions, nthreads)

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)
    localshortfalls = Vector{Vector{Int}}(undef, nthreads)

    Threads.@threads for i in 1:nthreads
        droppedcount_overall_period[i] = Series(Mean(), Variance())
        droppedsum_overall_period[i] = Series(Mean(), Variance())
        for r in 1:nregions
            droppedcount_region_period[r, i] = Series(Mean(), Variance())
            droppedsum_region_period[r, i] = Series(Mean(), Variance())
        end
        rngs[i] = copy(rngs_temp[i])
        localshortfalls[i] = zeros(Int, nregions)
    end

    return NonSequentialSpatialResultAccumulator(
        droppedcount_overall_valsum, droppedcount_overall_varsum,
        droppedsum_overall_valsum, droppedsum_overall_varsum,
        droppedcount_region_valsum, droppedcount_region_varsum,
        droppedsum_region_valsum, droppedsum_region_varsum,
        localshortfalls,
        periodidx, droppedcount_overall_period, droppedsum_overall_period,
        droppedcount_region_period, droppedsum_region_period,
        sys, simulationspec, rngs)

end

function update!(acc::NonSequentialSpatialResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    thread = Threads.threadid()

    acc.droppedcount_overall_valsum[thread] += result.lolp_system
    acc.droppedsum_overall_valsum[thread] += sum(result.eue_regions)

    for r in 1:length(acc.system.regions)
        acc.droppedcount_region_valsum[r, thread] += result.lolp_regions[r]
        acc.droppedsum_region_valsum[r, thread] += result.eue_regions[r]
    end

    return

end

function update!(acc::NonSequentialSpatialResultAccumulator{SystemModel{N,L,T,P,E}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E}

    thread = Threads.threadid()
    nregions = length(acc.system.regions)

    if t != acc.periodidx[thread]

        # Previous local period has finished,
        # so store previous local result and reset

        transferperiodresults!(
            acc.droppedcount_overall_valsum, acc.droppedcount_overall_varsum,
            acc.droppedcount_overall_period, thread)
        
        transferperiodresults!(
            acc.droppedsum_overall_valsum, acc.droppedsum_overall_varsum,
            acc.droppedsum_overall_period, thread)

        for r in 1:length(acc.system.regions)

            transferperiodresults!(
                acc.droppedcount_region_valsum, acc.droppedcount_region_varsum,
                acc.droppedcount_region_period, r, thread)

            transferperiodresults!(
                acc.droppedsum_region_valsum, acc.droppedsum_region_varsum,
                acc.droppedsum_region_period, r, thread)

        end

        acc.periodidx[thread] = t

    end

    isshortfall, totalshortfall, localshortfalls =
        droppedloads!(acc.localshortfalls[thread], sample)

    fit!(acc.droppedcount_overall_period[thread], isshortfall)
    fit!(acc.droppedsum_overall_period[thread],
         powertoenergy(E, totalshortfall, P, L, T))

    for r in 1:nregions
        shortfall = localshortfalls[r]
        fit!(acc.droppedcount_region_period[r, thread],
             approxnonzero(shortfall))
        fit!(acc.droppedsum_region_period[r, thread],
             powertoenergy(E, shortfall, P, L, T))
    end

    return

end

function finalize(acc::NonSequentialSpatialResultAccumulator{SystemModel{N,L,T,P,E}}
                  ) where {N,L,T,P,E}

    regions = acc.system.regions

    # Transfer the final thread-local results
    for thread in 1:Threads.nthreads()

        transferperiodresults!(
            acc.droppedcount_overall_valsum, acc.droppedcount_overall_varsum,
            acc.droppedcount_overall_period, thread)

        transferperiodresults!(
            acc.droppedsum_overall_valsum, acc.droppedsum_overall_varsum,
            acc.droppedsum_overall_period, thread)

        for r in 1:length(regions)

            transferperiodresults!(
                acc.droppedcount_region_valsum, acc.droppedcount_region_varsum,
                acc.droppedcount_region_period, r, thread)

            transferperiodresults!(
                acc.droppedsum_region_valsum, acc.droppedsum_region_varsum,
                acc.droppedsum_region_period, r, thread)

        end

    end

    lole = sum(acc.droppedcount_overall_valsum)
    loles = vec(sum(acc.droppedcount_region_valsum, dims=2))
    eue = sum(acc.droppedsum_overall_valsum)
    eues = vec(sum(acc.droppedsum_region_valsum, dims=2))

    if ismontecarlo(acc.simulationspec)

        nsamples = acc.simulationspec.nsamples
        lole_stderr = sqrt(sum(acc.droppedcount_overall_varsum) / nsamples)
        loles_stderr = sqrt.(vec(sum(acc.droppedcount_region_varsum, dims=2)) ./ nsamples)
        eue_stderr = sqrt(sum(acc.droppedsum_overall_varsum) / nsamples)
        eues_stderr = sqrt.(vec(sum(acc.droppedsum_region_varsum, dims=2)) ./ nsamples)

    else

        lole_stderr = loles_stderr = 0.
        eue_stderr = eues_stderr = 0.

    end

    return SpatialResult(regions,
                         LOLE{N,L,T}(lole, lole_stderr),
                         LOLE{N,L,T}.(loles, loles_stderr),
                         EUE{N,L,T,E}(eue, eue_stderr),
                         EUE{N,L,T,E}.(eues, eues_stderr),
                         acc.simulationspec)

end
