mutable struct SequentialMonteCarloDebugAccumulator{N,L,T,P,E} <: ResultAccumulator{Debug}

    # Cross-simulation LOL period count mean/variances
    periodsdropped_total::MeanVariance
    periodsdropped_region::Vector{MeanVariance}
    periodsdropped_period::Vector{MeanVariance}
    periodsdropped_region_period::Matrix{MeanVariance}

    # Running LOL period counts for current simulation
    periodsdropped_total_currentsim::Int
    periodsdropped_region_currentsim::Vector{Int}

    # Cross-simulation UE mean/variances
    unservedload_total::MeanVariance
    unservedload_region::Vector{MeanVariance}
    unservedload_period::Vector{MeanVariance}
    unservedload_region_period::Matrix{MeanVariance}

    # Running UE totals for current simulation
    unservedload_total_currentsim::Int
    unservedload_region_currentsim::Vector{Int}

    # Cross-simulation per-period interface statistics
    flows::Matrix{MeanVariance}
    utilizations::Matrix{MeanVariance}

    # Unit-level availabilities
    gens_available::Array{Bool,3}
    lines_available::Array{Bool,3}
    stors_available::Array{Bool,3}
    genstors_available::Array{Bool,3}

    # Sample-level unserved energy
    sample_ues::Vector{Float64}

end

accumulatortype(::SequentialMonteCarlo, ::Debug, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} =
    SequentialMonteCarloDebugAccumulator{N,L,T,P,E}

function accumulator(simspec::SequentialMonteCarlo, ::Debug, sys::SystemModel{N,L,T,P,E}
) where {N,L,T,P,E}

    nregions = length(sys.regions)
    ninterfaces = length(sys.interfaces)
    ngens = length(sys.generators.names)
    nlines = length(sys.lines.names)
    nstors = length(sys.storages.names)
    ngenstors = length(sys.generatorstorages.names)
    threads = nthreads()

    periodsdropped_total = meanvariance()
    periodsdropped_region = [meanvariance() for _ in 1:nregions]
    periodsdropped_period = [meanvariance() for _ in 1:N]
    periodsdropped_region_period = Matrix{MeanVariance}(undef, nregions, N)

    periodsdropped_total_currentsim = 0
    periodsdropped_region_currentsim = zeros(Int, nregions)

    unservedload_total = meanvariance()
    unservedload_region = [meanvariance() for _ in 1:nregions]
    unservedload_period = [meanvariance() for _ in 1:N]
    unservedload_region_period = Matrix{MeanVariance}(undef, nregions, N)

    gens_available = zeros(Bool, ngens, N, simspec.nsamples)
    lines_available = zeros(Bool, nlines, N, simspec.nsamples)
    stors_available = zeros(Bool, nstors, N, simspec.nsamples)
    genstors_available = zeros(Bool, ngenstors, N, simspec.nsamples)

    sample_ues = zeros(Float64, simspec.nsamples)

    unservedload_total_currentsim = 0
    unservedload_region_currentsim = zeros(Int, nregions)

    flows = Matrix{MeanVariance}(undef, ninterfaces, N)
    utilizations = Matrix{MeanVariance}(undef, ninterfaces, N)

    for t in 1:N

        for r in 1:nregions
            periodsdropped_region_period[r,t] = meanvariance()
            unservedload_region_period[r,t] = meanvariance()
        end

        for i in 1:ninterfaces
            flows[i,t] = meanvariance()
            utilizations[i,t] = meanvariance()
        end

    end

    return SequentialMonteCarloDebugAccumulator{N,L,T,P,E}(
        periodsdropped_total, periodsdropped_region,
        periodsdropped_period, periodsdropped_region_period,
        periodsdropped_total_currentsim, periodsdropped_region_currentsim,
        unservedload_total, unservedload_region,
        unservedload_period, unservedload_region_period,
        unservedload_total_currentsim, unservedload_region_currentsim,
        flows, utilizations, gens_available, lines_available,
        stors_available, genstors_available, sample_ues)

end

function record!(
    acc::SequentialMonteCarloDebugAccumulator{N,L,T,P,E},
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    totalshortfall = 0
    isshortfall = false

    edges = problem.fp.edges
    for r in problem.region_unserved_edges

        regionshortfall = edges[r].flow
        isregionshortfall = regionshortfall > 0

        fit!(acc.periodsdropped_region_period[r,t], isregionshortfall)
        fit!(acc.unservedload_region_period[r,t], regionshortfall)

        if isregionshortfall

            isshortfall = true
            totalshortfall += regionshortfall

            acc.periodsdropped_region_currentsim[r] += 1
            acc.unservedload_region_currentsim[r] += regionshortfall

        end

    end

    for (i, (f, b)) in enumerate(zip(problem.interface_forward_edges,
                                     problem.interface_reverse_edges))

        flow_forward = edges[f].flow
        max_forward = edges[f].limit

        flow_back = edges[b].flow
        max_back = edges[f].limit

        fit!(acc.flows[i,t], max(flow_forward, flow_back))
        fit!(acc.utilizations[i,t], max(flow_forward/max_forward, flow_back/max_back))

    end

    if isshortfall
        acc.periodsdropped_total_currentsim += 1
        acc.unservedload_total_currentsim += totalshortfall
    end

    fit!(acc.periodsdropped_period[t], isshortfall)
    fit!(acc.unservedload_period[t], totalshortfall)

    acc.gens_available[:,t,sampleid] = state.gens_available
    acc.lines_available[:,t,sampleid] = state.lines_available
    acc.stors_available[:,t,sampleid] = state.stors_available
    acc.genstors_available[:,t,sampleid] = state.genstors_available

    return

end

function reset!(acc::SequentialMonteCarloDebugAccumulator{N,L,T,P,E}, sampleid::Int
) where {N,L,T,P,E}

    # Store regional / total sums for current simulation
    fit!(acc.periodsdropped_total, acc.periodsdropped_total_currentsim)
    fit!(acc.unservedload_total, acc.unservedload_total_currentsim)
    acc.sample_ues[sampleid] = acc.unservedload_total_currentsim

    nregions = length(acc.periodsdropped_region)
    for r in 1:nregions
        fit!(acc.periodsdropped_region[r], acc.periodsdropped_region_currentsim[r])
        fit!(acc.unservedload_region[r], acc.unservedload_region_currentsim[r])
    end

    # Reset for new simulation
    acc.periodsdropped_total_currentsim = 0
    fill!(acc.periodsdropped_region_currentsim, 0)
    acc.unservedload_total_currentsim = 0
    fill!(acc.unservedload_region_currentsim, 0)

    return

end

function finalize(
    results::Channel{SequentialMonteCarloDebugAccumulator{N,L,T,P,E}},
    simspec::SequentialMonteCarlo,
    system::SystemModel{N,L,T,P,E},
    accsremaining::Int
) where {N,L,T,P,E}

    nregions = length(system.regions)
    ninterfaces = length(system.interfaces)
    interfaces = tuple.(system.interfaces.regions_from, system.interfaces.regions_to)
    ngens = length(system.generators.names)
    nlines = length(system.lines.names)
    nstors = length(system.storages.names)
    ngenstors = length(system.generatorstorages.names)

    periodsdropped_total = meanvariance()
    periodsdropped_period = [meanvariance() for _ in 1:N]
    periodsdropped_region = [meanvariance() for _ in 1:nregions]
    periodsdropped_region_period = Matrix{MeanVariance}(undef, nregions, N)

    unservedload_total = meanvariance()
    unservedload_period = [meanvariance() for _ in 1:N]
    unservedload_region = [meanvariance() for _ in 1:nregions]
    unservedload_region_period = Matrix{MeanVariance}(undef, nregions, N)

    flows = Matrix{MeanVariance}(undef, ninterfaces, N)
    utilizations = Matrix{MeanVariance}(undef, ninterfaces, N)

    gens_available = zeros(Bool, ngens, N, simspec.nsamples)
    lines_available = zeros(Bool, nlines, N, simspec.nsamples)
    stors_available = zeros(Bool, nstors, N, simspec.nsamples)
    genstors_available = zeros(Bool, ngenstors, N, simspec.nsamples)

    sample_ues = zeros(Float64, simspec.nsamples)

    for t in 1:N

        for r in 1:nregions
            periodsdropped_region_period[r,t] = meanvariance()
            unservedload_region_period[r,t] = meanvariance()
        end

        for i in 1:ninterfaces
            flows[i,t] = meanvariance()
            utilizations[i,t] = meanvariance()
        end

    end

    while accsremaining > 0

        acc = take!(results)

        merge!(periodsdropped_total, acc.periodsdropped_total)
        merge!(unservedload_total, acc.unservedload_total)

        for r in 1:nregions
            merge!(periodsdropped_region[r], acc.periodsdropped_region[r])
            merge!(unservedload_region[r], acc.unservedload_region[r])
        end

        for t in 1:N

            merge!(periodsdropped_period[t], acc.periodsdropped_period[t])
            merge!(unservedload_period[t], acc.unservedload_period[t])

            for r in 1:nregions
                merge!(periodsdropped_region_period[r,t], acc.periodsdropped_region_period[r, t])
                merge!(unservedload_region_period[r,t], acc.unservedload_region_period[r, t])
            end

            for i in 1:ninterfaces
                merge!(flows[i,t], acc.flows[i, t])
                merge!(utilizations[i,t], acc.utilizations[i, t])
            end

        end

        # elementwise OR to say whether a unit was outaged in this sample
        gens_available .|= acc.gens_available
        lines_available .|= acc.lines_available
        stors_available .|= acc.stors_available
        genstors_available .|= acc.genstors_available

        sample_ues .+= acc.sample_ues #same idea with integers instead of bools

        accsremaining -= 1

    end

    close(results)

    lole = makemetric(LOLE{N,L,T}, periodsdropped_total)
    region_loles = makemetric.(LOLE{N,L,T}, periodsdropped_region)
    lolps = makemetric.(LOLP{L,T}, periodsdropped_period)
    region_lolps = makemetric.(LOLP{L,T}, periodsdropped_region_period)

    p2e = conversionfactor(L,T,P,E)
    eue = makemetric_scale(EUE{N,L,T,E}, p2e, unservedload_total)
    region_eues = makemetric_scale.(EUE{N,L,T,E}, p2e, unservedload_region)
    period_eues = makemetric_scale.(EUE{1,L,T,E}, p2e, unservedload_period)
    regionperiod_eues = makemetric_scale.(EUE{1,L,T,E}, p2e, unservedload_region_period)

    flow_results = makemetric.(ExpectedInterfaceFlow{1,L,T,P}, flows)
    utilization_results = makemetric.(ExpectedInterfaceUtilization{1,L,T}, utilizations)

    sample_ues .*= p2e

    return DebugResult(
        system.regions.names, interfaces, system.timestamps,
        lole, region_loles, lolps, region_lolps,
        eue, region_eues, period_eues, regionperiod_eues,
        flow_results, utilization_results, gens_available,
        lines_available,  stors_available, genstors_available,
        sample_ues, simspec)

end
