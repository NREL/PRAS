@testset "TemporalResult" begin

    tstamps = ZonedDateTime(2012,4,1,0,tz):Hour(1):ZonedDateTime(2012,4,7,23,tz)
    lolps = LOLP{1,Hour}.(rand(168)/10, rand(168)/100)
    lole = LOLE{168,1,Hour}(sum(val.(lolps)), sqrt(sum(stderror.(lolps).^2)))
    eues = EUE{1,1,Hour,MWh}.(rand(168), 0.)
    eue = EUE{168,1,Hour,MWh}(sum(val.(eues)), sqrt(sum(stderror.(eues).^2)))

    result = ResourceAdequacy.TemporalResult(
        tstamps, lole, lolps, eue, eues,
        Convolution()
    )

    # Disallow metrics defined over different time periods
    @test_throws MethodError ResourceAdequacy.TemporalResult(
        tstamps, lole, lolps,
        EUE{168,30,Minute,MWh}(val(eue), stderror(eue)),
        EUE{1,30,Minute,MWh}.(val.(eues), stderror.(eues)),
        Convolution()
    )

    # Metric constructors

    @test LOLE(result) == lole
    @test LOLP(result, tstamps[1]) == lolps[1]
    @test LOLP(result, 1) == lolps[1]

    @test EUE(result) == eue
    @test EUE(result, tstamps[1]) == eues[1]
    @test EUE(result, 1) == eues[1]

    @test_throws BoundsError LOLP(result, ZonedDateTime(2013,1,1,12,tz))
    @test_throws BoundsError EUE(result, ZonedDateTime(2013,1,1,12,tz))

end
