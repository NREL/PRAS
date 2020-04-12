broadcastable(x::Result) = Ref(x)

include("minimal.jl")
include("temporal.jl")
include("spatiotemporal.jl")
include("network.jl")
