broadcastable(x::SimulationSpec) = Ref(x)

include("convolution/Convolution.jl")
include("sequentialmontecarlo/SequentialMonteCarlo.jl")
