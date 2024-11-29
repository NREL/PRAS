"""
    Flow

Flow metric represents the flow between interfaces at timestamps
in a FlowResult with a (interfaces, timestamps) matrix API.

Separate samples are averaged together into mean and std values.

See [`FlowSamples`](@ref) for all flow samples.
"""
struct Flow <: ResultSpec end
abstract type AbstractFlowResult{N,L,T} <: Result{N,L,T} end

# Colon indexing

getindex(x::AbstractFlowResult, ::Colon) =
    getindex.(x, x.interfaces)

getindex(x::AbstractFlowResult, ::Colon, t::ZonedDateTime) =
    getindex.(x, x.interfaces, t)

getindex(x::AbstractFlowResult, i::Pair{<:AbstractString,<:AbstractString}, ::Colon) =
    getindex.(x, i, x.timestamps)

getindex(x::AbstractFlowResult, ::Colon, ::Colon) =
    getindex.(x, x.interfaces, permutedims(x.timestamps))

# Sample-averaged flow data

struct FlowResult{N,L,T<:Period,P<:PowerUnit} <: AbstractFlowResult{N,L,T}

    nsamples::Union{Int,Nothing}
    interfaces::Vector{Pair{String,String}}
    timestamps::StepRange{ZonedDateTime,T}

    flow_mean::Matrix{Float64}

    flow_interface_std::Vector{Float64}
    flow_interfaceperiod_std::Matrix{Float64}

end

function getindex(x::FlowResult, i::Pair{<:AbstractString,<:AbstractString})
    i_i, reverse = findfirstunique_directional(x.interfaces, i)
    flow = mean(view(x.flow_mean, i_i, :))
    return reverse ? -flow : flow, x.flow_interface_std[i_i]
end

function getindex(x::FlowResult, i::Pair{<:AbstractString,<:AbstractString}, t::ZonedDateTime)
    i_i, reverse = findfirstunique_directional(x.interfaces, i)
    i_t = findfirstunique(x.timestamps, t)
    flow = x.flow_mean[i_i, i_t]
    return reverse ? -flow : flow, x.flow_interfaceperiod_std[i_i, i_t]
end

# Full flow data
"""
    FlowSamples

Flow samples represent the flow between interfaces at timestamps, which has
not been averaged across different samples. This presents a
3D matrix API (interfaces, timestamps, samples).

See [`Flow`](@ref) for sample-averaged flow data.
"""
struct FlowSamples <: ResultSpec end

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
