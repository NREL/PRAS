abstract type ReliabilityMetric{V<:Real} end

include("metrics/lolp.jl")
include("metrics/lole.jl")
include("metrics/eue.jl")

# Common getter methods
for T in [LOLP, LOLE, EUE]
    @eval val(x::($T)) = x.val
    @eval stderr(x::($T)) = x.stderr
end
