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

    timestamps_a = TestSystems.singlenode_a.timestamps
    timestamps_a5 = TestSystems.singlenode_a_5min.timestamps
    timestamps_b = TestSystems.singlenode_b.timestamps
    timestamps_3 = TestSystems.threenode.timestamps

    timestamprow_a = permutedims(timestamps_a)
    timestamprow_a5 = permutedims(timestamps_a5)
    timestamprow_b = permutedims(timestamps_b)
    timestamprow_3 = permutedims(timestamps_3)

    regionscol = TestSystems.threenode.regions.names

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

        @test all(LOLE.(shortfall_1a, timestamps_a) .≈
                  LOLE.(shortfall2_1a, timestamps_a))
        @test all(EUE.(shortfall_1a, timestamps_a) .≈
                  EUE.(shortfall2_1a, timestamps_a))
        @test all(LOLE(shortfall_1a, "Region", :) .≈
                  LOLE(shortfall2_1a, "Region", :))
        @test all(EUE(shortfall_1a, "Region", :) .≈
                  EUE(shortfall2_1a, "Region", :))

        @test all(withinrange.(LOLE.(shortfall_1a, timestamps_a),
                               TestSystems.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1a, timestamps_a),
                               TestSystems.singlenode_a_eues, nstderr_tol))
        @test all(withinrange.(LOLE(shortfall_1a, "Region", :),
                               TestSystems.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE(shortfall_1a, "Region", :),
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

        @test all(LOLE.(shortfall_1a5, timestamps_a5) .≈
                  LOLE.(shortfall2_1a5, timestamps_a5))
        @test all(EUE.(shortfall_1a5, timestamps_a5) .≈
                  EUE.(shortfall2_1a5, timestamps_a5))
        @test all(LOLE(shortfall_1a5, "Region", :) .≈
                  LOLE(shortfall2_1a5, "Region", :))
        @test all(EUE(shortfall_1a5, "Region", :) .≈
                  EUE(shortfall2_1a5, "Region", :))

        @test all(withinrange.(LOLE.(shortfall_1a5, timestamps_a5),
                               TestSystems.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1a5, timestamps_a5),
                               TestSystems.singlenode_a_eues ./ 12, nstderr_tol))
        @test all(withinrange.(LOLE(shortfall_1a5, "Region", :),
                               TestSystems.singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE(shortfall_1a5, "Region", :),
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

        @test all(LOLE.(shortfall_1b, timestamps_b) .≈
                  LOLE.(shortfall2_1b, timestamps_b))
        @test all(EUE.(shortfall_1b, timestamps_b) .≈
                  EUE.(shortfall2_1b, timestamps_b))
        @test all(LOLE(shortfall_1b, "Region", :) .≈
                  LOLE(shortfall2_1b, "Region", :))
        @test all(EUE(shortfall_1b, "Region", :) .≈
                  EUE(shortfall2_1b, "Region", :))

        @test all(withinrange.(LOLE.(shortfall_1b, timestamps_b),
                               TestSystems.singlenode_b_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_1b, timestamps_b),
                               TestSystems.singlenode_b_eues, nstderr_tol))
        @test all(withinrange.(LOLE(shortfall_1b, "Region", :),
                               TestSystems.singlenode_b_lolps, nstderr_tol))
        @test all(withinrange.(EUE(shortfall_1b, "Region", :),
                               TestSystems.singlenode_b_eues, nstderr_tol))

        # Three-region system

        @test LOLE(shortfall_3) ≈ LOLE(shortfall2_3)
        @test EUE(shortfall_3) ≈ EUE(shortfall2_3)
        @test all(LOLE.(shortfall_3, regionscol) .≈ LOLE.(shortfall2_3, regionscol))
        @test all(EUE.(shortfall_3, regionscol) .≈ EUE.(shortfall2_3, regionscol))

        @test withinrange(LOLE(shortfall_3),
                          TestSystems.threenode_lole, nstderr_tol)
        @test withinrange(EUE(shortfall_3),
                          TestSystems.threenode_eue, nstderr_tol)
        @test all(withinrange.(LOLE.(shortfall_3, timestamps_3),
                               TestSystems.threenode_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall_3, timestamps_3),
                               TestSystems.threenode_eues, nstderr_tol))

        @test all(LOLE.(shortfall_3, timestamps_3) .≈
                  LOLE.(shortfall2_3, timestamps_3))
        @test all(EUE.(shortfall_3, timestamps_3) .≈
                  EUE.(shortfall2_3, timestamps_3))
        @test all(LOLE(shortfall_3, :, :) .≈ LOLE(shortfall2_3, :, :))
        @test all(EUE(shortfall_3, :, :) .≈ EUE(shortfall2_3, :, :))

        @test withinrange(
            LOLE(shortfall_3, "Region C", ZonedDateTime(2018,10,30,1,TestSystems.tz)),
            0.1, nstderr_tol)
        @test withinrange(
            LOLE(shortfall_3, "Region C", ZonedDateTime(2018,10,30,2,TestSystems.tz)),
            0.1, nstderr_tol)

        # TODO:  Test spatially-disaggregated results - may need to develop
        # test systems with unique network flow solutions

        println("SpatioTemporal LOLPs:")

        display(vcat(
            hcat("", timestamprow_3),
            hcat(regionscol, LOLE(shortfall_3, :, :))
        )); println()

        println("SpatioTemporal EUEs:")
        display(vcat(
            hcat("", timestamprow_3),
            hcat(regionscol, EUE(shortfall_3, :, :))
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

        println("Network Flows:")
        display(vcat(
            hcat("", timestamprow_3),
            hcat(flow_3.interfaces, flow_3[:, :])
        )); println()

        @test all(flow_3[:] .≈ flow2_3[:])
        @test all(flow_3[:, :] .≈ flow2_3[:, :])

        println("Network Utilizations:")
        display(vcat(
            hcat("", timestamprow_3),
            hcat(flow_3.interfaces, util_3[:, :])
        )); println()

        @test all(util_3[:] .≈ util2_3[:])
        @test all(util_3[:, :] .≈ util2_3[:, :])

    end

    @testset "RTS" begin

        sys = SystemModel(dirname(@__FILE__) * "/../../PRASBase/rts.pras")

        assess(sys, SequentialMonteCarlo(samples=100),
               GeneratorAvailability(), LineAvailability(),
               StorageAvailability(), GeneratorStorageAvailability(),
               StorageEnergy(), GeneratorStorageEnergy(),
               StorageEnergySamples(), GeneratorStorageEnergySamples())

    end

    @testset "Test System 1: 2 Gens, 2 Regions" begin

        simspec = SequentialMonteCarlo(samples=1_000_000, seed=111)
        dt = first(TestSystems.test1.timestamps)
        regions = TestSystems.test1.regions.names

        shortfall, surplus, flow, utilization =
            assess(TestSystems.test1, simspec,
                   Shortfall(), Surplus(), Flow(), Utilization())

        # Shortfall - LOLE
        @test withinrange(LOLE(shortfall), TestSystems.test1_lole, nstderr_tol)
        @test withinrange(LOLE(shortfall, dt), TestSystems.test1_lole, nstderr_tol)
        @test all(withinrange.(LOLE.(shortfall, regions),
                               TestSystems.test1_loles, nstderr_tol))
        @test all(withinrange.(LOLE.(shortfall, regions, dt),
                               TestSystems.test1_loles, nstderr_tol))
        # Shortfall - EUE
        @test withinrange(EUE(shortfall), TestSystems.test1_eue, nstderr_tol)
        @test withinrange(EUE(shortfall, dt), TestSystems.test1_eue, nstderr_tol)
        @test all(withinrange.(EUE.(shortfall, regions),
                               TestSystems.test1_eues, nstderr_tol))
        @test all(withinrange.(EUE.(shortfall, regions, dt),
                               TestSystems.test1_eues, nstderr_tol))
        # Surplus
        @test withinrange(surplus[dt], TestSystems.test1_esurplus,
                          simspec.nsamples, nstderr_tol)
        @test all(withinrange.(getindex.(surplus, regions, dt),
                               TestSystems.test1_esurpluses,
                               simspec.nsamples, nstderr_tol))

        # Flow
        @test withinrange(flow["Region A" => "Region B"],
                          TestSystems.test1_i1_flow,
                          simspec.nsamples, nstderr_tol)
        @test withinrange(flow["Region A" => "Region B", dt],
                          TestSystems.test1_i1_flow,
                          simspec.nsamples, nstderr_tol)

        # Utilization
        @test withinrange(utilization["Region A" => "Region B"],
                          TestSystems.test1_i1_util,
                          simspec.nsamples, nstderr_tol)
        @test withinrange(utilization["Region A" => "Region B", dt],
                          TestSystems.test1_i1_util,
                          simspec.nsamples, nstderr_tol)

    end

    @testset "Test System 2: Gen + Storage, 1 Region" begin

        simspec = SequentialMonteCarlo(samples=1_000_000, seed=112)
        dts = TestSystems.test2.timestamps

        shortfall, surplus, energy =
            assess(TestSystems.test2, simspec,
                   Shortfall(), Surplus(), Energy())

        # (T1, T2, Overall)

        # Shortfall - LOLE

        # Shortfall - EUE

        # Surplus

        # Energy

    end

    @testset "Test System 3: Gen + Storage, 2 Regions" begin

        simspec = SequentialMonteCarlo(samples=1_000_000, seed=113)
        dts = TestSystems.test3.timestamps
        regions = TestSystems.test3.regions.names

        shortfall, surplus, flow, utilization, energy =
            assess(TestSystems.test3, simspec,
                   Shortfall(), Surplus(), Flow(), Utilization(), Energy())

        # (T1, T2, Overall) x (R1, R2, System)

        # Shortfall - LOLE

        # Shortfall - EUE

        # Surplus

        # Flow

        # Utilization

        # Energy

    end

end
