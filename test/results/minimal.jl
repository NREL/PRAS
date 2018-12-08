@testset "MinimalResult" begin

    lole1 = LOLE{1,1,Hour}(.1, 0.)
    lole2 = LOLE{2,1,Day}(.12, 0.04)
    eue1 = EUE{1,1,Hour,MWh}(1.2, 0.)

    # Single-period constructor
    singleresult = ResourceAdequacy.MinimalResult(
        lole1, eue1, Backcast(), NonSequentialCopperplate())

    # Disallow metrics defined over different time periods
    @test_throws MethodError ResourceAdequacy.MinimalResult(
        lole2, eue1, Backcast(), NonSequentialCopperplate())

    # Metric constructors
    @test LOLE(singleresult) == lole1
    @test EUE(singleresult) == eue1

end
