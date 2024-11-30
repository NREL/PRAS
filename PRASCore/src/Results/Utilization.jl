"""
    Utilization

Utilization metric represents how much an interface between regions is used
across timestamps in a UtilizationResult with a (interfaces, timestamps) matrix API.

Separate samples are averaged together into mean and std values.

See [`UtilizationSamples`](@ref) for all utilization samples.
"""
struct Utilization <: ResultSpec end

struct UtilizationAccumulator <: ResultAccumulator{Utilization}

    util_interface::Vector{MeanVariance}
    util_interfaceperiod::Matrix{MeanVariance}

    util_interface_currentsim::Vector{Float64}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::Utilization
) where {N}

    n_interfaces = length(sys.interfaces)
    util_interface = [meanvariance() for _ in 1:n_interfaces]
    util_interfaceperiod = [meanvariance() for _ in 1:n_interfaces, _ in 1:N]

    util_interface_currentsim = zeros(Int, n_interfaces)

    return UtilizationAccumulator(
        util_interface, util_interfaceperiod,  util_interface_currentsim)

end

function merge!(
    x::UtilizationAccumulator, y::UtilizationAccumulator
)

    foreach(merge!, x.util_interface, y.util_interface)
    foreach(merge!, x.util_interfaceperiod, y.util_interfaceperiod)

end

accumulatortype(::Utilization) = UtilizationAccumulator

struct UtilizationResult{N,L,T<:Period} <: AbstractUtilizationResult{N,L,T}

    nsamples::Union{Int,Nothing}
    interfaces::Vector{Pair{String,String}}
    timestamps::StepRange{ZonedDateTime,T}

    utilization_mean::Matrix{Float64}

    utilization_interface_std::Vector{Float64}
    utilization_interfaceperiod_std::Matrix{Float64}

end

function getindex(x::UtilizationResult, i::Pair{<:AbstractString,<:AbstractString})
    i_i, _ = findfirstunique_directional(x.interfaces, i)
    return mean(view(x.utilization_mean, i_i, :)), x.utilization_interface_std[i_i]
end

function getindex(x::UtilizationResult, i::Pair{<:AbstractString,<:AbstractString}, t::ZonedDateTime)
    i_i, _ = findfirstunique_directional(x.interfaces, i)
    i_t = findfirstunique(x.timestamps, t)
    return x.utilization_mean[i_i, i_t], x.utilization_interfaceperiod_std[i_i, i_t]
end

function finalize(
    acc::UtilizationAccumulator,
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
