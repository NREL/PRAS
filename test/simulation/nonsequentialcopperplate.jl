@testset "NonSequentialCopperplate" begin

    simspec = NonSequentialCopperplate()

    # Overall result - singlenode_a
    result_1ab = assess(simspec, Minimal(), singlenode_a)
    @test LOLE(result_1ab) ≈ LOLE{4,1,Hour}(0.355, 0.)
    @test EUE(result_1ab) ≈ EUE{4,1,Hour,MWh}(1.59, 0.)

    result_1ab = assess(simspec, Spatial(), singlenode_a)
    @test LOLE(result_1ab) ≈ LOLE{4,1,Hour}(0.355, 0.)
    @test LOLE(result_1ab, "Region") ≈ LOLE{4,1,Hour}(0.355, 0.)
    @test EUE(result_1ab) ≈ EUE{4,1,Hour,MWh}(1.59, 0.)
    @test EUE(result_1ab, "Region") ≈ EUE{4,1,Hour,MWh}(1.59, 0.)

    # Hourly result - singlenode_a
    result_1ab = assess(simspec, Temporal(), singlenode_a)
    @test LOLE(result_1ab) ≈ LOLE{4,1,Hour}(0.355, 0.)
    @test all(LOLP.(result_1ab, singlenode_a.timestamps) .≈ # TODO: Update broadcasting syntax?
              LOLP{1,Hour}.([0.028, 0.271, 0.028, 0.028], zeros(4)))
    @test EUE(result_1ab) ≈ EUE{4,1,Hour,MWh}(1.59, 0.)
    @test all(EUE.(result_1ab, singlenode_a.timestamps) .≈
              EUE{1,1,Hour,MWh}.([0.29, 0.832, 0.29, 0.178], zeros(4)))

    result_1ab = assess(simspec, SpatioTemporal(), singlenode_a)
    @test LOLE(result_1ab) ≈ LOLE{4,1,Hour}(0.355, 0.)
    @test all(LOLP.(result_1ab, singlenode_a.timestamps) .≈
              LOLP{1,Hour}.([0.028, 0.271, 0.028, 0.028], zeros(4)))
    @test EUE(result_1ab) ≈ EUE{4,1,Hour,MWh}(1.59, 0.)
    @test all(EUE.(result_1ab, singlenode_a.timestamps) .≈
              EUE{1,1,Hour,MWh}.([0.29, 0.832, 0.29, 0.178], zeros(4)))

    # Overall result - singlenode_b
    result_1bb = assess(simspec, Minimal(), singlenode_b)
    @test LOLE(result_1bb) ≈ LOLE{6,1,Hour}(0.96, 0.)
    @test EUE(result_1bb) ≈ EUE{6,1,Hour,MWh}(7.11, 0.)

    result_1bb = assess(simspec, Spatial(), singlenode_b)
    @test LOLE(result_1bb) ≈ LOLE{6,1,Hour}(0.96, 0.)
    @test LOLE(result_1bb, "Region") ≈ LOLE{6,1,Hour}(0.96, 0.)
    @test EUE(result_1bb) ≈ EUE{6,1,Hour,MWh}(7.11, 0.)
    @test EUE(result_1bb, "Region") ≈ EUE{6,1,Hour,MWh}(7.11, 0.)

    # Hourly result - singlenode_b
    result_1bb = assess(simspec, Temporal(), singlenode_b)
    @test LOLE(result_1bb) ≈ LOLE{6,1,Hour}(0.96, 0.)
    @test all(LOLP.(result_1bb, singlenode_b.timestamps) .≈
              LOLP{1,Hour}.([0.19, 0.19, 0.19, 0.1, 0.1, 0.19], zeros(6)))
    @test EUE(result_1bb) ≈ EUE{6,1,Hour,MWh}(7.11, 0.)
    @test all(EUE.(result_1bb, singlenode_b.timestamps) .≈
              EUE{1,1,Hour,MWh}.([1.29, 1.29, 1.29, 0.85, 1.05, 1.34], zeros(6)))

    result_1bb = assess(simspec, SpatioTemporal(), singlenode_b)
    @test LOLE(result_1bb) ≈ LOLE{6,1,Hour}(0.96, 0.)
    @test all(LOLP.(result_1bb, singlenode_b.timestamps) .≈
              LOLP{1,Hour}.([0.19, 0.19, 0.19, 0.1, 0.1, 0.19], zeros(6)))
    @test EUE(result_1bb) ≈ EUE{6,1,Hour,MWh}(7.11, 0.)
    @test all(EUE.(result_1bb, singlenode_b.timestamps) .≈
              EUE{1,1,Hour,MWh}.([1.29, 1.29, 1.29, 0.85, 1.05, 1.34], zeros(6)))

    # Note: Not testing Spatial and SpatioTemporal here since the number
    #       of system regions is >1 but only 1 region of data is reported
    #       (Minimal and Temporal provide identical functionality at
    #       lower computational cost)

    # Overall result - threenode
    result_3b = assess(simspec, Minimal(), threenode)
    @test LOLE(result_3b) ≈ LOLE{4,1,Hour}(1.17877, 0.)
    @test EUE(result_3b) ≈ EUE{4,1,Hour,MWh}(11.73276, 0.)

    # Hourly result - threenode
    result_3b = assess(simspec, Temporal(), threenode)
    @test LOLE(result_3b) ≈ LOLE{4,1,Hour}(1.17877, 0.)
    @test all(LOLP.(result_3b, result_3b.timestamps) .≈
              LOLP{1,Hour}.([.14707, .40951, .21268, .40951], zeros(4)))
    @test EUE(result_3b) ≈ EUE{4,1,Hour,MWh}(11.73276, 0.)
    @test all(EUE.(result_3b, result_3b.timestamps) .≈
              EUE{1,1,Hour,MWh}.([1.75783, 3.13343, 2.47954, 4.36196], zeros(4)))

end
