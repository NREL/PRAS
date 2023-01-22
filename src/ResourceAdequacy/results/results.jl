broadcastable(x::ResultSpec) = Ref(x)
broadcastable(x::Result) = Ref(x)

include("shortfall.jl")
include("surplus.jl")
include("flow.jl")
include("utilization.jl")
include("availability.jl")
include("energy.jl")

include("utils.jl")

function resultchannel(
    method::SimulationSpec, results::T, threads::Int
) where T <: Tuple{Vararg{ResultSpec}}

    types = accumulatortype.(method, results)
    return Channel{Tuple{types...}}(threads)

end

merge!(xs::T, ys::T) where T <: Tuple{Vararg{ResultAccumulator}} =
    foreach(merge!, xs, ys)

function finalize(
    results::Channel{<:Tuple{Vararg{ResultAccumulator}}},
    system::SystemModel{N,L,T,P,E},
    threads::Int
) where {N,L,T,P,E}

    total_result = take!(results)

    for _ in 2:threads
        thread_result = take!(results)
        merge!(total_result, thread_result)
    end
    close(results)

    return finalize.(total_result, system)

end
