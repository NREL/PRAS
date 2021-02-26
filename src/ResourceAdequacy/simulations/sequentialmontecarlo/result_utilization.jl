# Utilization

struct SMCUtilizationAccumulator <: ResultAccumulator{SequentialMonteCarlo,Utilization}

    util_interface::Vector{MeanVariance}
    util_interfaceperiod::Matrix{MeanVariance}

    util_interface_currentsim::Vector{Float64}

end

function merge!(
    x::SMCUtilizationAccumulator, y::SMCUtilizationAccumulator
)

    foreach(merge!, x.util_interface, y.util_interface)
    foreach(merge!, x.util_interfaceperiod, y.util_interfaceperiod)

end

accumulatortype(::SequentialMonteCarlo, ::Utilization) = SMCUtilizationAccumulator

function accumulator(
    sys::SystemModel{N}, ::SequentialMonteCarlo, ::Utilization
) where {N}

    n_interfaces = length(sys.interfaces)
    util_interface = [meanvariance() for _ in 1:n_interfaces]
    util_interfaceperiod = [meanvariance() for _ in 1:n_interfaces, _ in 1:N]

    util_interface_currentsim = zeros(Int, n_interfaces)

    return SMCUtilizationAccumulator(
        util_interface, util_interfaceperiod,  util_interface_currentsim)

end

function record!(
    acc::SMCUtilizationAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    edges = problem.fp.edges

    for (i, (f, b)) in enumerate(zip(problem.interface_forward_edges,
                                     problem.interface_reverse_edges))

        util = utilization(problem.fp.edges[f], problem.fp.edges[b])
        acc.util_interface_currentsim[i] += util
        fit!(acc.util_interfaceperiod[i,t], util)

    end

end

function reset!(acc::SMCUtilizationAccumulator, sampleid::Int)

    for i in eachindex(acc.util_interface_currentsim)
        fit!(acc.util_interface[i], acc.util_interface_currentsim[i])
        acc.util_interface_currentsim[i] = 0
    end

end

function finalize(
    acc::SMCUtilizationAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    nsamples = length(system.interfaces) > 0 ?
        first(acc.util_interface[1].stats).n : nothing

    util_mean, util_interfaceperiod_std = mean_std(acc.util_interfaceperiod)
    util_interface_std = last(mean_std(acc.util_interface)) / N

    fromregions = getindex.(Ref(system.regions.names), system.interfaces.regions_from)
    toregions = getindex.(Ref(system.regions.names), system.interfaces.regions_to)

    return UtilizationResult{N,L,T}(
        nsamples,  Pair.(fromregions, toregions), system.timestamps,
        util_mean, util_interface_std, util_interfaceperiod_std)

end

# UtilizationSamples

struct SMCUtilizationSamplesAccumulator <:
    ResultAccumulator{SequentialMonteCarlo,UtilizationSamples}

    utilization::Array{Float64,3}

end

function merge!(
    x::SMCUtilizationSamplesAccumulator, y::SMCUtilizationSamplesAccumulator
)

    x.utilization .+= y.utilization
    return

end

accumulatortype(::SequentialMonteCarlo, ::UtilizationSamples) = SMCUtilizationSamplesAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::SequentialMonteCarlo, ::UtilizationSamples
) where {N}

    ninterfaces = length(sys.interfaces)
    utilization = zeros(Float64, ninterfaces, N, simspec.nsamples)

    return SMCUtilizationSamplesAccumulator(utilization)

end

function record!(
    acc::SMCUtilizationSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    for (i, (e_f, e_r)) in enumerate(zip(problem.interface_forward_edges,
                                         problem.interface_reverse_edges))

        acc.utilization[i, t, sampleid] =
            utilization(problem.fp.edges[e_f], problem.fp.edges[e_r])

    end

    return

end

reset!(acc::SMCUtilizationSamplesAccumulator, sampleid::Int) = nothing

function finalize(
    acc::SMCUtilizationSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    fromregions = getindex.(Ref(system.regions.names), system.interfaces.regions_from)
    toregions = getindex.(Ref(system.regions.names), system.interfaces.regions_to)

    return UtilizationSamplesResult{N,L,T}(
        Pair.(fromregions, toregions), system.timestamps, acc.utilization)

end


function utilization(f::MinCostFlows.Edge, b::MinCostFlows.Edge)

    flow_forward = f.flow
    max_forward = f.limit

    flow_back = b.flow
    max_back = b.limit

    util = if flow_forward > 0
        flow_forward/max_forward
    elseif flow_back > 0
        flow_back/max_back
    elseif iszero(max_forward) && iszero(max_back)
        1.0
    else
        0.0
    end

    return util

end
