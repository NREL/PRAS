include("simulation/copperplate.jl")
include("simulation/networkflow.jl")

function assess(extractionspec::ExtractionSpec,
                simulationspec::SimulationSpec{NonSequential},
                resultspec::ResultSpec,
                system::SystemModel)

    batchsize = ceil(Int, length(system.timestamps)/nworkers()/2)

    systemstatedistrs = extract(
        extractionspec, system, copperplate=iscopperplate(simulationspec))

    # TODO: Could convert this to a multithreaded for-loop (less overhead?)
    results = pmap(
        state -> assess(simulationspec, resultspec, state),
        systemstatedistrs, batch_size=batchsize)

    return aggregator(resultspec)(system.timestamps, results, extractionspec)

end

function assess(extractionspec::ES,
                simulationspec::SS,
                resultspec::MinimalResult, #TODO: Generalize
                system::SystemModel{N1,T1,N2,T2,P,E,V},
                seed::UInt=rand(UInt)
                ) where {N1,T1,N2,T2,P,E,V,
                         ES<:ExtractionSpec,SS<:SimulationSpec{Sequential}}

    n_periods = length(system.timestamps)
    n_samples = simulationspec.nsamples
    rngs = init_rngs(seed)
    shortfalls = zeros(V, n_periods, n_samples)

    Threads.@threads for i in 1:n_samples
        assess_singlesequence!(
            view(shortfalls, :, i),
            rngs[Threads.threadid()],
            extractionspec, simulationspec, resultspec, system)
    end

    return MultiPeriodMinimalResult(
        system, shortfalls, extractionspec, simulationspec)

end

"Allocate each RNG on its own thread"
function init_rngs(seed::UInt=rand(UInt))
    nthreads = Threads.nthreads()
    rngs = Vector{MersenneTwister}(nthreads)
    rngs_temp = randjump(MersenneTwister(seed),nthreads)
    Threads.@threads for i in 1:nthreads
        rngs[i] = copy(rngs_temp[i])
    end
    return rngs
end
