@testset "Units and Conversions" begin

    @test powertoenergy(MWh, 10, MW, 2, Hour) == 20
    @test powertoenergy(MWh, 10, MW, 30, Minute) == 5

    @test energytopower(MW, 100, MWh, 10, Hour) == 10
    @test energytopower(MW, 100, MWh, 30, Minute) == 200

end
