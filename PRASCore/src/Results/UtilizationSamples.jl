"""
    UtilizationSamples

Utilization samples represent the utilization between interfaces at timestamps, which has
not been averaged across different samples. This presents a
3D matrix API (interfaces, timestamps, samples).

See [`Utilization`](@ref) for averaged utilization samples.
"""
struct UtilizationSamples <: ResultSpec end

struct UtilizationSamplesAccumulator <: ResultAccumulator{UtilizationSamples}

    utilization::Array{Float64,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::UtilizationSamples
) where {N}

    ninterfaces = length(sys.interfaces)
    utilization = zeros(Float64, ninterfaces, N, nsamples)

    return UtilizationSamplesAccumulator(utilization)

end

function merge!(
    x::UtilizationSamplesAccumulator, y::UtilizationSamplesAccumulator
)

    x.utilization .+= y.utilization
    return

end

accumulatortype(::UtilizationSamples) = UtilizationSamplesAccumulator

struct UtilizationSamplesResult{N,L,T<:Period} <: AbstractUtilizationResult{N,L,T}

    interfaces::Vector{Pair{String,String}}
    timestamps::StepRange{ZonedDateTime,T}

    utilization::Array{Float64,3}

end

function getindex(x::UtilizationSamplesResult,
                  i::Pair{<:AbstractString,<:AbstractString})
    i_i, _ = findfirstunique_directional(x.interfaces, i)
    return vec(mean(view(x.utilization, i_i, :, :), dims=1))
end


function getindex(x::UtilizationSamplesResult,
                  i::Pair{<:AbstractString,<:AbstractString}, t::ZonedDateTime)
    i_i, _ = findfirstunique_directional(x.interfaces, i)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.utilization[i_i, i_t, :])
end

function finalize(
    acc::UtilizationSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    fromregions = getindex.(Ref(system.regions.names), system.interfaces.regions_from)
    toregions = getindex.(Ref(system.regions.names), system.interfaces.regions_to)

    return UtilizationSamplesResult{N,L,T}(
        Pair.(fromregions, toregions), system.timestamps, acc.utilization)

end
