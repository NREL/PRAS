# Flow

struct SMCFlowAccumulator <: ResultAccumulator{SequentialMonteCarlo,Flow}

    flow_interface::Vector{MeanVariance}
    flow_interfaceperiod::Matrix{MeanVariance}

    flow_interface_currentsim::Vector{Int}

end

function merge!(
    x::SMCFlowAccumulator, y::SMCFlowAccumulator
)

    foreach(merge!, x.flow_interface, y.flow_interface)
    foreach(merge!, x.flow_interfaceperiod, y.flow_interfaceperiod)

end

accumulatortype(::SequentialMonteCarlo, ::Flow) = SMCFlowAccumulator

function accumulator(
    sys::SystemModel{N}, ::SequentialMonteCarlo, ::Flow
) where {N}

    n_interfaces = length(sys.interfaces)
    flow_interface = [meanvariance() for _ in 1:n_interfaces]
    flow_interfaceperiod = [meanvariance() for _ in 1:n_interfaces, _ in 1:N]

    flow_interface_currentsim = zeros(Int, n_interfaces)

    return SMCFlowAccumulator(
        flow_interface, flow_interfaceperiod,  flow_interface_currentsim)

end

function record!(
    acc::SMCFlowAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    edges = problem.fp.edges

    for (i, (f, b)) in enumerate(zip(problem.interface_forward_edges,
                                     problem.interface_reverse_edges))

        flow = edges[f].flow - edges[b].flow
        acc.flow_interface_currentsim[i] += flow
        fit!(acc.flow_interfaceperiod[i,t], flow)

    end

end

function reset!(acc::SMCFlowAccumulator, sampleid::Int)

    for i in eachindex(acc.flow_interface_currentsim)
        fit!(acc.flow_interface[i], acc.flow_interface_currentsim[i])
        acc.flow_interface_currentsim[i] = 0
    end

end

function finalize(
    acc::SMCFlowAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    nsamples = length(system.interfaces) > 0 ?
        first(acc.flow_interface[1].stats).n : nothing

    flow_mean, flow_interfaceperiod_std = mean_std(acc.flow_interfaceperiod)
    flow_interface_std = last(mean_std(acc.flow_interface)) / N

    fromregions = getindex.(Ref(system.regions.names), system.interfaces.regions_from)
    toregions = getindex.(Ref(system.regions.names), system.interfaces.regions_to)

    return FlowResult{N,L,T,P}(
        nsamples,  Pair.(fromregions, toregions), system.timestamps,
        flow_mean, flow_interface_std, flow_interfaceperiod_std)

end

# FlowSamples

struct SMCFlowSamplesAccumulator <:
    ResultAccumulator{SequentialMonteCarlo,FlowSamples}

    flow::Array{Int,3}

end

function merge!(
    x::SMCFlowSamplesAccumulator, y::SMCFlowSamplesAccumulator
)

    x.flow .+= y.flow
    return

end

accumulatortype(::SequentialMonteCarlo, ::FlowSamples) = SMCFlowSamplesAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::SequentialMonteCarlo, ::FlowSamples
) where {N}

    ninterfaces = length(sys.interfaces)
    flow = zeros(Int, ninterfaces, N, simspec.nsamples)

    return SMCFlowSamplesAccumulator(flow)

end

function record!(
    acc::SMCFlowSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    for (i, (e_f, e_r)) in enumerate(zip(problem.interface_forward_edges,
                                problem.interface_reverse_edges))
        acc.flow[i, t, sampleid] = problem.fp.edges[e_f].flow -
                                   problem.fp.edges[e_r].flow
    end

    return

end

reset!(acc::SMCFlowSamplesAccumulator, sampleid::Int) = nothing

function finalize(
    acc::SMCFlowSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    fromregions = getindex.(Ref(system.regions.names), system.interfaces.regions_from)
    toregions = getindex.(Ref(system.regions.names), system.interfaces.regions_to)

    return FlowSamplesResult{N,L,T,P}(
        Pair.(fromregions, toregions), system.timestamps, acc.flow)

end
