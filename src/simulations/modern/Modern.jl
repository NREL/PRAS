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
    samples = Channel{Tuple{Int,MersenneTwister}}(2*threads)
    results = Channel{accumulatortype(simspec, resultspec, system)}(threads)

    @spawn makesamples(samples, simspec)

    for _ in 1:threads
        @spawn assess(simspec, resultspec, system, samples, results)
    end

   return finalize(results, system, threads)

end

function makesamples(
    periods::Channel{Tuple{Int,MersenneTwister}},
    simspec::Modern,
    step::Integer=big(10)^20)

    rng = MersenneTwister(seed)

    for s in 1:simspec.nsamples
        put!(periods, (s, rng))
        rng = randjump(rng, step)
    end

    close(periods)

end

function assess(
    simspec::Modern, resultspec::R, system::SystemModel,
    samples::Channel{Tuple{Int,MersenneTwister}},
    recorders::Channel{<:ResultAccumulator{R}}
) where {R<:ResultSpec}

    dispatchproblem = DispatchProblem(system)
    systemstate = SystemState(system)
    recorder = accumulator(simspec, resultspec, system)

    # TODO: Maybe just store range indices in this format directly
    genranges = assetgrouprange(system.generators_regionstart, ngens)
    storranges = assetgrouprange(system.storages_regionstart, nstors)
    genstorranges = assetgrouprange(system.storages_regionstart, ngenstors)
    lineranges = assetgrouprange(system.lines_interfacestart, nlines)

    for (s, rng) in samples

        initialize!(rng, systemstate, system)

        for t in 1:nperiods

            advance!(rng, systemstate, dispatchproblem, system, t)
            solve!(dispatchproblem, systemstate)
            record!(recorder, systemstate, dispatchproblem, s, t)

        end

        reset!(recorder, s)

    end

    put!(recorders, recorder)

end

function initialize!(
    rng::MersenneTwister, state::SystemState, system::SystemModel
)

        nperiods = length(system.timesteps)

        initialize_availability!(
            rng, state.gens_available, state.gens_nexttransition,
            system.gens, nperiods)

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
    rng::MersenneTwister,
    state::SystemState,
    dispatchproblem::DispatchProblem,
    system::SystemModel, t::Int)

    nperiods = length(system.timesteps)

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

    decay_energy!(state.stors_energy, system.storages, t)
    decay_energy!(state.genstors_energy, system.generatorstorages, t)

    update_problem!(dispatchproblem, state, system, t)

end

function solve!(
    dispatchproblem::DispatchProblem, state::SystemState,
    system::SystemModel, t::Int
)

    solveflows!(dispatchproblem.fp)
    update_state!(state, dispatchproblem, system, t)

end

#include("result_minimal.jl")
#include("result_temporal.jl")
#include("result_spatiotemporal.jl")
#include("result_network.jl")
