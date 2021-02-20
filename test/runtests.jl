using Dates
using Distributions
using PRAS
using Test
using TimeZones

import PRAS.ResourceAdequacy: MeanEstimate

withinrange(x::ReliabilityMetric, y::Real, n::Real) =
    isapprox(val(x), y, atol=n*stderror(x))

Base.isapprox(x::DiscreteNonParametric, y::DiscreteNonParametric) =
    isapprox(support(x), support(y)) && isapprox(probs(x), probs(y))

Base.isapprox(x::T, y::T) where {T <: Tuple} = all(isapprox.(x, y))

@testset "PRAS" begin
    include("PRASBase/runtests.jl")
    include("testsystems.jl")
    include("dummydata.jl")
    include("ResourceAdequacy/runtests.jl")
    include("CapacityCredit/runtests.jl")
end
