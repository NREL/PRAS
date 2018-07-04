using ResourceAdequacy
using Base.Test
using Distributions

@testset "ResourceAdequacy" begin

    include("utils.jl")
    include("metrics.jl")
    include("results.jl")
    include("systems.jl")
    include("extraction.jl")
    include("simulation.jl")

end
