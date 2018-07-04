@testset "NonSequentialCopperPlate" begin

    result_1a = assess(NonSequentialCopperplate(), MinimalResult(), singlenode_a)
    @test LOLP(result_1a) ≈ LOLP{1,Hour}(0.06, 0.)
    @test_broken EUE(result_1a) ≈ EUE{1,Hour,MWh}(0.06, 0.)

    result_1b = assess(NonSequentialCopperplate(), MinimalResult(), singlenode_b)
    @test LOLP(result_1b) ≈ LOLP{1,Hour}(1e-5, 0.)
    @test_broken EUE(result_1b) ≈ EUE{1,Hour,MWh}(0.06, 0.)

    result_3a = assess(NonSequentialCopperplate(), MinimalResult(), threenode_a)
    @test LOLP(result_3a) ≈ LOLP{1,Hour}(0.1408, 0.)
    @test_broken EUE(result_3a) ≈ EUE{1,Hour,MWh}(0.06, 0.)

    result_3b = assess(NonSequentialCopperplate(), MinimalResult(), threenode_b)
    @test_broken LOLP(result_3b) ≈ LOLP{1,Hour}(0.1408, 0.)
    @test_broken EUE(result_3b) ≈ EUE{1,Hour,MWh}(0.06, 0.)


    result_3mb = assess(Backcast(), NonSequentialCopperplate(),
                        MinimalResult(), threenode_multiperiod)
    @test_broken LOLE(result_3mb) ≈ LOLE{1,Hour}(0.1408, 0.)
    @test_broken EUE(result_3mb) ≈ EUE{1,Hour,MWh}(0.06, 0.)

    result_3mr = assess(REPRA(1,1), NonSequentialCopperplate(),
                        MinimalResult(), threenode_multiperiod)
    @test_broken LOLE(result_3mr) ≈ LOLE{1,Hour}(0.1408, 0.)
    @test_broken EUE(result_3mr) ≈ EUE{1,Hour,MWh}(0.06, 0.)

end
