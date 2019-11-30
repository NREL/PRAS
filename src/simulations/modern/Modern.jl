include("SystemState.jl")
include("DispatchProblem.jl")
include("utils.jl")

struct Modern <: SimulationSpec

    nsamples::Int
    seed::UInt

    function Modern(;
        samples::Int=10_000, seed::UInt=rand(UInt))
        @assert samples > 0
        new(samples, seed)
    end

end

function assess(
    simspec::Modern,
    resultspec::ResultSpec,
    system::SystemModel)

    threads = nthreads()
    samples = Channel{Tuple{Int,Nothing}}(2*threads)
    results = Channel{accumulatortype(simspec, resultspec, system)}(threads)

    @spawn makesamples(samples, simspec)

    for _ in 1:threads
        @spawn assess(simspec, resultspec, system, samples, results)
    end

   return finalize(results, simspec, system, threads)

end

function makesamples(
    periods::Channel{Tuple{Int,Nothing}},
    simspec::Modern,
    step::Integer=big(10)^20)

    # TODO: Find a faster alternative to randjump for simulation-local RNG
    #       Maybe Random123? For now just falling back on thread-local RNG
    #rng = MersenneTwister(simspec.seed)

    for s in 1:simspec.nsamples
        put!(periods, (s, nothing))
        #rng = randjump(rng, step)
    end

    close(periods)

end

function assess(
    simspec::Modern, resultspec::R, system::SystemModel{N},
    samples::Channel{Tuple{Int,Nothing}},
    recorders::Channel{<:ResultAccumulator{R}}
) where {R<:ResultSpec, N}

    dispatchproblem = DispatchProblem(system)
    systemstate = SystemState(system)
    recorder = accumulator(simspec, resultspec, system)

    # TODO: Implement simulation-level RNG (Random123?)
    rng = GLOBAL_RNG
    for (s, _) in samples

        initialize!(rng, systemstate, system)

        for t in 1:N

            advance!(rng, systemstate, dispatchproblem, system, t)
            solve!(dispatchproblem, systemstate, system, t)
            record!(recorder, systemstate, dispatchproblem, s, t)

        end

        reset!(recorder, s)

    end

    put!(recorders, recorder)

end

function initialize!(
    rng::AbstractRNG, state::SystemState, system::SystemModel
)

        nperiods = length(system.timestamps)

        initialize_availability!(
            rng, state.gens_available, state.gens_nexttransition,
            system.generators, nperiods)

        initialize_availability!(
            rng, state.stors_available, state.stors_nexttransition,
            system.storages, nperiods)

        initialize_availability!(
            rng, state.genstors_available, state.genstors_nexttransition,
            system.generatorstorages, nperiods)

        initialize_availability!(
            rng, state.lines_available, state.lines_nexttransition,
            system.lines, nperiods)

        fill!(state.stors_energy, 0)
        fill!(state.genstors_energy, 0)

        return

end

function advance!(
    rng::AbstractRNG,
    state::SystemState,
    dispatchproblem::DispatchProblem,
    system::SystemModel, t::Int)

    nperiods = length(system.timestamps)

    update_availability!(
        rng, state.gens_available, state.gens_nexttransition,
        system.generators, t, nperiods)

    update_availability!(
        rng, state.stors_available, state.stors_nexttransition,
        system.storages, t, nperiods)

    update_availability!(
        rng, state.genstors_available, state.genstors_nexttransition,
        system.generatorstorages, t, nperiods)

    update_availability!(
        rng, state.lines_available, state.lines_nexttransition,
        system.lines, t, nperiods)

    update_energy!(state.stors_energy, system.storages, t)
    update_energy!(state.genstors_energy, system.generatorstorages, t)

    update_problem!(dispatchproblem, state, system, t)

end

function solve!(
    dispatchproblem::DispatchProblem, state::SystemState,
    system::SystemModel, t::Int
)
    fp = dispatchproblem.fp
    solveflows!(dispatchproblem.fp)
    update_state!(state, dispatchproblem, system, t)
end

include("result_minimal.jl")
#include("result_temporal.jl")
#include("result_spatiotemporal.jl")
#include("result_network.jl")
