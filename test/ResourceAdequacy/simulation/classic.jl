@testset "Classic" begin

    simspec = Classic()

    @testset "Minimal Result" begin

        # Overall result - singlenode_a
        result_1ab = assess(simspec, Minimal(), singlenode_a)
        @test LOLE(result_1ab) ≈ LOLE{4,1,Hour}(0.355, 0.)
        @test EUE(result_1ab) ≈ EUE{4,1,Hour,MWh}(1.59, 0.)

        # Overall result - singlenode_a_5min
        result_1a5 = assess(simspec, Minimal(), singlenode_a_5min)
        @test LOLE(result_1a5) ≈ LOLE{4,5,Minute}(singlenode_a_lole, 0.)
        @test EUE(result_1a5) ≈ EUE{4,5,Minute,MWh}(singlenode_a_eue/12, 0.)

        # Overall result - singlenode_b
        result_1bb = assess(simspec, Minimal(), singlenode_b)
        @test LOLE(result_1bb) ≈ LOLE{6,1,Hour}(0.96, 0.)
        @test EUE(result_1bb) ≈ EUE{6,1,Hour,MWh}(7.11, 0.)

        # Overall result - threenode
        result_3b = assess(simspec, Minimal(), threenode)
        @test LOLE(result_3b) ≈ LOLE{4,1,Hour}(1.17877, 0.)
        @test EUE(result_3b) ≈ EUE{4,1,Hour,MWh}(11.73276, 0.)

    end

    @testset "Temporal Result" begin

        # Hourly result - singlenode_a
        result_1ab = assess(simspec, Temporal(), singlenode_a)
        @test LOLE(result_1ab) ≈ LOLE{4,1,Hour}(0.355, 0.)
        @test all(LOLP.(result_1ab, singlenode_a.timestamps) .≈ # TODO: Update broadcasting syntax?
                  LOLP{1,Hour}.([0.028, 0.271, 0.028, 0.028], zeros(4)))
        @test EUE(result_1ab) ≈ EUE{4,1,Hour,MWh}(1.59, 0.)
        @test all(EUE.(result_1ab, singlenode_a.timestamps) .≈
                  EUE{1,1,Hour,MWh}.([0.29, 0.832, 0.29, 0.178], zeros(4)))

        # Hourly result - singlenode_a_5min
        result_1a5 = assess(simspec, Temporal(), singlenode_a_5min)
        @test LOLE(result_1a5) ≈ LOLE{4,5,Minute}(singlenode_a_lole, 0.)
        @test all(LOLP.(result_1a5, singlenode_a_5min.timestamps) .≈
                  LOLP{5,Minute}.(singlenode_a_lolps, zeros(4)))
        @test EUE(result_1a5) ≈ EUE{4,5,Minute,MWh}(singlenode_a_eue/12, 0.)
        @test all(EUE.(result_1a5, singlenode_a_5min.timestamps) .≈
                  EUE{1,5,Minute,MWh}.(singlenode_a_eues ./ 12, zeros(4)))

        # Hourly result - singlenode_b
        result_1bb = assess(simspec, Temporal(), singlenode_b)
        @test LOLE(result_1bb) ≈ LOLE{6,1,Hour}(0.96, 0.)
        @test all(LOLP.(result_1bb, singlenode_b.timestamps) .≈
                  LOLP{1,Hour}.([0.19, 0.19, 0.19, 0.1, 0.1, 0.19], zeros(6)))
        @test EUE(result_1bb) ≈ EUE{6,1,Hour,MWh}(7.11, 0.)
        @test all(EUE.(result_1bb, singlenode_b.timestamps) .≈
                  EUE{1,1,Hour,MWh}.([1.29, 1.29, 1.29, 0.85, 1.05, 1.34], zeros(6)))

        # Hourly result - threenode
        result_3b = assess(simspec, Temporal(), threenode)
        @test LOLE(result_3b) ≈ LOLE{4,1,Hour}(1.17877, 0.)
        @test all(LOLP.(result_3b, result_3b.timestamps) .≈
                  LOLP{1,Hour}.([.14707, .40951, .21268, .40951], zeros(4)))
        @test EUE(result_3b) ≈ EUE{4,1,Hour,MWh}(11.73276, 0.)
        @test all(EUE.(result_3b, result_3b.timestamps) .≈
                  EUE{1,1,Hour,MWh}.([1.75783, 3.13343, 2.47954, 4.36196], zeros(4)))

    end

end
