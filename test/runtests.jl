using Dates
using Distributions
using PRAS
using StatsBase
using Test
using TimeZones

import PRAS.ResourceAdequacy: MeanEstimate

withinrange(x::ReliabilityMetric, y::Real, n::Real) =
    isapprox(val(x), y, atol=n*stderror(x))

withinrange(x::Tuple{<:Real, <:Real}, y::Real, nsamples::Int, n::Real) =
    isapprox(first(x), y, atol=n*last(x)/sqrt(nsamples))

Base.isapprox(x::T, y::T) where {T <: Tuple} = all(isapprox.(x, y))

Base.isapprox(x::T, y::T) where {T <: ReliabilityMetric} =
    isapprox(val(x), val(y)) && isapprox(stderror(x), stderror(y))

Base.isapprox(x::Tuple{Float64,Float64}, y::Vector{<:Real}) =
    isapprox(x[1], mean(y)) && isapprox(x[2], std(y))

@testset "PRAS" begin
    include("PRASBase/runtests.jl")
    include("testsystems.jl")
    include("dummydata.jl")
    include("ResourceAdequacy/runtests.jl")
    include("CapacityCredit/runtests.jl")
end
