struct NonSequentialSpatialResultAccumulator{V,S,ES,SS} <: ResultAccumulator{V,S,ES,SS}

    droppedcount_overall_valsum::Vector{V}
    droppedcount_overall_varsum::Vector{V}
    droppedsum_overall_valsum::Vector{V}
    droppedsum_overall_varsum::Vector{V}
    droppedcount_region_valsum::Matrix{V}
    droppedcount_region_varsum::Matrix{V}
    droppedsum_region_valsum::Matrix{V}
    droppedsum_region_varsum::Matrix{V}

    periodidx::Vector{Int}
    droppedcount_overall_period::Vector{MeanVariance}
    droppedsum_overall_period::Vector{MeanVariance}
    droppedcount_region_period::Matrix{MeanVariance}
    droppedsum_region_period::Matrix{MeanVariance}

    system::S
    extractionspec::ES
    simulationspec::SS
    rngs::Vector{MersenneTwister}

end

function accumulator(extractionspec::ExtractionSpec,
                     simulationspec::SimulationSpec{NonSequential},
                     resultspec::Spatial, sys::SystemModel{N,L,T,P,E,V},
                     seed::UInt) where {N,L,T,P,E,V}

    nthreads = Threads.nthreads()
    nregions = length(sys.regions)

    droppedcount_overall_valsum = zeros(nthreads)
    droppedcount_overall_varsum = zeros(nthreads)
    droppedsum_overall_valsum = zeros(nthreads)
    droppedsum_overall_varsum = zeros(nthreads)

    droppedcount_region_valsum = zeros(nregions, nthreads)
    droppedcount_region_varsum = zeros(nregions, nthreads)
    droppedsum_region_valsum = zeros(nregions, nthreads)
    droppedsum_region_varsum = zeros(nregions, nthreads)

    periodidx = zeros(Int, nthreads)
    droppedcount_overall_period = Vector{MeanVariance}(nthreads)
    droppedsum_overall_period = Vector{MeanVariance}(nthreads)
    droppedcount_region_period = Matrix{MeanVariance}(nregions, nthreads)
    droppedsum_region_period = Matrix{MeanVariance}(nregions, nthreads)

    rngs = Vector{MersenneTwister}(nthreads)
    rngs_temp = randjump(MersenneTwister(seed), nthreads)

    Threads.@threads for i in 1:nthreads
        droppedcount_overall_period[i] = Series(Mean(), Variance())
        droppedsum_overall_period[i] = Series(Mean(), Variance())
        for r in 1:nregions
            droppedcount_region_period[r, i] = Series(Mean(), Variance())
            droppedsum_region_period[r, i] = Series(Mean(), Variance())
        end
        rngs[i] = copy(rngs_temp[i])
    end

    return NonSequentialSpatialResultAccumulator(
        droppedcount_overall_valsum, droppedcount_overall_varsum,
        droppedsum_overall_valsum, droppedsum_overall_varsum,
        droppedcount_region_valsum, droppedcount_region_varsum,
        droppedsum_region_valsum, droppedsum_region_varsum,
        periodidx, droppedcount_overall_period, droppedsum_overall_period,
        droppedcount_region_period, droppedsum_region_period,
        sys, extractionspec, simulationspec, rngs)

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

function update!(acc::NonSequentialSpatialResultAccumulator{V,SystemModel{N,L,T,P,E,V}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E,V}

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

    shortfalls = droppedloads(sample)
    shortfall = sum(shortfalls)

    fit!(acc.droppedcount_overall_period[thread], approxnonzero(shortfall))
    fit!(acc.droppedsum_overall_period[thread],
         powertoenergy(shortfall, L, T, P, E))

    for r in 1:nregions
        fit!(acc.droppedcount_region_period[r, thread],
             approxnonzero(shortfalls[r]))
        fit!(acc.droppedsum_region_period[r, thread],
             powertoenergy(shortfalls[r], L, T, P, E))
    end

    return

end

function finalize(acc::NonSequentialSpatialResultAccumulator{V,<:SystemModel{N,L,T,P,E,V}}
                  ) where {N,L,T,P,E,V}

    regions = acc.system.regions
    nregions = length(regions)

    # Transfer the final thread-local results
    for thread in 1:Threads.threadid()

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

    end

    lole = sum(acc.droppedcount_overall_valsum)
    loles = vec(sum(acc.droppedcount_region_valsum, 2))
    eue = sum(acc.droppedsum_overall_valsum)
    eues = vec(sum(acc.droppedsum_region_valsum, 2))

    if ismontecarlo(acc.simulationspec)

        nsamples = acc.simulationspec.nsamples
        lole_stderr = sqrt(sum(acc.droppedcount_overall_varsum) / nsamples)
        loles_stderr = sqrt.(vec(sum(acc.droppedcount_region_varsum, 2)) ./ nsamples)
        eue_stderr = sqrt(sum(acc.droppedsum_overall_varsum) / nsamples)
        eues_stderr = sqrt.(vec(sum(acc.droppedsum_region_varsum, 2)) ./ nsamples)

    else

        lole_stderr = loles_stderr = zero(V)
        eue_stderr = eues_stderr = zero(V)

    end

    return SpatialResult(regions,
                         LOLE{N,L,T}(lole, lole_stderr),
                         LOLE{N,L,T}.(loles, loles_stderr),
                         EUE{N,L,T,E}(eue, eue_stderr),
                         EUE{N,L,T,E}.(eues, eues_stderr),
                         acc.extractionspec, acc.simulationspec)

end
