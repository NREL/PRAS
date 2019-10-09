struct SequentialNetworkResultAccumulator{N,L,T,P,E} <:
    ResultAccumulator{Network,Sequential}

    droppedcount_overall::Vector{MeanVariance}
    droppedsum_overall::Vector{MeanVariance}
    droppedcount_region::Matrix{MeanVariance}
    droppedsum_region::Matrix{MeanVariance}
    droppedcount_period::Matrix{MeanVariance}
    droppedsum_period::Matrix{MeanVariance}
    droppedcount_regionperiod::Array{MeanVariance,3}
    droppedsum_regionperiod::Array{MeanVariance,3}
    simidx::Vector{Int}
    droppedcount_overall_sim::Vector{Int}
    droppedsum_overall_sim::Vector{Int}
    droppedcount_region_sim::Matrix{Int}
    droppedsum_region_sim::Matrix{Int}
    localshortfalls::Vector{Vector{Int}}
    flows::Array{MeanVariance,3}
    utilizations::Array{MeanVariance,3}

end

function accumulator(
    ::Type{Sequential}, resultspec::Network, sys::SystemModel{N,L,T,P,E}
) where {N,L,T,P,E}

    nthreads = Threads.nthreads()
    nregions = length(sys.regions)
    ninterfaces = length(sys.interfaces)
    nperiods = length(sys.timestamps)

    droppedcount_overall = Vector{MeanVariance}(undef, nthreads)
    droppedsum_overall = Vector{MeanVariance}(undef, nthreads)
    droppedcount_region = Matrix{MeanVariance}(undef, nregions, nthreads)
    droppedsum_region = Matrix{MeanVariance}(undef, nregions, nthreads)
    droppedcount_period = Matrix{MeanVariance}(undef, nperiods, nthreads)
    droppedsum_period = Matrix{MeanVariance}(undef, nperiods, nthreads)
    droppedcount_regionperiod = Array{MeanVariance,3}(undef, nregions, nperiods, nthreads)
    droppedsum_regionperiod = Array{MeanVariance,3}(undef, nregions, nperiods, nthreads)
    flows = Array{MeanVariance,3}(undef, ninterfaces, nperiods, nthreads)
    utilizations = Array{MeanVariance,3}(undef, ninterfaces, nperiods, nthreads)

    simidx = zeros(Int, nthreads)
    droppedcount_overall_sim = Vector{Int}(undef, nthreads)
    droppedsum_overall_sim = Vector{Int}(undef, nthreads)
    droppedcount_region_sim = Matrix{Int}(undef, nregions, nthreads)
    droppedsum_region_sim = Matrix{Int}(undef, nregions, nthreads)
    localshortfalls = Vector{Vector{Int}}(undef, nthreads)

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

        localshortfalls[i] = zeros(Int, nregions)

    end

    return SequentialNetworkResultAccumulator{N,L,T,P,E}(
        droppedcount_overall, droppedsum_overall,
        droppedcount_region, droppedsum_region,
        droppedcount_period, droppedsum_period,
        droppedcount_regionperiod, droppedsum_regionperiod,
        simidx, droppedcount_overall_sim, droppedsum_overall_sim,
        droppedcount_region_sim, droppedsum_region_sim, localshortfalls,
        flows, utilizations)

end

function update!(acc::SequentialNetworkResultAccumulator,
                 result::SystemOutputStateSummary, t::Int)

        error("Sequential analytical solutions are not currently supported.")

end

function update!(
    acc::SequentialNetworkResultAccumulator{N,L,T,P,E},
    sample::SystemOutputStateSample, t::Int, i::Int
) where {N,L,T,P,E}

    thread = Threads.threadid()
    nregions = length(acc.localshortfalls[thread])
    ninterfaces = size(acc.flows, 1)

    isshortfall, unservedload, unservedloads =
        droppedloads!(acc.localshortfalls[thread], sample)
    unservedenergy = powertoenergy(E, unservedload, P, L, T)

    # Update temporal/spatiotemporal result data
    fit!(acc.droppedcount_period[t, thread], isshortfall)
    fit!(acc.droppedsum_period[t, thread], unservedenergy)
    for r in 1:nregions
        regionshortfall = unservedloads[r]
        fit!(acc.droppedcount_regionperiod[r, t, thread], regionshortfall > 0)
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
        acc.droppedcount_overall_sim[thread] = isshortfall
        acc.droppedsum_overall_sim[thread] = unservedenergy
        for r in 1:nregions
            regionshortfall = unservedloads[r]
            acc.droppedcount_region_sim[r, thread] = (regionshortfall > 0)
            acc.droppedsum_region_sim[r, thread] = regionshortfall
        end

    elseif isshortfall

        # Local simulation/timestep is still ongoing
        # Load was dropped, update time-aggregated tracking

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

function finalize(
    cache::SimulationCache{N,L,T,P,E},
    acc::SequentialNetworkResultAccumulator{N,L,T,P,E}
) where {N,L,T,P,E}

    regions = cache.system.regions.names
    interfaces = tuple.(
        cache.system.interfaces.regions_from,
        cache.system.interfaces.regions_to)
    timestamps = cache.system.timestamps

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

    nsamples = cache.simulationspec.nsamples

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
        flows, utilizations, cache.simulationspec)

end
