@testset "SpatioTemporalResult" begin

    tstamps = ZonedDateTime(2012,4,1,0,tz):Hour(1):ZonedDateTime(2012,4,7,23,tz)
    regions = ["A", "B", "C"]

    periodlolps = LOLP{1,Hour}.(rand(168)/10, rand(168)/100)
    lole = LOLE{168,1,Hour}(sum(val.(periodlolps)), sqrt(sum(stderror.(periodlolps).^2)))
    regionalperiodlolps = LOLP{1,Hour}.(rand(3,168)/10, rand(3,168)/100)
    regionalloles = vec(LOLE{168,1,Hour}.(
        sum(val.(regionalperiodlolps), dims=2),
        sqrt.(sum(stderror.(regionalperiodlolps).^2, dims=2))))

    periodeues = EUE{1,1,Hour,MWh}.(rand(168), rand(168)/10)
    eue = EUE{168,1,Hour,MWh}(sum(val.(periodeues)), sqrt(sum(stderror.(periodeues).^2)))
    regionalperiodeues = EUE{1,1,Hour,MWh}.(rand(3,168)/10, rand(3,168)/100)
    regionaleues = vec(EUE{168,1,Hour,MWh}.(
        sum(val.(regionalperiodeues), dims=2),
        sqrt.(sum(stderror.(regionalperiodeues).^2, dims=2))))

    result = ResourceAdequacy.SpatioTemporalResult(
        regions, tstamps,
        lole, regionalloles, periodlolps, regionalperiodlolps,
        eue, regionaleues, periodeues, regionalperiodeues,
        SequentialMonteCarlo())

    # Disallow metrics defined over different time periods
    @test_throws MethodError ResourceAdequacy.SpatioTemporalResult(
        regions, tstamps,
        lole, regionalloles, periodlolps, regionalperiodlolps,
        EUE{168,30,Minute,MWh}(val(eue), stderror(eue)),
        EUE{168,30,Minute,MWh}.(val.(regionaleues), stderror.(regionaleues)),
        EUE{1,30,Minute,MWh}.(val.(periodeues), stderror.(periodeues)),
        EUE{1,30,Minute,MWh}.(val.(regionalperiodeues), stderror.(regionalperiodeues)),
        SequentialMonteCarlo()
    )

    # Metric constructors

    @test LOLE(result) == lole
    @test LOLE(result, regions[1]) == regionalloles[1]
    @test LOLP(result, tstamps[1]) == periodlolps[1]
    @test LOLP(result, regions[2], tstamps[1]) == regionalperiodlolps[2,1]

    @test EUE(result) == eue
    @test EUE(result, regions[1]) == regionaleues[1]
    @test EUE(result, tstamps[1]) == periodeues[1]
    @test EUE(result, regions[2], tstamps[1]) == regionalperiodeues[2,1]

    @test_throws BoundsError LOLP(result, ZonedDateTime(2013,1,1,12,tz))
    @test_throws BoundsError EUE(result, ZonedDateTime(2013,1,1,12,tz))
    @test_throws BoundsError LOLE(result, "NotARegion")
    @test_throws BoundsError EUE(result, "NotARegion")

end
