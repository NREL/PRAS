# StorageEnergy

mutable struct SMCStorageEnergyAccumulator <:
    ResultAccumulator{SequentialMonteCarlo,StorageEnergy}

    # Cross-simulation energy mean/variances
    energy_period::Vector{MeanVariance}
    energy_storageperiod::Matrix{MeanVariance}

end

function merge!(
    x::SMCStorageEnergyAccumulator, y::SMCStorageEnergyAccumulator
)

    foreach(merge!, x.energy_period, y.energy_period)
    foreach(merge!, x.energy_storageperiod, y.energy_storageperiod)

    return

end

accumulatortype(::SequentialMonteCarlo, ::StorageEnergy) = SMCStorageEnergyAccumulator

function accumulator(
    sys::SystemModel{N}, ::SequentialMonteCarlo, ::StorageEnergy
) where {N}

    nstorages = length(sys.storages)

    energy_period = [meanvariance() for _ in 1:N]
    energy_storageperiod = [meanvariance() for _ in 1:nstorages, _ in 1:N]

    return SMCStorageEnergyAccumulator(
        energy_period, energy_storageperiod)

end

function record!(
    acc::SMCStorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    totalenergy = 0
    nstorages = length(system.storages)

    for s in 1:nstorages

        storageenergy = state.stors_energy[s]
        fit!(acc.energy_storageperiod[s,t], storageenergy)
        totalenergy += storageenergy

    end

    fit!(acc.energy_period[t], totalenergy)

    return

end

reset!(acc::SMCStorageEnergyAccumulator, sampleid::Int) = nothing

function finalize(
    acc::SMCStorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    _, period_std = mean_std(acc.energy_period)
    storageperiod_mean, storageperiod_std = mean_std(acc.energy_storageperiod)

    nsamples = first(first(acc.energy_period).stats).n

    return StorageEnergyResult{N,L,T,E}(
        nsamples, system.storages.names, system.timestamps,
        storageperiod_mean, period_std, storageperiod_std)

end

# GeneratorStorageEnergy

mutable struct SMCGenStorageEnergyAccumulator <:
    ResultAccumulator{SequentialMonteCarlo,GeneratorStorageEnergy}

    # Cross-simulation energy mean/variances
    energy_period::Vector{MeanVariance}
    energy_genstorperiod::Matrix{MeanVariance}

end

function merge!(
    x::SMCGenStorageEnergyAccumulator, y::SMCGenStorageEnergyAccumulator
)

    foreach(merge!, x.energy_period, y.energy_period)
    foreach(merge!, x.energy_genstorperiod, y.energy_genstorperiod)

    return

end

accumulatortype(::SequentialMonteCarlo, ::GeneratorStorageEnergy) =
    SMCGenStorageEnergyAccumulator

function accumulator(
    sys::SystemModel{N}, ::SequentialMonteCarlo, ::GeneratorStorageEnergy
) where {N}

    ngenstors = length(sys.generatorstorages)

    energy_period = [meanvariance() for _ in 1:N]
    energy_genstorperiod = [meanvariance() for _ in 1:ngenstors, _ in 1:N]

    return SMCGenStorageEnergyAccumulator(
        energy_period, energy_genstorperiod)

end

function record!(
    acc::SMCGenStorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    totalenergy = 0
    ngenstors = length(system.generatorstorages)

    for s in 1:ngenstors

        genstorenergy = state.genstors_energy[s]
        fit!(acc.energy_genstorperiod[s,t], genstorenergy)
        totalenergy += genstorenergy

    end

    fit!(acc.energy_period[t], totalenergy)

    return

end

reset!(acc::SMCGenStorageEnergyAccumulator, sampleid::Int) = nothing

function finalize(
    acc::SMCGenStorageEnergyAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    _, period_std = mean_std(acc.energy_period)
    genstorperiod_mean, genstorperiod_std = mean_std(acc.energy_genstorperiod)

    nsamples = first(first(acc.energy_period).stats).n

    return GeneratorStorageEnergyResult{N,L,T,E}(
        nsamples, system.generatorstorages.names, system.timestamps,
        genstorperiod_mean, period_std, genstorperiod_std)

end

# StorageEnergySamples

struct SMCStorageEnergySamplesAccumulator <:
    ResultAccumulator{SequentialMonteCarlo,StorageEnergySamples}

    energy::Array{Float64,3}

end

function merge!(
    x::SMCStorageEnergySamplesAccumulator, y::SMCStorageEnergySamplesAccumulator
)

    x.energy .+= y.energy
    return

end

accumulatortype(::SequentialMonteCarlo, ::StorageEnergySamples) =
    SMCStorageEnergySamplesAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::SequentialMonteCarlo, ::StorageEnergySamples
) where {N}

    nstors = length(sys.storages)
    energy = zeros(Int, nstors, N, simspec.nsamples)

    return SMCStorageEnergySamplesAccumulator(energy)

end

function record!(
    acc::SMCStorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.energy[:, t, sampleid] .= state.stors_energy
    return

end

reset!(acc::SMCStorageEnergySamplesAccumulator, sampleid::Int) = nothing

function finalize(
    acc::SMCStorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return StorageEnergySamplesResult{N,L,T,E}(
        system.storages.names, system.timestamps, acc.energy)

end

# GeneratorStorageEnergySamples

struct SMCGenStorageEnergySamplesAccumulator <:
    ResultAccumulator{SequentialMonteCarlo,GeneratorStorageEnergySamples}

    energy::Array{Float64,3}

end

function merge!(
    x::SMCGenStorageEnergySamplesAccumulator,
    y::SMCGenStorageEnergySamplesAccumulator
)

    x.energy .+= y.energy
    return

end

accumulatortype(::SequentialMonteCarlo, ::GeneratorStorageEnergySamples) =
    SMCGenStorageEnergySamplesAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::SequentialMonteCarlo, ::GeneratorStorageEnergySamples
) where {N}

    ngenstors = length(sys.generatorstorages)
    energy = zeros(Int, ngenstors, N, simspec.nsamples)

    return SMCGenStorageEnergySamplesAccumulator(energy)

end

function record!(
    acc::SMCGenStorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.energy[:, t, sampleid] .= state.genstors_energy
    return

end

reset!(acc::SMCGenStorageEnergySamplesAccumulator, sampleid::Int) = nothing

function finalize(
    acc::SMCGenStorageEnergySamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorStorageEnergySamplesResult{N,L,T,E}(
        system.generatorstorages.names, system.timestamps, acc.energy)

end
