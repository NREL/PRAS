include("conv.jl")

struct Convolution <: SimulationSpec

    verbose::Bool
    threaded::Bool

    Convolution(;verbose::Bool=false, threaded::Bool=true) =
        new(verbose, threaded)

end

function assess(
    system::SystemModel{N},
    method::Convolution,
    resultspecs::ResultSpec...
) where {N}

    nregions = length(system.regions)
    nstors = length(system.storages)
    ngenstors = length(system.generatorstorages)

    if nregions > 1
        @warn "$method is a copper plate simulation method. " *
              "Transmission constraints between the system's $nregions " *
              "regions will be ignored in this assessment."
    end

    if nstors + ngenstors > 0
        resources = String[]
        nstors > 0 && push!(resources, "$nstors Storage")
        ngenstors > 0 && push!(resources, "$ngenstors GeneratorStorage")
        @warn "$method is a non-sequential simulation method. " *
              "The system's " * join(resources, " and ") * " resources " *
              "will be ignored in this assessment."
    end

    threads = nthreads()
    periods = Channel{Int}(2*threads)
    results = resultchannel(method, resultspecs, threads)

    @spawn makeperiods(periods, N)

    if method.threaded
        for _ in 1:threads
            @spawn assess(system, method, periods, results, resultspecs...)
        end
    else
        assess(system, method, periods, results, resultspecs...)
    end

    return finalize(results, system, method.threaded ? threads : 1)

end

function makeperiods(periods::Channel{Int}, N::Int)
    for t in 1:N
        put!(periods, t)
    end
    close(periods)
end

function assess(
    system::SystemModel{N,L,T,P,E}, method::Convolution,
    periods::Channel{Int},
    results::Channel{<:Tuple{Vararg{ResultAccumulator{Convolution}}}},
    resultspecs::ResultSpec...
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    accs = accumulator.(system, method, resultspecs)

    for t in periods

        distr = CapacityDistribution(system, t)
        foreach(acc -> record!(acc, t, distr), accs)

    end

    put!(results, accs)

end

include("result_shortfall.jl")
include("result_surplus.jl")
