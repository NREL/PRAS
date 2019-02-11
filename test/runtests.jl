using Test
using ResourceAdequacy
using Dates
using Distributions

const RA = ResourceAdequacy

withinrange(x::RA.ReliabilityMetric, y::Real, n::Real) =
    isapprox(val(x), y, atol=n*stderror(x))

@testset "ResourceAdequacy" begin

    include("utils.jl")
    include("metrics.jl")
    include("results.jl")
    include("systems.jl")
    include("extraction.jl")
    include("simulation.jl")

end
