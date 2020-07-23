@testset "DebugResult" begin

    tstamps = ZonedDateTime(2012,4,1,0,tz):Hour(1):ZonedDateTime(2012,4,7,23,tz)
    regions = ["A", "B", "C"]
    interfaces = [(1,2), (2,3)]

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

    interfaceflows = ExpectedInterfaceFlow{1,1,Hour,MW}.(
        100*randn(2,168), rand(2,168))
    interfaceutilizations = ExpectedInterfaceUtilization{1,1,Hour}.(
        rand(2,168), rand(2,168)./100)

    gens_available = lines_available = stors_available = genstors_available =
        zeros(Bool, 0, 0, 0)

    sample_ues = zeros(Int, 0)

    result = ResourceAdequacy.DebugResult(
        regions, interfaces, tstamps,
        lole, regionalloles, periodlolps, regionalperiodlolps,
        eue, regionaleues, periodeues, regionalperiodeues,
        interfaceflows, interfaceutilizations, gens_available,
        lines_available, stors_available, genstors_available,
        sample_ues, SequentialMonteCarlo())

    # Disallow metrics defined over different time periods
    @test_throws MethodError ResourceAdequacy.DebugResult(
        regions, tstamps,
        lole, regionalloles, periodlolps, regionalperiodlolps,
        EUE{168,30,Minute,MWh}(val(eue), stderror(eue)),
        EUE{168,30,Minute,MWh}.(val.(regionaleues), stderror.(regionaleues)),
        EUE{1,30,Minute,MWh}.(val.(periodeues), stderror.(periodeues)),
        EUE{1,30,Minute,MWh}.(val.(regionalperiodeues), stderror.(regionalperiodeues)),
        ExpectedInterfaceFlow{1,30,Minute,MW}.(
            val.(interfaceflows), stderror.(interfaceflows)),
        ExpectedInterfaceUtilization{1,30,Minute}.(
            val.(interfaceutilizations), stderror.(interfaceutilizations)),
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

    @test ExpectedInterfaceFlow(result, regions[1], regions[2], tstamps[1]) == interfaceflows[1,1]
    @test ExpectedInterfaceFlow(result, regions[2], regions[1], tstamps[1]) == -interfaceflows[1,1]
    @test ExpectedInterfaceFlow(result, regions[2], regions[3], tstamps[4]) == interfaceflows[2,4]
    @test ExpectedInterfaceFlow(result, regions[3], regions[2], tstamps[12]) == -interfaceflows[2,12]

    @test ExpectedInterfaceUtilization(result, regions[1], regions[2], tstamps[1]) == interfaceutilizations[1,1]
    @test ExpectedInterfaceUtilization(result, regions[2], regions[1], tstamps[1]) == interfaceutilizations[1,1]
    @test ExpectedInterfaceUtilization(result, regions[2], regions[3], tstamps[4]) == interfaceutilizations[2,4]
    @test ExpectedInterfaceUtilization(result, regions[3], regions[2], tstamps[12]) == interfaceutilizations[2,12]

    @test_throws BoundsError LOLP(result, ZonedDateTime(2013,1,1,12,tz))
    @test_throws BoundsError EUE(result, ZonedDateTime(2013,1,1,12,tz))
    @test_throws BoundsError LOLE(result, "NotARegion")
    @test_throws BoundsError EUE(result, "NotARegion")
    @test_throws BoundsError ExpectedInterfaceFlow(result, regions[1], regions[3], tstamps[1])
    @test_throws BoundsError ExpectedInterfaceFlow(result, regions[1], "NotARegion", tstamps[1])
    @test_throws BoundsError ExpectedInterfaceFlow(result, "A", "B", ZonedDateTime(2013,1,1,12,tz))
    @test_throws BoundsError ExpectedInterfaceUtilization(result, regions[1], regions[3], tstamps[1])
    @test_throws BoundsError ExpectedInterfaceUtilization(result, regions[1], "NotARegion", tstamps[1])
    @test_throws BoundsError ExpectedInterfaceUtilization(result, "A", "B", ZonedDateTime(2013,1,1,12,tz))

end
