@testset "MinimalResult" begin

    @testset "Single Period" begin

        lolp1 = LOLP{1,Hour}(.1, 0.)
        lolp2 = LOLP{2,Day}(.12, 0.04)
        eue1 = EUE{MWh,1,Hour}(1.2, 0.)

        # Single-period constructor
        singleresult = ResourceAdequacy.SinglePeriodMinimalResult{MW}(
            lolp1, eue1, NonSequentialCopperplate())

        # Disallow metrics defined over different time periods
        @test_throws MethodError ResourceAdequacy.SinglePeriodMinimalResult{MW}(
            lolp2, eue1, NonSequentialCopperplate())

        # Metric constructors
        @test LOLP(singleresult) == lolp1
        @test EUE(singleresult) == eue1

    end

    @testset "Multi Period" begin

        lolps = LOLP{1,Hour}.(rand(168)/10, rand(168)/100)
        eues = EUE{MWh,1,Hour}.(rand(168), 0.)

        # Multi-period constructor
        tstamps = collect(DateTime(2012,4,1):Hour(1):DateTime(2012,4,7, 23))
        multiresult = ResourceAdequacy.MultiPeriodMinimalResult(
            tstamps,
            ResourceAdequacy.SinglePeriodMinimalResult{MW}.(
                lolps, eues, NonSequentialNetworkFlow(1000)),
            Backcast(),
            NonSequentialNetworkFlow(1000)
        )

        # Disallow metrics defined over different time periods
        @test_throws MethodError ResourceAdequacy.MultiPeriodMinimalResult(
            tstamps,
            ResourceAdequacy.SinglePeriodMinimalResult.(
                lolps, EUE{MWh,30,Minute}.(rand(168), 0.),
                NonSequentialNetworkFlow(1000)),
            Backcast(),
            NonSequentialNetworkFlow(1000)
        )

        # Metric constructors
        @test LOLE(multiresult) ≈ LOLE(lolps)
        @test EUE(multiresult) ≈ EUE(eues)

        @test timestamps(multiresult) == tstamps
        @test multiresult[tstamps[1]] ==
            ResourceAdequacy.SinglePeriodMinimalResult{MW}(
                lolps[1], eues[1], multiresult.simulationspec)
        @test_throws BoundsError multiresult[DateTime(2013,1,1,12)]

    end

end
