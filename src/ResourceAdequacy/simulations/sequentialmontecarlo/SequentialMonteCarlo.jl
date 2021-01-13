include("SystemState.jl")
include("DispatchProblem.jl")
include("utils.jl")

struct SequentialMonteCarlo <: SimulationSpec

    nsamples::Int
    seed::UInt64
    threaded::Bool

    function SequentialMonteCarlo(;
        samples::Int=10_000, seed::Integer=rand(UInt64), threaded::Bool=true
    )
        samples <= 0 && error("Sample count must be positive")
        seed < 0 && error("Random seed must be non-negative")
        new(samples, UInt64(seed), threaded)
    end

end

function assess(
    simspec::SequentialMonteCarlo,
    resultspec::ResultSpec,
    system::SystemModel)

    threads = nthreads()
    samples = Channel{Int}(2*threads)
    results = Channel{accumulatortype(simspec, resultspec, system)}(threads)

    @spawn makesamples(samples, simspec)

    if simspec.threaded
        for _ in 1:threads
            @spawn assess(simspec, resultspec, system, samples, results)
        end
    else
        assess(simspec, resultspec, system, samples, results)
    end

    return finalize(results, simspec, system, threads)

end

function makesamples(samples::Channel{Int}, simspec::SequentialMonteCarlo)

    for s in 1:simspec.nsamples
        put!(samples, s)
    end

    close(samples)

end

function assess(
    simspec::SequentialMonteCarlo, resultspec::R, system::SystemModel{N},
    samples::Channel{Int},
    recorders::Channel{<:ResultAccumulator{R}}
) where {R<:ResultSpec, N}

    dispatchproblem = DispatchProblem(system)
    systemstate = SystemState(system)
    recorder = accumulator(simspec, resultspec, system)

    # TODO: Test performance of Philox vs Threefry, choice of rounds
    # Also consider implementing an efficient Bernoulli trial with direct
    # mantissa comparison
    rng = Philox4x((0, 0), 10)

    for s in samples

        seed!(rng, (simspec.seed, s))
        initialize!(rng, systemstate, system)

        for t in 1:N

            advance!(rng, systemstate, dispatchproblem, system, t)
            solve!(dispatchproblem, systemstate, system, t)
            record!(recorder, system, systemstate, dispatchproblem, s, t)

        end

        reset!(recorder, s)

    end

    put!(recorders, recorder)

end

function initialize!(
    rng::AbstractRNG, state::SystemState, system::SystemModel{N}
) where N

        initialize_availability!(
            rng, state.gens_available, state.gens_nexttransition,
            system.generators, N)

        initialize_availability!(
            rng, state.stors_available, state.stors_nexttransition,
            system.storages, N)

        initialize_availability!(
            rng, state.genstors_available, state.genstors_nexttransition,
            system.generatorstorages, N)

        initialize_availability!(
            rng, state.lines_available, state.lines_nexttransition,
            system.lines, N)

        fill!(state.stors_energy, 0)
        fill!(state.genstors_energy, 0)

        return

end

function advance!(
    rng::AbstractRNG,
    state::SystemState,
    dispatchproblem::DispatchProblem,
    system::SystemModel{N}, t::Int) where N

    update_availability!(
        rng, state.gens_available, state.gens_nexttransition,
        system.generators, t, N)

    update_availability!(
        rng, state.stors_available, state.stors_nexttransition,
        system.storages, t, N)

    update_availability!(
        rng, state.genstors_available, state.genstors_nexttransition,
        system.generatorstorages, t, N)

    update_availability!(
        rng, state.lines_available, state.lines_nexttransition,
        system.lines, t, N)

    update_energy!(state.stors_energy, system.storages, t)
    update_energy!(state.genstors_energy, system.generatorstorages, t)

    update_problem!(dispatchproblem, state, system, t)

end

function solve!(
    dispatchproblem::DispatchProblem, state::SystemState,
    system::SystemModel, t::Int
)
    solveflows!(dispatchproblem.fp)
    update_state!(state, dispatchproblem, system, t)
end

include("result_minimal.jl")
include("result_temporal.jl")
include("result_spatiotemporal.jl")
include("result_network.jl")
include("result_debug.jl")
