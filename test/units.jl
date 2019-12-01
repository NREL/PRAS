@testset "Units and Conversions" begin

    @test powertoenergy(10, MW, 2, Hour, MWh) == 20
    @test powertoenergy(10, MW, 30, Minute, MWh) == 5

    @test energytopower(100, MWh, 10, Hour, MW) == 10
    @test energytopower(100, MWh, 30, Minute, MW) == 200

end
