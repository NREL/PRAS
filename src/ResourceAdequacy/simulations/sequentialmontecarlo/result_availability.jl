# GeneratorAvailability

struct SMCGenAvailabilityAccumulator <:
    ResultAccumulator{SequentialMonteCarlo,GeneratorAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::SMCGenAvailabilityAccumulator, y::SMCGenAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::SequentialMonteCarlo, ::GeneratorAvailability) = SMCGenAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::SequentialMonteCarlo, ::GeneratorAvailability
) where {N}

    ngens = length(sys.generators)
    available = zeros(Bool, ngens, N, simspec.nsamples)

    return SMCGenAvailabilityAccumulator(available)

end

function record!(
    acc::SMCGenAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.gens_available
    return

end

reset!(acc::SMCGenAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::SMCGenAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorAvailabilityResult{N,L,T}(
        system.generators.names, system.timestamps, acc.available)

end

# StorageAvailability

struct SMCStorAvailabilityAccumulator <:
    ResultAccumulator{SequentialMonteCarlo,StorageAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::SMCStorAvailabilityAccumulator, y::SMCStorAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::SequentialMonteCarlo, ::StorageAvailability) = SMCStorAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::SequentialMonteCarlo, ::StorageAvailability
) where {N}

    nstors = length(sys.storages)
    available = zeros(Bool, nstors, N, simspec.nsamples)

    return SMCStorAvailabilityAccumulator(available)

end

function record!(
    acc::SMCStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.stors_available
    return

end

reset!(acc::SMCStorAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::SMCStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return StorageAvailabilityResult{N,L,T}(
        system.storages.names, system.timestamps, acc.available)

end

# GeneratorStorageAvailability

struct SMCGenStorAvailabilityAccumulator <:
    ResultAccumulator{SequentialMonteCarlo,GeneratorStorageAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::SMCGenStorAvailabilityAccumulator, y::SMCGenStorAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::SequentialMonteCarlo, ::GeneratorStorageAvailability) = SMCGenStorAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::SequentialMonteCarlo, ::GeneratorStorageAvailability
) where {N}

    ngenstors = length(sys.generatorstorages)
    available = zeros(Bool, ngenstors, N, simspec.nsamples)

    return SMCGenStorAvailabilityAccumulator(available)

end

function record!(
    acc::SMCGenStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.genstors_available
    return

end

reset!(acc::SMCGenStorAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::SMCGenStorAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return GeneratorStorageAvailabilityResult{N,L,T}(
        system.generatorstorages.names, system.timestamps, acc.available)

end

# LineAvailability

struct SMCLineAvailabilityAccumulator <:
    ResultAccumulator{SequentialMonteCarlo,LineAvailability}

    available::Array{Bool,3}

end

function merge!(
    x::SMCLineAvailabilityAccumulator, y::SMCLineAvailabilityAccumulator
)

    x.available .|= y.available
    return

end

accumulatortype(::SequentialMonteCarlo, ::LineAvailability) = SMCLineAvailabilityAccumulator

function accumulator(
    sys::SystemModel{N}, simspec::SequentialMonteCarlo, ::LineAvailability
) where {N}

    nlines = length(sys.lines)
    available = zeros(Bool, nlines, N, simspec.nsamples)

    return SMCLineAvailabilityAccumulator(available)

end

function record!(
    acc::SMCLineAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
    state::SystemState, problem::DispatchProblem,
    sampleid::Int, t::Int
) where {N,L,T,P,E}

    acc.available[:, t, sampleid] .= state.lines_available
    return

end

reset!(acc::SMCLineAvailabilityAccumulator, sampleid::Int) = nothing

function finalize(
    acc::SMCLineAvailabilityAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return LineAvailabilityResult{N,L,T}(
        system.lines.names, system.timestamps, acc.available)

end
