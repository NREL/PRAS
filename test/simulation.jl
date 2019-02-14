@testset "Simulation" begin

    include("simulation/nonsequentialcopperplate.jl")
    include("simulation/sequentialcopperplate.jl")
    include("simulation/nonsequentialnetworkflow.jl")

end
