@testset "Simulation" begin

    include("simulation/nonsequentialcopperplate.jl")
    include("simulation/sequentialcopperplate.jl")
    include("simulation/nonsequentialnetworkflow.jl")
    include("simulation/sequentialnetworkflow.jl")

end
