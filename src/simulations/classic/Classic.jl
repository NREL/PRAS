include("convolution.jl")

struct Classic <: SimulationSpec end

function assess(
    simspec::Classic,       # TODO: Look into traits for defining
    resultspec::ResultSpec, #       valid SimSpec/ResultSpec pairs
    system::SystemModel{N}, seed::UInt=rand(UInt)) where {N}

    nregions = length(system.regions)
    nstors = length(system.storages)
    ngenstors = length(system.generatorstorages)

    if nregions > 1
        @warn "$simspec is a copper plate simulation method. " *
              "Transmission constraints between the system's $nregions " *
              "regions will be ignored in this assessment."
    end

    if nstors + ngenstors > 0
        resources = String[]
        nstors > 0 && push!(resources, "$nstors Storage")
        ngenstors > 0 && push!(resources, "$ngenstors GeneratorStorage")
        @warn "$simspec is a non-sequential simulation method. " *
              "The system's " * join(resources, " and ") * " resources " *
              "will be ignored in this assessment."
    end

    threads = nthreads()

    periods = Channel{Int}(2*threads)
    results = Channel{accumulatortype(simspec, resultspec, system)}(threads)

    @spawn makeperiods(periods, N)

    for _ in 1:nthreads() 
        @spawn assess(simspec, resultspec, system, periods, results)
    end

   return finalize(results, system, threads)

end

function makeperiods(periods::Channel{Int}, N::Int)
    for t in 1:N
        put!(periods, t)
    end
    close(periods)
end

function assess(
    simspec::Classic, resultspec::R, system::SystemModel{N,L,T,P,E},
    periods::Channel{Int}, results::Channel{<:ResultAccumulator{R}}
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit,R<:ResultSpec}

    acc = accumulator(simspec, resultspec, system)

    for t in periods

        # TODO: Deduplicate identical available capacity distributions?
        lolp, eul = assess(CapacityDistribution(system, t))
        eue = powertoenergy(E, eul, P, L, T)
        update!(acc, t, lolp, eue)

    end

    put!(results, acc)

end

include("result_minimal.jl")
include("result_temporal.jl")
