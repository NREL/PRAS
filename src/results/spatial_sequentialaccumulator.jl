struct SequentialSpatialResultAccumulator{S,SS} <: ResultAccumulator{S,SS}
    droppedcount_overall::Vector{MeanVariance}
    droppedsum_overall::Vector{MeanVariance}
    droppedcount_region::Matrix{MeanVariance}
    droppedsum_region::Matrix{MeanVariance}
    simidx::Vector{Int}
    droppedcount_overall_sim::Vector{Int}
    droppedsum_overall_sim::Vector{Int}
    droppedcount_region_sim::Matrix{Int}
    droppedsum_region_sim::Matrix{Int}
    localshortfalls::Vector{Vector{Int}}
    system::S
    simulationspec::SS
    rngs::Vector{MersenneTwister}
    gens_available::Vector{Vector{Bool}}
    lines_available::Vector{Vector{Bool}}
    stors_available::Vector{Vector{Bool}}
    stors_energy::Vector{Vector{Int}}
end

function accumulator(simulationspec::SimulationSpec{Sequential},
                     resultspec::Spatial, sys::SystemModel{N,L,T,P,E},
                     seed::UInt) where {N,L,T,P,E}

    nthreads = Threads.nthreads()
    nregions = length(sys.regions)

    ngens = length(sys.generators)
    nstors = length(sys.storages)
    nlines = length(sys.lines)

    droppedcount_overall = Vector{MeanVariance}(undef, nthreads)
    droppedsum_overall = Vector{MeanVariance}(undef, nthreads)
    droppedcount_region = Matrix{MeanVariance}(undef, nregions, nthreads)
    droppedsum_region = Matrix{MeanVariance}(undef, nregions, nthreads)

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)

    simidx = zeros(Int, nthreads)
    simcount = Vector{Int}(undef, nthreads)
    simsum = Vector{Int}(undef, nthreads)
    simcount_region = Matrix{Int}(undef, nregions, nthreads)
    simsum_region = Matrix{Int}(undef, nregions, nthreads)
    localshortfalls = Vector{Vector{Int}}(undef, nthreads)

    gens_available = Vector{Vector{Bool}}(undef, nthreads)
    lines_available = Vector{Vector{Bool}}(undef, nthreads)
    stors_available = Vector{Vector{Bool}}(undef, nthreads)
    stors_energy = Vector{Vector{Int}}(undef, nthreads)

    Threads.@threads for i in 1:nthreads
        droppedcount_overall[i] = Series(Mean(), Variance())
        droppedsum_overall[i] = Series(Mean(), Variance())
        for r in 1:nregions
            droppedsum_region[r, i] = Series(Mean(), Variance())
            droppedcount_region[r, i] = Series(Mean(), Variance())
        end
        rngs[i] = copy(rngs_temp[i])
        localshortfalls[i] = zeros(Int, nregions)
        gens_available[i] = Vector{Bool}(undef, ngens)
        lines_available[i] = Vector{Bool}(undef, nlines)
        stors_available[i] = Vector{Bool}(undef, nstors)
        stors_energy[i] = Vector{Int}(undef, nstors)
    end

    return SequentialSpatialResultAccumulator(
        droppedcount_overall, droppedsum_overall,
        droppedcount_region, droppedsum_region,
        simidx, simcount, simsum, simcount_region, simsum_region,
        localshortfalls, sys, simulationspec, rngs,
        gens_available, lines_available, stors_available,
        stors_energy)

end

function update!(acc::SequentialSpatialResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

    error("Sequential analytical solutions are not currently supported.")

end

function update!(acc::SequentialSpatialResultAccumulator{SystemModel{N,L,T,P,E}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E}

    nregions = length(acc.system.regions)

    thread = Threads.threadid()
    isshortfall, unservedload, unservedloads = droppedloads!(acc.localshortfalls[thread], sample)
    unservedenergy = powertoenergy(E, unservedload, P, L, T)

    prev_i = acc.simidx[thread]
    if i != prev_i

        # Previous local simulation has finished,
        # so store previous local result (if appropriate) and reset

        if prev_i != 0 # Previous simulation had results, so store them
            fit!(acc.droppedcount_overall[thread], acc.droppedcount_overall_sim[thread])
            fit!(acc.droppedsum_overall[thread], acc.droppedsum_overall_sim[thread])
            for r in 1:nregions
                fit!(acc.droppedcount_region[r, thread], acc.droppedcount_region_sim[r, thread])
                fit!(acc.droppedsum_region[r, thread], acc.droppedsum_region_sim[r, thread])
            end
        end

        # Initialize new simulation data
        acc.simidx[thread] = i
        acc.droppedcount_overall_sim[thread] = isshortfall
        acc.droppedsum_overall_sim[thread] = unservedenergy
        for r in 1:nregions
            regionshortfall = unservedloads[r]
            acc.droppedcount_region_sim[r, thread] = (regionshortfall > 0)
            acc.droppedsum_region_sim[r, thread] = regionshortfall
        end

    elseif isshortfall

        # Local simulation/timestep is still ongoing
        # Load was dropped, update local tracking

        acc.droppedcount_overall_sim[thread] += 1
        acc.droppedsum_overall_sim[thread] += unservedenergy
        for r in 1:nregions
            regionshortfall = unservedloads[r]
            acc.droppedcount_region_sim[r, thread] += (regionshortfall > 0)
            acc.droppedsum_region_sim[r, thread] += regionshortfall
        end

    end

    return

end

function finalize(acc::SequentialSpatialResultAccumulator{SystemModel{N,L,T,P,E}}
                  ) where {N,L,T,P,E}

    regions = acc.system.regions.names
    nregions = length(regions)
    nthreads = Threads.nthreads()

    # Store final simulation time-aggregated results
    for thread in 1:nthreads
        if acc.simidx[thread] != 0
            fit!(acc.droppedcount_overall[thread], acc.droppedcount_overall_sim[thread])
            fit!(acc.droppedsum_overall[thread], acc.droppedsum_overall_sim[thread])
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
                          acc.simulationspec)

end
