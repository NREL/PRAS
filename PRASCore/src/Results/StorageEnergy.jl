"""
    StorageEnergy

Storage energy represents the state-of-charge of storage
resources at timestamps in a StorageEnergyResult with a (storages, timestamps)
matrix API.

Separate samples are averaged together into mean and std values.

See [`StorageEnergySamples`](@ref) for all storage energy samples.

See [`GeneratorStorageEnergy`](@ref) for generator storage energy.
"""
struct StorageEnergy <: ResultSpec end

mutable struct StorageEnergyAccumulator <: ResultAccumulator{StorageEnergy}

    # Cross-simulation energy mean/variances
    energy_period::Vector{MeanVariance}
    energy_storageperiod::Matrix{MeanVariance}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::StorageEnergy
) where {N}

    nstorages = length(sys.storages)

    energy_period = [meanvariance() for _ in 1:N]
    energy_storageperiod = [meanvariance() for _ in 1:nstorages, _ in 1:N]

    return StorageEnergyAccumulator(
        energy_period, energy_storageperiod)

end

function merge!(
    x::StorageEnergyAccumulator, y::StorageEnergyAccumulator
)

    foreach(merge!, x.energy_period, y.energy_period)
    foreach(merge!, x.energy_storageperiod, y.energy_storageperiod)

    return

end

accumulatortype(::StorageEnergy) = StorageEnergyAccumulator

struct StorageEnergyResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    nsamples::Union{Int,Nothing}
    storages::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    energy_mean::Matrix{Float64}

    energy_period_std::Vector{Float64}
    energy_regionperiod_std::Matrix{Float64}

end

names(x::StorageEnergyResult) = x.storages

function getindex(x::StorageEnergyResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return sum(view(x.energy_mean, :, i_t)), x.energy_period_std[i_t]
end

function getindex(x::StorageEnergyResult, s::AbstractString, t::ZonedDateTime)
    i_s = findfirstunique(x.storages, s)
    i_t = findfirstunique(x.timestamps, t)
    return x.energy_mean[i_s, i_t], x.energy_regionperiod_std[i_s, i_t]
end

function finalize(
    acc::StorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    _, period_std = mean_std(acc.energy_period)
    storageperiod_mean, storageperiod_std = mean_std(acc.energy_storageperiod)

    nsamples = first(first(acc.energy_period).stats).n

    return StorageEnergyResult{N,L,T,E}(
        nsamples, system.storages.names, system.timestamps,
        storageperiod_mean, period_std, storageperiod_std)

end
