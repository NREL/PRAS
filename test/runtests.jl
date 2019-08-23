using Test
using PRASBase
using ResourceAdequacy
using Distributions

const RA = ResourceAdequacy

withinrange(x::RA.ReliabilityMetric, y::Real, n::Real) =
    isapprox(val(x), y, atol=n*stderror(x))

Base.isapprox(x::DiscreteNonParametric, y::DiscreteNonParametric) =
    isapprox(support(x), support(y)) && isapprox(probs(x), probs(y))

@testset "ResourceAdequacy" begin

    include("utils.jl")
    include("metrics.jl")
    include("results.jl")
    include("systems.jl")
    include("systemdata.jl")
    include("simulation.jl")

end
