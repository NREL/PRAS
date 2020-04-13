using Dates
using Distributions
using PRAS
using Test
using TimeZones

withinrange(x::ReliabilityMetric, y::Real, n::Real) =
    isapprox(val(x), y, atol=n*stderror(x))

Base.isapprox(x::DiscreteNonParametric, y::DiscreteNonParametric) =
    isapprox(support(x), support(y)) && isapprox(probs(x), probs(y))

tz = tz"UTC"

@testset "PRAS" begin
    include("PRASBase/runtests.jl")
    include("testsystems.jl")
    include("ResourceAdequacy/runtests.jl")
    include("CapacityCredit/runtests.jl")
end
