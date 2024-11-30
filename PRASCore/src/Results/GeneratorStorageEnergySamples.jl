"""
    GeneratorStorageEnergySamples

Generator storage energy samples represent the state-of-charge of generatorstorage
resources at timestamps, which has not been averaged across different samples.
This presents a 3D matrix API (generatorstorages, timestamps, samples).

See [`GeneratorStorageEnergy`](@ref) for sample-averaged generator storage energy.
"""
struct GeneratorStorageEnergySamples <: ResultSpec end

struct GenStorageEnergySamplesAccumulator <: ResultAccumulator{GeneratorStorageEnergySamples}

    energy::Array{Float64,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::GeneratorStorageEnergySamples
) where {N}

    ngenstors = length(sys.generatorstorages)
    energy = zeros(Int, ngenstors, N, nsamples)

    return GenStorageEnergySamplesAccumulator(energy)

end

function merge!(
    x::GenStorageEnergySamplesAccumulator,
    y::GenStorageEnergySamplesAccumulator
)

    x.energy .+= y.energy
    return

end

accumulatortype(::GeneratorStorageEnergySamples) = GenStorageEnergySamplesAccumulator

struct GeneratorStorageEnergySamplesResult{N,L,T<:Period,E<:EnergyUnit} <: AbstractEnergyResult{N,L,T}

    generatorstorages::Vector{String}
    timestamps::StepRange{ZonedDateTime,T}

    energy::Array{Int,3}

end

names(x::GeneratorStorageEnergySamplesResult) = x.generatorstorages

function getindex(x::GeneratorStorageEnergySamplesResult, t::ZonedDateTime)
    i_t = findfirstunique(x.timestamps, t)
    return vec(sum(view(x.energy, :, i_t, :), dims=1))
end

function getindex(x::GeneratorStorageEnergySamplesResult, gs::AbstractString, t::ZonedDateTime)
    i_gs = findfirstunique(x.generatorstorages, gs)
    i_t = findfirstunique(x.timestamps, t)
    return vec(x.energy[i_gs, i_t, :])
end

function finalize(
    acc::GenStorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorStorageEnergySamplesResult{N,L,T,E}(
        system.generatorstorages.names, system.timestamps, acc.energy)

end
