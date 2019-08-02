struct SequentialNetworkResultAccumulator{V,S,ES,SS} <: ResultAccumulator{V,S,ES,SS}
    droppedcount_overall::Vector{MeanVariance{V}}
    droppedsum_overall::Vector{MeanVariance{V}}
    droppedcount_region::Matrix{MeanVariance{V}}
    droppedsum_region::Matrix{MeanVariance{V}}
    droppedcount_period::Matrix{MeanVariance{V}}
    droppedsum_period::Matrix{MeanVariance{V}}
    droppedcount_regionperiod::Array{MeanVariance{V},3}
    droppedsum_regionperiod::Array{MeanVariance{V},3}
    simidx::Vector{Int}
    droppedcount_overall_sim::Vector{V}
    droppedsum_overall_sim::Vector{V}
    droppedcount_region_sim::Matrix{V}
    droppedsum_region_sim::Matrix{V}
    localshortfalls::Vector{Vector{V}}
    flows::Array{MeanVariance{V},3}
    utilizations::Array{MeanVariance{V},3}
    system::S
    extractionspec::ES
    simulationspec::SS
    rngs::Vector{MersenneTwister}
    gens_available::Vector{Vector{Bool}}
    lines_available::Vector{Vector{Bool}}
    stors_available::Vector{Vector{Bool}}
    stors_energy::Vector{Vector{V}}
end

function accumulator(extractionspec::ExtractionSpec,
                     simulationspec::SimulationSpec{Sequential},
                     resultspec::Network, sys::SystemModel{N,L,T,P,E,V},
                     seed::UInt) where {N,L,T,P,E,V}

    nthreads = Threads.nthreads()
    nregions = length(sys.regions)
    ninterfaces = length(sys.interfaces)
    nperiods = length(sys.timestamps)

    ngens = size(sys.generators, 1)
    nstors = size(sys.storages, 1)
    nlines = size(sys.lines, 1)

    droppedcount_overall = Vector{MeanVariance{V}}(undef, nthreads)
    droppedsum_overall = Vector{MeanVariance{V}}(undef, nthreads)
    droppedcount_region = Matrix{MeanVariance{V}}(undef, nregions, nthreads)
    droppedsum_region = Matrix{MeanVariance{V}}(undef, nregions, nthreads)
    droppedcount_period = Matrix{MeanVariance{V}}(undef, nperiods, nthreads)
    droppedsum_period = Matrix{MeanVariance{V}}(undef, nperiods, nthreads)
    droppedcount_regionperiod = Array{MeanVariance{V},3}(undef, nregions, nperiods, nthreads)
    droppedsum_regionperiod = Array{MeanVariance{V},3}(undef, nregions, nperiods, nthreads)
    flows = Array{MeanVariance{V},3}(undef, ninterfaces, nperiods, nthreads)
    utilizations = Array{MeanVariance{V},3}(undef, ninterfaces, nperiods, nthreads)

    rngs = Vector{MersenneTwister}(undef, nthreads)
    rngs_temp = initrngs(nthreads, seed=seed)

    simidx = zeros(Int, nthreads)
    droppedcount_overall_sim = Vector{V}(undef, nthreads)
    droppedsum_overall_sim = Vector{V}(undef, nthreads)
    droppedcount_region_sim = Matrix{V}(undef, nregions, nthreads)
    droppedsum_region_sim = Matrix{V}(undef, nregions, nthreads)
    localshortfalls = Vector{Vector{V}}(undef, nthreads)

    gens_available = Vector{Vector{Bool}}(undef, nthreads)
    lines_available = Vector{Vector{Bool}}(undef, nthreads)
    stors_available = Vector{Vector{Bool}}(undef, nthreads)
    stors_energy = Vector{Vector{V}}(undef, nthreads)

    Threads.@threads for i in 1:nthreads

        droppedcount_overall[i] = Series(Mean(), Variance())
        droppedsum_overall[i] = Series(Mean(), Variance())

        for t in 1:nperiods

            droppedcount_period[t, i] = Series(Mean(), Variance())
            droppedsum_period[t, i] = Series(Mean(), Variance())

            for r in 1:nregions
                droppedcount_regionperiod[r, t, i] = Series(Mean(), Variance())
                droppedsum_regionperiod[r, t, i] = Series(Mean(), Variance())
            end

            for iface in 1:ninterfaces
                flows[iface, t, i] = Series(Mean(), Variance())
                utilizations[iface, t, i] = Series(Mean(), Variance())
            end

        end

        for r in 1:nregions
            droppedcount_region[r, i] = Series(Mean(), Variance())
            droppedsum_region[r, i] = Series(Mean(), Variance())
        end

        rngs[i] = copy(rngs_temp[i])
        localshortfalls[i] = zeros(V, nregions)
        gens_available[i] = Vector{Bool}(undef, ngens)
        lines_available[i] = Vector{Bool}(undef, nlines)
        stors_available[i] = Vector{Bool}(undef, nstors)
        stors_energy[i] = Vector{V}(undef, nstors)

    end

    return SequentialNetworkResultAccumulator(
        droppedcount_overall, droppedsum_overall,
        droppedcount_region, droppedsum_region,
        droppedcount_period, droppedsum_period,
        droppedcount_regionperiod, droppedsum_regionperiod,
        simidx, droppedcount_overall_sim, droppedsum_overall_sim,
        droppedcount_region_sim, droppedsum_region_sim, localshortfalls,
        flows, utilizations, sys, extractionspec, simulationspec, rngs,
        gens_available, lines_available, stors_available,
        stors_energy)

end

function update!(acc::SequentialNetworkResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

        error("Sequential analytical solutions are not currently supported.")

end

function update!(acc::SequentialNetworkResultAccumulator{V,SystemModel{N,L,T,P,E,V}},
                 sample::SystemOutputStateSample, t::Int, i::Int) where {N,L,T,P,E,V}

    thread = Threads.threadid()
    nregions = length(acc.system.regions)
    ninterfaces = length(acc.system.interfaces)

    isshortfall, unservedload, unservedloads = droppedloads!(acc.localshortfalls[thread], sample)
    unservedenergy = powertoenergy(unservedload, L, T, P, E)

    # Update temporal/spatiotemporal result data
    fit!(acc.droppedcount_period[t, thread], V(isshortfall))
    fit!(acc.droppedsum_period[t, thread], unservedenergy)
    for r in 1:nregions
        regionshortfall = unservedloads[r]
        fit!(acc.droppedcount_regionperiod[r, t, thread], approxnonzero(regionshortfall))
        fit!(acc.droppedsum_regionperiod[r, t, thread], regionshortfall)
    end

    for i in 1:ninterfaces
        fit!(acc.flows[i, t, thread], sample.interfaces[i].transfer)
        fit!(acc.utilizations[i, t, thread],
             abs(sample.interfaces[i].transfer) / sample.interfaces[i].max_transfer_magnitude)
    end

    prev_i = acc.simidx[thread]
    if i != prev_i

        # Previous local simulation has finished,
        # so store previous time-aggregated results (if appropriate) and reset

        if prev_i != 0 # Previous simulation had results, so store them
            fit!(acc.droppedcount_overall[thread], acc.droppedcount_overall_sim[thread])
            fit!(acc.droppedsum_overall[thread], acc.droppedsum_overall_sim[thread])
            for r in 1:nregions
                fit!(acc.droppedcount_region[r, thread], acc.droppedcount_region_sim[r, thread])
                fit!(acc.droppedsum_region[r, thread], acc.droppedsum_region_sim[r, thread])
            end
        end

        # Initialize time-aggregated result data for new simulation
        acc.simidx[thread] = i
        acc.droppedcount_overall_sim[thread] = V(isshortfall)
        acc.droppedsum_overall_sim[thread] = unservedenergy
        for r in 1:nregions
            regionshortfall = unservedloads[r]
            acc.droppedcount_region_sim[r, thread] = approxnonzero(regionshortfall)
            acc.droppedsum_region_sim[r, thread] = regionshortfall
        end

    elseif isshortfall

        # Local simulation/timestep is still ongoing
        # Load was dropped, update time-aggregated tracking

        acc.droppedcount_overall_sim[thread] += one(V)
        acc.droppedsum_overall_sim[thread] += unservedenergy
        for r in 1:nregions
            regionshortfall = unservedloads[r]
            acc.droppedcount_region_sim[r, thread] += approxnonzero(regionshortfall)
            acc.droppedsum_region_sim[r, thread] += regionshortfall
        end

    end

    return

end

function finalize(acc::SequentialNetworkResultAccumulator{V,<:SystemModel{N,L,T,P,E,V}}
                  ) where {N,L,T,P,E,V}

    regions = acc.system.regions
    interfaces = acc.system.interfaces
    timestamps = acc.system.timestamps

    nthreads = Threads.nthreads()
    nregions = length(regions)
    ninterfaces = length(interfaces)
    nperiods = length(timestamps)

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

        for t in 1:nperiods

            merge!(acc.droppedcount_period[t, 1], acc.droppedcount_period[t, i])
            merge!(acc.droppedsum_period[t, 1], acc.droppedsum_period[t, i])

            for r in 1:nregions
                merge!(acc.droppedcount_regionperiod[r, t, 1], acc.droppedcount_regionperiod[r, t, i])
                merge!(acc.droppedsum_regionperiod[r, t, 1], acc.droppedsum_regionperiod[r, t, i])
            end

            for iface in 1:ninterfaces
                merge!(acc.flows[iface, t, 1], acc.flows[iface, t, i])
                merge!(acc.utilizations[iface, t, 1], acc.utilizations[iface, t, i])
            end

        end

        for r in 1:nregions
            merge!(acc.droppedcount_region[r, 1], acc.droppedcount_region[r, i])
            merge!(acc.droppedsum_region[r, 1], acc.droppedsum_region[r, i])
        end

    end

    nsamples = acc.simulationspec.nsamples

    lole = LOLE{N,L,T}(mean_stderr(acc.droppedcount_overall[1], nsamples)...)
    region_loles = map(r -> LOLE{N,L,T}(r...),
                mean_stderr.(acc.droppedcount_region[:, 1], nsamples))
    period_lolps = map(r -> LOLP{L,T}(r...),
                mean_stderr.(acc.droppedcount_period[:, 1], nsamples))
    regionperiod_lolps = map(r -> LOLP{L,T}(r...),
                mean_stderr.(acc.droppedcount_regionperiod[:, :, 1], nsamples))

    eue = EUE{N,L,T,E}(mean_stderr(acc.droppedsum_overall[1], nsamples)...)
    region_eues = map(r -> EUE{N,L,T,E}(r...),
               mean_stderr.(acc.droppedsum_region[:, 1], nsamples))
    period_eues = map(r -> EUE{1,L,T,E}(r...),
               mean_stderr.(acc.droppedsum_period[:, 1], nsamples))
    regionperiod_eues = map(r -> EUE{1,L,T,E}(r...),
               mean_stderr.(acc.droppedsum_regionperiod[:, :, 1], nsamples))

    flows = makemetric.(ExpectedInterfaceFlow{1,L,T,P}, acc.flows[:, :, 1])
    utilizations = makemetric.(ExpectedInterfaceUtilization{1,L,T}, acc.utilizations[:, :, 1])

    return NetworkResult(
        regions, interfaces, timestamps,
        lole, region_loles, period_lolps, regionperiod_lolps,
        eue, region_eues, period_eues, regionperiod_eues,
        flows, utilizations, acc.extractionspec, acc.simulationspec)

end
