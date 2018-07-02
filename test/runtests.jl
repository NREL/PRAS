using ResourceAdequacy
using Base.Test
using Distributions

@testset "ResourceAdequacy" begin

    include("metrics.jl")
    include("results.jl")

    include("systems.jl")
    include("reliabilityassessment.jl")

end
