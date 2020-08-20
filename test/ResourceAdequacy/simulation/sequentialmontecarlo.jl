@testset "SequentialMonteCarlo" begin

    @testset "DispatchProblem" begin

    end

    nstderr_tol = 3

    simspec = SequentialMonteCarlo(samples=100_000, seed=0)
    smallsample = SequentialMonteCarlo(samples=10, seed=123)
    smallsample_alt = SequentialMonteCarlo(samples=10, seed=124)

    timestampcol_a = collect(singlenode_a.timestamps)
    timestampcol_a5 = collect(singlenode_a_5min.timestamps)
    timestampcol_b = collect(singlenode_b.timestamps)
    timestampcol_3 = collect(threenode.timestamps)
    regionsrow = reshape(threenode.regions.names, 1, :)

    @testset "Minimal Result" begin

        # TODO: More test cases with storage
        r1 = assess(smallsample, Minimal(), singlenode_stor)
        r2 = assess(smallsample, Minimal(), singlenode_stor)
        @test EUE(r1) == EUE(r2) # with same seeds, should match exactly

        r3 = assess(smallsample_alt, Minimal(), singlenode_stor)
        @test EUE(r1) != EUE(r3) # with different seeds, should be slightly different

        # Single-region system A
        result_1a = assess(simspec, Minimal(), singlenode_a)
        @test withinrange(LOLE(result_1a), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a), singlenode_a_eue, nstderr_tol)

        # Single-region system A - 5 min version
        result_1a5 = assess(simspec, Minimal(), singlenode_a_5min)
        @test withinrange(LOLE(result_1a5), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a5), singlenode_a_eue/12, nstderr_tol)

        # Single-region system B
        result_1b = assess(simspec, Minimal(), singlenode_b)
        @test withinrange(LOLE(result_1b), singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(result_1b), singlenode_b_eue, nstderr_tol)

        # Three-region system
        result_3 = assess(simspec, Minimal(), threenode)
        @test withinrange(LOLE(result_3), threenode_lole, nstderr_tol)
        @test withinrange(EUE(result_3), threenode_eue, nstderr_tol)

    end

    @testset "Temporal Result" begin

        # Single-region system A
        result_1a = assess(simspec, Temporal(), singlenode_a)
        @test withinrange(LOLE(result_1a), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a), singlenode_a_eue, nstderr_tol)

        @test all(withinrange.(LOLP.(result_1a, timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a, timestampcol_a),
                               singlenode_a_eues, nstderr_tol))

        # Single-region system A - 5 min version
        result_1a5 = assess(simspec, Temporal(), singlenode_a_5min)
        @test withinrange(LOLE(result_1a5), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a5), singlenode_a_eue/12, nstderr_tol)

        @test all(withinrange.(LOLP.(result_1a5, timestampcol_a5),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a5, timestampcol_a5),
                               singlenode_a_eues ./ 12, nstderr_tol))

        # Single-region system B
        result_1b = assess(simspec, Temporal(), singlenode_b)
        @test withinrange(LOLE(result_1b), singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(result_1b), singlenode_b_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1b, timestampcol_b),
                               singlenode_b_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1b, timestampcol_b),
                               singlenode_b_eues, nstderr_tol))

        # Three-region system
        result_3 = assess(simspec, Temporal(), threenode)
        @test withinrange(LOLE(result_3), threenode_lole, nstderr_tol)
        @test withinrange(EUE(result_3), threenode_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_3, timestampcol_3),
                               threenode_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_3, timestampcol_3),
                               threenode_eues, nstderr_tol))

    end

    @testset "SpatioTemporal Result" begin

        # Single-region system A
        result_1a = assess(simspec, SpatioTemporal(), singlenode_a)
        @test withinrange(LOLE(result_1a), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a), singlenode_a_eue, nstderr_tol)
        @test withinrange(LOLE(result_1a, "Region"), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a, "Region"), singlenode_a_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1a, timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a, timestampcol_a),
                               singlenode_a_eues, nstderr_tol))
        @test all(withinrange.(LOLP.(result_1a, "Region", timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a, "Region", timestampcol_a),
                               singlenode_a_eues, nstderr_tol))

        # Single-region system A - 5 min version
        result_1a5 = assess(simspec, SpatioTemporal(), singlenode_a_5min)
        @test withinrange(LOLE(result_1a5), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a5), singlenode_a_eue/12, nstderr_tol)
        @test withinrange(LOLE(result_1a5, "Region"), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a5, "Region"), singlenode_a_eue/12, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1a5, timestampcol_a5),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a5, timestampcol_a5),
                               singlenode_a_eues ./ 12, nstderr_tol))
        @test all(withinrange.(LOLP.(result_1a5, "Region", timestampcol_a5),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a5, "Region", timestampcol_a5),
                               singlenode_a_eues ./ 12, nstderr_tol))

        # Single-region system B
        result_1b = assess(simspec, SpatioTemporal(), singlenode_b)
        @test withinrange(LOLE(result_1b), singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(result_1b), singlenode_b_eue, nstderr_tol)
        @test withinrange(LOLE(result_1b, "Region"), singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(result_1b, "Region"), singlenode_b_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1b, timestampcol_b),
                  singlenode_b_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1b, timestampcol_b),
                               singlenode_b_eues, nstderr_tol))
        @test all(withinrange.(LOLP.(result_1b, "Region", timestampcol_b),
                               reshape(singlenode_b_lolps, :, 1), nstderr_tol))
        @test all(withinrange.(EUE.(result_1b, "Region", timestampcol_b),
                               reshape(singlenode_b_eues, :, 1), nstderr_tol))

        # Three-region system
        result_3 = assess(simspec, SpatioTemporal(), threenode)
        @test withinrange(LOLE(result_3), threenode_lole, nstderr_tol)
        @test withinrange(EUE(result_3), threenode_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_3, timestampcol_3),
                               threenode_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_3, timestampcol_3),
                               threenode_eues, nstderr_tol))

        @test withinrange(LOLP(result_3, "Region C", ZonedDateTime(2018,10,30,1,tz)), 0.1, nstderr_tol)
        @test withinrange(LOLP(result_3, "Region C", ZonedDateTime(2018,10,30,2,tz)), 0.1, nstderr_tol)

        # TODO:  Test spatially-disaggregated results
        println("SpatioTemporal LOLPs:")
        display(
            vcat(
                hcat("", regionsrow),
                hcat(threenode.timestamps,
                     LOLP.(result_3, regionsrow, timestampcol_3))
        )); println()

        println("SpatioTemporal EUEs:")
        display(
            vcat(
                hcat("", regionsrow),
                hcat(threenode.timestamps,
                     EUE.(result_3, regionsrow, timestampcol_3))
        )); println()

    end

    @testset "Network Result" begin

        # Single-region system A
        result_1a = assess(simspec, Network(), singlenode_a)
        @test withinrange(LOLE(result_1a), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a), singlenode_a_eue, nstderr_tol)
        @test withinrange(LOLE(result_1a, "Region"), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a, "Region"), singlenode_a_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1a, timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a, timestampcol_a),
                               singlenode_a_eues, nstderr_tol))
        @test all(withinrange.(LOLP.(result_1a, "Region", timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a, "Region", timestampcol_a),
                               singlenode_a_eues, nstderr_tol))
        @test length(result_1a.flows) == 0
        @test length(result_1a.utilizations) == 0

        # Single-region system A
        result_1a5 = assess(simspec, Network(), singlenode_a_5min)
        @test withinrange(LOLE(result_1a5), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a5), singlenode_a_eue/12, nstderr_tol)
        @test withinrange(LOLE(result_1a5, "Region"), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a5, "Region"), singlenode_a_eue/12, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1a5, timestampcol_a5),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a5, timestampcol_a5),
                               singlenode_a_eues ./ 12, nstderr_tol))
        @test all(withinrange.(LOLP.(result_1a5, "Region", timestampcol_a5),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a5, "Region", timestampcol_a5),
                               singlenode_a_eues ./ 12, nstderr_tol))
        @test length(result_1a5.flows) == 0
        @test length(result_1a5.utilizations) == 0

        # Single-region system B
        result_1b = assess(simspec, Network(), singlenode_b)
        @test withinrange(LOLE(result_1b), singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(result_1b), singlenode_b_eue, nstderr_tol)
        @test withinrange(LOLE(result_1b, "Region"), singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(result_1b, "Region"), singlenode_b_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1b, timestampcol_b),
                  singlenode_b_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1b, timestampcol_b),
                               singlenode_b_eues, nstderr_tol))
        @test all(withinrange.(LOLP.(result_1b, "Region", timestampcol_b),
                               reshape(singlenode_b_lolps, :, 1), nstderr_tol))
        @test all(withinrange.(EUE.(result_1b, "Region", timestampcol_b),
                               reshape(singlenode_b_eues, :, 1), nstderr_tol))
        @test length(result_1b.flows) == 0
        @test length(result_1b.utilizations) == 0

        # Three-region system
        result_3 = assess(simspec, Network(), threenode)
        @test withinrange(LOLE(result_3), threenode_lole, nstderr_tol)
        @test withinrange(EUE(result_3), threenode_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_3, timestampcol_3),
                               threenode_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_3, timestampcol_3),
                               threenode_eues, nstderr_tol))

        @test withinrange(LOLP(result_3, "Region C", ZonedDateTime(2018,10,30,1,tz)), 0.1, nstderr_tol)
        @test withinrange(LOLP(result_3, "Region C", ZonedDateTime(2018,10,30,2,tz)), 0.1, nstderr_tol)

        println("Network ExpectedInterfaceFlows:")
        threenode_interfaces = tuple.(threenode.interfaces.regions_from,
                                      threenode.interfaces.regions_to)
        interfacenamesrow = reshape([(threenode.regions.names[from], threenode.regions.names[to])
                                 for (from, to) in threenode_interfaces],
                                1, :)
        interfacesrow = reshape(threenode_interfaces, 1, :)
        display(
            vcat(
                hcat("", interfacenamesrow),
                hcat(threenode.timestamps,
                     ExpectedInterfaceFlow.(result_3, interfacesrow, timestampcol_3))
        )); println()

        println("Network ExpectedInterfaceUtilizations:")
        display(
            vcat(
                hcat("", interfacenamesrow),
                hcat(threenode.timestamps,
                     ExpectedInterfaceUtilization.(result_3, interfacesrow, timestampcol_3))
        )); println()

    end

    @testset "Debug Result" begin

        # Single-region system A
        result_1a = assess(simspec, Debug(), singlenode_a)
        @test withinrange(LOLE(result_1a), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a), singlenode_a_eue, nstderr_tol)
        @test sum(result_1a.sample_ues)/length(result_1a.sample_ues) ≈ val(EUE(result_1a))
        @test withinrange(LOLE(result_1a, "Region"), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a, "Region"), singlenode_a_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1a, timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a, timestampcol_a),
                               singlenode_a_eues, nstderr_tol))
        @test all(withinrange.(LOLP.(result_1a, "Region", timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a, "Region", timestampcol_a),
                               singlenode_a_eues, nstderr_tol))
        @test length(result_1a.flows) == 0
        @test length(result_1a.utilizations) == 0
        @test length(result_1a.sample_ues) == simspec.nsamples

        # Single-region system A
        result_1a5 = assess(simspec, Debug(), singlenode_a_5min)
        @test withinrange(LOLE(result_1a5), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a5), singlenode_a_eue/12, nstderr_tol)
        @test sum(result_1a5.sample_ues)/length(result_1a5.sample_ues) ≈ val(EUE(result_1a5))
        @test withinrange(LOLE(result_1a5, "Region"), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a5, "Region"), singlenode_a_eue/12, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1a5, timestampcol_a5),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a5, timestampcol_a5),
                               singlenode_a_eues ./ 12, nstderr_tol))
        @test all(withinrange.(LOLP.(result_1a5, "Region", timestampcol_a5),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1a5, "Region", timestampcol_a5),
                               singlenode_a_eues ./ 12, nstderr_tol))
        @test length(result_1a5.flows) == 0
        @test length(result_1a5.utilizations) == 0
        @test length(result_1a5.sample_ues) == simspec.nsamples

        # Single-region system B
        result_1b = assess(simspec, Debug(), singlenode_b)
        @test withinrange(LOLE(result_1b), singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(result_1b), singlenode_b_eue, nstderr_tol)
        @test sum(result_1b.sample_ues)/length(result_1b.sample_ues) ≈ val(EUE(result_1b))
        @test withinrange(LOLE(result_1b, "Region"), singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(result_1b, "Region"), singlenode_b_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1b, timestampcol_b),
                  singlenode_b_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1b, timestampcol_b),
                               singlenode_b_eues, nstderr_tol))
        @test all(withinrange.(LOLP.(result_1b, "Region", timestampcol_b),
                               reshape(singlenode_b_lolps, :, 1), nstderr_tol))
        @test all(withinrange.(EUE.(result_1b, "Region", timestampcol_b),
                               reshape(singlenode_b_eues, :, 1), nstderr_tol))
        @test length(result_1b.flows) == 0
        @test length(result_1b.utilizations) == 0
        @test length(result_1b.sample_ues) == simspec.nsamples

        # Three-region system
        result_3 = assess(simspec, Debug(), threenode)
        @test withinrange(LOLE(result_3), threenode_lole, nstderr_tol)
        @test withinrange(EUE(result_3), threenode_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_3, timestampcol_3),
                               threenode_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_3, timestampcol_3),
                               threenode_eues, nstderr_tol))

        @test withinrange(LOLP(result_3, "Region C", ZonedDateTime(2018,10,30,1,tz)), 0.1, nstderr_tol)
        @test withinrange(LOLP(result_3, "Region C", ZonedDateTime(2018,10,30,2,tz)), 0.1, nstderr_tol)
        @test length(result_3.sample_ues) == simspec.nsamples

        println("Debug ExpectedInterfaceFlows:")
        threenode_interfaces = tuple.(threenode.interfaces.regions_from,
                                      threenode.interfaces.regions_to)
        interfacenamesrow = reshape([(threenode.regions.names[from], threenode.regions.names[to])
                                 for (from, to) in threenode_interfaces],
                                1, :)
        interfacesrow = reshape(threenode_interfaces, 1, :)
        display(
            vcat(
                hcat("", interfacenamesrow),
                hcat(threenode.timestamps,
                     ExpectedInterfaceFlow.(result_3, interfacesrow, timestampcol_3))
        )); println()

        println("Debug ExpectedInterfaceUtilizations:")
        display(
            vcat(
                hcat("", interfacenamesrow),
                hcat(threenode.timestamps,
                     ExpectedInterfaceUtilization.(result_3, interfacesrow, timestampcol_3))
        )); println()

    end

end
