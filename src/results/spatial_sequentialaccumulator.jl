struct SequentialSpatialResultAccumulator{V,S,ES,SS} <: ResultAccumulator{V,S,ES,SS}
    droppedcount_overall::Vector{MeanVariance{V}}
    droppedsum_overall::Vector{MeanVariance{V}}
    droppedcount_region::Matrix{MeanVariance{V}}
    droppedsum_region::Matrix{MeanVariance{V}}
    simidx::Vector{Int}
    droppedcount_overall_sim::Vector{V}
    droppedsum_overall_sim::Vector{V}
    droppedcount_region_sim::Matrix{V}
    droppedsum_region_sim::Matrix{V}
    localshortfalls::Vector{Vector{V}}
    system::S
    extractionspec::ES
    simulationspec::SS
    rngs::Vector{MersenneTwister}
end

function accumulator(extractionspec::ExtractionSpec,
                     simulationspec::SimulationSpec{Sequential},
                     resultspec::Spatial, sys::SystemModel{N,L,T,P,E,V},
                     seed::UInt) where {N,L,T,P,E,V}

    nthreads = Threads.nthreads()
    nregions = length(sys.regions)

    droppedcount_overall = Vector{MeanVariance{V}}(undef, nthreads)
    droppedsum_overall = Vector{MeanVariance{V}}(undef, nthreads)
    droppedcount_region = Matrix{MeanVariance{V}}(undef, nregions, nthreads)
    droppedsum_region = Matrix{MeanVariance{V}}(undef, nregions, nthreads)

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)

    simidx = zeros(Int, nthreads)
    simcount = Vector{V}(undef, nthreads)
    simsum = Vector{V}(undef, nthreads)
    simcount_region = Matrix{V}(undef, nregions, nthreads)
    simsum_region = Matrix{V}(undef, nregions, nthreads)
    localshortfalls = Vector{Vector{V}}(undef, nthreads)

    Threads.@threads for i in 1:nthreads
        droppedcount_overall[i] = Series(Mean(), Variance())
        droppedsum_overall[i] = Series(Mean(), Variance())
        for r in 1:nregions
            droppedsum_region[r, i] = Series(Mean(), Variance())
            droppedcount_region[r, i] = Series(Mean(), Variance())
        end
        rngs[i] = copy(rngs_temp[i])
        localshortfalls[i] = zeros(V, nregions)
    end

    return SequentialSpatialResultAccumulator(
        droppedcount_overall, droppedsum_overall,
        droppedcount_region, droppedsum_region,
        simidx, simcount, simsum, simcount_region, simsum_region,
        localshortfalls, sys, extractionspec, simulationspec, rngs)

end

function update!(acc::SequentialSpatialResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    error("Sequential analytical solutions are not currently supported.")

end

function update!(acc::SequentialSpatialResultAccumulator{V,SystemModel{N,L,T,P,E,V}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E,V}

    nregions = length(acc.system.regions)

    thread = Threads.threadid()
    isshortfall, unservedload, unservedloads = droppedloads!(acc.localshortfalls[thread], sample)
    unservedenergy = powertoenergy(unservedload, L, T, P, E)

    prev_i = acc.simidx[thread]
    if i != prev_i

        # Previous local simulation has finished,
        # so store previous local result (if appropriate) and reset

        if prev_i != 0 # Previous simulation had results, so store them
            fit!(acc.droppedcount_overall[thread], acc.droppedcount_sim[thread])
            fit!(acc.droppedsum_overall[thread], acc.droppedsum_sim[thread])
            for r in 1:nregions
                fit!(acc.droppedcount_region[r, thread], acc.droppedcount_region_sim[r, thread])
                fit!(acc.droppedsum_region[r, thread], acc.droppedsum_region_sim[r, thread])
            end
        end

        # Initialize new simulation data
        acc.simidx[thread] = i
        acc.droppedcount_sim[thread] = V(isshortfall)
        acc.droppedsum_sim[thread] = unservedenergy
        for r in 1:nregions
            regionshortfall = unservedloads[r]
            acc.droppedcount_region_sim[r, thread] = approxnonzero(regionshortfall)
            acc.droppedsum_region_sim[r, thread] = regionshortfall
        end

    elseif isshortfall

        # Local simulation/timestep is still ongoing
        # Load was dropped, update local tracking

        acc.droppedcount_sim[thread] += one(V)
        acc.droppedsum_sim[thread] += unservedenergy
        for r in 1:nregions
            regionshortfall = unservedloads[r]
            acc.droppedcount_region_sim[r, thread] += approxnonzero(regionshortfall)
            acc.droppedsum_region_sim[r, thread] += regionshortfall
        end

    end

    return

end

function finalize(acc::SequentialSpatialResultAccumulator{V,<:SystemModel{N,L,T,P,E,V}}
                  ) where {N,L,T,P,E,V}

    regions = acc.system.regions
    nregions = length(regions)
    nthreads = Threads.nthreads()

    # Store final simulation time-aggregated results
    for thread in 1:nthreads
        if acc.simidx[thread] != 0
            fit!(acc.droppedcount_overall[thread], acc.droppedcount_sim[thread])
            fit!(acc.droppedsum_overall[thread], acc.droppedsum_sim[thread])
            for r in 1:nregions
                fit!(acc.droppedcount_region[r, thread], acc.droppedcount_region_sim[r, thread])
                fit!(acc.droppedsum_region[r, thread], acc.droppedsum_region_sim[r, thread])
            end
        end
    end

    # Merge thread-local stats into final stats
    for i in 2:nthreads

        merge!(acc.droppedcount_overall[1], acc.droppedcount_overall[i])
        merge!(acc.droppedsum_overall[1], acc.droppedsum_overall[i])

        for r in 1:nregions
            merge!(acc.droppedcount_region[r, 1], acc.droppedcount_region[r, i])
            merge!(acc.droppedsum_region[r, 1], acc.droppedsum_region[r, i])
        end

    end

    nsamples = acc.simulationspec.nsamples
    lole = LOLE{N,L,T}(mean_stderr(acc.droppedcount_overall[1], nsamples)...)
    loles = map(r -> LOLE{N,L,T}(r...),
                mean_stderr.(acc.droppedcount_region[:, 1], nsamples))
    eue = EUE{N,L,T,E}(mean_stderr(acc.droppedsum_overall[1], nsamples)...)
    eues = map(r -> EUE{N,L,T,E}(r...),
               mean_stderr.(acc.droppedsum_region[:, 1], nsamples))

    return SpatialResult(regions, lole, loles, eue, eues,
                          acc.extractionspec, acc.simulationspec)

end
