@testset "Convolution" begin
    simspec = Convolution(threaded=false)
    simspec_threaded = Convolution(threaded=true)
    resultspecs = (Shortfall(), Surplus())

    result_1a, surplus_1a = assess(TestSystems.singlenode_a, simspec, resultspecs...)

    @test LOLE(result_1a) ≈ LOLE{4, 1, Hour}(MeanEstimate(0.355))
    @test all(
        LOLE.(result_1a, result_1a.timestamps) .≈
        LOLE{1, 1, Hour}.(MeanEstimate.([0.028, 0.271, 0.028, 0.028])),
    )
    @test EUE(result_1a) ≈ EUE{4, 1, Hour, MWh}(MeanEstimate(1.59))
    @test all(
        EUE.(result_1a, result_1a.timestamps) .≈
        EUE{1, 1, Hour, MWh}.(MeanEstimate.([0.29, 0.832, 0.29, 0.178])),
    )

    result_1a5, surplus_1a5 = assess(TestSystems.singlenode_a_5min, simspec, resultspecs...)

    @test LOLE(result_1a5) ≈ LOLE{4, 5, Minute}(MeanEstimate(TestSystems.singlenode_a_lole))
    @test all(
        LOLE.(result_1a5, result_1a5.timestamps) .≈
        LOLE{1, 5, Minute}.(MeanEstimate.(TestSystems.singlenode_a_lolps)),
    )
    @test EUE(result_1a5) ≈
          EUE{4, 5, Minute, MWh}(MeanEstimate.(TestSystems.singlenode_a_eue / 12))
    @test all(
        EUE.(result_1a5, result_1a5.timestamps) .≈
        EUE{1, 5, Minute, MWh}.(MeanEstimate.(TestSystems.singlenode_a_eues ./ 12)),
    )

    result_1b, surplus_1b = assess(TestSystems.singlenode_b, simspec, resultspecs...)

    @test LOLE(result_1b) ≈ LOLE{6, 1, Hour}(MeanEstimate(0.96))
    @test all(
        LOLE.(result_1b, result_1b.timestamps) .≈
        LOLE{1, 1, Hour}.(MeanEstimate.([0.19, 0.19, 0.19, 0.1, 0.1, 0.19])),
    )
    @test EUE(result_1b) ≈ EUE{6, 1, Hour, MWh}(MeanEstimate(7.11))
    @test all(
        EUE.(result_1b, result_1b.timestamps) .≈
        EUE{1, 1, Hour, MWh}.(MeanEstimate.([1.29, 1.29, 1.29, 0.85, 1.05, 1.34])),
    )

    result_3, surplus_3 = assess(TestSystems.threenode, simspec, resultspecs...)

    @test LOLE(result_3) ≈ LOLE{4, 1, Hour}(MeanEstimate(1.17877))
    @test all(
        LOLE.(result_3, result_3.timestamps) .≈
        LOLE{1, 1, Hour}.(MeanEstimate.([0.14707, 0.40951, 0.21268, 0.40951])),
    )
    @test EUE(result_3) ≈ EUE{4, 1, Hour, MWh}(MeanEstimate(11.73276))
    @test all(
        EUE.(result_3, result_3.timestamps) .≈
        EUE{1, 1, Hour, MWh}.(MeanEstimate.([1.75783, 3.13343, 2.47954, 4.36196])),
    )

    # TODO: Surplus tests

    assess(TestSystems.singlenode_a, simspec_threaded, resultspecs...)
end
