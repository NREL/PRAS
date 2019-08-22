@testset "SpatialResult" begin

    regions = ["A", "B", "C"]
    nregions = length(regions)

    lole = LOLE{168,1,Hour}(rand()*1.68, rand()*0.168)
    loles = LOLE{168,1,Hour}.(rand(nregions)*1.68, rand(nregions)*0.168)
    eues = EUE{168,1,Hour,MWh}.(rand(nregions), rand(nregions)/10)
    eue = EUE{168,1,Hour,MWh}(sum(val.(eues)), sqrt(sum(stderror.(eues).^2)))

    result = ResourceAdequacy.SpatialResult(
        regions, lole, loles, eue, eues,
        NonSequentialCopperplate()
    )

    # Disallow metrics defined over different time periods
    @test_throws MethodError ResourceAdequacy.SpatialResult(
        regions, lole, loles,
        EUE{168,30,Minute,MWh}(val(eue), stderror(eue)),
        EUE{168,30,Minute,MWh}.(val.(eues), stderror.(eues)),
        NonSequentialCopperplate()
    )

    # Metric constructors

    @test LOLE(result) == lole
    @test LOLE(result, regions[1]) == loles[1]
    @test LOLE(result, 1) == loles[1]

    @test EUE(result) == eue
    @test EUE(result, regions[1]) == eues[1]
    @test EUE(result, 1) == eues[1]

    @test_throws BoundsError LOLE(result, "NotARegion")
    @test_throws BoundsError EUE(result, "NotARegion")

end
