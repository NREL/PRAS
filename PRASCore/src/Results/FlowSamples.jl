"""
    FlowSamples

Flow samples represent the flow between interfaces at timestamps, which has
not been averaged across different samples. This presents a
3D matrix API (interfaces, timestamps, samples).

See [`Flow`](@ref) for sample-averaged flow data.
"""
struct FlowSamples <: ResultSpec end

struct FlowSamplesAccumulator <: ResultAccumulator{FlowSamples}

    flow::Array{Int,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::FlowSamples
) where {N}

    ninterfaces = length(sys.interfaces)
    flow = zeros(Int, ninterfaces, N, nsamples)

    return FlowSamplesAccumulator(flow)

end

function merge!(
    x::FlowSamplesAccumulator, y::FlowSamplesAccumulator
)

    x.flow .+= y.flow
    return

end

accumulatortype(::FlowSamples) = FlowSamplesAccumulator

struct FlowSamplesResult{N,L,T<:Period,P<:PowerUnit} <: AbstractFlowResult{N,L,T}

    interfaces::Vector{Pair{String,String}}
    timestamps::StepRange{ZonedDateTime,T}

    flow::Array{Int,3}

end

function getindex(x::FlowSamplesResult, i::Pair{<:AbstractString,<:AbstractString})
    i_i, reverse = findfirstunique_directional(x.interfaces, i)
    flow = vec(mean(view(x.flow, i_i, :, :), dims=1))
    return reverse ? -flow : flow
end


function getindex(x::FlowSamplesResult, i::Pair{<:AbstractString,<:AbstractString}, t::ZonedDateTime)
    i_i, reverse = findfirstunique_directional(x.interfaces, i)
    i_t = findfirstunique(x.timestamps, t)
    flow = vec(x.flow[i_i, i_t, :])
    return reverse ? -flow : flow
end

function finalize(
    acc::FlowSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    fromregions = getindex.(Ref(system.regions.names), system.interfaces.regions_from)
    toregions = getindex.(Ref(system.regions.names), system.interfaces.regions_to)

    return FlowSamplesResult{N,L,T,P}(
        Pair.(fromregions, toregions), system.timestamps, acc.flow)

end
