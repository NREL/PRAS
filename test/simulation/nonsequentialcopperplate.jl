@testset "NonSequentialCopperplate" begin

    # Overall result - singlenode_a
    result_1ab = assess(Backcast(), NonSequentialCopperplate(), Minimal(), singlenode_a)
    @test LOLE(result_1ab) ≈ LOLE{4,1,Hour}(0.355, 0.)
    @test EUE(result_1ab) ≈ EUE{4,1,Hour,MWh}(1.59, 0.)

    result_1ab = assess(Backcast(), NonSequentialCopperplate(), Spatial(), singlenode_a)
    @test LOLE(result_1ab) ≈ LOLE{4,1,Hour}(0.355, 0.)
    @test LOLE(result_1ab, "Region") ≈ LOLE{4,1,Hour}(0.355, 0.)
    @test EUE(result_1ab) ≈ EUE{4,1,Hour,MWh}(1.59, 0.)
    @test EUE(result_1ab, "Region") ≈ EUE{4,1,Hour,MWh}(1.59, 0.)

    # Hourly result - singlenode_a
    result_1ab = assess(Backcast(), NonSequentialCopperplate(), Temporal(), singlenode_a)
    @test LOLE(result_1ab) ≈ LOLE{4,1,Hour}(0.355, 0.)
    @test all(LOLP.(result_1ab, singlenode_a.timestamps) .≈
              LOLP{1,Hour}.([0.028, 0.271, 0.028, 0.028], zeros(4)))
    @test EUE(result_1ab) ≈ EUE{4,1,Hour,MWh}(1.59, 0.)
    @test all(EUE.(result_1ab, singlenode_a.timestamps) .≈
              EUE{1,1,Hour,MWh}.([0.29, 0.832, 0.29, 0.178], zeros(4)))

    # Overall result - singlenode_b
    result_1bb = assess(Backcast(), NonSequentialCopperplate(), Minimal(), singlenode_b)
    @test LOLE(result_1bb) ≈ LOLE{6,1,Hour}(0.96, 0.)
    @test EUE(result_1bb) ≈ EUE{6,1,Hour,MWh}(7.11, 0.)

    result_1bb = assess(Backcast(), NonSequentialCopperplate(), Spatial(), singlenode_b)
    @test LOLE(result_1bb) ≈ LOLE{6,1,Hour}(0.96, 0.)
    @test LOLE(result_1bb, "Region") ≈ LOLE{6,1,Hour}(0.96, 0.)
    @test EUE(result_1bb) ≈ EUE{6,1,Hour,MWh}(7.11, 0.)
    @test EUE(result_1bb, "Region") ≈ EUE{6,1,Hour,MWh}(7.11, 0.)

    # Hourly result - singlenode_b
    result_1bb = assess(Backcast(), NonSequentialCopperplate(), Temporal(), singlenode_b)
    @test LOLE(result_1bb) ≈ LOLE{6,1,Hour}(0.96, 0.)
    @test all(LOLP.(result_1bb, singlenode_b.timestamps) .≈
              LOLP{1,Hour}.([0.19, 0.19, 0.19, 0.1, 0.1, 0.19], zeros(6)))
    @test EUE(result_1bb) ≈ EUE{6,1,Hour,MWh}(7.11, 0.)
    @test all(EUE.(result_1bb, singlenode_b.timestamps) .≈
              EUE{1,1,Hour,MWh}.([1.29, 1.29, 1.29, 0.85, 1.05, 1.34], zeros(6)))

    # Overall result - threenode
    result_3b = assess(Backcast(), NonSequentialCopperplate(),
                       Minimal(), threenode)
    @test LOLE(result_3b) ≈ LOLE{4,1,Hour}(1.17877, 0.)
    @test EUE(result_3b) ≈ EUE{4,1,Hour,MWh}(11.73276, 0.)

    # Hourly result - threenode
    result_3b = assess(Backcast(), NonSequentialCopperplate(),
                       Temporal(), threenode)
    @test LOLE(result_3b) ≈ LOLE{4,1,Hour}(1.17877, 0.)
    @test all(LOLP.(result_3b, result_3b.timestamps) .≈
              LOLP{1,Hour}.([.14707, .40951, .21268, .40951], zeros(4)))
    @test EUE(result_3b) ≈ EUE{4,1,Hour,MWh}(11.73276, 0.)
    @test all(EUE.(result_3b, result_3b.timestamps) .≈
              EUE{1,1,Hour,MWh}.([1.75783, 3.13343, 2.47954, 4.36196], zeros(4)))


    # TODO: Check REPRA results by hand

    result_1ar = assess(REPRA(1,1), NonSequentialCopperplate(), Minimal(), singlenode_a)
    @test_broken LOLE(result_1ar) ≈ LOLE{4,1,Hour}(0.06, 0.)
    @test_broken EUE(result_1ar) ≈ EUE{4,1,Hour,MWh}(0.06, 0.)

    result_1br = assess(REPRA(1,1), NonSequentialCopperplate(), Minimal(), singlenode_b)
    @test_broken LOLE(result_1br) ≈ LOLE{6,1,Hour}(1e-5, 0.)
    @test_broken EUE(result_1br) ≈ EUE{6,1,Hour,MWh}(0.06, 0.)

    result_3r = assess(REPRA(1,1), NonSequentialCopperplate(), Minimal(), threenode)
    @test_broken LOLE(result_3r) ≈ LOLE{4,1,Hour}(0.1408, 0.)
    @test_broken EUE(result_3r) ≈ EUE{4,1,Hour,MWh}(0.06, 0.)

end
