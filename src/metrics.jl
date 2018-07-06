abstract type ReliabilityMetric{V<:Real} end

include("metrics/lolp.jl")
include("metrics/lole.jl")
include("metrics/eue.jl")

# Common getter methods
for T in [LOLP, LOLE, EUE]
    @eval val(x::($T)) = x.val
    @eval stderr(x::($T)) = x.stderr
    @eval Base.isapprox(x::M, y::M) where {M<:($T)} =
        isapprox(x.val, y.val) &&
        isapprox(x.stderr, y.stderr)

end
