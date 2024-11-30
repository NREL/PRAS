"""
    StorageEnergySamples

Storage energy samples represent the state-of-charge of storage
resources at timestamps, which has not been averaged across different samples.
This presents a 3D matrix API (storages, timestamps, samples).

See [`StorageEnergy`](@ref) for sample-averaged storage energy.
"""
struct StorageEnergySamples <: ResultSpec end

struct StorageEnergySamplesAccumulator <: ResultAccumulator{StorageEnergySamples}

    energy::Array{Float64,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::StorageEnergySamples
) where {N}

    nstors = length(sys.storages)
    energy = zeros(Int, nstors, N, nsamples)

    return StorageEnergySamplesAccumulator(energy)

end

function merge!(
    x::StorageEnergySamplesAccumulator, y::StorageEnergySamplesAccumulator
)

    x.energy .+= y.energy
    return

end

accumulatortype(::StorageEnergySamples) = StorageEnergySamplesAccumulator

struct StorageEnergySamplesResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    storages::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    energy::Array{Int,3}

end

names(x::StorageEnergySamplesResult) = x.storages

function getindex(x::StorageEnergySamplesResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return vec(sum(view(x.energy, :, i_t, :), dims=1))
end

function getindex(x::StorageEnergySamplesResult, s::AbstractString, t::ZonedDateTime)
    i_s = findfirstunique(x.storages, s)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.energy[i_s, i_t, :])
end

function finalize(
    acc::StorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return StorageEnergySamplesResult{N,L,T,E}(
        system.storages.names, system.timestamps, acc.energy)

end
