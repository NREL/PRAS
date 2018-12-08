@testset "TemporalResult" begin

    tstamps = DateTime(2012,4,1,0):Hour(1):DateTime(2012,4,7,23)
    lolps = LOLP{1,Hour}.(rand(168)/10, rand(168)/100)
    lole = LOLE{168,1,Hour}(sum(val.(lolps)), sqrt(sum(stderr.(lolps).^2)))
    eues = EUE{1,1,Hour,MWh}.(rand(168), 0.)
    eue = EUE{168,1,Hour,MWh}(sum(val.(eues)), sqrt(sum(stderr.(eues).^2)))

    result = ResourceAdequacy.TemporalResult(
        tstamps, lole, lolps, eue, eues,
        Backcast(), NonSequentialCopperplate()
    )

    # Disallow metrics defined over different time periods
    @test_throws MethodError ResourceAdequacy.MinimalResult(
        tstamps, lole, lolps,
        EUE{168,30,Minute,MWh}(val(eue), stderr(eue)),
        EUE{1,30,Minute,MWh}.(val.(eues), stderr.(eues)),
        Backcast(), NonSequentialCopperplate()
    )

    # Metric constructors

    @test LOLE(result) == lole
    @test LOLP(result, tstamps[1]) == lolps[1]
    @test LOLP(result, 1) == lolps[1]

    @test EUE(result) == eue
    @test EUE(result, tstamps[1]) == eues[1]
    @test EUE(result, 1) == eues[1]

    @test_throws BoundsError LOLP(result, DateTime(2013,1,1,12))
    @test_throws BoundsError EUE(result, DateTime(2013,1,1,12))

end
