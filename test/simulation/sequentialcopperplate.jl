@testset "SequentialCopperPlate" begin

    result_3mb = assess(Backcast(), SequentialCopperplate(100),
                        MinimalResult(), singlenode_multiperiod)
    @test_broken LOLE(result_3mb) ≈ LOLE{1,Hour}(0.1408, 0.)
    @test_broken EUE(result_3mb) ≈ EUE{1,Hour,MWh}(0.06, 0.)

end
