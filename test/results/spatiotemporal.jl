@testset "SpatioTemporalResult" begin

    tstamps = DateTime(2012,4,1,0):Hour(1):DateTime(2012,4,7,23)
    regions = ["A", "B", "C"]

    periodlolps = LOLP{1,Hour}.(rand(168)/10, rand(168)/100)
    lole = LOLE{168,1,Hour}(sum(val.(periodlolps)), sqrt(sum(stderr.(periodlolps).^2)))
    regionalperiodlolps = LOLP{1,Hour}.(rand(3,168)/10, rand(3,168)/100)
    regionalloles = vec(LOLE{168,1,Hour}.(
        sum(val.(regionalperiodlolps), dims=2),
        sqrt.(sum(stderr.(regionalperiodlolps).^2, dims=2))))

    periodeues = EUE{1,1,Hour,MWh}.(rand(168), rand(168)/10)
    eue = EUE{168,1,Hour,MWh}(sum(val.(periodeues)), sqrt(sum(stderr.(periodeues).^2)))
    regionalperiodeues = EUE{1,1,Hour,MWh}.(rand(3,168)/10, rand(3,168)/100)
    regionaleues = vec(EUE{168,1,Hour,MWh}.(
        sum(val.(regionalperiodeues), dims=2),
        sqrt.(sum(stderr.(regionalperiodeues).^2, dims=2))))

    result = ResourceAdequacy.SpatioTemporalResult(
        regions, tstamps,
        lole, regionalloles, periodlolps, regionalperiodlolps,
        eue, regionaleues, periodeues, regionalperiodeues,
        Backcast(), NonSequentialCopperplate())

    # Disallow metrics defined over different time periods
    @test_throws MethodError ResourceAdequacy.SpatioTemporalResult(
        regions, tstamps,
        lole, regionalloles, periodlolps, regionalperiodlolps,
        EUE{168,30,Minute,MWh}(val(eue), stderr(eue)),
        EUE{168,30,Minute,MWh}.(val.(regionaleues), stderr.(regionaleues)),
        EUE{1,30,Minute,MWh}.(val.(periodeues), stderr.(periodeues)),
        EUE{1,30,Minute,MWh}.(val.(regionalperiodeues), stderr.(regionalperiodeues)),
        Backcast(), NonSequentialCopperplate()
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

    @test_throws BoundsError LOLP(result, DateTime(2013,1,1,12))
    @test_throws BoundsError EUE(result, DateTime(2013,1,1,12))
    @test_throws BoundsError LOLE(result, "NotARegion")
    @test_throws BoundsError EUE(result, "NotARegion")

end
