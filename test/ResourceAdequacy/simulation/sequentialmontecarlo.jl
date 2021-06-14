@testset "SequentialMonteCarlo" begin

    @testset "DispatchProblem" begin

    end

    nstderr_tol = 3

    simspec = SequentialMonteCarlo(samples=100_000, seed=1, threaded=false)
    smallsample = SequentialMonteCarlo(samples=10, seed=123)

    resultspecs = (Shortfall(), Surplus(), Flow(), Utilization(),
                   ShortfallSamples(), SurplusSamples(),
                   FlowSamples(), UtilizationSamples(),
                   GeneratorAvailability())

    timestampcol_a = collect(TestSystems.singlenode_a.timestamps)
    timestampcol_a5 = collect(TestSystems.singlenode_a_5min.timestamps)
    timestampcol_b = collect(TestSystems.singlenode_b.timestamps)
    timestampcol_3 = collect(TestSystems.threenode.timestamps)
    regionsrow = reshape(TestSystems.threenode.regions.names, 1, :)

    assess(TestSystems.singlenode_a, smallsample, resultspecs...)
    shortfall_1a, _, flow_1a, util_1a,
    shortfall2_1a, _, flow2_1a, util2_1a, _ =
        assess(TestSystems.singlenode_a, simspec, resultspecs...)

    assess(TestSystems.singlenode_a_5min, smallsample, resultspecs...)
    shortfall_1a5, _, flow_1a5, util_1a5,
    shortfall2_1a5, _, flow2_1a5, util2_1a5, _ =
        assess(TestSystems.singlenode_a_5min, simspec, resultspecs...)

    assess(TestSystems.singlenode_b, smallsample, resultspecs...)
    shortfall_1b, _, flow_1b, util_1b,
    shortfall2_1b, _, flow2_1b, util2_1b, _ =
        assess(TestSystems.singlenode_b, simspec, resultspecs...)

    assess(TestSystems.threenode, smallsample, resultspecs...)
    shortfall_3, _, flow_3, util_3,
    shortfall2_3, _, flow2_3, util2_3, _ =
        assess(TestSystems.threenode, simspec, resultspecs...)

    @testset "Shortfall Results" begin

        # Single-region system A

        @test LOLE(shortfall_1a) ≈ LOLE(shortfall2_1a)
        @test EUE(shortfall_1a) ≈ EUE(shortfall2_1a)
        @test LOLE(shortfall_1a, "Region") ≈ LOLE(shortfall2_1a, "Region")
        @test EUE(shortfall_1a, "Region") ≈ EUE(shortfall2_1a, "Region")

        @test withinrange(LOLE(shortfall_1a),
                          TestSystems.singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1a),
                          TestSystems.singlenode_a_eue, nstderr_tol)
        @test withinrange(LOLE(shortfall_1a, "Region"),
                          TestSystems.singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1a, "Region"),
                          TestSystems.singlenode_a_eue, nstderr_tol)

        @test all(LOLE.(shortfall_1a, timestampcol_a) .≈
              LOLE.(shortfall2_1a, timestampcol_a))
        @test all(EUE.(shortfall_1a, timestampcol_a) .≈
              EUE.(shortfall2_1a, timestampcol_a))
        @test all(LOLE.(shortfall_1a, "Region", timestampcol_a) .≈
              LOLE.(shortfall2_1a, "Region", timestampcol_a))
        @test all(EUE.(shortfall_1a, "Region", timestampcol_a) .≈
              EUE.(shortfall2_1a, "Region", timestampcol_a))

        @test all(withinrange.(LOLE.(shortfall_1a, timestampcol_a),
                               TestSystems.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1a, timestampcol_a),
                               TestSystems.singlenode_a_eues, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall_1a, "Region", timestampcol_a),
                               TestSystems.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1a, "Region", timestampcol_a),
                               TestSystems.singlenode_a_eues, nstderr_tol))

        # Single-region system A - 5 min version

        @test LOLE(shortfall_1a5) ≈ LOLE(shortfall2_1a5)
        @test EUE(shortfall_1a5) ≈ EUE(shortfall2_1a5)
        @test LOLE(shortfall_1a5, "Region") ≈ LOLE(shortfall2_1a5, "Region")
        @test EUE(shortfall_1a5, "Region") ≈ EUE(shortfall2_1a5, "Region")

        @test withinrange(LOLE(shortfall_1a5),
                          TestSystems.singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1a5),
                          TestSystems.singlenode_a_eue/12, nstderr_tol)
        @test withinrange(LOLE(shortfall_1a5, "Region"),
                          TestSystems.singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1a5, "Region"),
                          TestSystems.singlenode_a_eue/12, nstderr_tol)

        @test all(LOLE.(shortfall_1a5, timestampcol_a5) .≈
              LOLE.(shortfall2_1a5, timestampcol_a5))
        @test all(EUE.(shortfall_1a5, timestampcol_a5) .≈
              EUE.(shortfall2_1a5, timestampcol_a5))
        @test all(LOLE.(shortfall_1a5, "Region", timestampcol_a5) .≈
              LOLE.(shortfall2_1a5, "Region", timestampcol_a5))
        @test all(EUE.(shortfall_1a5, "Region", timestampcol_a5) .≈
              EUE.(shortfall2_1a5, "Region", timestampcol_a5))

        @test all(withinrange.(LOLE.(shortfall_1a5, timestampcol_a5),
                               TestSystems.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1a5, timestampcol_a5),
                               TestSystems.singlenode_a_eues ./ 12, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall_1a5, "Region", timestampcol_a5),
                               TestSystems.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1a5, "Region", timestampcol_a5),
                               TestSystems.singlenode_a_eues ./ 12, nstderr_tol))

        # Single-region system B

        @test LOLE(shortfall_1b) ≈ LOLE(shortfall2_1b)
        @test EUE(shortfall_1b) ≈ EUE(shortfall2_1b)
        @test LOLE(shortfall_1b, "Region") ≈ LOLE(shortfall2_1b, "Region")
        @test EUE(shortfall_1b, "Region") ≈ EUE(shortfall2_1b, "Region")

        @test withinrange(LOLE(shortfall_1b),
                          TestSystems.singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1b),
                          TestSystems.singlenode_b_eue, nstderr_tol)
        @test withinrange(LOLE(shortfall_1b, "Region"),
                          TestSystems.singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_1b, "Region"),
                          TestSystems.singlenode_b_eue, nstderr_tol)

        @test all(LOLE.(shortfall_1b, timestampcol_b) .≈
              LOLE.(shortfall2_1b, timestampcol_b))
        @test all(EUE.(shortfall_1b, timestampcol_b) .≈
              EUE.(shortfall2_1b, timestampcol_b))
        @test all(LOLE.(shortfall_1b, "Region", timestampcol_b) .≈
              LOLE.(shortfall2_1b, "Region", timestampcol_b))
        @test all(EUE.(shortfall_1b, "Region", timestampcol_b) .≈
              EUE.(shortfall2_1b, "Region", timestampcol_b))

        @test all(withinrange.(LOLE.(shortfall_1b, timestampcol_b),
                               TestSystems.singlenode_b_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1b, timestampcol_b),
                               TestSystems.singlenode_b_eues, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall_1b, "Region", timestampcol_b),
                               reshape(TestSystems.singlenode_b_lolps, :, 1), nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1b, "Region", timestampcol_b),
                               reshape(TestSystems.singlenode_b_eues, :, 1), nstderr_tol))

        # Three-region system

        @test LOLE(shortfall_3) ≈ LOLE(shortfall2_3)
        @test EUE(shortfall_3) ≈ EUE(shortfall2_3)
        @test all(LOLE.(shortfall_3, regionsrow) .≈ LOLE.(shortfall2_3, regionsrow))
        @test all(EUE.(shortfall_3, regionsrow) .≈ EUE.(shortfall2_3, regionsrow))

        @test withinrange(LOLE(shortfall_3),
                          TestSystems.threenode_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_3),
                          TestSystems.threenode_eue, nstderr_tol)
        @test all(withinrange.(LOLE.(shortfall_3, timestampcol_3),
                               TestSystems.threenode_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_3, timestampcol_3),
                               TestSystems.threenode_eues, nstderr_tol))

        @test all(LOLE.(shortfall_3, timestampcol_3) .≈
              LOLE.(shortfall2_3, timestampcol_3))
        @test all(EUE.(shortfall_3, timestampcol_3) .≈
              EUE.(shortfall2_3, timestampcol_3))
        @test all(LOLE.(shortfall_3, regionsrow, timestampcol_3) .≈
              LOLE.(shortfall2_3, regionsrow, timestampcol_3))
        @test all(EUE.(shortfall_3, regionsrow, timestampcol_3) .≈
              EUE.(shortfall2_3, regionsrow, timestampcol_3))

        @test withinrange(
            LOLE(shortfall_3, "Region C", ZonedDateTime(2018,10,30,1,TestSystems.tz)),
            0.1, nstderr_tol)
        @test withinrange(
            LOLE(shortfall_3, "Region C", ZonedDateTime(2018,10,30,2,TestSystems.tz)),
            0.1, nstderr_tol)

        # TODO:  Test spatially-disaggregated results - may need to develop
        # test systems with unique network flow solutions

        println("SpatioTemporal LOLPs:")
        display(
            vcat(
                hcat("", regionsrow),
                hcat(TestSystems.threenode.timestamps,
                     LOLE.(shortfall_3, regionsrow, timestampcol_3))
        )); println()

        println("SpatioTemporal EUEs:")
        display(
            vcat(
                hcat("", regionsrow),
                hcat(TestSystems.threenode.timestamps,
                     EUE.(shortfall_3, regionsrow, timestampcol_3))
        )); println()

    end

    @testset "Flow and Utilization Results" begin

        # Single-region system A
        @test length(flow_1a.flow_mean) == 0
        @test length(util_1a.utilization_mean) == 0

        @test size(flow2_1a.flow, 1) == 0
        @test size(util2_1a.utilization, 1) == 0

        # Single-region system A (5 minute)
        @test length(flow_1a5.flow_mean) == 0
        @test length(util_1a5.utilization_mean) == 0

        @test size(flow2_1a5.flow, 1) == 0
        @test size(util2_1a5.utilization, 1) == 0

        # Single-region system B
        @test length(flow_1b.flow_mean) == 0
        @test length(util_1b.utilization_mean) == 0

        @test size(flow2_1b.flow, 1) == 0
        @test size(util2_1b.utilization, 1) == 0

        # Three-region system

        interfacesrow = reshape(flow_3.interfaces, 1, :)

        println("Network Flows:")
        display(
            vcat(
                hcat("", interfacesrow),
                hcat(timestampcol_3,
                     getindex.(flow_3, interfacesrow, timestampcol_3))
        )); println()

        @test all(getindex.(flow_3, interfacesrow) .≈
                  getindex.(flow2_3, interfacesrow))
        @test all(getindex.(flow_3, interfacesrow, timestampcol_3) .≈
                  getindex.(flow2_3, interfacesrow, timestampcol_3))

        println("Network Utilizations:")
        display(
            vcat(
                hcat("", interfacesrow),
                hcat(timestampcol_3,
                     getindex.(util_3, interfacesrow, timestampcol_3))
        )); println()

        @test all(getindex.(util_3, interfacesrow) .≈
                  getindex.(util2_3, interfacesrow))
        @test all(getindex.(util_3, interfacesrow, timestampcol_3) .≈
                  getindex.(util2_3, interfacesrow, timestampcol_3))

    end

    @testset "RTS" begin

        sys = SystemModel(dirname(@__FILE__) * "/../../PRASBase/rts.pras")

        assess(sys, SequentialMonteCarlo(samples=1000),
               GeneratorAvailability(), LineAvailability(),
               StorageAvailability(), GeneratorStorageAvailability(),
               StorageEnergy(), GeneratorStorageEnergy(),
               StorageEnergySamples(), GeneratorStorageEnergySamples())

    end

end
